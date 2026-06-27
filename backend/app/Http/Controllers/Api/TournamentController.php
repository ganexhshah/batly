<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\GameMatch;
use App\Models\Notification;
use App\Models\Transaction;
use App\Models\Tournament;
use App\Models\TournamentRegistration;
use App\Models\User;
use App\Services\BattlyCache;
use App\Services\MatchFlowService;
use App\Services\PrizeDistributionService;
use App\Services\TournamentIntegrityService;
use App\Services\WalletLedgerService;
use App\Models\TeamInvite;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Arr;
use Illuminate\Support\Str;

class TournamentController extends Controller
{
    private function prizes(): PrizeDistributionService
    {
        return new PrizeDistributionService;
    }

    private function integrity(): TournamentIntegrityService
    {
        return new TournamentIntegrityService;
    }

    private function matchFlow(): MatchFlowService
    {
        return new MatchFlowService;
    }

    /**
     * List tournaments, optionally filtered by status or type.
     */
    public function index(Request $request): JsonResponse
    {
        $status = $request->input('status');
        $type = $request->input('type');

        $tournaments = BattlyCache::remember(
            BattlyCache::TAG_TOURNAMENTS,
            BattlyCache::tournamentListKey($status, $type),
            BattlyCache::TTL_LIST,
            function () use ($status, $type) {
                $query = Tournament::query()->with('creator')->orderBy('starts_at', 'asc');

                if ($status !== null) {
                    $query->where('status', $status);
                }

                if ($type !== null) {
                    $query->where('type', $type);
                }

                return $query->get()
                    ->map(fn ($t) => $this->formatTournament($t))
                    ->toArray();
            }
        );

        return response()->json([
            'tournaments' => $tournaments,
        ]);
    }

    /**
     * List featured tournaments.
     */
    public function featured(): JsonResponse
    {
        $tournaments = BattlyCache::remember(
            BattlyCache::TAG_TOURNAMENTS,
            'tournaments:featured',
            BattlyCache::TTL_LIST,
            fn () => Tournament::featured()
                ->orderBy('starts_at', 'asc')
                ->get()
                ->map(fn ($t) => $this->formatFeatured($t))
                ->toArray()
        );

        return response()->json([
            'tournaments' => $tournaments,
        ]);
    }

    /**
     * Get a single tournament by ID.
     * Returns participants, registration status, and owner status.
     */
    public function show(Request $request, Tournament $tournament): JsonResponse
    {
        $user = $request->user('sanctum') ?? Auth::guard('sanctum')->user();
        $tournament->loadMissing('creator');

        $shared = BattlyCache::remember(
            BattlyCache::TAG_TOURNAMENTS,
            BattlyCache::tournamentSharedKey($tournament->id),
            BattlyCache::TTL_DETAIL,
            function () use ($tournament) {
                $regs = $tournament->registrations()
                    ->where('status', 'registered')
                    ->get()
                    ->keyBy('user_id');

                $participants = $tournament->activeParticipants()
                    ->get(['users.id', 'users.name', 'users.ign', 'users.game_uid', 'users.avatar_url'])
                    ->map(function ($u) use ($tournament, $regs) {
                        $reg = $regs->get($u->id);

                        return [
                            'id'             => $u->id,
                            'name'           => $u->name,
                            'ign'            => $u->ign,
                            'game_uid'       => $u->game_uid,
                            'avatar_url'     => $u->avatar_url,
                            'is_owner'       => $tournament->created_by === $u->id,
                            'entry_fee_paid' => (float) ($u->pivot->entry_fee_paid ?? 0),
                            'is_ready'       => (bool) ($reg?->is_ready ?? false),
                            'ready_at'       => $reg?->ready_at?->toIso8601String(),
                        ];
                    });

                return [
                    'tournament'   => $this->formatTournament($tournament),
                    'participants' => $this->normalizeParticipants($participants),
                    'owner_id'     => $tournament->created_by,
                ];
            }
        );

        $isRegistered = false;
        $isOwner = false;

        if ($user) {
            $isRegistered = $tournament->registrations()->where('user_id', $user->id)->exists();
            $isOwner = $tournament->created_by === $user->id;
        }

        $canViewRoomCredentials = $isOwner
            || ($isRegistered && $this->integrity()->roomCodesShared($tournament));

        return response()->json([
            'tournament'    => $shared['tournament'],
            'participants'  => $this->normalizeParticipants($shared['participants'] ?? []),
            'is_registered' => $isRegistered,
            'is_owner'      => $isOwner,
            'owner_id'      => $shared['owner_id'],
            'rounds'        => $this->buildRounds($tournament, $canViewRoomCredentials),
            'registration'  => $this->integrity()->registrationMeta($tournament),
            'match_flow'    => $user && ($isRegistered || $isOwner) && $this->matchFlow()->appliesTo($tournament)
                ? $this->matchFlow()->toPublicArray($tournament, $user)
                : ['applies' => $this->matchFlow()->appliesTo($tournament)],
        ]);
    }

    /**
     * Register the authenticated user for a tournament.
     */
    public function register(Request $request, Tournament $tournament): JsonResponse
    {
        $user = $request->user();

        // Owner cannot register as participant in their own tournament
        if ($tournament->created_by === $user->id) {
            return response()->json([
                'message' => 'You are the organizer of this tournament.',
            ], 422);
        }

        // Check if already registered (active registration only)
        if ($tournament->registrations()->where('user_id', $user->id)->where('status', 'registered')->exists()) {
            return response()->json([
                'message' => 'Already registered for this tournament',
            ], 409);
        }

        // Check capacity / registration window
        if (! $this->integrity()->registrationOpen($tournament)) {
            $message = $tournament->current_players >= $tournament->max_players
                ? 'Registration closed — tournament is full (' . $tournament->current_players . '/' . $tournament->max_players . ').'
                : ($this->integrity()->roomCodesShared($tournament)
                    ? 'Registration closed — room codes have already been shared.'
                    : 'Registration is closed for this tournament.');

            return response()->json(['message' => $message], 422);
        }

        $teamCaptainId = null;
        if ($this->integrity()->requiresTeam($tournament)) {
            $acceptedInvite = TeamInvite::query()
                ->where('tournament_id', $tournament->id)
                ->where('invitee_id', $user->id)
                ->where('status', 'accepted')
                ->first();

            if (! $acceptedInvite) {
                return response()->json([
                    'message' => 'You need an accepted team invite before registering for this ' . ($tournament->custom_settings['team_size'] ?? 'team') . ' match.',
                ], 422);
            }

            $teamCaptainId = $acceptedInvite->captain_id;
        }

        $entryFee = $this->parseAmount($tournament->entry_fee);

        try {
            DB::transaction(function () use ($tournament, $user, $entryFee, $teamCaptainId): void {
                $lockedTournament = \App\Models\Tournament::query()
                    ->whereKey($tournament->id)
                    ->lockForUpdate()
                    ->firstOrFail();

                if ($lockedTournament->registrations()->where('user_id', $user->id)->where('status', 'registered')->exists()) {
                    throw new \RuntimeException('Already registered for this tournament');
                }

                if ($lockedTournament->current_players >= $lockedTournament->max_players) {
                    throw new \RuntimeException('Registration closed — tournament is full.');
                }

                if (! $this->integrity()->registrationOpen($lockedTournament)) {
                    throw new \RuntimeException('Registration is closed for this tournament.');
                }

                $transactionId = null;
                if ($entryFee > 0) {
                    $transactionId = WalletLedgerService::entryFee($user, $entryFee, $lockedTournament->id, $lockedTournament->title);
                }

                TournamentRegistration::create([
                    'tournament_id' => $lockedTournament->id,
                    'user_id' => $user->id,
                    'team_captain_id' => $teamCaptainId,
                    'status' => 'registered',
                    'entry_fee_paid' => $entryFee,
                    'transaction_id' => $transactionId,
                ]);

                $lockedTournament->gameMatches()->firstOrCreate(
                    ['user_id' => $user->id],
                    [
                        'round_name' => 'Round 1',
                        'map_name' => 'Bermuda',
                        'round_time' => $lockedTournament->starts_at?->format('g:i A'),
                        'status' => 'scheduled',
                        'played_at' => null,
                    ],
                );

                $lockedTournament->increment('current_players');

                Notification::create([
                    'user_id' => $user->id,
                    'title' => 'Tournament Registration Confirmed',
                    'message' => 'You joined ' . $lockedTournament->title . ($entryFee > 0 ? ' for NPR ' . number_format($entryFee) . '.' : '.'),
                    'type' => 'tournament',
                    'deep_link' => 'tournament:' . $lockedTournament->id,
                    'time' => 'Just Now',
                    'unread' => true,
                    'metadata' => ['tournament_id' => $lockedTournament->id],
                ]);
            });
        } catch (\RuntimeException $e) {
            $code = str_contains($e->getMessage(), 'Already registered') ? 409 : 422;

            return response()->json(['message' => $e->getMessage()], $code);
        }

        BattlyCache::flushTournaments($tournament->id);
        BattlyCache::flushWallet($user->id);
        BattlyCache::flushMatches($user->id);

        $this->matchFlow()->resetToWaitingReadyIfNeeded($tournament->fresh());

        return response()->json([
            'message' => 'Successfully registered for tournament',
        ]);
    }

    /**
     * Leave tournament before registration closes (auto-refund if room codes not shared).
     */
    public function leave(Request $request, Tournament $tournament): JsonResponse
    {
        $user = $request->user();

        if ($tournament->created_by === $user->id) {
            return response()->json(['message' => 'Room maker cannot leave. Cancel the tournament instead.'], 422);
        }

        $registration = $tournament->registrations()->where('user_id', $user->id)->first();
        if (! $registration) {
            return response()->json(['message' => 'You are not registered for this tournament.'], 404);
        }

        if ($registration->status !== 'registered') {
            return response()->json(['message' => 'You are not actively registered for this tournament.'], 422);
        }

        if (! $this->integrity()->canLeave($tournament)) {
            return response()->json([
                'message' => $this->integrity()->roomCodesShared($tournament)
                    ? 'Cannot leave after room codes have been shared. No refund available.'
                    : 'Cannot leave this tournament at the current stage.',
            ], 422);
        }

        $entryFee = (float) $registration->entry_fee_paid;

        try {
            DB::transaction(function () use ($tournament, $user, $entryFee): void {
                $lockedReg = TournamentRegistration::query()
                    ->where('tournament_id', $tournament->id)
                    ->where('user_id', $user->id)
                    ->lockForUpdate()
                    ->firstOrFail();

                if ($lockedReg->status !== 'registered') {
                    throw new \RuntimeException('Not actively registered.');
                }

                $fee = (float) $lockedReg->entry_fee_paid;
                if ($fee > 0) {
                    WalletLedgerService::refund(
                        $user,
                        $fee,
                        $tournament->id,
                        $tournament->title,
                        'Left tournament before start',
                    );
                }

                $lockedReg->update(['status' => 'left', 'left_at' => now(), 'entry_fee_paid' => 0]);
                $tournament->gameMatches()->where('user_id', $user->id)->delete();
                $tournament->decrement('current_players');
            });
        } catch (\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        BattlyCache::flushTournaments($tournament->id);
        BattlyCache::flushWallet($user->id);
        BattlyCache::flushMatches($user->id);

        $this->matchFlow()->syncReadyPhase($tournament->fresh());

        return response()->json([
            'message' => $entryFee > 0
                ? 'You left the tournament. NPR ' . number_format($entryFee) . ' refunded to your wallet.'
                : 'You left the tournament.',
        ]);
    }

    /**
     * Mark self as ready before match start.
     */
    public function setReady(Request $request, Tournament $tournament): JsonResponse
    {
        $user = $request->user();
        $registration = $tournament->registrations()->where('user_id', $user->id)->first();

        if (! $registration) {
            return response()->json(['message' => 'You are not registered for this tournament.'], 404);
        }

        if (! in_array($tournament->status, ['registration', 'upcoming', 'live'], true)) {
            return response()->json(['message' => 'Ready check is not available for this tournament stage.'], 422);
        }

        $ready = $request->boolean('ready', true);
        $registration->update([
            'is_ready' => $ready,
            'ready_at' => $ready ? now() : null,
        ]);

        BattlyCache::flushTournaments();

        $this->matchFlow()->syncReadyPhase($tournament->fresh());

        return response()->json([
            'message' => $ready ? 'You are marked as ready.' : 'Ready status cleared.',
            'is_ready' => $ready,
        ]);
    }

    /**
     * Room maker views ready-check status for all participants.
     */
    public function readyStatus(Request $request, Tournament $tournament): JsonResponse
    {
        $user = $request->user();
        $isOwner = $tournament->created_by === $user->id;
        $isRegistered = $tournament->registrations()->where('user_id', $user->id)->exists();

        if (! $isOwner && ! $isRegistered) {
            return response()->json(['message' => 'Unauthorized'], 403);
        }

        $players = $tournament->registrations()
            ->with('user:id,name,ign,avatar_url')
            ->get()
            ->map(fn ($reg) => [
                'user_id' => $reg->user_id,
                'name' => $reg->user?->ign ?: $reg->user?->name,
                'avatar_url' => $reg->user?->avatar_url,
                'is_ready' => (bool) $reg->is_ready,
                'ready_at' => $reg->ready_at?->toIso8601String(),
                'is_owner' => $reg->user_id === $tournament->created_by,
            ]);

        $readyCount = $players->where('is_ready', true)->count();

        return response()->json([
            'players' => $players->values(),
            'ready_count' => $readyCount,
            'total_count' => $players->count(),
        ]);
    }

    // ── Owner / Management Endpoints ─────────────────────────────────

    /**
     * Remove a participant from the tournament (owner or staff).
     */
    public function removeParticipant(Request $request, Tournament $tournament, User $user): JsonResponse
    {
        $authUser = $request->user();

        if (! in_array(strtolower((string) $authUser->role), ['admin', 'moderator', 'host'], true)
            && $tournament->created_by !== $authUser->id) {
            return response()->json(['message' => 'Unauthorized'], 403);
        }

        if ($tournament->created_by === $user->id) {
            return response()->json(['message' => 'Room maker cannot be removed from their own match.'], 422);
        }

        if (in_array($tournament->status, ['completed', 'cancelled'], true)) {
            return response()->json(['message' => 'Cannot remove players from a finished tournament.'], 422);
        }

        $registration = $tournament->registrations()->where('user_id', $user->id)->first();
        if (! $registration) {
            return response()->json(['message' => 'Participant not found'], 404);
        }

        $entryFee = (float) $registration->entry_fee_paid;

        DB::transaction(function () use ($tournament, $user, $entryFee): void {
            $lockedReg = TournamentRegistration::query()
                ->where('tournament_id', $tournament->id)
                ->where('user_id', $user->id)
                ->lockForUpdate()
                ->firstOrFail();

            $fee = (float) $lockedReg->entry_fee_paid;
            if ($fee > 0) {
                WalletLedgerService::refund(
                    $user,
                    $fee,
                    $tournament->id,
                    $tournament->title,
                    'Refund after removal from ' . $tournament->title,
                );
            }

            $lockedReg->delete();
            $tournament->gameMatches()->where('user_id', $user->id)->delete();
            $tournament->decrement('current_players');

            Notification::create([
                'user_id' => $user->id,
                'title' => 'Removed from Tournament',
                'message' => 'You were removed from "' . $tournament->title . '".' . ($entryFee > 0 ? ' NPR ' . number_format($entryFee) . ' refunded to your wallet.' : ''),
                'type' => 'tournament',
                'deep_link' => 'tournament:' . $tournament->id,
                'time' => 'Just Now',
                'unread' => true,
                'metadata' => ['tournament_id' => $tournament->id],
            ]);
        });

        BattlyCache::flushTournaments($tournament->id);
        BattlyCache::flushWallet($user->id);
        BattlyCache::flushMatches($user->id);

        $this->matchFlow()->syncReadyPhase($tournament->fresh());

        return response()->json(['message' => 'Participant removed successfully']);
    }

    /**
     * Update the room code / password for the tournament (owner only).
     */
    public function updateRoomCode(Request $request, Tournament $tournament): JsonResponse
    {
        $authUser = $request->user();

        if ($tournament->created_by !== $authUser->id) {
            return response()->json(['message' => 'Unauthorized'], 403);
        }

        if ($this->matchFlow()->appliesTo($tournament)) {
            $this->matchFlow()->syncReadyPhase($tournament->fresh());
            $tournament = $tournament->fresh();

            $flow = $this->matchFlow()->getFlow($tournament);
            if ($flow['phase'] !== MatchFlowService::PHASE_SHARING_CODES) {
                return response()->json([
                    'message' => 'Room codes can only be shared after all players are ready.',
                ], 422);
            }
            if (! $this->matchFlow()->allRegisteredReady($tournament)) {
                return response()->json([
                    'message' => 'All registered players must be ready before sharing room codes.',
                ], 422);
            }
        }

        $validated = $request->validate([
            'room_id'       => ['nullable', 'string', 'max:50'],
            'room_password' => ['nullable', 'string', 'max:50'],
        ]);

        // Store inside custom_settings
        $settings = $tournament->custom_settings ?? [];
        $existingRoomId = trim((string) ($settings['room_id'] ?? ''));
        $existingRoomPassword = trim((string) ($settings['room_password'] ?? ''));

        if ($existingRoomId !== '' || $existingRoomPassword !== '') {
            return response()->json([
                'message' => 'Room ID and password cannot be changed after they have been shared with players.',
            ], 422);
        }

        if (isset($validated['room_id'])) {
            $settings['room_id'] = $validated['room_id'];
        }
        if (isset($validated['room_password'])) {
            $settings['room_password'] = $validated['room_password'];
        }

        $tournament->update(['custom_settings' => $settings + [
            'room_codes_shared_at' => now()->toIso8601String(),
        ]]);

        if ($this->matchFlow()->appliesTo($tournament)) {
            $this->matchFlow()->onRoomCodesShared($tournament->fresh());
        }

        BattlyCache::flushTournaments($tournament->id);

        $roomId = $settings['room_id'] ?? '';
        $roomPassword = $settings['room_password'] ?? '';
        if ($roomId !== '' || $roomPassword !== '') {
            $this->notifyParticipants(
                $tournament,
                'Room Code Updated',
                'Room details for "' . $tournament->title . '": ID ' . ($roomId ?: 'N/A') . ', Password ' . ($roomPassword ?: 'N/A'),
                'tournament:' . $tournament->id,
            );
        }

        return response()->json([
            'message'         => 'Room code updated successfully',
            'tournament'      => $this->formatTournament($tournament->fresh()),
        ]);
    }

    /**
     * Update tournament status (owner only).
     */
    public function updateStatus(Request $request, Tournament $tournament): JsonResponse
    {
        $authUser = $request->user();

        if ($tournament->created_by !== $authUser->id) {
            return response()->json(['message' => 'Unauthorized'], 403);
        }

        $validated = $request->validate([
            'status' => ['required', 'string', 'in:registration,upcoming,live,completed,cancelled'],
        ]);

        $newStatus = $validated['status'];
        $oldStatus = $tournament->status;

        if ($oldStatus === $newStatus) {
            return response()->json([
                'message' => 'Status is already ' . strtoupper($newStatus),
                'tournament' => $this->formatTournament($tournament),
            ]);
        }

        if ($newStatus === 'cancelled') {
            if (in_array($oldStatus, ['completed', 'live'], true)) {
                return response()->json(['message' => 'Cannot cancel a tournament that is live or completed.'], 422);
            }

            $settings = $tournament->custom_settings ?? [];
            if (! empty($settings['results_approved_at']) || ! empty($settings['results_locked_at'])) {
                return response()->json(['message' => 'Cannot cancel — results have already been finalized.'], 422);
            }
        }

        DB::transaction(function () use ($tournament, $newStatus, $oldStatus): void {
            $tournament->update(['status' => $newStatus]);

            if ($newStatus === 'live') {
                $tournament->gameMatches()->where('status', 'scheduled')->update(['status' => 'live']);
            }

            if ($newStatus === 'completed') {
                $tournament->gameMatches()
                    ->whereIn('status', ['scheduled', 'live', 'pending_verification'])
                    ->update(['status' => 'completed']);
            }

            if ($newStatus === 'cancelled') {
                $this->refundAllParticipants($tournament, 'Tournament cancelled by room maker');
                $tournament->gameMatches()->update(['status' => 'cancelled']);
            }
        });

        $statusLabels = [
            'registration' => 'Registration Open',
            'upcoming' => 'Upcoming',
            'live' => 'Live Now',
            'completed' => 'Completed',
            'cancelled' => 'Cancelled',
        ];

        $this->notifyParticipants(
            $tournament->fresh(),
            'Tournament Status Updated',
            '"' . $tournament->title . '" is now ' . ($statusLabels[$newStatus] ?? strtoupper($newStatus)) . '.',
            'tournament:' . $tournament->id,
        );

        BattlyCache::flushTournaments($tournament->id);

        return response()->json([
            'message'    => 'Status updated successfully',
            'tournament' => $this->formatTournament($tournament->fresh()),
        ]);
    }

    /**
     * Get tournament leaderboard and the authenticated user's result.
     */
    public function results(Request $request, Tournament $tournament): JsonResponse
    {
        $user = $request->user();
        $role = strtolower((string) $user->role);
        $isStaff = in_array($role, ['admin', 'moderator', 'host'], true);
        $isOwner = $tournament->created_by === $user->id;
        $isRegistered = $tournament->registrations()
            ->where('user_id', $user->id)
            ->where('status', 'registered')
            ->exists();

        if (! $isOwner && ! $isRegistered && ! $isStaff) {
            return response()->json(['message' => 'Unauthorized'], 403);
        }

        $matches = $tournament->gameMatches()->with('user')->get()->keyBy('user_id');
        $participants = $tournament->activeParticipants()->get(['users.id', 'users.name', 'users.ign', 'users.avatar_url', 'users.game_uid']);

        $leaderboard = $participants->map(function ($p) use ($tournament, $matches) {
            $match = $matches->get($p->id);
            $rankNum = $match?->rank ? (int) preg_replace('/\D/', '', (string) $match->rank) : null;

            return [
                'user_id'      => $p->id,
                'name'         => $p->name,
                'ign'          => $p->ign,
                'game_uid'     => $p->game_uid,
                'avatar_url'   => $p->avatar_url,
                'is_owner'     => $tournament->created_by === $p->id,
                'rank'         => $rankNum,
                'kills'        => $match?->kills !== null ? (int) $match->kills : null,
                'points'       => $match?->points,
                'status'       => $match?->status ?? 'scheduled',
                'prize_amount' => (float) ($match?->prize_amount ?? 0),
                'match_id'     => $match?->id,
            ];
        })->sort(function ($a, $b) {
            $ptsA = $a['points'] ?? -1;
            $ptsB = $b['points'] ?? -1;
            if ($ptsB !== $ptsA) {
                return $ptsB <=> $ptsA;
            }

            return ($a['rank'] ?? 999) <=> ($b['rank'] ?? 999);
        })->values()->all();

        $myMatch = $matches->get($user->id);
        $isOwner = $tournament->created_by === $user->id;
        $isRegistered = $tournament->registrations()->where('user_id', $user->id)->exists();
        $resultsLocked = $this->integrity()->resultsLocked($tournament);

        return response()->json([
            'leaderboard'        => $leaderboard,
            'my_result'          => $myMatch ? $this->formatResultRow($myMatch, $tournament) : null,
            'results_published'  => $tournament->status === 'completed',
            'results_locked'     => $resultsLocked,
            'can_submit'         => $isRegistered
                && ! $isOwner
                && ! $resultsLocked
                && in_array($tournament->status, ['live', 'completed'], true)
                && ($myMatch === null || in_array($myMatch->status, ['scheduled', 'rejected'], true)),
            'can_manage_results' => $isOwner
                && $tournament->status !== 'cancelled'
                && ! $resultsLocked,
            'is_owner'           => $isOwner,
        ]);
    }

    /**
     * Room maker submits results for admin review (anti-cheat). Prizes are NOT paid yet.
     */
    public function publishResults(Request $request, Tournament $tournament): JsonResponse
    {
        if ($tournament->created_by !== $request->user()->id) {
            return response()->json(['message' => 'Unauthorized'], 403);
        }

        if ($this->integrity()->resultsLocked($tournament)) {
            return response()->json(['message' => 'Results are locked after admin approval.'], 422);
        }

        if ($tournament->status === 'cancelled') {
            return response()->json(['message' => 'Cannot publish results for a cancelled tournament.'], 422);
        }

        $settings = $tournament->custom_settings ?? [];
        if (! empty($settings['results_submitted_at']) && empty($settings['results_rejected_at'])) {
            return response()->json(['message' => 'Results are already submitted and awaiting admin review.'], 422);
        }

        $validated = $request->validate([
            'results'           => ['required', 'array', 'min:1'],
            'results.*.user_id' => ['required', 'integer'],
            'results.*.rank'    => ['required', 'integer', 'min:1', 'max:100'],
            'results.*.kills'   => ['required', 'integer', 'min:0', 'max:100'],
            'results.*.points'  => ['required', 'integer', 'min:0', 'max:500'],
        ]);

        $registeredIds = $tournament->registrations()
            ->where('status', 'registered')
            ->pluck('user_id')
            ->map(fn ($id) => (int) $id)
            ->all();
        $seenRanks = [];

        foreach ($validated['results'] as $row) {
            $userId = (int) $row['user_id'];
            $rank = (int) $row['rank'];

            if (! in_array($userId, $registeredIds, true)) {
                return response()->json([
                    'message' => "User {$userId} is not a registered participant.",
                ], 422);
            }

            if (in_array($rank, $seenRanks, true)) {
                return response()->json(['message' => 'Duplicate ranks are not allowed.'], 422);
            }

            $seenRanks[] = $rank;
        }

        DB::transaction(function () use ($request, $tournament, $validated, $settings): void {
            foreach ($validated['results'] as $row) {
                $match = $tournament->gameMatches()->firstOrCreate(
                    ['user_id' => $row['user_id']],
                    [
                        'round_name' => 'Round 1',
                        'map_name'   => $settings['map'] ?? 'Bermuda',
                        'round_time' => $tournament->starts_at?->format('g:i A'),
                        'status'     => 'scheduled',
                    ],
                );

                $prizeAmount = $this->prizes()->prizeForRank($tournament, (int) $row['rank']);

                $match->update([
                    'rank'         => '#' . $row['rank'],
                    'kills'        => (string) $row['kills'],
                    'points'       => $row['points'],
                    'status'       => 'pending_admin_review',
                    'verified_by'  => null,
                    'verified_at'  => null,
                    'played_at'    => now(),
                    'prize_amount' => $prizeAmount,
                    'rejected_reason' => null,
                ]);
            }

            $tournament->update([
                'custom_settings' => $settings + [
                    'results_submitted_at' => now()->toIso8601String(),
                    'results_submitted_by' => $request->user()->id,
                    'results_rejected_at' => null,
                ],
            ]);

            $this->notifyParticipants(
                $tournament->fresh(),
                'Results Submitted',
                'Results for "' . $tournament->title . '" were submitted and are pending admin review.',
                'tournament:' . $tournament->id,
            );
        });

        BattlyCache::flushTournaments();
        BattlyCache::flushAdmin();

        return response()->json([
            'message' => 'Results submitted for admin review. Prizes will be credited after approval.',
            'tournament' => $this->formatTournament($tournament->fresh()),
        ]);
    }

    /**
     * Admin approves submitted results and credits prizes.
     */
    public function approveResults(Request $request, Tournament $tournament): JsonResponse
    {
        $settings = $tournament->custom_settings ?? [];
        if (empty($settings['results_submitted_at'])) {
            return response()->json(['message' => 'No submitted results to approve.'], 422);
        }

        if (! empty($settings['results_approved_at'])) {
            return response()->json(['message' => 'Results already approved.'], 422);
        }

        try {
            DB::transaction(function () use ($request, $tournament, $settings): void {
                $locked = Tournament::query()->whereKey($tournament->id)->lockForUpdate()->firstOrFail();
                $lockedSettings = $locked->custom_settings ?? [];

                if (! empty($lockedSettings['results_approved_at'])) {
                    throw new \RuntimeException('Results already approved.');
                }

                $pending = $locked->gameMatches()->where('status', 'pending_admin_review')->get();
                if ($pending->isEmpty()) {
                    throw new \RuntimeException('No pending match results to approve.');
                }

                foreach ($pending as $match) {
                    $prizeAmount = (float) $match->prize_amount;

                    $match->update([
                        'status' => 'verified',
                        'verified_by' => $request->user()->id,
                        'verified_at' => now(),
                    ]);

                    $transactionId = WalletLedgerService::prizeForMatch(
                        $match,
                        $prizeAmount,
                        $locked->id,
                        $locked->title,
                    );

                    if ($transactionId && $match->user) {
                        BattlyCache::flushMatches($match->user_id);

                        Notification::create([
                            'user_id'   => $match->user_id,
                            'title'     => 'Prize Credited!',
                            'message'   => 'You won NPR ' . number_format($prizeAmount) . ' in "' . $locked->title . '".',
                            'type'      => 'match_result',
                            'deep_link' => 'tournament:' . $locked->id,
                            'time'      => 'Just Now',
                            'unread'    => true,
                            'metadata'  => ['tournament_id' => $locked->id, 'prize_amount' => $prizeAmount],
                        ]);
                    }
                }

                $locked->update([
                    'status' => 'completed',
                    'custom_settings' => $lockedSettings + [
                        'results_approved_at' => now()->toIso8601String(),
                        'results_approved_by' => $request->user()->id,
                        'results_locked_at' => now()->toIso8601String(),
                    ],
                ]);

                $locked->gameMatches()
                    ->whereNotIn('status', ['verified'])
                    ->update(['status' => 'completed']);

                $this->notifyParticipants(
                    $locked->fresh(),
                    'Results Approved',
                    'Final results for "' . $locked->title . '" are confirmed. Check your rank and prize!',
                    'tournament:' . $locked->id,
                );
            });
        } catch (\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        $this->matchFlow()->syncCompletedFromAdminApproval($tournament->fresh());

        BattlyCache::flushTournaments();
        BattlyCache::flushAdmin();

        return response()->json([
            'message' => 'Results approved and prizes credited.',
            'tournament' => $this->formatTournament($tournament->fresh()),
        ]);
    }

    /**
     * Admin lists tournaments awaiting bulk result approval.
     */
    public function pendingResults(Request $request): JsonResponse
    {
        $tournaments = Tournament::query()
            ->with(['creator:id,name,ign', 'gameMatches.user:id,name,ign'])
            ->whereNotNull('custom_settings->results_submitted_at')
            ->whereNull('custom_settings->results_approved_at')
            ->orderByDesc('updated_at')
            ->get()
            ->map(function (Tournament $t) {
                $settings = $t->custom_settings ?? [];
                $leaderboard = $t->gameMatches
                    ->where('status', 'pending_admin_review')
                    ->map(fn ($m) => [
                        'user_id' => $m->user_id,
                        'name' => $m->user?->ign ?: $m->user?->name,
                        'rank' => $m->rank,
                        'kills' => $m->kills,
                        'points' => $m->points,
                        'prize_amount' => (float) ($m->prize_amount ?? 0),
                    ])
                    ->values()
                    ->all();

                return [
                    'id' => $t->id,
                    'title' => $t->title,
                    'status' => $t->status,
                    'current_players' => $t->current_players,
                    'max_players' => $t->max_players,
                    'prize_pool' => $t->prize_pool,
                    'submitted_at' => $settings['results_submitted_at'] ?? null,
                    'host' => $t->creator?->ign ?: $t->creator?->name,
                    'leaderboard' => $leaderboard,
                ];
            });

        return response()->json(['tournaments' => $tournaments]);
    }

    /**
     * Admin rejects submitted results so host can resubmit.
     */
    public function rejectResults(Request $request, Tournament $tournament): JsonResponse
    {
        $validated = $request->validate([
            'reason' => ['nullable', 'string', 'max:2000'],
        ]);

        $settings = $tournament->custom_settings ?? [];
        if (empty($settings['results_submitted_at'])) {
            return response()->json(['message' => 'No submitted results to reject.'], 422);
        }

        DB::transaction(function () use ($request, $tournament, $settings, $validated): void {
            $tournament->gameMatches()
                ->where('status', 'pending_admin_review')
                ->update(['status' => 'rejected', 'rejected_reason' => $validated['reason'] ?? 'Rejected by admin. Please resubmit.']);

            $tournament->update([
                'custom_settings' => $settings + [
                    'results_rejected_at' => now()->toIso8601String(),
                    'results_rejected_by' => $request->user()->id,
                    'results_rejection_reason' => $validated['reason'] ?? 'Rejected by admin.',
                ],
            ]);

            if ($tournament->created_by) {
                Notification::create([
                    'user_id' => $tournament->created_by,
                    'title' => 'Results Rejected',
                    'message' => 'Submitted results for "' . $tournament->title . '" were rejected. Please review and resubmit.',
                    'type' => 'tournament',
                    'deep_link' => 'tournament:' . $tournament->id,
                    'time' => 'Just Now',
                    'unread' => true,
                    'metadata' => ['tournament_id' => $tournament->id],
                ]);
            }
        });

        BattlyCache::flushTournaments();
        BattlyCache::flushAdmin();

        return response()->json([
            'message' => 'Results rejected. Host can resubmit.',
            'tournament' => $this->formatTournament($tournament->fresh()),
        ]);
    }

    /**
     * Cancel tournament when minimum players not met (refunds all).
     */
    public function cancelUnderfilled(Request $request, Tournament $tournament): JsonResponse
    {
        if ($tournament->created_by !== $request->user()->id) {
            return response()->json(['message' => 'Unauthorized'], 403);
        }

        if (in_array($tournament->status, ['completed', 'cancelled', 'live'], true)) {
            return response()->json(['message' => 'Cannot cancel this tournament at its current stage.'], 422);
        }

        $minPlayers = min(2, max(1, (int) $tournament->max_players));
        if ($tournament->current_players >= $minPlayers) {
            return response()->json([
                'message' => 'Cannot cancel — minimum player count (' . $minPlayers . ') is met.',
            ], 422);
        }

        DB::transaction(function () use ($tournament): void {
            $this->refundAllParticipants($tournament, 'Tournament cancelled — not enough players');
            $tournament->update(['status' => 'cancelled']);
            $tournament->gameMatches()->update(['status' => 'cancelled']);
        });

        $this->notifyParticipants(
            $tournament->fresh(),
            'Tournament Cancelled',
            '"' . $tournament->title . '" was cancelled due to insufficient players. Entry fees refunded.',
            'tournament:' . $tournament->id,
        );

        BattlyCache::flushTournaments();
        BattlyCache::flushAdmin();

        return response()->json([
            'message' => 'Tournament cancelled and all players refunded.',
            'tournament' => $this->formatTournament($tournament->fresh()),
        ]);
    }

    // ── Admin Endpoints ──────────────────────────────────────────────

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'title'           => ['required', 'string', 'max:255'],
            'game'            => ['required', 'string', 'max:255'],
            'stage'           => ['required', 'string', 'max:255'],
            'type'            => ['required', 'string', 'in:Solo,Duo,Squad'],
            'mode'            => ['required', 'string', 'max:255'],
            'prize_pool'      => ['required', 'string', 'max:255'],
            'entry_fee'       => ['nullable', 'string', 'max:255'],
            'max_players'     => ['required', 'integer', 'min:2'],
            'starts_at'       => ['required', 'date'],
            'status'          => ['required', 'string', 'in:registration,upcoming,live,completed,cancelled'],
            'is_featured'     => ['nullable', 'boolean'],
            'logo_asset'      => ['nullable', 'string'],
            'image_path'      => ['nullable', 'string'],
            'custom_settings' => ['nullable', 'array'],
        ]);

        $user = $request->user();
        $validated['created_by'] = $user->id;

        $isAdminRoute = str_starts_with($request->path(), 'api/admin/');
        if (! $isAdminRoute) {
            $validated['status'] = 'registration';
            $validated['is_featured'] = false;
            if (isset($validated['custom_settings']) && is_array($validated['custom_settings'])) {
                $validated['custom_settings'] = $this->sanitizeUserCustomSettings($validated['custom_settings']);
            }
        }

        if (in_array($validated['mode'] ?? '', ['Custom Room', 'Lone Wolf'], true)) {
            $custom = $validated['custom_settings'] ?? [];
            $custom['match_flow'] = $this->matchFlow()->initialState();
            $validated['custom_settings'] = $custom;
        }

        $entryFee = $this->parseAmount($validated['entry_fee'] ?? null);

        try {
            $tournament = DB::transaction(function () use ($validated, $user, $entryFee) {
                $tournament = Tournament::create($validated);

                $transactionId = null;
                if ($entryFee > 0) {
                    $transactionId = WalletLedgerService::entryFee(
                        $user,
                        $entryFee,
                        $tournament->id,
                        $tournament->title,
                    );
                }

                TournamentRegistration::create([
                'tournament_id'  => $tournament->id,
                'user_id'        => $user->id,
                'status'         => 'registered',
                'entry_fee_paid' => $entryFee,
                'transaction_id' => $transactionId,
            ]);

            $tournament->gameMatches()->create([
                'user_id'    => $user->id,
                'round_name' => 'Round 1',
                'map_name'   => 'Bermuda',
                'round_time' => $tournament->starts_at?->format('g:i A'),
                'status'     => 'scheduled',
                'played_at'  => null,
            ]);

            $tournament->increment('current_players');

            Notification::create([
                'user_id'    => $user->id,
                'title'      => 'Match Room Created',
                'message'    => 'Your match "' . $tournament->title . '" is live. You are registered as room maker.' . ($entryFee > 0 ? ' Entry fee NPR ' . number_format($entryFee) . ' deducted.' : ''),
                'type'       => 'tournament',
                'deep_link'  => 'tournament:' . $tournament->id,
                'time'       => 'Just Now',
                'unread'     => true,
            ]);

            return $tournament;
            });
        } catch (\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        // Invalidate caches
        BattlyCache::flushTournaments();
        BattlyCache::flushWallet($user->id);
        BattlyCache::flushMatches($user->id);
        BattlyCache::flushAdmin();

        return response()->json([
            'message'    => 'Tournament published successfully!',
            'tournament' => $this->formatTournament($tournament->fresh()),
        ], 201);
    }

    public function update(Request $request, Tournament $tournament): JsonResponse
    {
        $validated = $request->validate([
            'title'           => ['sometimes', 'string', 'max:255'],
            'game'            => ['sometimes', 'string', 'max:255'],
            'stage'           => ['sometimes', 'string', 'max:255'],
            'type'            => ['sometimes', 'string', 'in:Solo,Duo,Squad'],
            'mode'            => ['sometimes', 'string', 'max:255'],
            'prize_pool'      => ['sometimes', 'string', 'max:255'],
            'entry_fee'       => ['sometimes', 'nullable', 'string', 'max:255'],
            'max_players'     => ['sometimes', 'integer', 'min:2'],
            'starts_at'       => ['sometimes', 'date'],
            'status'          => ['sometimes', 'string', 'in:registration,upcoming,live,completed,cancelled'],
            'is_featured'     => ['sometimes', 'boolean'],
            'logo_asset'      => ['sometimes', 'nullable', 'string'],
            'image_path'      => ['sometimes', 'nullable', 'string'],
            'custom_settings' => ['sometimes', 'nullable', 'array'],
        ]);

        $role = strtolower((string) $request->user()->role);
        $isPrivilegedStaff = in_array($role, ['admin', 'moderator'], true);

        if (! $isPrivilegedStaff) {
            unset($validated['status'], $validated['is_featured']);
            if (isset($validated['custom_settings']) && is_array($validated['custom_settings'])) {
                $validated['custom_settings'] = $this->sanitizeUserCustomSettings($validated['custom_settings']);
            }
        }

        if (isset($validated['custom_settings']) && is_array($validated['custom_settings'])) {
            $existing = $tournament->custom_settings ?? [];
            $validated['custom_settings'] = array_merge($existing, $validated['custom_settings']);
        }

        $tournament->update($validated);

        // Invalidate caches
        BattlyCache::flushTournaments();

        return response()->json([
            'message'    => 'Tournament updated successfully!',
            'tournament' => $this->formatTournament($tournament->fresh()),
        ]);
    }

    public function destroy(Tournament $tournament): JsonResponse
    {
        DB::transaction(function () use ($tournament): void {
            if (! in_array($tournament->status, ['completed', 'cancelled'], true)) {
                $this->refundAllParticipants($tournament, 'Tournament deleted by admin');
            }
            $tournament->delete();
        });

        try {
            BattlyCache::flushTournaments();
        } catch (\Throwable) {
            // Deletion succeeded; cache will expire naturally if Redis is unavailable.
        }

        return response()->json(['message' => 'Tournament deleted successfully.']);
    }

    /** @param array<string, mixed> $settings */
    private function sanitizeUserCustomSettings(array $settings): array
    {
        $allowed = ['team_size', 'map', 'rounds', 'prize_distribution', 'chat_open'];

        return array_intersect_key($settings, array_flip($allowed));
    }

    // ── Formatters ───────────────────────────────────────────────────

    private function normalizeParticipants(mixed $participants): array
    {
        if ($participants instanceof \Illuminate\Support\Collection) {
            $participants = $participants->values()->all();
        }

        if (! is_array($participants)) {
            return [];
        }

        return array_values(array_filter(array_map(function ($item) {
            if (is_array($item)) {
                return $item;
            }

            if (is_object($item) && method_exists($item, 'toArray')) {
                return $item->toArray();
            }

            return null;
        }, $participants)));
    }

    private function formatTournament(Tournament $t): array
    {
        $creator = $t->creator;
        return [
            'id'              => $t->id,
            'title'           => $t->title,
            'game'            => $t->game,
            'stage'           => $t->stage,
            'type'            => $t->type,
            'mode'            => $t->mode,
            'dateText'        => $t->starts_at->format('d M, Y • g:i A'),
            'currentPlayers'  => $t->current_players,
            'maxPlayers'      => $t->max_players,
            'prizePool'       => $t->prize_pool,
            'entryFee'        => $t->entry_fee ?? 'Free',
            'statusText'      => strtoupper($t->status),
            'timerSeconds'    => max(0, now()->diffInSeconds($t->starts_at, false)),
            'starts_at'       => $t->starts_at->toIso8601String(),
            'created_at'      => $t->created_at->toIso8601String(),
            'logoAsset'       => $t->logo_asset,
            'imagePath'       => $t->image_path,
            'isFeatured'      => $t->is_featured,
            'customSettings'  => Arr::except($t->custom_settings ?? [], [
                'room_id',
                'room_password',
                'room_codes_shared_at',
            ]),
            'createdBy'       => $t->created_by,
            'creatorName'     => $creator ? ($creator->ign ?: $creator->name) : null,
            'creatorAvatar'   => $creator ? $creator->avatar_url : null,
            'prizeDistribution' => $this->prizes()->toArray($t),
            'registration'    => $this->integrity()->registrationMeta($t),
            'resultsPendingReview' => ! empty($t->custom_settings['results_submitted_at'])
                && empty($t->custom_settings['results_approved_at']),
            'resultsLocked' => $this->integrity()->resultsLocked($t),
            'chatOpen' => $this->integrity()->chatOpen($t),
            'matchFlowApplies' => $this->matchFlow()->appliesTo($t),
            'matchFlowPhase' => $this->matchFlow()->appliesTo($t)
                ? $this->matchFlow()->getFlow($t)['phase']
                : null,
        ];
    }

    private function formatFeatured(Tournament $t): array
    {
        return [
            'id'        => $t->id,
            'title'     => $t->title,
            'prizePool' => $t->prize_pool,
            'dateText'  => $t->starts_at->format('d M, Y • g:i A'),
            'isLive'    => $t->status === 'live',
            'imagePath' => $t->image_path ?? 'assets/Untitled (1080 x 900 px) (1080 x 600 px).png',
        ];
    }

    private function parseAmount(?string $value): float
    {
        if ($value === null) {
            return 0;
        }

        return (float) preg_replace('/[^0-9.]/', '', $value);
    }

    private function buildRounds(Tournament $tournament, bool $includeCredentials = false): array
    {
        $settings = $tournament->custom_settings ?? [];
        $round = [
            'name' => 'Round 1',
            'map' => $settings['map'] ?? 'Bermuda',
            'time' => $tournament->starts_at?->format('g:i A'),
            'status' => $tournament->status,
        ];

        if ($includeCredentials) {
            $round['room_id'] = $settings['room_id'] ?? null;
            $round['room_password'] = $settings['room_password'] ?? null;
        }

        return [$round];
    }

    private function notifyParticipants(
        Tournament $tournament,
        string $title,
        string $message,
        ?string $deepLink = null,
    ): void {
        $userIds = $tournament->registrations()->pluck('user_id');

        foreach ($userIds as $userId) {
            Notification::create([
                'user_id' => $userId,
                'title' => $title,
                'message' => $message,
                'type' => 'tournament',
                'deep_link' => $deepLink ?? ('tournament:' . $tournament->id),
                'time' => 'Just Now',
                'unread' => true,
                'metadata' => ['tournament_id' => $tournament->id],
            ]);
        }
    }

    private function refundAllParticipants(Tournament $tournament, string $reason): void
    {
        $registrations = $tournament->registrations()->with('user')->get();

        foreach ($registrations as $registration) {
            $entryFee = (float) $registration->entry_fee_paid;
            if ($entryFee <= 0 || ! $registration->user) {
                continue;
            }

            WalletLedgerService::refund(
                $registration->user,
                $entryFee,
                $tournament->id,
                $tournament->title,
                $reason,
            );

            $registration->update(['entry_fee_paid' => 0]);
        }
    }

    private function formatResultRow(GameMatch $match, Tournament $tournament): array
    {
        $rankNum = $match->rank ? (int) preg_replace('/\D/', '', (string) $match->rank) : null;

        return [
            'match_id'     => $match->id,
            'user_id'      => $match->user_id,
            'rank'         => $rankNum,
            'kills'        => $match->kills !== null ? (int) $match->kills : null,
            'points'       => $match->points,
            'status'       => $match->status,
            'prize_amount' => (float) $match->prize_amount,
            'proof_images' => $match->proof_images ?? [],
            'rejected_reason' => $match->rejected_reason,
        ];
    }

    private function calculatePrizeForRank(Tournament $tournament, int $rank): float
    {
        return $this->prizes()->prizeForRank($tournament, $rank);
    }
}
