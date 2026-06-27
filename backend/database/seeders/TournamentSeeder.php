<?php

namespace Database\Seeders;

use App\Models\Tournament;
use Illuminate\Database\Seeder;

class TournamentSeeder extends Seeder
{
    /**
     * Optional local demo tournaments. Disabled unless BATTLY_SEED_DEMO_DATA=true.
     */
    public function run(): void
    {
        // ── Featured Tournaments ─────────────────────────────────────

        Tournament::create([
            'title'           => "BATTLY\nCHAMPIONSHIP",
            'type'            => 'Squad',
            'mode'            => 'Battle Royale',
            'prize_pool'      => 'NPR 50,000',
            'entry_fee'       => 'NPR 500',
            'max_players'     => 128,
            'current_players' => 96,
            'starts_at'       => now()->addDays(3)->setTime(19, 0),
            'status'          => 'live',
            'image_path'      => 'assets/Untitled (1080 x 900 px) (1080 x 600 px).png',
            'is_featured'     => true,
        ]);

        Tournament::create([
            'title'           => "NEPTUNE CUP\nSOLO MATCHES",
            'type'            => 'Solo',
            'mode'            => 'Battle Royale',
            'prize_pool'      => 'NPR 15,000',
            'entry_fee'       => 'NPR 150',
            'max_players'     => 64,
            'current_players' => 28,
            'starts_at'       => now()->addDays(7)->setTime(16, 0),
            'status'          => 'upcoming',
            'image_path'      => 'assets/Untitled (1080 x 900 px) (1080 x 600 px).png',
            'is_featured'     => true,
        ]);

        Tournament::create([
            'title'           => "BOOYAH SHOWDOWN\nDUO CLASH",
            'type'            => 'Duo',
            'mode'            => 'Battle Royale',
            'prize_pool'      => 'NPR 25,000',
            'entry_fee'       => 'NPR 250',
            'max_players'     => 64,
            'current_players' => 40,
            'starts_at'       => now()->addDays(10)->setTime(18, 0),
            'status'          => 'upcoming',
            'image_path'      => 'assets/Untitled (1080 x 900 px) (1080 x 600 px).png',
            'is_featured'     => true,
        ]);

        Tournament::create([
            'title'           => "WILDLAND CRUCIBLE\nSQUAD ARENA",
            'type'            => 'Squad',
            'mode'            => 'Battle Royale',
            'prize_pool'      => 'NPR 40,000',
            'entry_fee'       => 'NPR 400',
            'max_players'     => 128,
            'current_players' => 64,
            'starts_at'       => now()->addDays(14)->setTime(20, 0),
            'status'          => 'upcoming',
            'image_path'      => 'assets/Untitled (1080 x 900 px) (1080 x 600 px).png',
            'is_featured'     => true,
        ]);

        // ── Upcoming (Non-Featured) Tournaments ──────────────────────

        Tournament::create([
            'title'           => 'Battly Cup',
            'type'            => 'Squad',
            'mode'            => 'Battle Royale',
            'prize_pool'      => 'NPR 10,000',
            'entry_fee'       => 'NPR 200',
            'max_players'     => 64,
            'current_players' => 32,
            'starts_at'       => now()->addHours(2)->addMinutes(15),
            'status'          => 'registration',
            'logo_asset'      => 'assets/logo/battly_cup.png',
            'is_featured'     => false,
        ]);

        Tournament::create([
            'title'           => 'Booyah Arena',
            'type'            => 'Duo',
            'mode'            => 'Battle Royale',
            'prize_pool'      => 'NPR 20,000',
            'entry_fee'       => 'NPR 300',
            'max_players'     => 128,
            'current_players' => 48,
            'starts_at'       => now()->addDays(2)->setTime(20, 0),
            'status'          => 'upcoming',
            'logo_asset'      => 'assets/logo/booyah_arena.png',
            'is_featured'     => false,
        ]);

        Tournament::create([
            'title'           => 'Night Showdown',
            'type'            => 'Squad',
            'mode'            => 'Battle Royale',
            'prize_pool'      => 'NPR 15,000',
            'entry_fee'       => 'NPR 250',
            'max_players'     => 64,
            'current_players' => 16,
            'starts_at'       => now()->addDays(5)->setTime(21, 0),
            'status'          => 'upcoming',
            'logo_asset'      => 'assets/logo/night_showdown.png',
            'is_featured'     => false,
        ]);
    }
}
