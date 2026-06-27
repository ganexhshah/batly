<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Chrome blocks cross-origin requests to loopback unless this header is set.
 * Required when Flutter web (localhost:PORT) calls the API (localhost:8888).
 */
class AllowPrivateNetworkAccess
{
    public function handle(Request $request, Closure $next): Response
    {
        $response = $next($request);

        $response->headers->set('Access-Control-Allow-Private-Network', 'true');

        return $response;
    }
}
