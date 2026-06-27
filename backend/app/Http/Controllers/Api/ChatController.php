<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Conversation;
use App\Models\Message;
use App\Models\User;
use App\Services\BattlyCache;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ChatController extends Controller
{
    /**
     * List conversations for the authenticated user.
     */
    public function index(Request $request): JsonResponse
    {
        $userId = $request->user()->id;

        $conversations = BattlyCache::remember(
            BattlyCache::TAG_CHAT,
            "chat:conversations:{$userId}",
            BattlyCache::TTL_CHAT,
            fn () => Conversation::query()
                ->where('user_one_id', $userId)
                ->orWhere('user_two_id', $userId)
                ->with(['userOne:id,name,ign,avatar_url,game_uid', 'userTwo:id,name,ign,avatar_url,game_uid'])
                ->orderByDesc('last_message_at')
                ->orderByDesc('updated_at')
                ->get()
                ->map(fn (Conversation $c) => $this->formatConversation($c, $userId))
                ->values()
                ->all(),
        );

        return response()->json(['conversations' => $conversations]);
    }

    /**
     * Start or fetch a direct conversation with another user.
     */
    public function start(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'recipient_id' => ['required', 'integer', 'exists:users,id'],
        ]);

        $user = $request->user();
        $recipientId = (int) $validated['recipient_id'];

        if ($recipientId === $user->id) {
            return response()->json(['message' => 'You cannot chat with yourself.'], 422);
        }

        [$userOneId, $userTwoId] = Conversation::orderedPair($user->id, $recipientId);

        $conversation = Conversation::firstOrCreate(
            ['user_one_id' => $userOneId, 'user_two_id' => $userTwoId],
        );

        $conversation->load(['userOne:id,name,ign,avatar_url,game_uid', 'userTwo:id,name,ign,avatar_url,game_uid']);

        BattlyCache::flushChat($user->id);
        BattlyCache::flushChat($recipientId);

        return response()->json([
            'conversation' => $this->formatConversation($conversation, $user->id),
        ]);
    }

    /**
     * Fetch paginated messages for a conversation.
     */
    public function messages(Request $request, Conversation $conversation): JsonResponse
    {
        $user = $request->user();

        if (! $conversation->involves($user->id)) {
            return response()->json(['message' => 'Forbidden.'], 403);
        }

        $perPage = min((int) $request->query('per_page', 50), 100);

        $messages = $conversation->messages()
            ->with('sender:id,name,ign,avatar_url')
            ->orderByDesc('created_at')
            ->paginate($perPage);

        Message::query()
            ->where('conversation_id', $conversation->id)
            ->where('sender_id', '!=', $user->id)
            ->whereNull('read_at')
            ->update(['read_at' => now()]);

        return response()->json([
            'messages' => collect($messages->items())
                ->reverse()
                ->values()
                ->map(fn (Message $m) => $this->formatMessage($m))
                ->all(),
            'pagination' => [
                'current_page' => $messages->currentPage(),
                'last_page' => $messages->lastPage(),
                'total' => $messages->total(),
            ],
        ]);
    }

    /**
     * Send a message in a conversation.
     */
    public function send(Request $request, Conversation $conversation): JsonResponse
    {
        $user = $request->user();

        if (! $conversation->involves($user->id)) {
            return response()->json(['message' => 'Forbidden.'], 403);
        }

        $validated = $request->validate([
            'body' => ['required', 'string', 'max:2000'],
        ]);

        $body = trim($validated['body']);
        if ($body === '') {
            return response()->json(['message' => 'Message cannot be empty.'], 422);
        }

        $message = DB::transaction(function () use ($conversation, $user, $body) {
            $message = Message::create([
                'conversation_id' => $conversation->id,
                'sender_id' => $user->id,
                'body' => $body,
            ]);

            $conversation->update(['last_message_at' => now()]);

            return $message;
        });

        $message->load('sender:id,name,ign,avatar_url');

        BattlyCache::flushChat($user->id);
        $otherId = $conversation->otherUserId($user->id);
        if ($otherId) {
            BattlyCache::flushChat($otherId);
        }

        return response()->json([
            'message' => $this->formatMessage($message),
        ], 201);
    }

    private function formatConversation(Conversation $conversation, int $viewerId): array
    {
        $otherId = $conversation->otherUserId($viewerId);
        $other = $conversation->user_one_id === $otherId ? $conversation->userOne : $conversation->userTwo;

        $latest = $conversation->messages()
            ->latest()
            ->first();

        $unread = $conversation->messages()
            ->where('sender_id', '!=', $viewerId)
            ->whereNull('read_at')
            ->count();

        return [
            'id' => $conversation->id,
            'other_user' => $this->formatPublicUser($other),
            'last_message' => $latest ? [
                'body' => $latest->body,
                'created_at' => $latest->created_at->toIso8601String(),
                'sender_id' => $latest->sender_id,
            ] : null,
            'unread_count' => $unread,
            'last_message_at' => $conversation->last_message_at?->toIso8601String(),
        ];
    }

    private function formatMessage(Message $message): array
    {
        return [
            'id' => $message->id,
            'conversation_id' => $message->conversation_id,
            'body' => $message->body,
            'sender_id' => $message->sender_id,
            'sender' => $this->formatPublicUser($message->sender),
            'read_at' => $message->read_at?->toIso8601String(),
            'created_at' => $message->created_at->toIso8601String(),
            'is_mine' => false,
        ];
    }

    private function formatPublicUser(?User $user): ?array
    {
        if (! $user) {
            return null;
        }

        return [
            'id' => $user->id,
            'name' => $user->name,
            'ign' => $user->ign,
            'game_uid' => $user->game_uid,
            'avatar_url' => $user->avatar_url,
        ];
    }
}
