<?php

namespace App\Services;

use Closure;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Redis;

/**
 * Central Redis-backed cache layer for Battly API responses.
 *
 * Requires CACHE_STORE=redis. All tagged caches use the Redis driver.
 */
class BattlyCache
{
    public const TAG_TOURNAMENTS = 'tournaments';

    public const TAG_BANNERS = 'banners';

    public const TAG_WALLET = 'wallet';

    public const TAG_USERS = 'users';

    public const TAG_MATCHES = 'matches';

    public const TAG_ADMIN = 'admin';

    public const TAG_CHAT = 'chat';

    public const TTL_LIST = 300;

    public const TTL_DETAIL = 120;

    public const TTL_WALLET = 60;

    public const TTL_BANNERS = 600;

    public const TTL_USER = 600;

    public const TTL_ADMIN = 120;

    public const TTL_CHAT = 30;

    public static function remember(string $tag, string $key, int $ttl, Closure $callback): mixed
    {
        try {
            return Cache::tags([$tag])->remember($key, $ttl, $callback);
        } catch (\Throwable) {
            return $callback();
        }
    }

    public static function forget(string $tag, string $key): void
    {
        try {
            Cache::tags([$tag])->forget($key);
        } catch (\Throwable) {
        }
    }

    public static function flush(string $tag): void
    {
        try {
            Cache::tags([$tag])->flush();
        } catch (\Throwable) {
        }
    }

    public static function flushTournaments(?int $tournamentId = null): void
    {
        self::flush(self::TAG_TOURNAMENTS);
        if ($tournamentId !== null) {
            try {
                Cache::forget("tournament:{$tournamentId}:shared");
            } catch (\Throwable) {
            }
        }
    }

    public static function flushBanners(): void
    {
        self::flush(self::TAG_BANNERS);
    }

    public static function flushWallet(int $userId): void
    {
        self::forget(self::TAG_WALLET, "wallet:balance:{$userId}");
        self::forget(self::TAG_WALLET, "wallet:summary:{$userId}");
    }

    public static function flushUser(int $userId): void
    {
        self::forget(self::TAG_USERS, "user:public:{$userId}");
    }

    public static function flushMatches(int $userId): void
    {
        self::forget(self::TAG_MATCHES, "matches:user:{$userId}");
    }

    public static function flushChat(int $userId): void
    {
        self::forget(self::TAG_CHAT, "chat:conversations:{$userId}");
    }

    public static function flushAdmin(): void
    {
        self::flush(self::TAG_ADMIN);
    }

    public static function tournamentListKey(?string $status = null, ?string $type = null): string
    {
        return 'tournaments:list:' . md5(json_encode([
            'status' => $status,
            'type' => $type,
        ]));
    }

    public static function tournamentSharedKey(int $tournamentId): string
    {
        return "tournament:{$tournamentId}:shared";
    }

    public static function walletBalanceKey(int $userId): string
    {
        return "wallet:balance:{$userId}";
    }

    public static function userPublicKey(int $userId): string
    {
        return "user:public:{$userId}";
    }

    public static function userMatchesKey(int $userId): string
    {
        return "matches:user:{$userId}";
    }

    /** @return array{ok: bool, latency_ms: float|null, error: string|null} */
    public static function ping(): array
    {
        try {
            $start = microtime(true);
            $pong = Redis::connection()->ping();
            $latency = round((microtime(true) - $start) * 1000, 2);

            return [
                'ok' => $pong === true || $pong === 'PONG' || $pong === '+PONG',
                'latency_ms' => $latency,
                'error' => null,
            ];
        } catch (\Throwable $e) {
            return [
                'ok' => false,
                'latency_ms' => null,
                'error' => $e->getMessage(),
            ];
        }
    }
}
