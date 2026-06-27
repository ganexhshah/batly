<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Tournament;
use App\Models\User;
use App\Services\BattlyCache;
use App\Services\MatchFlowService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use InvalidArgumentException;

class MatchFlowController extends Controller
{
    private function flow(): MatchFlowService
    {
        return new MatchFlowService;
    }

    private function canAccessMatchFlow(Tournament $tournament, User $user): bool
    {
        return $tournament->created_by === $user->id
            || $tournament->registrations()->where('user_id', $user->id)->exists();
    }

    private function denyUnlessAccess(Request $request, Tournament $tournament): ?JsonResponse
    {
        if (! $this->canAccessMatchFlow($tournament, $request->user())) {
            return response()->json(['message' => 'You are not registered for this tournament.'], 403);
        }

        return null;
    }

    public function show(Request $request, Tournament $tournament): JsonResponse
    {
        $user = $request->user();

        if (! $this->flow()->appliesTo($tournament)) {
            return response()->json([
                'match_flow' => ['applies' => false],
            ]);
        }

        if ($denied = $this->denyUnlessAccess($request, $tournament)) {
            return $denied;
        }

        return response()->json([
            'match_flow' => $this->flow()->toPublicArray($tournament, $user),
        ]);
    }

    public function confirmInGame(Request $request, Tournament $tournament): JsonResponse
    {
        if ($denied = $this->denyUnlessAccess($request, $tournament)) {
            return $denied;
        }

        try {
            $this->flow()->confirmInGame($tournament, $request->user());
            BattlyCache::flushTournaments();

            return response()->json([
                'message' => 'In-game join confirmed.',
                'match_flow' => $this->flow()->toPublicArray($tournament->fresh(), $request->user()),
            ]);
        } catch (InvalidArgumentException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }
    }

    public function stop(Request $request, Tournament $tournament): JsonResponse
    {
        if ($denied = $this->denyUnlessAccess($request, $tournament)) {
            return $denied;
        }

        try {
            $this->flow()->recordStop($tournament, $request->user());
            BattlyCache::flushTournaments();

            return response()->json([
                'message' => 'Stop recorded.',
                'match_flow' => $this->flow()->toPublicArray($tournament->fresh(), $request->user()),
            ]);
        } catch (InvalidArgumentException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }
    }

    public function acknowledgeStop(Request $request, Tournament $tournament): JsonResponse
    {
        if ($denied = $this->denyUnlessAccess($request, $tournament)) {
            return $denied;
        }

        try {
            $this->flow()->acknowledgeStop($tournament, $request->user());
            BattlyCache::flushTournaments();

            return response()->json([
                'message' => 'Match end acknowledged. Vote for the winner.',
                'match_flow' => $this->flow()->toPublicArray($tournament->fresh(), $request->user()),
            ]);
        } catch (InvalidArgumentException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }
    }

    public function voteWinner(Request $request, Tournament $tournament): JsonResponse
    {
        if ($denied = $this->denyUnlessAccess($request, $tournament)) {
            return $denied;
        }

        $validated = $request->validate([
            'claim' => ['required', 'string', 'in:self,opponent'],
        ]);

        try {
            $this->flow()->voteWinner($tournament, $request->user(), $validated['claim']);
            BattlyCache::flushTournaments();

            return response()->json([
                'message' => 'Vote recorded.',
                'match_flow' => $this->flow()->toPublicArray($tournament->fresh(), $request->user()),
            ]);
        } catch (InvalidArgumentException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }
    }

    public function submitProof(Request $request, Tournament $tournament): JsonResponse
    {
        if ($denied = $this->denyUnlessAccess($request, $tournament)) {
            return $denied;
        }

        $validated = $request->validate([
            'proof_urls' => ['required', 'array', 'min:1'],
            'proof_urls.*' => ['required', 'string', 'max:2000'],
        ]);

        try {
            $this->flow()->submitProof($tournament, $request->user(), $validated['proof_urls']);
            BattlyCache::flushTournaments();

            return response()->json([
                'message' => 'Proof submitted for admin review.',
                'match_flow' => $this->flow()->toPublicArray($tournament->fresh(), $request->user()),
            ]);
        } catch (InvalidArgumentException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }
    }

    public function resolveStop(Request $request, Tournament $tournament): JsonResponse
    {
        $validated = $request->validate([
            'winner_user_id' => ['required', 'integer'],
        ]);

        $winnerId = (int) $validated['winner_user_id'];
        $isParticipant = $tournament->registrations()
            ->where('user_id', $winnerId)
            ->where('status', 'registered')
            ->exists();

        if (! $isParticipant && $tournament->created_by !== $winnerId) {
            return response()->json(['message' => 'Winner must be a registered participant.'], 422);
        }

        $flow = $this->flow()->getFlow($tournament);
        if ($flow['phase'] !== MatchFlowService::PHASE_ADMIN_STOP_REVIEW) {
            return response()->json(['message' => 'No stop review pending.'], 422);
        }

        $this->flow()->completeWithWinner($tournament, $winnerId);
        BattlyCache::flushTournaments();

        return response()->json([
            'message' => 'Stop dispute resolved. Winner paid.',
            'match_flow' => $this->flow()->toPublicArray($tournament->fresh(), $request->user()),
        ]);
    }
}
