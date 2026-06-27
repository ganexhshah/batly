<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\Rules\Password;

class AuthController extends Controller
{
    private function blockedAccountResponse(User $user): ?JsonResponse
    {
        $status = strtolower((string) ($user->status ?? 'active'));

        if (in_array($status, ['suspended', 'revoked'], true)) {
            return response()->json(['message' => 'Account access is restricted.'], 403);
        }

        return null;
    }

    /**
     * Register a new user and return an API token.
     */
    public function register(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name'         => ['required', 'string', 'max:255'],
            'email'        => ['required', 'string', 'email', 'max:255', 'unique:users'],
            'password'     => ['required', 'string', 'confirmed', Password::defaults()],
            'ign'          => ['nullable', 'string', 'max:100'],
            'game_uid'     => ['nullable', 'string', 'max:100'],
            'avatar_url'   => ['nullable', 'string', 'max:500'],
        ]);

        $user = User::create([
            'name'       => $validated['name'],
            'email'      => $validated['email'],
            'password'   => $validated['password'], // Hashed by cast
            'ign'        => $validated['ign'] ?? null,
            'game_uid'   => $validated['game_uid'] ?? null,
            'avatar_url' => $validated['avatar_url'] ?? null,
        ]);

        $token = $user->createToken('battly-mobile')->plainTextToken;

        return response()->json([
            'message' => 'Registration successful',
            'user'    => $user,
            'token'   => $token,
        ], 201);
    }

    /**
     * Login with email and password, return an API token.
     */
    public function login(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'email'    => ['required', 'string', 'email'],
            'password' => ['required', 'string'],
        ]);

        $user = User::where('email', $validated['email'])->first();

        if (! $user || ! Hash::check($validated['password'], (string) $user->password)) {
            return response()->json([
                'message' => 'Invalid credentials',
            ], 401);
        }

        if ($blocked = $this->blockedAccountResponse($user)) {
            return $blocked;
        }

        // Revoke all existing tokens for fresh login
        $user->tokens()->delete();

        $token = $user->createToken('battly-mobile')->plainTextToken;

        return response()->json([
            'message' => 'Login successful',
            'user'    => $user,
            'token'   => $token,
        ]);
    }

    /**
     * Get the authenticated user's profile.
     */
    public function user(Request $request): JsonResponse
    {
        return response()->json([
            'user' => $request->user(),
        ]);
    }

    /**
     * Update the authenticated user's profile.
     */
    public function updateProfile(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name'       => ['sometimes', 'string', 'max:255'],
            'ign'        => ['sometimes', 'nullable', 'string', 'max:100'],
            'game_uid'   => ['sometimes', 'nullable', 'string', 'max:100'],
            'avatar_url' => ['sometimes', 'nullable', 'string', 'max:500'],
        ]);

        $user = $request->user();
        $user->update($validated);

        return response()->json([
            'message' => 'Profile updated',
            'user'    => $user->fresh(),
        ]);
    }

    /**
     * Store the device FCM token for push notifications.
     */
    public function registerFcmToken(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'token' => ['required', 'string', 'max:512'],
        ]);

        $request->user()->update(['fcm_token' => $validated['token']]);

        return response()->json(['message' => 'FCM token registered']);
    }

    /**
     * Authenticate via Google (Firebase ID token).
     *
     * This handles both sign-up AND sign-in.
     * If the user does not exist, they are created automatically.
     * If they already exist (matched by google_id or email), they are logged in.
     */
    public function googleAuth(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'firebase_token' => ['required', 'string'],
            'name'           => ['required', 'string', 'max:255'],
            'email'          => ['required', 'string', 'email', 'max:255'],
            'google_id'      => ['required', 'string'],
            'avatar_url'     => ['nullable', 'string', 'max:500'],
        ]);

        // Verify the Firebase ID token by calling the Firebase Auth REST API.
        // This ensures the token is genuine and issued by our Firebase project.
        $firebaseApiKey = config('services.firebase.api_key');
        if (! is_string($firebaseApiKey) || $firebaseApiKey === '') {
            Log::error('Firebase authentication is not configured.');

            return response()->json(['message' => 'Google authentication is unavailable'], 503);
        }

        $firebaseUrl = 'https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=' . urlencode($firebaseApiKey);

        $client = new \GuzzleHttp\Client(['timeout' => 10]);
        try {
            $firebaseResponse = $client->post($firebaseUrl, [
                'json' => ['idToken' => $validated['firebase_token']],
            ]);

            $firebaseData = json_decode($firebaseResponse->getBody(), true);

            if (empty($firebaseData['users'])) {
                return response()->json(['message' => 'Invalid Firebase token'], 401);
            }

            $firebaseUser = $firebaseData['users'][0];
            $firebaseUid = $firebaseUser['localId'];
            $providerGoogleId = collect($firebaseUser['providerUserInfo'] ?? [])
                ->firstWhere('providerId', 'google.com')['rawId'] ?? null;

            // Verify the email matches
            if (! isset($firebaseUser['email'])
                || ! hash_equals(strtolower($firebaseUser['email']), strtolower($validated['email']))
                || ($firebaseUser['emailVerified'] ?? false) !== true
                || ! is_string($providerGoogleId)
                || ! hash_equals($providerGoogleId, $validated['google_id'])) {
                return response()->json(['message' => 'Email mismatch'], 401);
            }
        } catch (\Exception $e) {
            Log::warning('Firebase token verification failed.', [
                'exception' => $e::class,
            ]);

            return response()->json(['message' => 'Token verification failed'], 401);
        }

        // Prefer immutable provider identifiers; email is only used after Firebase
        // has confirmed that it is verified.
        $user = User::where('firebase_uid', $firebaseUid)
            ->orWhere('google_id', $providerGoogleId)
            ->orWhere('email', $validated['email'])
            ->first();

        if ($user) {
            // Existing user — update google_id and firebase_uid if not set
            $user->update([
                'google_id'    => $user->google_id ?? $providerGoogleId,
                'firebase_uid' => $user->firebase_uid ?? $firebaseUid,
                'avatar_url'   => $user->avatar_url ?? ($validated['avatar_url'] ?? null),
            ]);
        } else {
            // New user — create account
            $user = User::create([
                'name'         => $validated['name'],
                'email'        => $validated['email'],
                'google_id'    => $providerGoogleId,
                'firebase_uid' => $firebaseUid,
                'avatar_url'   => $validated['avatar_url'] ?? null,
                'password'     => null,
            ]);
        }

        if ($blocked = $this->blockedAccountResponse($user)) {
            return $blocked;
        }

        $user->tokens()->delete();
        $token = $user->createToken('battly-mobile')->plainTextToken;

        $statusCode = $user->wasRecentlyCreated ? 201 : 200;

        return response()->json([
            'message' => $user->wasRecentlyCreated ? 'Account created via Google' : 'Login successful',
            'user'    => $user,
            'token'   => $token,
        ], $statusCode);
    }

    /**
     * Logout: revoke the current API token.
     */
    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json([
            'message' => 'Logged out successfully',
        ]);
    }

    /**
     * Delete the authenticated user account and revoke all tokens.
     */
    public function deleteAccount(Request $request): JsonResponse
    {
        $user = $request->user();

        if ((float) $user->wallet_balance > 0) {
            return response()->json([
                'message' => 'Withdraw your wallet balance before deleting your account.',
            ], 422);
        }

        $user->tokens()->delete();
        $user->delete();

        return response()->json([
            'message' => 'Account deleted successfully',
        ]);
    }
}
