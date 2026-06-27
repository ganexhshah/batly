<?php

namespace App\Http\Middleware;

use App\Http\Middleware\Concerns\ChecksRole;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/** Admin, moderator, and host — dashboard read + host operational routes. */
class EnsureStaff
{
    use ChecksRole;

    public function handle(Request $request, Closure $next): Response
    {
        if (! $this->hasRole($request, ['admin', 'moderator', 'host'])) {
            return $this->deny('Staff access required.');
        }

        return $next($request);
    }
}
