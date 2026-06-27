<?php

namespace App\Http\Middleware\Concerns;

use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

trait ChecksRole
{
    protected function hasRole(Request $request, array $roles): bool
    {
        $role = strtolower((string) $request->user()?->role);

        return in_array($role, $roles, true);
    }

    protected function deny(string $message = 'Insufficient permissions.'): Response
    {
        return response()->json(['message' => $message], 403);
    }
}
