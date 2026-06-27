<?php

namespace App\Services;

use App\Models\GameMatch;
use App\Models\MatchDispute;
use App\Models\Notification;
use App\Models\Tournament;
use App\Models\TournamentRegistration;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use InvalidArgumentException;

class MatchFlowService
{
    public const PHASE_WAITING_READY = 'waiting_ready';

    public const PHASE_SHARING_CODES = 'sharing_codes';

    public const PHASE_WAITING_IN_GAME = 'waiting_in_game';

    public const PHASE_LIVE = 'live';

    public const PHASE_ADMIN_STOP_REVIEW = 'admin_stop_review';

    public const PHASE_RESULT_VOTE = 'result_vote';

    public const PHASE_PROOF_REVIEW = 'proof_review';

    public const PHASE_COMPLETED = 'completed';

    public const MATCH_DURATION_MINUTES = 25;

    public const STOP_ADMIN_MINUTES = 15;

    public function appliesTo(Tournament $tournament): bool
    {
        $mode = (string) $tournament->mode;

        return in_array($mode, ['Custom Room', 'Lone Wolf'], true);
    }

    /** @return array<string, mixed> */
    public function initialState(): array
    {
        return [
            'phase' => self::PHASE_WAITING_READY,
            'match_started_at' => null,
            'match_ends_at' => null,
            'stop_clicked_by' => [],
            'stop_admin_deadline_at' => null,
            'winner_votes' => [],
            'in_game_confirmed_by' => [],
            'proofs' => [],
            'completed_winner_id' => null,
        ];
    }

    public function getFlow(Tournament $tournament): array
    {
        $settings = $tournament->custom_settings ?? [];

        return array_merge($this->initialState(), $settings['match_flow'] ?? []);
    }

    public function saveFlow(Tournament $tournament, array $flow): Tournament
    {
        return DB::transaction(function () use ($tournament, $flow) {
            $locked = Tournament::query()->whereKey($tournament->id)->lockForUpdate()->firstOrFail();
            $settings = $locked->custom_settings ?? [];
            $settings['match_flow'] = $flow;
            $locked->update(['custom_settings' => $settings]);

            return $locked->fresh();
        });
    }

    public function isCustomRoom(Tournament $tournament): bool
    {
        return $this->appliesTo($tournament);
    }

    /** @return list<int> */
    public function representatives(Tournament $tournament): array
    {
        $hostId = (int) $tournament->created_by;
        $regs = $tournament->registrations()
            ->where('status', 'registered')
            ->get();

        $reps = [$hostId];

        $opponentCaptainIds = $regs
            ->where('user_id', '!=', $hostId)
            ->pluck('team_captain_id')
            ->filter()
            ->unique()
            ->values();

        if ($opponentCaptainIds->isNotEmpty()) {
            foreach ($opponentCaptainIds as $captainId) {
                $reps[] = (int) $captainId;
            }
        } else {
            foreach ($regs as $reg) {
                if ((int) $reg->user_id !== $hostId) {
                    $reps[] = (int) $reg->user_id;
                }
            }
        }

        return array_values(array_unique($reps));
    }

    public function isRepresentative(Tournament $tournament, int $userId): bool
    {
        return in_array($userId, $this->representatives($tournament), true);
    }

    public function allRegisteredReady(Tournament $tournament): bool
    {
        $regs = $tournament->registrations()
            ->where('status', 'registered')
            ->where('user_id', '!=', $tournament->created_by)
            ->get();

        if ($regs->isEmpty()) {
            return true;
        }

        return $regs->every(fn (TournamentRegistration $r) => (bool) $r->is_ready);
    }

    public function resetToWaitingReadyIfNeeded(Tournament $tournament): void
    {
        if (! $this->appliesTo($tournament)) {
            return;
        }

        $flow = $this->getFlow($tournament);
        if ($flow['phase'] === self::PHASE_SHARING_CODES) {
            $flow['phase'] = self::PHASE_WAITING_READY;
            $this->saveFlow($tournament, $flow);
        }
    }

    public function syncReadyPhase(Tournament $tournament): void
    {
        if (! $this->appliesTo($tournament)) {
            return;
        }

        $flow = $this->getFlow($tournament);
        if ($flow['phase'] !== self::PHASE_WAITING_READY) {
            return;
        }

        if ($this->allRegisteredReady($tournament)) {
            $flow['phase'] = self::PHASE_SHARING_CODES;
            $this->saveFlow($tournament, $flow);
        }
    }

    public function onRoomCodesShared(Tournament $tournament): void
    {
        if (! $this->appliesTo($tournament)) {
            return;
        }

        $flow = $this->getFlow($tournament);
        if ($flow['phase'] !== self::PHASE_SHARING_CODES) {
            return;
        }

        $flow['phase'] = self::PHASE_WAITING_IN_GAME;
        $this->saveFlow($tournament, $flow);
    }

    public function confirmInGame(Tournament $tournament, User $user): Tournament
    {
        if (! $this->isRepresentative($tournament, $user->id)) {
            throw new InvalidArgumentException('Only a team representative can confirm in-game.');
        }

        $flow = $this->getFlow($tournament);
        if ($flow['phase'] !== self::PHASE_WAITING_IN_GAME) {
            throw new InvalidArgumentException('In-game confirmation is not available at this stage.');
        }

        $confirmed = $flow['in_game_confirmed_by'] ?? [];
        if (in_array($user->id, $confirmed, true)) {
            throw new InvalidArgumentException('You already confirmed in-game.');
        }

        $confirmed[] = $user->id;
        $flow['in_game_confirmed_by'] = array_values(array_unique($confirmed));

        $reps = $this->representatives($tournament);
        if (count(array_intersect($reps, $flow['in_game_confirmed_by'])) >= count($reps)) {
            $flow = $this->startLiveMatch($tournament, $flow);
        } else {
            $this->saveFlow($tournament, $flow);
        }

        return $tournament->fresh();
    }

    /** @param array<string, mixed> $flow */
    private function startLiveMatch(Tournament $tournament, array $flow): array
    {
        $started = now();
        $flow['phase'] = self::PHASE_LIVE;
        $flow['match_started_at'] = $started->toIso8601String();
        $flow['match_ends_at'] = $started->copy()->addMinutes(self::MATCH_DURATION_MINUTES)->toIso8601String();
        $flow['stop_clicked_by'] = [];

        $tournament->update(['status' => 'live']);
        $tournament->gameMatches()->where('status', 'scheduled')->update(['status' => 'live']);

        $this->saveFlow($tournament, $flow);
        $this->notifyAll($tournament, 'Match Started', 'Your match "' . $tournament->title . '" is now live. Good luck!');

        return $flow;
    }

    public function recordStop(Tournament $tournament, User $user): Tournament
    {
        if (! $this->isRepresentative($tournament, $user->id)) {
            throw new InvalidArgumentException('Only a team representative can stop the match.');
        }

        $flow = $this->getFlow($tournament);
        if ($flow['phase'] !== self::PHASE_LIVE) {
            throw new InvalidArgumentException('Stop is only available during a live match.');
        }

        $endsAt = isset($flow['match_ends_at']) ? \Carbon\Carbon::parse($flow['match_ends_at']) : null;
        $timerExpired = $endsAt && now()->gte($endsAt);

        $stopped = $flow['stop_clicked_by'] ?? [];
        if (in_array($user->id, $stopped, true)) {
            throw new InvalidArgumentException('You already tapped Stop.');
        }

        $stopped[] = $user->id;
        $flow['stop_clicked_by'] = array_values(array_unique($stopped));

        $reps = $this->representatives($tournament);
        $allStopped = count(array_intersect($reps, $flow['stop_clicked_by'])) >= count($reps);

        if ($allStopped) {
            $flow['phase'] = self::PHASE_RESULT_VOTE;
            $flow['stop_admin_deadline_at'] = null;
            $this->saveFlow($tournament, $flow);
            $this->notifyAll($tournament, 'Match Ended', 'Both sides stopped the match. Vote for the winner.');

            return $tournament->fresh();
        }

        if (! $timerExpired) {
            $this->saveFlow($tournament, $flow);

            return $tournament->fresh();
        }

        // Timer expired, only one side stopped
        $flow['phase'] = self::PHASE_ADMIN_STOP_REVIEW;
        $flow['stop_admin_deadline_at'] = now()->addMinutes(self::STOP_ADMIN_MINUTES)->toIso8601String();
        $this->saveFlow($tournament, $flow);
        $this->openStopReviewDispute($tournament, $user);
        $this->notifyAll(
            $tournament,
            'Match Stop — Review',
            'One player ended the match. Respond within ' . self::STOP_ADMIN_MINUTES . ' minutes or the stopper may receive the prize.',
        );

        return $tournament->fresh();
    }

    public function acknowledgeStop(Tournament $tournament, User $user): Tournament
    {
        if (! $this->isRepresentative($tournament, $user->id)) {
            throw new InvalidArgumentException('Only a team representative can acknowledge.');
        }

        $flow = $this->getFlow($tournament);
        if ($flow['phase'] !== self::PHASE_ADMIN_STOP_REVIEW) {
            throw new InvalidArgumentException('No stop review is pending.');
        }

        $stopper = $flow['stop_clicked_by'][0] ?? null;
        if ($stopper && (int) $stopper === $user->id) {
            throw new InvalidArgumentException('The player who tapped Stop cannot acknowledge.');
        }

        $flow['phase'] = self::PHASE_RESULT_VOTE;
        $flow['stop_admin_deadline_at'] = null;
        $this->saveFlow($tournament, $flow);

        return $tournament->fresh();
    }

    /**
     * @param  'self'|'opponent'  $claim
     */
    public function voteWinner(Tournament $tournament, User $user, string $claim): Tournament
    {
        if (! $this->isRepresentative($tournament, $user->id)) {
            throw new InvalidArgumentException('Only a team representative can vote.');
        }

        $flow = $this->getFlow($tournament);
        if ($flow['phase'] !== self::PHASE_RESULT_VOTE) {
            throw new InvalidArgumentException('Winner voting is not open.');
        }

        $votes = $flow['winner_votes'] ?? [];
        if (isset($votes[(string) $user->id])) {
            throw new InvalidArgumentException('You already submitted your vote.');
        }

        $winnerId = $claim === 'self' ? $user->id : $this->opponentUserId($tournament, $user->id);
        if ($winnerId === null) {
            throw new InvalidArgumentException('Could not resolve opponent.');
        }

        $votes[(string) $user->id] = $winnerId;
        $flow['winner_votes'] = $votes;

        $reps = $this->representatives($tournament);
        $allVoted = count($votes) >= count($reps);

        if (! $allVoted) {
            $this->saveFlow($tournament, $flow);

            return $tournament->fresh();
        }

        $winnerIds = array_values(array_unique(array_map('intval', $votes)));
        if (count($winnerIds) === 1) {
            return $this->completeWithWinner($tournament, $winnerIds[0], $flow);
        }

        $flow['phase'] = self::PHASE_PROOF_REVIEW;
        $this->saveFlow($tournament, $flow);
        $this->openResultDisputesForConflict($tournament, $reps);
        $this->notifyAll($tournament, 'Proof Required', 'Players disagreed on the winner. Submit screenshot proof for admin review.');

        return $tournament->fresh();
    }

    /** @param list<string> $proofUrls */
    public function submitProof(Tournament $tournament, User $user, array $proofUrls): Tournament
    {
        if (! $this->isRepresentative($tournament, $user->id)) {
            throw new InvalidArgumentException('Only a team representative can submit proof.');
        }

        $flow = $this->getFlow($tournament);
        if ($flow['phase'] !== self::PHASE_PROOF_REVIEW) {
            throw new InvalidArgumentException('Proof submission is not open.');
        }

        $proofs = $flow['proofs'] ?? [];
        if (isset($proofs[(string) $user->id])) {
            throw new InvalidArgumentException('You already submitted proof.');
        }

        $proofs[(string) $user->id] = [
            'urls' => $proofUrls,
            'submitted_at' => now()->toIso8601String(),
        ];
        $flow['proofs'] = $proofs;

        $match = $tournament->gameMatches()->firstOrCreate(
            ['user_id' => $user->id],
            [
                'round_name' => 'Round 1',
                'map_name' => 'Bermuda',
                'round_time' => $tournament->starts_at?->format('g:i A'),
                'status' => 'scheduled',
            ],
        );

        $match->update([
            'rank' => null,
            'kills' => null,
            'points' => null,
            'status' => 'pending_admin_review',
            'verified_by' => null,
            'verified_at' => null,
            'played_at' => now(),
            'prize_amount' => 0,
            'rejected_reason' => null,
            'proof_images' => $proofUrls,
        ]);

        MatchDispute::updateOrCreate(
            [
                'tournament_id' => $tournament->id,
                'user_id' => $user->id,
                'type' => 'wrong_result',
            ],
            [
                'game_match_id' => $match->id,
                'reason' => 'Match flow: player submitted proof claiming victory.',
                'proof_images' => $proofUrls,
                'status' => 'open',
            ],
        );

        $settings = $tournament->custom_settings ?? [];
        $tournament->update([
            'custom_settings' => $settings + [
                'match_flow' => $flow,
                'results_submitted_at' => $settings['results_submitted_at'] ?? now()->toIso8601String(),
            ],
        ]);

        return $tournament->fresh();
    }

    public function completeWithWinner(Tournament $tournament, int $winnerUserId, ?array $flow = null): Tournament
    {
        $flow ??= $this->getFlow($tournament);
        if (($flow['phase'] ?? null) === self::PHASE_COMPLETED) {
            return $tournament->fresh();
        }

        $prizes = new PrizeDistributionService;

        DB::transaction(function () use ($tournament, $winnerUserId, $flow, $prizes): void {
            $regs = $tournament->registrations()->where('status', 'registered')->pluck('user_id');

            foreach ($regs as $userId) {
                $uid = (int) $userId;
                $isWinner = $uid === $winnerUserId;
                $playerRank = $isWinner ? 1 : 2;
                $prizeAmount = $isWinner ? $prizes->prizeForRank($tournament, 1) : 0.0;

                $match = $tournament->gameMatches()->firstOrCreate(
                    ['user_id' => $uid],
                    [
                        'round_name' => 'Round 1',
                        'map_name' => 'Bermuda',
                        'round_time' => $tournament->starts_at?->format('g:i A'),
                        'status' => 'scheduled',
                    ],
                );

                $match->update([
                    'rank' => '#' . $playerRank,
                    'kills' => $isWinner ? '1' : '0',
                    'points' => $isWinner ? 100 : 0,
                    'status' => 'verified',
                    'verified_at' => now(),
                    'played_at' => now(),
                    'prize_amount' => $prizeAmount,
                ]);

                if ($prizeAmount > 0) {
                    $txnId = WalletLedgerService::prizeForMatch(
                        $match,
                        $prizeAmount,
                        $tournament->id,
                        $tournament->title,
                    );
                    if ($txnId) {
                        BattlyCache::flushWallet($uid);
                        BattlyCache::flushMatches($uid);

                        Notification::create([
                            'user_id' => $uid,
                            'title' => 'Prize Credited!',
                            'message' => 'You won NPR ' . number_format($prizeAmount) . ' in "' . $tournament->title . '".',
                            'type' => 'match_result',
                            'deep_link' => 'tournament:' . $tournament->id,
                            'time' => 'Just Now',
                            'unread' => true,
                            'metadata' => ['tournament_id' => $tournament->id],
                        ]);
                    }
                }
            }

            $flow['phase'] = self::PHASE_COMPLETED;
            $flow['completed_winner_id'] = $winnerUserId;

            $settings = $tournament->custom_settings ?? [];
            $tournament->update([
                'status' => 'completed',
                'custom_settings' => $settings + [
                    'match_flow' => $flow,
                    'results_approved_at' => now()->toIso8601String(),
                    'results_locked_at' => now()->toIso8601String(),
                ],
            ]);

            $tournament->gameMatches()
                ->where('status', '!=', 'verified')
                ->update(['status' => 'completed']);
        });

        BattlyCache::flushTournaments();
        $this->notifyAll($tournament, 'Match Completed', 'Results are final for "' . $tournament->title . '".');

        return $tournament->fresh();
    }

    public function processExpiredStopReviews(): int
    {
        $count = 0;
        $tournaments = Tournament::query()
            ->whereIn('status', ['registration', 'upcoming', 'live'])
            ->get()
            ->filter(fn (Tournament $t) => $this->appliesTo($t));

        foreach ($tournaments as $tournament) {
            $flow = $this->getFlow($tournament);
            if ($flow['phase'] !== self::PHASE_ADMIN_STOP_REVIEW) {
                continue;
            }

            $deadline = $flow['stop_admin_deadline_at'] ?? null;
            if (! $deadline || now()->lt(\Carbon\Carbon::parse($deadline))) {
                continue;
            }

            $stopperId = (int) ($flow['stop_clicked_by'][0] ?? 0);
            if ($stopperId > 0) {
                $this->completeWithWinner($tournament, $stopperId);
                $count++;
            }
        }

        return $count;
    }

    public function opponentUserId(Tournament $tournament, int $userId): ?int
    {
        $reps = $this->representatives($tournament);
        foreach ($reps as $repId) {
            if ($repId !== $userId) {
                return $repId;
            }
        }

        return null;
    }

    /** @return array<string, mixed> */
    public function toPublicArray(Tournament $tournament, ?User $user): array
    {
        $flow = $this->getFlow($tournament);
        $reps = $this->representatives($tournament);
        $endsAt = isset($flow['match_ends_at']) ? \Carbon\Carbon::parse($flow['match_ends_at']) : null;
        $timerExpired = $endsAt && now()->gte($endsAt);
        $secondsRemaining = $endsAt ? max(0, now()->diffInSeconds($endsAt, false)) : null;

        $settings = $tournament->custom_settings ?? [];
        $canViewCredentials = $user && (
            $tournament->created_by === $user->id
            || ($tournament->registrations()->where('user_id', $user->id)->exists()
                && ! empty($settings['room_codes_shared_at']))
        );

        $readyPlayers = $tournament->registrations()
            ->with('user:id,name,ign,avatar_url')
            ->where('status', 'registered')
            ->get()
            ->map(fn (TournamentRegistration $reg) => [
                'user_id' => $reg->user_id,
                'name' => $reg->user?->ign ?: $reg->user?->name,
                'avatar_url' => $reg->user?->avatar_url,
                'is_ready' => (bool) $reg->is_ready,
                'is_owner' => $reg->user_id === $tournament->created_by,
                'is_representative' => in_array($reg->user_id, $reps, true),
            ]);

        return [
            'applies' => $this->appliesTo($tournament),
            'phase' => $flow['phase'],
            'is_owner' => $user && $tournament->created_by === $user->id,
            'is_representative' => $user && $this->isRepresentative($tournament, $user->id),
            'representatives' => $reps,
            'all_ready' => $this->allRegisteredReady($tournament),
            'ready_players' => $readyPlayers->values()->all(),
            'ready_count' => $readyPlayers->where('is_ready', true)->count(),
            'total_players' => $readyPlayers->count(),
            'max_players' => $tournament->max_players,
            'room_id' => $canViewCredentials ? ($settings['room_id'] ?? null) : null,
            'room_password' => $canViewCredentials ? ($settings['room_password'] ?? null) : null,
            'room_codes_shared' => ! empty($settings['room_codes_shared_at']),
            'in_game_confirmed_by' => $flow['in_game_confirmed_by'] ?? [],
            'stop_clicked_by' => $flow['stop_clicked_by'] ?? [],
            'stop_admin_deadline_at' => $flow['stop_admin_deadline_at'] ?? null,
            'winner_votes' => (object) ($flow['winner_votes'] ?? []),
            'my_vote' => $user ? ($flow['winner_votes'][(string) $user->id] ?? null) : null,
            'my_in_game_confirmed' => $user && in_array($user->id, $flow['in_game_confirmed_by'] ?? [], true),
            'my_stop_clicked' => $user && in_array($user->id, $flow['stop_clicked_by'] ?? [], true),
            'match_started_at' => $flow['match_started_at'] ?? null,
            'match_ends_at' => $flow['match_ends_at'] ?? null,
            'timer_expired' => $timerExpired,
            'seconds_remaining' => $secondsRemaining,
            'completed_winner_id' => $flow['completed_winner_id'] ?? null,
            'proofs_submitted' => array_keys($flow['proofs'] ?? []),
            'my_proof_submitted' => $user && isset(($flow['proofs'] ?? [])[(string) $user->id]),
            'tournament_status' => $tournament->status,
        ];
    }

    private function notifyAll(Tournament $tournament, string $title, string $message): void
    {
        $userIds = $tournament->registrations()->pluck('user_id');
        foreach ($userIds as $userId) {
            Notification::create([
                'user_id' => $userId,
                'title' => $title,
                'message' => $message,
                'type' => 'tournament',
                'deep_link' => 'tournament:' . $tournament->id,
                'time' => 'Just Now',
                'unread' => true,
                'metadata' => ['tournament_id' => $tournament->id],
            ]);
        }
    }

    /** @param list<int> $representativeIds */
    private function openResultDisputesForConflict(Tournament $tournament, array $representativeIds): void
    {
        foreach ($representativeIds as $repId) {
            $rep = User::find($repId);
            if (! $rep) {
                continue;
            }

            MatchDispute::firstOrCreate(
                [
                    'tournament_id' => $tournament->id,
                    'user_id' => $rep->id,
                    'type' => 'wrong_result',
                ],
                [
                    'reason' => 'Match flow: both sides claimed victory. Submit proof for admin review.',
                    'proof_images' => [],
                    'status' => 'open',
                ],
            );
        }
    }

    private function openStopReviewDispute(Tournament $tournament, User $stopper): void
    {
        MatchDispute::firstOrCreate(
            [
                'tournament_id' => $tournament->id,
                'user_id' => $stopper->id,
                'type' => 'wrong_result',
            ],
            [
                'reason' => 'Match flow: one-sided stop after timer. Opponent has '
                    . self::STOP_ADMIN_MINUTES
                    . ' minutes to acknowledge or stopper may receive prize.',
                'proof_images' => [],
                'status' => 'open',
            ],
        );
    }

    public function syncCompletedFromAdminApproval(Tournament $tournament): void
    {
        if (! $this->appliesTo($tournament)) {
            return;
        }

        $flow = $this->getFlow($tournament);
        if ($flow['phase'] === self::PHASE_COMPLETED) {
            return;
        }

        $winnerMatch = $tournament->gameMatches()
            ->where('status', 'verified')
            ->get()
            ->sortBy(fn (GameMatch $m) => (int) ltrim((string) $m->rank, '#'))
            ->first();

        $flow['phase'] = self::PHASE_COMPLETED;
        $flow['completed_winner_id'] = $winnerMatch?->user_id;
        $this->saveFlow($tournament, $flow);
    }
}
