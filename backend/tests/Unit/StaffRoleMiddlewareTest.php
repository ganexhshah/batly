<?php

namespace Tests\Unit;

use App\Http\Middleware\EnsureAdmin;
use App\Http\Middleware\EnsureModerator;
use App\Http\Middleware\EnsureStaff;
use App\Models\User;
use Illuminate\Http\Request;
use Tests\TestCase;

class StaffRoleMiddlewareTest extends TestCase
{
    public function test_staff_middleware_allows_host(): void
    {
        $user = new User;
        $user->forceFill(['role' => 'Host']);

        $request = Request::create('/api/admin/overview', 'GET');
        $request->setUserResolver(fn () => $user);

        $response = (new EnsureStaff())->handle($request, fn () => response()->json(['ok' => true]));

        $this->assertSame(200, $response->getStatusCode());
    }

    public function test_moderator_middleware_blocks_host(): void
    {
        $user = new User;
        $user->forceFill(['role' => 'Host']);

        $request = Request::create('/api/admin/wallet/adjust', 'POST');
        $request->setUserResolver(fn () => $user);

        $response = (new EnsureModerator())->handle($request, fn () => response()->json(['ok' => true]));

        $this->assertSame(403, $response->getStatusCode());
    }

    public function test_admin_middleware_blocks_moderator(): void
    {
        $user = new User;
        $user->forceFill(['role' => 'Moderator']);

        $request = Request::create('/api/admin/users/invite', 'POST');
        $request->setUserResolver(fn () => $user);

        $response = (new EnsureAdmin())->handle($request, fn () => response()->json(['ok' => true]));

        $this->assertSame(403, $response->getStatusCode());
    }
}
