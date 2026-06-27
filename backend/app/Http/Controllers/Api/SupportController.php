<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Notification;
use App\Models\SupportTicket;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SupportController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $tickets = SupportTicket::where('user_id', $request->user()->id)
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json(['tickets' => $tickets]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'subject' => ['required', 'string', 'max:255'],
            'message' => ['required', 'string', 'max:5000'],
            'category' => ['nullable', 'string', 'max:100'],
        ]);

        $ticket = SupportTicket::create([
            'user_id' => $request->user()->id,
            'subject' => $validated['subject'],
            'message' => $validated['message'],
            'category' => $validated['category'] ?? 'general',
        ]);

        Notification::create([
            'title' => 'New Support Ticket',
            'message' => $request->user()->name . ' submitted: ' . $ticket->subject,
            'type' => 'support',
            'time' => 'Just Now',
            'unread' => true,
            'metadata' => ['ticket_id' => $ticket->id],
        ]);

        return response()->json([
            'message' => 'Support ticket submitted successfully.',
            'ticket' => $ticket,
        ], 201);
    }

    public function adminIndex(Request $request): JsonResponse
    {
        $query = SupportTicket::with('user:id,name,email,ign,game_uid')
            ->orderByRaw("CASE WHEN status = 'open' THEN 0 WHEN status = 'pending' THEN 1 ELSE 2 END")
            ->orderBy('created_at', 'desc');

        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }

        return response()->json(['tickets' => $query->get()]);
    }

    public function adminUpdate(Request $request, SupportTicket $ticket): JsonResponse
    {
        $validated = $request->validate([
            'status' => ['required', 'string', 'in:open,pending,resolved,closed'],
            'priority' => ['nullable', 'string', 'in:low,normal,high,urgent'],
            'admin_reply' => ['nullable', 'string', 'max:5000'],
        ]);

        $ticket->fill($validated);
        $ticket->assigned_to = $request->user()->id;
        if (in_array($validated['status'], ['resolved', 'closed'], true)) {
            $ticket->resolved_at = now();
        }
        $ticket->save();

        Notification::create([
            'user_id' => $ticket->user_id,
            'title' => 'Support Ticket Updated',
            'message' => 'Your ticket "' . $ticket->subject . '" is now ' . $ticket->status . '.',
            'type' => 'support',
            'deep_link' => 'support',
            'time' => 'Just Now',
            'unread' => true,
            'metadata' => ['ticket_id' => $ticket->id],
        ]);

        return response()->json([
            'message' => 'Support ticket updated.',
            'ticket' => $ticket->fresh(['user:id,name,email,ign,game_uid']),
        ]);
    }
}
