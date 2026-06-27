<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\GameMatch;
use App\Models\MatchDispute;
use App\Models\Notification;
use App\Models\PlayerReport;
use App\Models\Tournament;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class DisputeController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $disputes = MatchDispute::query()
            ->where('user_id', $request->user()->id)
            ->with('tournament:id,title')
            ->orderByDesc('created_at')
            ->get()
            ->map(fn (MatchDispute $d) => $this->formatDispute($d));

        return response()->json(['disputes' => $disputes]);
    }

    public function store(Request $request, Tournament $tournament): JsonResponse
    {
        $validated = $request->validate([
            'type' => ['required', 'string', 'in:wrong_result,wrong_rank,wrong_kills'],
            'reason' => ['required', 'string', 'max:2000'],
            'game_match_id' => ['nullable', 'integer', 'exists:game_matches,id'],
            'proof_images' => ['nullable', 'array'],
            'proof_images.*' => ['string', 'max:2000'],
            'proof_files' => ['nullable', 'array'],
            'proof_files.*' => ['file', 'image', 'max:5120'],
        ]);

        if (! $tournament->registrations()->where('user_id', $request->user()->id)->exists()) {
            return response()->json(['message' => 'You must be registered to raise a dispute.'], 403);
        }

        $proofImages = $validated['proof_images'] ?? [];
        if ($request->hasFile('proof_files')) {
            $diskName = config('filesystems.default', 'public');
            $disk = Storage::disk($diskName);
            foreach ($request->file('proof_files') as $file) {
                $path = $file->store('dispute-proofs', $diskName);
                $proofImages[] = $disk->url($path);
            }
        }

        if (! empty($validated['game_match_id'])) {
            $match = GameMatch::query()->find($validated['game_match_id']);
            if (! $match || $match->tournament_id !== $tournament->id) {
                return response()->json(['message' => 'Invalid match for this tournament.'], 422);
            }
            if ($match->user_id !== $request->user()->id) {
                return response()->json(['message' => 'You can only dispute your own match record.'], 422);
            }
        }

        $dispute = MatchDispute::create([
            'tournament_id' => $tournament->id,
            'game_match_id' => $validated['game_match_id'] ?? null,
            'user_id' => $request->user()->id,
            'type' => $validated['type'],
            'reason' => $validated['reason'],
            'proof_images' => $proofImages,
            'status' => 'open',
        ]);

        return response()->json([
            'message' => 'Dispute submitted. Admin will review your case.',
            'dispute' => $this->formatDispute($dispute),
        ], 201);
    }

    public function reportPlayer(Request $request, Tournament $tournament): JsonResponse
    {
        $validated = $request->validate([
            'reported_user_id' => ['required', 'integer', 'exists:users,id'],
            'reason' => ['required', 'string', 'max:2000'],
            'proof_images' => ['nullable', 'array'],
            'proof_images.*' => ['string', 'max:2000'],
            'proof_files' => ['nullable', 'array'],
            'proof_files.*' => ['file', 'image', 'max:5120'],
        ]);

        if ((int) $validated['reported_user_id'] === $request->user()->id) {
            return response()->json(['message' => 'You cannot report yourself.'], 422);
        }

        if (! $tournament->registrations()->where('user_id', $request->user()->id)->exists()) {
            return response()->json(['message' => 'You must be registered in this tournament to report a player.'], 403);
        }

        if (! $tournament->registrations()
            ->where('user_id', $validated['reported_user_id'])
            ->where('status', 'registered')
            ->exists()) {
            return response()->json(['message' => 'Reported user is not a registered participant in this tournament.'], 422);
        }

        $proofImages = $validated['proof_images'] ?? [];
        if ($request->hasFile('proof_files')) {
            $diskName = config('filesystems.default', 'public');
            $disk = Storage::disk($diskName);
            foreach ($request->file('proof_files') as $file) {
                $path = $file->store('report-proofs', $diskName);
                $proofImages[] = $disk->url($path);
            }
        }

        $report = PlayerReport::create([
            'tournament_id' => $tournament->id,
            'reporter_id' => $request->user()->id,
            'reported_user_id' => $validated['reported_user_id'],
            'reason' => $validated['reason'],
            'proof_images' => $proofImages,
            'status' => 'open',
        ]);

        return response()->json([
            'message' => 'Report submitted for admin review.',
            'report' => [
                'id' => $report->id,
                'status' => $report->status,
                'reported_user_id' => $report->reported_user_id,
            ],
        ], 201);
    }

    public function adminIndex(Request $request): JsonResponse
    {
        $disputes = MatchDispute::query()
            ->with(['tournament:id,title', 'user:id,name,ign'])
            ->orderByDesc('created_at')
            ->limit(100)
            ->get()
            ->map(fn (MatchDispute $d) => $this->formatDispute($d));

        $reports = PlayerReport::query()
            ->with(['tournament:id,title', 'reporter:id,name,ign', 'reportedUser:id,name,ign'])
            ->orderByDesc('created_at')
            ->limit(100)
            ->get()
            ->map(fn (PlayerReport $r) => [
                'id' => $r->id,
                'tournament_id' => $r->tournament_id,
                'tournament_title' => $r->tournament?->title,
                'reporter' => $r->reporter?->ign ?: $r->reporter?->name,
                'reported_user' => $r->reportedUser?->ign ?: $r->reportedUser?->name,
                'reason' => $r->reason,
                'proof_images' => $r->proof_images ?? [],
                'status' => $r->status,
                'admin_note' => $r->admin_note,
                'created_at' => $r->created_at?->toIso8601String(),
            ]);

        return response()->json(['disputes' => $disputes, 'reports' => $reports]);
    }

    public function adminResolve(Request $request, MatchDispute $dispute): JsonResponse
    {
        $validated = $request->validate([
            'status' => ['required', 'string', 'in:resolved,dismissed,under_review'],
            'admin_note' => ['nullable', 'string', 'max:2000'],
        ]);

        $dispute->update([
            'status' => $validated['status'],
            'admin_note' => $validated['admin_note'] ?? null,
            'resolved_by' => $request->user()->id,
            'resolved_at' => in_array($validated['status'], ['resolved', 'dismissed'], true) ? now() : null,
        ]);

        Notification::create([
            'user_id' => $dispute->user_id,
            'title' => 'Dispute Update',
            'message' => 'Your dispute for "' . ($dispute->tournament?->title ?? 'a tournament') . '" was marked ' . $validated['status'] . '.',
            'type' => 'dispute',
            'deep_link' => 'tournament:' . $dispute->tournament_id,
            'time' => 'Just Now',
            'unread' => true,
            'metadata' => ['dispute_id' => $dispute->id],
        ]);

        return response()->json(['message' => 'Dispute updated.', 'dispute' => $this->formatDispute($dispute->fresh())]);
    }

    public function adminResolveReport(Request $request, PlayerReport $report): JsonResponse
    {
        $validated = $request->validate([
            'status' => ['required', 'string', 'in:resolved,dismissed,under_review'],
            'admin_note' => ['nullable', 'string', 'max:2000'],
        ]);

        $report->update([
            'status' => $validated['status'],
            'admin_note' => $validated['admin_note'] ?? null,
            'resolved_by' => $request->user()->id,
            'resolved_at' => in_array($validated['status'], ['resolved', 'dismissed'], true) ? now() : null,
        ]);

        Notification::create([
            'user_id' => $report->reporter_id,
            'title' => 'Report Update',
            'message' => 'Your player report for "' . ($report->tournament?->title ?? 'a tournament') . '" was marked ' . $validated['status'] . '.',
            'type' => 'report',
            'deep_link' => 'tournament:' . $report->tournament_id,
            'time' => 'Just Now',
            'unread' => true,
            'metadata' => ['report_id' => $report->id],
        ]);

        return response()->json([
            'message' => 'Report updated.',
            'report' => [
                'id' => $report->id,
                'status' => $report->status,
                'admin_note' => $report->admin_note,
            ],
        ]);
    }

    private function formatDispute(MatchDispute $dispute): array
    {
        return [
            'id' => $dispute->id,
            'tournament_id' => $dispute->tournament_id,
            'tournament_title' => $dispute->tournament?->title,
            'game_match_id' => $dispute->game_match_id,
            'user_id' => $dispute->user_id,
            'type' => $dispute->type,
            'reason' => $dispute->reason,
            'proof_images' => $dispute->proof_images ?? [],
            'status' => $dispute->status,
            'admin_note' => $dispute->admin_note,
            'filer' => $dispute->user?->ign ?: $dispute->user?->name,
            'created_at' => $dispute->created_at?->toIso8601String(),
        ];
    }
}
