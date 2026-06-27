<?php

namespace App\Services;

use App\Models\Transaction;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use RuntimeException;

/**
 * Creates auditable wallet transactions with transaction ID + reference ID.
 */
class WalletLedgerService
{
    public static function entryFee(User $user, float $amount, int $tournamentId, string $title): string
    {
        return DB::transaction(function () use ($user, $amount, $tournamentId, $title) {
            $locked = User::query()->whereKey($user->id)->lockForUpdate()->firstOrFail();
            if ((float) $locked->wallet_balance < $amount) {
                throw new RuntimeException('Insufficient wallet balance for entry fee.');
            }

            $transactionId = 'ENT-' . strtoupper(Str::random(10));
            $referenceId = 'TOURN-' . $tournamentId;

            $locked->decrement('wallet_balance', $amount);

            Transaction::create([
                'id' => $transactionId,
                'user_id' => $locked->id,
                'type' => 'Outflow',
                'transaction_type' => 'spend',
                'payment_method' => 'wallet',
                'amount' => '-Rs. ' . number_format($amount),
                'amount_numeric' => -$amount,
                'description' => 'Entry fee for ' . $title,
                'date' => 'Just Now',
                'status' => 'completed',
                'reference_id' => $referenceId,
                'reference_type' => 'tournament',
                'reference_entity_id' => $tournamentId,
            ]);

            BattlyCache::flushWallet($locked->id);

            return $transactionId;
        });
    }

    public static function refund(User $user, float $amount, int $tournamentId, string $title, string $reason): string
    {
        $transactionId = 'REF-' . strtoupper(Str::random(10));
        $referenceId = 'TOURN-' . $tournamentId . '-REF';

        DB::transaction(function () use ($user, $amount, $tournamentId, $title, $reason, $transactionId, $referenceId): void {
            $locked = User::query()->whereKey($user->id)->lockForUpdate()->firstOrFail();
            $locked->increment('wallet_balance', $amount);

            Transaction::create([
                'id' => $transactionId,
                'user_id' => $locked->id,
                'type' => 'Inflow',
                'transaction_type' => 'refund',
                'payment_method' => 'wallet',
                'amount' => '+Rs. ' . number_format($amount),
                'amount_numeric' => $amount,
                'description' => $reason . ' — ' . $title,
                'date' => 'Just Now',
                'status' => 'completed',
                'reference_id' => $referenceId,
                'reference_type' => 'tournament',
                'reference_entity_id' => $tournamentId,
            ]);
        });

        BattlyCache::flushWallet($user->id);

        return $transactionId;
    }

    public static function prize(User $user, float $amount, int $tournamentId, int $matchId, string $title): string
    {
        $transactionId = 'WIN-' . strtoupper(Str::random(10));
        $referenceId = 'MATCH-' . $matchId;

        DB::transaction(function () use ($user, $amount, $tournamentId, $matchId, $title, $transactionId, $referenceId): void {
            $locked = User::query()->whereKey($user->id)->lockForUpdate()->firstOrFail();
            $locked->increment('wallet_balance', $amount);

            Transaction::create([
                'id' => $transactionId,
                'user_id' => $locked->id,
                'type' => 'Inflow',
                'transaction_type' => 'winnings',
                'payment_method' => 'wallet',
                'amount' => '+Rs. ' . number_format($amount),
                'amount_numeric' => $amount,
                'description' => 'Prize winnings from ' . $title,
                'date' => 'Just Now',
                'status' => 'completed',
                'reference_id' => $referenceId,
                'reference_type' => 'game_match',
                'reference_entity_id' => $matchId,
            ]);
        });

        BattlyCache::flushWallet($user->id);

        return $transactionId;
    }

    public static function prizeForMatch(\App\Models\GameMatch $match, float $amount, int $tournamentId, string $title): ?string
    {
        if ($amount <= 0) {
            return null;
        }

        return DB::transaction(function () use ($match, $amount, $tournamentId, $title) {
            $lockedMatch = \App\Models\GameMatch::query()->whereKey($match->id)->lockForUpdate()->firstOrFail();
            if ($lockedMatch->prize_transaction_id) {
                return null;
            }

            $user = $lockedMatch->user;
            if (! $user) {
                return null;
            }

            $locked = User::query()->whereKey($user->id)->lockForUpdate()->firstOrFail();
            $locked->increment('wallet_balance', $amount);

            $transactionId = 'WIN-' . strtoupper(Str::random(10));
            Transaction::create([
                'id' => $transactionId,
                'user_id' => $locked->id,
                'type' => 'Inflow',
                'transaction_type' => 'winnings',
                'payment_method' => 'wallet',
                'amount' => '+Rs. ' . number_format($amount),
                'amount_numeric' => $amount,
                'description' => 'Prize winnings from ' . $title,
                'date' => 'Just Now',
                'status' => 'completed',
                'reference_id' => 'MATCH-' . $lockedMatch->id,
                'reference_type' => 'game_match',
                'reference_entity_id' => $lockedMatch->id,
            ]);

            $lockedMatch->update(['prize_transaction_id' => $transactionId]);
            BattlyCache::flushWallet($locked->id);

            return $transactionId;
        });
    }
}
