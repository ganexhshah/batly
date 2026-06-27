<?php

namespace App\Http\Middleware;

use App\Http\Middleware\Concerns\ChecksRole;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/** Admin only — staff lifecycle, wallet adjustments, destructive overrides. */
class EnsureAdmin
{
    use ChecksRole;

    public function handle(Request $request, Closure $next): Response
    {
        if (! $this->hasRole($request, ['admin'])) {
            return $this->deny('Admin access required.');
        }

        return $next($request);
    }
}
