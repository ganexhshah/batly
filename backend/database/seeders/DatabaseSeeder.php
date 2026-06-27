<?php

namespace Database\Seeders;

use App\Models\User;
use App\Models\Team;
use App\Models\Scrim;
use App\Models\Notification;
use App\Models\Transaction;
use App\Models\Tournament;
use App\Models\GameMatch;
use App\Models\Banner;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        $admin = User::updateOrCreate(
            ['email' => env('BATTLY_ADMIN_EMAIL', 'admin@battly.zone')],
            [
                'name' => env('BATTLY_ADMIN_NAME', 'Battly Admin'),
                'password' => Hash::make(env('BATTLY_ADMIN_PASSWORD', 'ChangeMe123!')),
                'role' => 'Admin',
                'status' => 'Active',
                'wallet_balance' => 0.00,
            ],
        );

        if (! filter_var(env('BATTLY_SEED_DEMO_DATA', false), FILTER_VALIDATE_BOOL)) {
            return;
        }

        if (
            User::where('email', 'ganesh@battly.zone')->exists()
            && Tournament::exists()
            && Transaction::where('id', 'TX-0081')->exists()
            && Banner::exists()
        ) {
            return;
        }

        // ── Seed Users / Staff ───────────────────────────────────────

        $admin = User::create([
            'name'           => 'Ganesh Shah',
            'email'          => 'ganesh@battly.zone',
            'password'       => 'password', // Auto-hashed by Laravel's cast/hash
            'role'           => 'Admin',
            'status'         => 'Active',
            'wallet_balance' => 19500.00,
            'ign'            => 'GANESH_PRO',
            'game_uid'       => '882103',
        ]);

        User::create([
            'name'           => 'Suman Shrestha',
            'email'          => 'suman@battly.zone',
            'password'       => 'password',
            'role'           => 'Moderator',
            'status'         => 'Active',
            'wallet_balance' => 0.00,
        ]);

        User::create([
            'name'           => 'Adit Karki',
            'email'          => 'adit@battly.zone',
            'password'       => 'password',
            'role'           => 'Host',
            'status'         => 'Pending',
            'wallet_balance' => 0.00,
        ]);

        User::create([
            'name'           => 'Ram Thapa',
            'email'          => 'ram@battly.zone',
            'password'       => 'password',
            'role'           => 'Player',
            'status'         => 'Active',
            'wallet_balance' => 250.00,
            'ign'            => 'RAM_X',
            'game_uid'       => '334201',
        ]);

        User::create([
            'name'           => 'Priya Rai',
            'email'          => 'priya@battly.zone',
            'password'       => 'password',
            'role'           => 'Player',
            'status'         => 'Active',
            'wallet_balance' => 750.00,
            'ign'            => 'PRIYA_FIRE',
            'game_uid'       => '558817',
        ]);

        User::create([
            'name'           => 'Bijay Magar',
            'email'          => 'bijay@battly.zone',
            'password'       => 'password',
            'role'           => 'Player',
            'status'         => 'Active',
            'wallet_balance' => 125.00,
            'ign'            => 'BIJAY_STORM',
            'game_uid'       => '771043',
        ]);

        // ── Seed Tournaments ─────────────────────────────────────────
        
        $this->call([
            TournamentSeeder::class,
        ]);

        // ── Seed Teams ───────────────────────────────────────────────

        Team::create([
            'name'        => 'Team Apex',
            'tag'         => 'APX',
            'game'        => 'Apex Legends',
            'points'      => 1250,
            'is_verified' => true,
            'members'     => ['Wraith', 'Gibby', 'Bloodhound'],
        ]);

        Team::create([
            'name'        => 'Viper Esports',
            'tag'         => 'VIP',
            'game'        => 'Valorant',
            'points'      => 980,
            'is_verified' => true,
            'members'     => ['Jett', 'Omen', 'Sova', 'Sage', 'Killjoy'],
        ]);

        Team::create([
            'name'        => 'Alpha Squad',
            'tag'         => 'ALP',
            'game'        => 'Valorant',
            'points'      => 840,
            'is_verified' => true,
            'members'     => ['Reyna', 'Brimstone', 'Breach', 'Cypher', 'Phoenix'],
        ]);

        Team::create([
            'name'        => 'Delta Academy',
            'tag'         => 'DEL',
            'game'        => 'LoL',
            'points'      => 1100,
            'is_verified' => true,
            'members'     => ['Top', 'Jungle', 'Mid', 'ADC', 'Support'],
        ]);

        // ── Seed Scrims ──────────────────────────────────────────────

        Scrim::create([
            'teams'  => 'Team Apex vs Alpha Squad',
            'game'   => 'Apex Legends',
            'time'   => 'Today, 21:00',
            'status' => 'Open',
        ]);

        Scrim::create([
            'teams'  => 'Viper Esports vs Team Liquid',
            'game'   => 'Valorant',
            'time'   => 'Today, 22:30',
            'status' => 'Full',
        ]);

        Scrim::create([
            'teams'  => 'T1 Academy vs Gen.G Academy',
            'game'   => 'LoL',
            'time'   => 'Yesterday, 19:00',
            'status' => 'Finished',
        ]);

        // ── Seed Notifications ───────────────────────────────────────

        Notification::create([
            'title'   => 'Dispute Reported - Match #M-9021',
            'message' => 'Team Apex uploaded score verification. Please inspect details.',
            'time'    => '10 minutes ago',
            'unread'  => true,
        ]);

        Notification::create([
            'title'   => 'New Registration Alert',
            'message' => 'Viper Esports has registered for Apex Predator Showdown.',
            'time'    => '2 hours ago',
            'unread'  => true,
        ]);

        Notification::create([
            'title'   => 'Withdrawal Completed',
            'message' => 'Withdrawal request of $350 has been finalized.',
            'time'    => '1 day ago',
            'unread'  => false,
        ]);

        // ── Seed Transactions ────────────────────────────────────────

        Transaction::create([
            'id'               => 'TX-0081',
            'user_id'          => $admin->id,
            'type'             => 'Inflow',
            'transaction_type' => 'deposit',
            'amount'           => '+Rs. 500',
            'amount_numeric'   => 500.00,
            'description'      => 'Valorant Tournament Entry Fees',
            'date'             => 'Today, 14:30',
            'status'           => 'completed',
        ]);

        Transaction::create([
            'id'               => 'TX-0080',
            'user_id'          => $admin->id,
            'type'             => 'Outflow',
            'transaction_type' => 'withdraw',
            'amount'           => '-Rs. 350',
            'amount_numeric'   => -350.00,
            'description'      => 'Winner prize pool payout (Cyberpunk Arena)',
            'date'             => 'Today, 10:00',
            'status'           => 'completed',
        ]);

        Transaction::create([
            'id'               => 'TX-0079',
            'user_id'          => $admin->id,
            'type'             => 'Inflow',
            'transaction_type' => 'deposit',
            'amount'           => '+Rs. 1,200',
            'amount_numeric'   => 1200.00,
            'description'      => 'Apex Predator Sponsor Placement',
            'date'             => 'Yesterday, 17:00',
            'status'           => 'completed',
        ]);

        // ── Seed Game Matches (for verify/reject admin tests) ─────────
        
        $tournaments = Tournament::all();
        if ($tournaments->count() > 0) {
            GameMatch::create([
                'tournament_id' => $tournaments->first()->id,
                'user_id'       => $admin->id,
                'rank'          => '2 - 1',
                'kills'         => '10',
                'played_at'     => now(),
            ]);

            if ($tournaments->count() > 1) {
                // This match is pending score verification
                GameMatch::create([
                    'tournament_id' => $tournaments->get(1)->id,
                    'user_id'       => $admin->id,
                    'rank'          => 'Pending Result', // rank not null, played_at null => Pending Verification
                    'kills'         => '0',
                    'played_at'     => null,
                ]);
            }
        }

        // ── Seed Banners ─────────────────────────────────────────────

        Banner::create([
            'title'      => "BATTLY\nCHAMPIONSHIP",
            'prize_pool' => 'NPR 50,000',
            'date_text'  => '25 MAY, 2024 • 7:00 PM',
            'is_live'    => true,
            'image_path' => 'assets/Untitled (1080 x 900 px) (1080 x 600 px).png',
            'is_active'  => true,
        ]);

        Banner::create([
            'title'      => "NEPTUNE CUP\nSOLO MATCHES",
            'prize_pool' => 'NPR 15,000',
            'date_text'  => '30 MAY, 2024 • 4:00 PM',
            'is_live'    => false,
            'image_path' => 'assets/Untitled (1080 x 900 px) (1080 x 600 px).png',
            'is_active'  => true,
        ]);

        Banner::create([
            'title'      => "BOOYAH SHOWDOWN\nDUO CLASH",
            'prize_pool' => 'NPR 25,000',
            'date_text'  => '02 JUNE, 2024 • 6:00 PM',
            'is_live'    => false,
            'image_path' => 'assets/Untitled (1080 x 900 px) (1080 x 600 px).png',
            'is_active'  => true,
        ]);

        Banner::create([
            'title'      => "WILDLAND CRUCIBLE\nSQUAD ARENA",
            'prize_pool' => 'NPR 40,000',
            'date_text'  => '05 JUNE, 2024 • 8:00 PM',
            'is_live'    => false,
            'image_path' => 'assets/Untitled (1080 x 900 px) (1080 x 600 px).png',
            'is_active'  => true,
        ]);
    }
}
