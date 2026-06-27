<?php

namespace App\Http\Middleware;

use App\Http\Middleware\Concerns\ChecksRole;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/** Admin and moderator — moderation, payouts, broadcasts, support updates. */
class EnsureModerator
{
    use ChecksRole;

    public function handle(Request $request, Closure $next): Response
    {
        if (! $this->hasRole($request, ['admin', 'moderator'])) {
            return $this->deny('Moderator access required.');
        }

        return $next($request);
    }
}
