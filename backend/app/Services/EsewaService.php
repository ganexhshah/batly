<?php

namespace App\Services;

use Illuminate\Http\Request;

class EsewaService
{
    public const RETURN_URL_CACHE_PREFIX = 'esewa_return:';

    public static function gatewayUrl(): string
    {
        return config('services.esewa.environment') === 'production'
            ? 'https://epay.esewa.com.np/api/epay/main/v2/form'
            : 'https://rc-epay.esewa.com.np/api/epay/main/v2/form';
    }

    public static function statusCheckUrl(): string
    {
        return config('services.esewa.environment') === 'production'
            ? 'https://esewa.com.np/api/epay/transaction/status/'
            : 'https://rc.esewa.com.np/api/epay/transaction/status/';
    }

    public static function productCode(): string
    {
        return (string) config('services.esewa.product_code', 'EPAYTEST');
    }

    public static function secretKey(): string
    {
        return (string) config('services.esewa.secret_key', '');
    }

    /** @param array<string, string> $fields */
    public static function signRequest(array $fields): string
    {
        $message = 'total_amount=' . $fields['total_amount']
            . ',transaction_uuid=' . $fields['transaction_uuid']
            . ',product_code=' . $fields['product_code'];

        return base64_encode(hash_hmac('sha256', $message, self::secretKey(), true));
    }

    /** @return array<string, mixed>|null */
    public static function decodeCallback(?string $encoded): ?array
    {
        if ($encoded === null || $encoded === '') {
            return null;
        }

        $decoded = base64_decode($encoded, true);
        if ($decoded === false) {
            return null;
        }

        $payload = json_decode($decoded, true);

        return is_array($payload) ? $payload : null;
    }

    /** @param array<string, mixed> $payload */
    public static function verifyCallbackSignature(array $payload): bool
    {
        $secret = self::secretKey();
        if ($secret === '') {
            return false;
        }

        $signedFieldNames = (string) ($payload['signed_field_names'] ?? '');
        if ($signedFieldNames === '') {
            return false;
        }

        $parts = [];
        foreach (explode(',', $signedFieldNames) as $field) {
            $field = trim($field);
            if ($field === '' || $field === 'signature') {
                continue;
            }
            $parts[] = $field . '=' . ($payload[$field] ?? '');
        }

        $message = implode(',', $parts);
        $expected = base64_encode(hash_hmac('sha256', $message, $secret, true));

        return hash_equals($expected, (string) ($payload['signature'] ?? ''));
    }

    public static function rememberReturnUrl(string $transactionId, string $returnUrl): void
    {
        cache()->put(self::RETURN_URL_CACHE_PREFIX . $transactionId, $returnUrl, now()->addHour());
    }

    public static function pullReturnUrl(string $transactionId): ?string
    {
        $url = cache()->pull(self::RETURN_URL_CACHE_PREFIX . $transactionId);

        return is_string($url) && self::isAllowedReturnUrl($url) ? $url : null;
    }

    /** @return array<string, mixed>|null */
    public static function parseCallbackPayload(Request $request): ?array
    {
        if ($request->filled('data')) {
            return self::decodeCallback($request->query('data'));
        }

        $returnUrl = $request->query('return_url');
        if (is_string($returnUrl) && str_contains($returnUrl, '?data=')) {
            [, $encoded] = explode('?data=', $returnUrl, 2);

            return self::decodeCallback($encoded);
        }

        $queryString = $request->server('QUERY_STRING');
        if (is_string($queryString) && str_contains($queryString, 'data=')) {
            if (preg_match('/(?:^|[?&])data=([^&]+)/', urldecode($queryString), $matches)) {
                return self::decodeCallback($matches[1]);
            }
        }

        return null;
    }

    public static function isAllowedReturnUrl(?string $url): bool
    {
        if ($url === null || $url === '') {
            return false;
        }

        $parts = parse_url($url);
        if (! is_array($parts) || empty($parts['scheme']) || empty($parts['host'])) {
            return false;
        }

        if (! in_array(strtolower($parts['scheme']), ['http', 'https'], true)) {
            return false;
        }

        $host = strtolower($parts['host']);
        $appHost = parse_url((string) config('app.url'), PHP_URL_HOST);

        return in_array($host, ['localhost', '127.0.0.1'], true)
            || ($appHost && $host === strtolower((string) $appHost));
    }
}
