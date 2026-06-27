<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Notification;
use App\Models\TeamInvite;
use App\Models\Tournament;
use App\Models\User;
use App\Services\TournamentIntegrityService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class TeamInviteController extends Controller
{
    private function integrity(): TournamentIntegrityService
    {
        return new TournamentIntegrityService;
    }

    public function index(Request $request, Tournament $tournament): JsonResponse
    {
        $user = $request->user();

        $sent = TeamInvite::query()
            ->where('tournament_id', $tournament->id)
            ->where('captain_id', $user->id)
            ->with('invitee:id,name,ign,game_uid,avatar_url')
            ->get()
            ->map(fn (TeamInvite $i) => $this->formatInvite($i));

        $received = TeamInvite::query()
            ->where('tournament_id', $tournament->id)
            ->where('invitee_id', $user->id)
            ->with('captain:id,name,ign,game_uid,avatar_url')
            ->get()
            ->map(fn (TeamInvite $i) => $this->formatInvite($i));

        return response()->json([
            'sent' => $sent,
            'received' => $received,
            'teamSize' => $this->integrity()->teamSize($tournament->custom_settings['team_size'] ?? null),
            'requiresTeam' => $this->integrity()->requiresTeam($tournament),
        ]);
    }

    public function store(Request $request, Tournament $tournament): JsonResponse
    {
        if (! $this->integrity()->requiresTeam($tournament)) {
            return response()->json(['message' => 'Team invites are only for 2v2, 3v3, and 4v4 matches.'], 422);
        }

        if (! $this->integrity()->registrationOpen($tournament)) {
            return response()->json(['message' => 'Registration is closed for this tournament.'], 422);
        }

        $validated = $request->validate([
            'invitee_id' => ['required', 'integer', 'exists:users,id'],
        ]);

        $captain = $request->user();
        $inviteeId = (int) $validated['invitee_id'];

        if ($inviteeId === $captain->id) {
            return response()->json(['message' => 'You cannot invite yourself.'], 422);
        }

        if ($tournament->registrations()->where('user_id', $inviteeId)->exists()) {
            return response()->json(['message' => 'That player is already registered.'], 422);
        }

        $teamSize = $this->integrity()->teamSize($tournament->custom_settings['team_size'] ?? null);
        $acceptedCount = TeamInvite::query()
            ->where('tournament_id', $tournament->id)
            ->where('captain_id', $captain->id)
            ->where('status', 'accepted')
            ->count();

        if ($acceptedCount >= $teamSize - 1) {
            return response()->json(['message' => 'Your team is already full.'], 422);
        }

        $existingAccepted = TeamInvite::query()
            ->where('tournament_id', $tournament->id)
            ->where('invitee_id', $inviteeId)
            ->where('status', 'accepted')
            ->where('captain_id', '!=', $captain->id)
            ->exists();

        if ($existingAccepted) {
            return response()->json(['message' => 'That player is already on another team.'], 422);
        }

        $invite = TeamInvite::updateOrCreate(
            [
                'tournament_id' => $tournament->id,
                'captain_id' => $captain->id,
                'invitee_id' => $inviteeId,
            ],
            ['status' => 'pending', 'responded_at' => null],
        );

        Notification::create([
            'user_id' => $inviteeId,
            'title' => 'Team Invite',
            'message' => ($captain->ign ?: $captain->name) . ' invited you to their team for "' . $tournament->title . '".',
            'type' => 'team_invite',
            'deep_link' => 'tournament:' . $tournament->id,
            'time' => 'Just Now',
            'unread' => true,
            'metadata' => ['tournament_id' => $tournament->id, 'invite_id' => $invite->id],
        ]);

        return response()->json([
            'message' => 'Invite sent.',
            'invite' => $this->formatInvite($invite->load('invitee:id,name,ign,game_uid,avatar_url')),
        ], 201);
    }

    public function respond(Request $request, Tournament $tournament, TeamInvite $invite): JsonResponse
    {
        if ($invite->tournament_id !== $tournament->id) {
            return response()->json(['message' => 'Invite not found.'], 404);
        }

        if ($invite->invitee_id !== $request->user()->id) {
            return response()->json(['message' => 'Unauthorized'], 403);
        }

        if ($invite->status !== 'pending') {
            return response()->json(['message' => 'Invite already responded to.'], 422);
        }

        $validated = $request->validate([
            'action' => ['required', 'string', 'in:accept,decline'],
        ]);

        $invite->update([
            'status' => $validated['action'] === 'accept' ? 'accepted' : 'declined',
            'responded_at' => now(),
        ]);

        Notification::create([
            'user_id' => $invite->captain_id,
            'title' => $validated['action'] === 'accept' ? 'Invite Accepted' : 'Invite Declined',
            'message' => ($request->user()->ign ?: $request->user()->name)
                . ($validated['action'] === 'accept' ? ' joined your team for ' : ' declined your team invite for ')
                . '"' . $tournament->title . '".',
            'type' => 'team_invite',
            'deep_link' => 'tournament:' . $tournament->id,
            'time' => 'Just Now',
            'unread' => true,
            'metadata' => ['tournament_id' => $tournament->id, 'invite_id' => $invite->id],
        ]);

        return response()->json([
            'message' => $validated['action'] === 'accept' ? 'Invite accepted.' : 'Invite declined.',
            'invite' => $this->formatInvite($invite->fresh()->load('captain:id,name,ign,game_uid,avatar_url')),
        ]);
    }

    private function formatInvite(TeamInvite $invite): array
    {
        return [
            'id' => $invite->id,
            'tournament_id' => $invite->tournament_id,
            'captain_id' => $invite->captain_id,
            'invitee_id' => $invite->invitee_id,
            'status' => $invite->status,
            'responded_at' => $invite->responded_at?->toIso8601String(),
            'captain' => $invite->relationLoaded('captain') && $invite->captain ? [
                'id' => $invite->captain->id,
                'name' => $invite->captain->name,
                'ign' => $invite->captain->ign,
                'game_uid' => $invite->captain->game_uid,
                'avatar_url' => $invite->captain->avatar_url,
            ] : null,
            'invitee' => $invite->relationLoaded('invitee') && $invite->invitee ? [
                'id' => $invite->invitee->id,
                'name' => $invite->invitee->name,
                'ign' => $invite->invitee->ign,
                'game_uid' => $invite->invitee->game_uid,
                'avatar_url' => $invite->invitee->avatar_url,
            ] : null,
        ];
    }
}
