#!/bin/bash
###############################################################################
#  Battly Backend — Auth Routes & Controller Setup
#  Run this INSIDE the app container AFTER setup-laravel.sh
###############################################################################
set -e

cd /var/www/html

echo "============================================"
echo "  Battly — Auth Configuration"
echo "============================================"

# ── Step 1: Create Auth Controller for Google OAuth ──────────────────────────
echo ""
echo "▶ Creating Google OAuth Controller..."

mkdir -p app/Http/Controllers/Auth

cat > app/Http/Controllers/Auth/GoogleAuthController.php << 'CONTROLLER'
<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Laravel\Socialite\Facades\Socialite;

class GoogleAuthController extends Controller
{
    /**
     * Redirect to Google OAuth consent screen.
     */
    public function redirect(): RedirectResponse
    {
        return Socialite::driver('google')
            ->scopes(['openid', 'profile', 'email'])
            ->redirect();
    }

    /**
     * Handle callback from Google OAuth.
     */
    public function callback(): JsonResponse
    {
        try {
            $googleUser = Socialite::driver('google')->stateless()->user();
        } catch (\Exception $e) {
            return response()->json([
                'message' => 'Google authentication failed.',
                'error' => $e->getMessage(),
            ], 401);
        }

        $user = User::updateOrCreate(
            ['email' => $googleUser->getEmail()],
            [
                'name' => $googleUser->getName(),
                'google_id' => $googleUser->getId(),
                'avatar' => $googleUser->getAvatar(),
                'email_verified_at' => now(),
                'password' => Hash::make(Str::random(24)),
            ]
        );

        $token = $user->createToken('google-auth')->plainTextToken;

        return response()->json([
            'message' => 'Authentication successful.',
            'user' => $user,
            'token' => $token,
            'token_type' => 'Bearer',
        ]);
    }
}
CONTROLLER

echo "✓ GoogleAuthController created"

# ── Step 2: Create FCM Controller ───────────────────────────────────────────
echo ""
echo "▶ Creating FCM Push Notification Service..."

mkdir -p app/Services

cat > app/Services/PushNotificationService.php << 'SERVICE'
<?php

namespace App\Services;

use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\Notification;
use Kreait\Laravel\Firebase\Facades\Firebase;

class PushNotificationService
{
    /**
     * Send push notification to a single device.
     */
    public function sendToDevice(string $deviceToken, string $title, string $body, array $data = []): void
    {
        $message = CloudMessage::withTarget('token', $deviceToken)
            ->withNotification(Notification::create($title, $body))
            ->withData($data);

        Firebase::messaging()->send($message);
    }

    /**
     * Send push notification to a topic.
     */
    public function sendToTopic(string $topic, string $title, string $body, array $data = []): void
    {
        $message = CloudMessage::withTarget('topic', $topic)
            ->withNotification(Notification::create($title, $body))
            ->withData($data);

        Firebase::messaging()->send($message);
    }

    /**
     * Send push notification to multiple devices.
     */
    public function sendToMultipleDevices(array $tokens, string $title, string $body, array $data = []): void
    {
        $message = CloudMessage::new()
            ->withNotification(Notification::create($title, $body))
            ->withData($data);

        Firebase::messaging()->sendMulticast($message, $tokens);
    }
}
SERVICE

echo "✓ PushNotificationService created"

# ── Step 3: Add Google OAuth routes ─────────────────────────────────────────
echo ""
echo "▶ Creating auth routes..."

# Check if routes/api.php exists, add to it
if [ -f "routes/api.php" ]; then
    cat >> routes/api.php << 'ROUTES'

/*
|--------------------------------------------------------------------------
| Google OAuth Routes
|--------------------------------------------------------------------------
*/
use App\Http\Controllers\Auth\GoogleAuthController;

Route::prefix('auth/google')->group(function () {
    Route::get('/redirect', [GoogleAuthController::class, 'redirect'])
        ->name('auth.google.redirect');
    Route::get('/callback', [GoogleAuthController::class, 'callback'])
        ->name('auth.google.callback');
});

/*
|--------------------------------------------------------------------------
| Authenticated API Routes
|--------------------------------------------------------------------------
*/
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/user', function (Request $request) {
        return $request->user();
    })->name('api.user');

    Route::post('/logout', function (Request $request) {
        $request->user()->currentAccessToken()->delete();
        return response()->json(['message' => 'Logged out successfully.']);
    })->name('api.logout');
});
ROUTES
    echo "✓ Auth routes added to routes/api.php"
fi

# ── Step 4: Add google_id and avatar columns to users migration ────────────
echo ""
echo "▶ Creating migration for Google OAuth fields..."

php artisan make:migration add_google_oauth_fields_to_users_table --table=users 2>/dev/null || true

# Find the latest migration file and update it
MIGRATION_FILE=$(ls -t database/migrations/*add_google_oauth_fields* 2>/dev/null | head -1)

if [ -n "$MIGRATION_FILE" ]; then
    cat > "$MIGRATION_FILE" << 'MIGRATION'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('google_id')->nullable()->unique()->after('email');
            $table->string('avatar')->nullable()->after('google_id');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['google_id', 'avatar']);
        });
    }
};
MIGRATION
    echo "✓ Migration created: $MIGRATION_FILE"
fi

# ── Step 5: Update Google config in services.php ────────────────────────────
echo ""
echo "▶ Updating config/services.php for Google OAuth..."

# Use sed to add Google config before the closing bracket
if [ -f "config/services.php" ]; then
    # Check if google config already exists
    if ! grep -q "'google'" config/services.php; then
        sed -i "s/\];/\n    'google' => [\n        'client_id' => env('GOOGLE_CLIENT_ID'),\n        'client_secret' => env('GOOGLE_CLIENT_SECRET'),\n        'redirect' => env('GOOGLE_REDIRECT_URL', '\/auth\/google\/callback'),\n    ],\n\n];/" config/services.php
        echo "✓ Google OAuth config added to services.php"
    else
        echo "✓ Google OAuth config already exists"
    fi
fi

# ── Step 6: Run the new migration ───────────────────────────────────────────
echo ""
echo "▶ Running new migrations..."
php artisan migrate --force
echo "✓ Migrations complete"

echo ""
echo "============================================"
echo "  ✓ Auth Configuration Complete!"
echo "============================================"
