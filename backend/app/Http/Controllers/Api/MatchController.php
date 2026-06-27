<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\GameMatch;
use App\Services\BattlyCache;
use App\Services\PrizeDistributionService;
use App\Services\TournamentIntegrityService;
use App\Models\Notification;
use App\Models\Transaction;
use App\Models\Tournament;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class MatchController extends Controller
{
    /**
     * List the authenticated user's match history.
     */
    public function index(Request $request): JsonResponse
    {
        $userId = $request->user()->id;
        $matches = BattlyCache::remember(
            BattlyCache::TAG_MATCHES,
            BattlyCache::userMatchesKey($userId),
            BattlyCache::TTL_LIST,
            fn () => GameMatch::where('user_id', $userId)
                ->with('tournament')
                ->orderByRaw('CASE WHEN played_at IS NULL THEN 0 ELSE 1 END')
                ->orderBy('played_at', 'desc')
                ->get()
                ->map(fn ($m) => $this->formatMatch($m))
                ->values()
                ->all(),
        );

        return response()->json([
            'matches' => $matches,
        ]);
    }

    /**
     * Get a single match by ID.
     */
    public function show(Request $request, GameMatch $match): JsonResponse
    {
        // Ensure the match belongs to the authenticated user
        if ($match->user_id !== $request->user()->id) {
            return response()->json(['message' => 'Unauthorized'], 403);
        }

        return response()->json([
            'match' => $this->formatMatch($match->load('tournament')),
        ]);
    }

    public function submitResult(Request $request, GameMatch $match): JsonResponse
    {
        if ($match->user_id !== $request->user()->id) {
            return response()->json(['message' => 'Unauthorized'], 403);
        }

        $tournament = $match->tournament;
        if ($tournament && app(TournamentIntegrityService::class)->resultsLocked($tournament)) {
            return response()->json(['message' => 'Results are locked after admin approval.'], 422);
        }

        $validated = $request->validate([
            'rank' => ['required', 'integer', 'min:1', 'max:100'],
            'kills' => ['required', 'integer', 'min:0', 'max:100'],
            'points' => ['required', 'integer', 'min:0', 'max:500'],
            'round_name' => ['nullable', 'string', 'max:100'],
            'map_name' => ['nullable', 'string', 'max:100'],
            'round_time' => ['nullable', 'string', 'max:100'],
            'proof_images' => ['nullable', 'array'],
            'proof_images.*' => ['string', 'max:2000'],
            'proof_files' => ['nullable', 'array'],
            'proof_files.*' => ['file', 'image', 'max:5120'],
            'notes' => ['nullable', 'string', 'max:2000'],
        ]);

        $proofImages = $validated['proof_images'] ?? [];
        if ($request->hasFile('proof_files')) {
            $diskName = config('filesystems.default');
            $disk = Storage::disk($diskName);

            foreach ($request->file('proof_files') as $file) {
                $path = $file->store('match-proofs', $diskName);
                $proofImages[] = $disk->url($path);
            }
        }

        $match->update([
            'rank' => '#' . $validated['rank'],
            'kills' => (string) $validated['kills'],
            'points' => $validated['points'],
            'round_name' => $validated['round_name'] ?? $match->round_name,
            'map_name' => $validated['map_name'] ?? $match->map_name,
            'round_time' => $validated['round_time'] ?? $match->round_time,
            'proof_images' => $proofImages,
            'notes' => $validated['notes'] ?? null,
            'status' => 'pending_verification',
            'played_at' => null,
            'verified_by' => null,
            'verified_at' => null,
            'rejected_reason' => null,
        ]);

        Notification::create([
            'title' => 'Result Pending Verification',
            'message' => $request->user()->name . ' submitted results for ' . ($match->tournament->title ?? 'a tournament') . '.',
            'type' => 'match_result',
            'time' => 'Just Now',
            'unread' => true,
            'metadata' => ['match_id' => $match->id, 'tournament_id' => $match->tournament_id],
        ]);

        BattlyCache::flushMatches($match->user_id);

        return response()->json([
            'message' => 'Result submitted for admin verification.',
            'match' => $this->formatMatch($match->fresh(['tournament'])),
        ]);
    }

    public function submitTournamentResult(Request $request, Tournament $tournament): JsonResponse
    {
        $match = $tournament->gameMatches()->firstOrCreate(
            ['user_id' => $request->user()->id],
            [
                'round_name' => $request->input('round_name', 'Round 1'),
                'map_name' => $request->input('map_name', 'Bermuda'),
                'round_time' => $request->input('round_time', $tournament->starts_at?->format('g:i A')),
                'status' => 'scheduled',
            ],
        );

        return $this->submitResult($request, $match);
    }

    public function verificationStatus(Request $request, GameMatch $match): JsonResponse
    {
        if ($match->user_id !== $request->user()->id) {
            return response()->json(['message' => 'Unauthorized'], 403);
        }

        return response()->json([
            'match' => $this->formatMatch($match->load('tournament')),
            'status' => $match->status,
            'proof_images' => $match->proof_images ?? [],
            'rejected_reason' => $match->rejected_reason,
            'prize_amount' => (float) $match->prize_amount,
        ]);
    }

    // ── Admin Endpoints ──────────────────────────────────────────────

    public function listAllMatches(): JsonResponse
    {
        $matches = GameMatch::with(['tournament', 'user'])->orderBy('updated_at', 'desc')->get()->map(function ($m) {
            $status = match ($m->status) {
                'verified' => 'Verified',
                'rejected' => 'Rejected',
                'pending_verification' => 'Pending Verification',
                default => 'Scheduled',
            };

            return [
                'id'              => 'M-' . $m->id,
                'tournament'      => $m->tournament->title ?? 'Tournament',
                'teamA'           => $m->user->name ?? 'Player',
                'teamB'           => $m->user->ign ?? 'Opponent',
                'game'            => $m->tournament->game ?? 'BGMI',
                'score'           => $m->rank,
                'kills'           => $m->kills,
                'points'          => $m->points,
                'roundName'       => $m->round_name,
                'mapName'         => $m->map_name,
                'roundTime'       => $m->round_time,
                'status'          => $status,
                'screenshotProof' => $m->proof_images[0] ?? null,
                'proofImages'     => $m->proof_images ?? [],
                'notes'           => $m->notes,
                'prizeAmount'     => (float) $m->prize_amount,
            ];
        });

        return response()->json([
            'matches' => $matches,
        ]);
    }

    public function verifyMatch(Request $request, GameMatch $match): JsonResponse
    {
        $tournament = $match->tournament;
        if ($tournament && app(TournamentIntegrityService::class)->resultsLocked($tournament)) {
            return response()->json(['message' => 'Results are locked after admin approval.'], 422);
        }

        $validated = $request->validate([
            'scoreA' => ['nullable', 'integer', 'min:0'],
            'scoreB' => ['nullable', 'integer', 'min:0'],
            'rank' => ['nullable', 'integer', 'min:1'],
            'kills' => ['nullable', 'integer', 'min:0'],
            'points' => ['nullable', 'integer', 'min:0'],
            'notes' => ['nullable', 'string', 'max:2000'],
            'prize_amount' => ['nullable', 'numeric', 'min:0'],
        ]);

        DB::transaction(function () use ($request, $match, $validated): void {
            $rank = $validated['rank'] ?? null;
            $scoreA = $validated['scoreA'] ?? null;
            $scoreB = $validated['scoreB'] ?? null;
            $prizeAmount = (float) ($validated['prize_amount'] ?? $this->calculatePrizeAmount($match));

            $match->update([
                'rank' => $rank !== null ? '#' . $rank : ($scoreA !== null && $scoreB !== null ? $scoreA . ' - ' . $scoreB : $match->rank),
                'kills' => isset($validated['kills']) ? (string) $validated['kills'] : $match->kills,
                'points' => $validated['points'] ?? $match->points,
                'status' => 'verified',
                'notes' => $validated['notes'] ?? $match->notes,
                'verified_by' => $request->user()->id,
                'verified_at' => now(),
                'played_at' => now(),
                'prize_amount' => $prizeAmount,
            ]);

            if ($prizeAmount > 0 && ! $match->prize_transaction_id) {
                $transactionId = 'WIN-' . strtoupper(Str::random(10));
                $match->user->increment('wallet_balance', $prizeAmount);
                BattlyCache::flushWallet($match->user_id);
                Transaction::create([
                    'id' => $transactionId,
                    'user_id' => $match->user_id,
                    'type' => 'Inflow',
                    'transaction_type' => 'winnings',
                    'payment_method' => 'wallet',
                    'amount' => '+Rs. ' . number_format($prizeAmount),
                    'amount_numeric' => $prizeAmount,
                    'description' => 'Prize winnings from ' . ($match->tournament->title ?? 'tournament'),
                    'date' => 'Just Now',
                    'status' => 'completed',
                ]);
                $match->update(['prize_transaction_id' => $transactionId]);
            }

            Notification::create([
                'user_id' => $match->user_id,
                'title' => 'Match Result Verified',
                'message' => 'Your result for ' . ($match->tournament->title ?? 'the match') . ' has been verified.',
                'type' => 'match_result',
                'deep_link' => 'match:' . $match->id,
                'time' => 'Just Now',
                'unread' => true,
                'metadata' => ['match_id' => $match->id, 'prize_amount' => $prizeAmount],
            ]);
        });

        BattlyCache::flushMatches($match->user_id);
        BattlyCache::flushAdmin();

        return response()->json([
            'message' => 'Match results verified!',
            'match'   => $this->formatMatch($match->fresh(['tournament'])),
        ]);
    }

    public function rejectMatch(Request $request, GameMatch $match): JsonResponse
    {
        $tournament = $match->tournament;
        if ($tournament && app(TournamentIntegrityService::class)->resultsLocked($tournament)) {
            return response()->json(['message' => 'Results are locked after admin approval.'], 422);
        }

        $validated = $request->validate([
            'reason' => ['nullable', 'string', 'max:2000'],
        ]);

        $match->update([
            'status' => 'rejected',
            'played_at' => null,
            'verified_by' => $request->user()->id,
            'verified_at' => now(),
            'rejected_reason' => $validated['reason'] ?? 'Proof did not match admin verification.',
        ]);

        Notification::create([
            'user_id' => $match->user_id,
            'title' => 'Match Result Rejected',
            'message' => $match->rejected_reason,
            'type' => 'match_result',
            'deep_link' => 'match:' . $match->id,
            'time' => 'Just Now',
            'unread' => true,
            'metadata' => ['match_id' => $match->id],
        ]);

        BattlyCache::flushMatches($match->user_id);

        return response()->json([
            'message' => 'Match results rejected!',
            'match'   => $this->formatMatch($match->fresh(['tournament'])),
        ]);
    }

    // ── Formatter ────────────────────────────────────────────────────

    private function formatMatch(GameMatch $m): array
    {
        return [
            'id'         => $m->id,
            'title'      => $m->tournament->title ?? 'Unknown Tournament',
            'type'       => $m->tournament->type ?? 'Squad',
            'dateText'   => $m->played_at?->format('d M, Y') ?? ($m->tournament->starts_at?->format('d M, Y • g:i A') ?? ''),
            'rankString' => $m->rank ?? 'Pending',
            'killsText'  => $m->kills !== null ? (string)$m->kills : '-',
            'logoAsset'  => $m->tournament->logo_asset,
            'status'     => $m->status,
            'points'     => $m->points,
            'proofImages' => $m->proof_images ?? [],
            'rejectedReason' => $m->rejected_reason,
            'prizeAmount' => (float) $m->prize_amount,
        ];
    }

    private function calculatePrizeAmount(GameMatch $match): float
    {
        $rank = (int) preg_replace('/[^0-9]/', '', (string) $match->rank);
        $tournament = $match->tournament;

        if (! $tournament) {
            return 0;
        }

        return (new PrizeDistributionService)->prizeForRank($tournament, $rank);
    }
}
