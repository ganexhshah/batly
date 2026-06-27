<?php

namespace App\Services;

use App\Models\Tournament;

class PrizeDistributionService
{
    public const TYPE_WINNER_TAKES_ALL = 'winner_takes_all';

    public const TYPE_CLASSIC_TOP3 = 'classic_top3';

    private const CUSTOM_FORMATS = ['1v1', '2v2', '3v3', '4v4', '1v2'];

    public function resolveType(Tournament $tournament): string
    {
        $settings = $tournament->custom_settings ?? [];

        if (! empty($settings['prize_distribution'])) {
            return (string) $settings['prize_distribution'];
        }

        $teamSize = $settings['team_size'] ?? null;
        if (is_string($teamSize) && in_array($teamSize, self::CUSTOM_FORMATS, true)) {
            return self::TYPE_WINNER_TAKES_ALL;
        }

        if (preg_match('/\[(1v1|2v2|3v3|4v4|1v2)\]/', (string) $tournament->stage)) {
            return self::TYPE_WINNER_TAKES_ALL;
        }

        return self::TYPE_CLASSIC_TOP3;
    }

    public function matchFormat(Tournament $tournament): ?string
    {
        $settings = $tournament->custom_settings ?? [];

        if (! empty($settings['team_size']) && is_string($settings['team_size'])) {
            return $settings['team_size'];
        }

        if (preg_match('/\[(1v1|2v2|3v3|4v4|1v2)\]/', (string) $tournament->stage, $matches)) {
            return $matches[1];
        }

        return null;
    }

    public function label(Tournament $tournament): string
    {
        return match ($this->resolveType($tournament)) {
            self::TYPE_WINNER_TAKES_ALL => 'Winner Takes All',
            default => 'Classic Top 3',
        };
    }

    public function description(Tournament $tournament): string
    {
        $format = $this->matchFormat($tournament);

        return match ($this->resolveType($tournament)) {
            self::TYPE_WINNER_TAKES_ALL => $format !== null
                ? "Custom {$format} match — the winner receives the full prize pool."
                : 'Custom match — the winner receives the full prize pool.',
            default => 'Classic squad tournament — prizes split among top 3 (50% / 30% / 20%).',
        };
    }

    public function parsePool(Tournament $tournament): float
    {
        return (float) preg_replace('/[^0-9.]/', '', (string) $tournament->prize_pool);
    }

    public function parseEntryFee(Tournament $tournament): float
    {
        return (float) preg_replace('/[^0-9.]/', '', (string) ($tournament->entry_fee ?? '0'));
    }

    /** @return list<array{rank:int,label:string,share:string,amount:float,color:string}> */
    public function slots(Tournament $tournament): array
    {
        $pool = $this->parsePool($tournament);

        if ($this->resolveType($tournament) === self::TYPE_WINNER_TAKES_ALL) {
            return [
                [
                    'rank'   => 1,
                    'label'  => 'Match Winner',
                    'share'  => '100% Pool',
                    'amount' => round($pool, 2),
                    'color'  => '#FFD700',
                ],
            ];
        }

        return [
            [
                'rank'   => 1,
                'label'  => '1st Place Champion',
                'share'  => '50% Pool',
                'amount' => round($pool * 0.5, 2),
                'color'  => '#FFD700',
            ],
            [
                'rank'   => 2,
                'label'  => '2nd Place Runner-up',
                'share'  => '30% Pool',
                'amount' => round($pool * 0.3, 2),
                'color'  => '#C0C0C0',
            ],
            [
                'rank'   => 3,
                'label'  => '3rd Place Finalist',
                'share'  => '20% Pool',
                'amount' => round($pool * 0.2, 2),
                'color'  => '#CD7F32',
            ],
        ];
    }

    public function prizeForRank(Tournament $tournament, int $rank): float
    {
        foreach ($this->slots($tournament) as $slot) {
            if ($slot['rank'] === $rank) {
                return (float) $slot['amount'];
            }
        }

        return 0;
    }

    public function payingRanks(Tournament $tournament): array
    {
        return array_column($this->slots($tournament), 'rank');
    }

    public function toArray(Tournament $tournament): array
    {
        $settings = $tournament->custom_settings ?? [];

        return [
            'type'        => $this->resolveType($tournament),
            'label'       => $this->label($tournament),
            'description' => $this->description($tournament),
            'matchFormat' => $this->matchFormat($tournament),
            'roomType'    => $settings['room_type'] ?? null,
            'totalPool'   => $this->parsePool($tournament),
            'entryFee'    => $this->parseEntryFee($tournament),
            'maxPlayers'  => $tournament->max_players,
            'slots'       => $this->slots($tournament),
        ];
    }
}
