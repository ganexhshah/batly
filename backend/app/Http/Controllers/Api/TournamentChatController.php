<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Tournament;
use App\Models\TournamentChatMessage;
use App\Services\TournamentIntegrityService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class TournamentChatController extends Controller
{
    public function __construct(
        private readonly TournamentIntegrityService $integrity,
    ) {}

    /**
     * Lobby chats for tournaments the user is registered in (or owns).
     */
    public function myLobbyChats(Request $request): JsonResponse
    {
        $userId = $request->user()->id;

        $tournaments = Tournament::query()
            ->whereHas('registrations', fn ($q) => $q->where('user_id', $userId))
            ->with(['chatMessages' => function ($query) {
                $query->with('user:id,name,ign')
                    ->orderByDesc('created_at')
                    ->limit(1);
            }])
            ->orderByDesc('starts_at')
            ->get();

        $lobbyChats = $tournaments->map(function (Tournament $tournament) {
            $last = $tournament->chatMessages->first();
            $chatOpen = $this->integrity->chatOpen($tournament);

            return [
                'tournament_id' => $tournament->id,
                'title' => $tournament->title,
                'status' => $tournament->status,
                'status_text' => strtoupper($tournament->status ?? 'upcoming'),
                'chat_open' => $chatOpen,
                'closed_reason' => $chatOpen ? null : $this->integrity->chatClosedReason($tournament),
                'last_message' => $last ? [
                    'body' => $last->body,
                    'sender_name' => $last->user?->ign ?: $last->user?->name ?: 'Player',
                    'created_at' => $last->created_at?->toIso8601String(),
                ] : null,
            ];
        })->values()->all();

        return response()->json(['lobby_chats' => $lobbyChats]);
    }

    /**
     * Chat status — open before match ends, closed after completed/cancelled.
     */
    public function status(Request $request, Tournament $tournament): JsonResponse
    {
        if (! $this->canAccess($request, $tournament)) {
            return response()->json(['message' => 'Only registered players can view tournament chat.'], 403);
        }

        $open = $this->integrity->chatOpen($tournament);

        return response()->json([
            'open' => $open,
            'closed_reason' => $open ? null : $this->integrity->chatClosedReason($tournament),
        ]);
    }

    /**
     * Paginated tournament lobby chat (newest page returns chronological order).
     */
    public function messages(Request $request, Tournament $tournament): JsonResponse
    {
        if (! $this->canAccess($request, $tournament)) {
            return response()->json(['message' => 'Only registered players can view tournament chat.'], 403);
        }

        $open = $this->integrity->chatOpen($tournament);

        if (! $open) {
            return response()->json([
                'open' => false,
                'closed_reason' => $this->integrity->chatClosedReason($tournament),
                'messages' => $this->loadMessages($tournament),
            ]);
        }

        $perPage = min((int) $request->query('per_page', 50), 100);

        $messages = $tournament->chatMessages()
            ->with('user:id,name,ign,avatar_url')
            ->orderByDesc('created_at')
            ->paginate($perPage);

        return response()->json([
            'open' => true,
            'messages' => collect($messages->items())
                ->reverse()
                ->values()
                ->map(fn (TournamentChatMessage $m) => $this->formatMessage($m, $tournament))
                ->all(),
            'pagination' => [
                'current_page' => $messages->currentPage(),
                'last_page' => $messages->lastPage(),
                'total' => $messages->total(),
            ],
        ]);
    }

    /**
     * Send a message in tournament lobby chat.
     */
    public function send(Request $request, Tournament $tournament): JsonResponse
    {
        if (! $this->canAccess($request, $tournament)) {
            return response()->json(['message' => 'Only registered players can chat.'], 403);
        }

        if (! $this->integrity->chatOpen($tournament)) {
            return response()->json([
                'message' => $this->integrity->chatClosedReason($tournament) ?? 'Tournament chat is closed.',
            ], 422);
        }

        $validated = $request->validate([
            'body' => ['nullable', 'string', 'max:500'],
            'image' => ['nullable', 'image', 'mimes:jpeg,jpg,png,gif,webp', 'max:5120'],
        ]);

        $body = trim((string) ($validated['body'] ?? ''));
        $imageUrl = $this->resolveImageUrl($request, $tournament);

        if ($body === '' && $imageUrl === null) {
            return response()->json(['message' => 'Message cannot be empty.'], 422);
        }

        $message = TournamentChatMessage::create([
            'tournament_id' => $tournament->id,
            'user_id' => $request->user()->id,
            'body' => $body,
            'image_url' => $imageUrl,
        ]);

        $message->load('user:id,name,ign,avatar_url');

        return response()->json([
            'message' => $this->formatMessage($message, $tournament),
        ], 201);
    }

    private function canAccess(Request $request, Tournament $tournament): bool
    {
        return $tournament->registrations()
            ->where('user_id', $request->user()->id)
            ->exists();
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function loadMessages(Tournament $tournament, int $limit = 50): array
    {
        return $tournament->chatMessages()
            ->with('user:id,name,ign,avatar_url')
            ->orderByDesc('created_at')
            ->limit($limit)
            ->get()
            ->reverse()
            ->values()
            ->map(fn (TournamentChatMessage $m) => $this->formatMessage($m, $tournament))
            ->all();
    }

    private function formatMessage(TournamentChatMessage $message, Tournament $tournament): array
    {
        $user = $message->user;
        $isOwner = $tournament->created_by === $message->user_id;

        return [
            'id' => $message->id,
            'user_id' => $message->user_id,
            'sender_name' => $user?->ign ?: $user?->name ?: 'Player',
            'avatar_url' => $user?->avatar_url,
            'is_owner' => $isOwner,
            'body' => $message->body,
            'image_url' => $message->image_url,
            'created_at' => $message->created_at?->toIso8601String(),
        ];
    }

    private function resolveImageUrl(Request $request, Tournament $tournament): ?string
    {
        if (! $request->hasFile('image')) {
            return null;
        }

        $diskName = config('filesystems.default', 'public');
        $path = $request->file('image')->store("tournament-chat/{$tournament->id}", $diskName);

        return Storage::disk($diskName)->url($path);
    }
}
