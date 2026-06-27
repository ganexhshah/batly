<?php

namespace App\Services;

use App\Models\Tournament;

class TournamentIntegrityService
{
    public const TEAM_FORMATS = ['2v2', '3v3', '4v4'];

    public function teamSize(?string $teamSize): int
    {
        return match ($teamSize) {
            '2v2' => 2,
            '3v3' => 3,
            '4v4' => 4,
            '1v2' => 3,
            default => 1,
        };
    }

    public function requiresTeam(Tournament $tournament): bool
    {
        $size = $tournament->custom_settings['team_size'] ?? null;

        return is_string($size) && in_array($size, self::TEAM_FORMATS, true);
    }

    public function roomCodesShared(Tournament $tournament): bool
    {
        $settings = $tournament->custom_settings ?? [];

        return ! empty($settings['room_codes_shared_at'])
            || ! empty(trim((string) ($settings['room_id'] ?? '')))
            || ! empty(trim((string) ($settings['room_password'] ?? '')));
    }

    public function registrationOpen(Tournament $tournament): bool
    {
        if (! in_array($tournament->status, ['registration', 'upcoming'], true)) {
            return false;
        }

        if ($tournament->current_players >= $tournament->max_players) {
            return false;
        }

        return ! $this->roomCodesShared($tournament);
    }

    public function canLeave(Tournament $tournament): bool
    {
        return in_array($tournament->status, ['registration', 'upcoming'], true)
            && ! $this->roomCodesShared($tournament);
    }

    public function registrationMeta(Tournament $tournament): array
    {
        $full = $tournament->current_players >= $tournament->max_players;

        return [
            'registrationOpen' => $this->registrationOpen($tournament),
            'registrationClosed' => ! $this->registrationOpen($tournament),
            'isFull' => $full,
            'currentPlayers' => $tournament->current_players,
            'maxPlayers' => $tournament->max_players,
            'roomCodesShared' => $this->roomCodesShared($tournament),
            'canLeave' => $this->canLeave($tournament),
            'requiresTeam' => $this->requiresTeam($tournament),
            'teamSize' => $this->teamSize($tournament->custom_settings['team_size'] ?? null),
            'chatOpen' => $this->chatOpen($tournament),
        ];
    }

    public function resultsLocked(Tournament $tournament): bool
    {
        $settings = $tournament->custom_settings ?? [];

        return ! empty($settings['results_locked_at'])
            || ! empty($settings['results_approved_at']);
    }

    public function chatOpen(Tournament $tournament): bool
    {
        if (in_array($tournament->status, ['completed', 'cancelled'], true)) {
            return false;
        }

        return in_array($tournament->status, ['registration', 'upcoming', 'live'], true);
    }

    public function chatClosedReason(Tournament $tournament): ?string
    {
        if ($tournament->status === 'completed') {
            return 'Chat closed — match ended.';
        }

        if ($tournament->status === 'cancelled') {
            return 'Chat closed — tournament was cancelled.';
        }

        return 'Chat is only available to registered players before the match ends.';
    }

    public function matchFlowApplies(Tournament $tournament): bool
    {
        return in_array((string) $tournament->mode, ['Custom Room', 'Lone Wolf'], true);
    }

    public function matchFlowPhase(Tournament $tournament): ?string
    {
        if (! $this->matchFlowApplies($tournament)) {
            return null;
        }

        $settings = $tournament->custom_settings ?? [];

        return $settings['match_flow']['phase'] ?? null;
    }

    public function matchFlowLocked(Tournament $tournament): bool
    {
        $phase = $this->matchFlowPhase($tournament);

        return $phase !== null && $phase !== 'completed';
    }
}
