<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Laravel\Sanctum\PersonalAccessToken;
use Symfony\Component\HttpFoundation\Response;

/**
 * Authenticate via Sanctum when a Bearer token is present, without requiring auth.
 */
class OptionalSanctum
{
    public function handle(Request $request, Closure $next): Response
    {
        if (! $request->user('sanctum') && ($token = $request->bearerToken())) {
            $accessToken = PersonalAccessToken::findToken($token);

            if ($accessToken?->tokenable) {
                Auth::guard('sanctum')->setUser($accessToken->tokenable);
            }
        }

        return $next($request);
    }
}
