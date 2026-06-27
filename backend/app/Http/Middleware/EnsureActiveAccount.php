<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureActiveAccount
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();
        $status = strtolower((string) ($user?->status ?? 'active'));

        if (in_array($status, ['suspended', 'revoked'], true)) {
            return response()->json(['message' => 'Account access is restricted.'], 403);
        }

        return $next($request);
    }
}
