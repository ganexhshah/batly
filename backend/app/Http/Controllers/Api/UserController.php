<?php



namespace App\Http\Controllers\Api;



use App\Http\Controllers\Controller;

use App\Models\User;

use App\Services\BattlyCache;

use Illuminate\Http\JsonResponse;

use Illuminate\Http\Request;



class UserController extends Controller

{

    /**

     * Public profile for another Battly player.

     */

    public function show(Request $request, User $user): JsonResponse

    {

        if (strtolower((string) ($user->status ?? 'active')) !== 'active') {

            return response()->json(['message' => 'User not found.'], 404);

        }



        $authUser = $request->user();

        $payload = BattlyCache::remember(

            BattlyCache::TAG_USERS,

            BattlyCache::userPublicKey($user->id),

            BattlyCache::TTL_USER,

            function () use ($user, $authUser): array {

                return [

                    'user' => [

                        'id' => $user->id,

                        'name' => $user->name,

                        'ign' => $user->ign,

                        'game_uid' => $user->game_uid,

                        'avatar_url' => $user->avatar_url,

                        'match_count' => $user->gameMatches()->count(),

                        'tournament_count' => $user->tournamentRegistrations()->count(),

                        'is_self' => $authUser->id === $user->id,

                    ],

                ];

            },

        );



        $payload['user']['is_self'] = $authUser->id === $user->id;



        return response()->json($payload);

    }

}

