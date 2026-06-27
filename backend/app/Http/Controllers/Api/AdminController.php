<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\Team;
use App\Models\Scrim;
use App\Models\Notification;
use App\Models\SupportTicket;
use App\Models\Transaction;
use App\Models\Tournament;
use App\Models\GameMatch;
use App\Models\MatchDispute;
use App\Models\PlayerReport;
use App\Services\BattlyCache;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class AdminController extends Controller
{
    // ── Staff Management ─────────────────────────────────────────────

    public function listStaff(): JsonResponse
    {
        $users = User::query()
            ->whereIn('role', ['Admin', 'Moderator', 'Host'])
            ->orderBy('created_at', 'desc')
            ->get(['id', 'name', 'email', 'role', 'status', 'created_at']);
        return response()->json([
            'users' => $users,
        ]);
    }

    public function listPlayers(Request $request): JsonResponse
    {
        $query = User::query()
            ->where('role', 'Player')
            ->orderBy('created_at', 'desc');

        if ($search = trim((string) $request->query('search'))) {
            $query->where(function ($q) use ($search): void {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('email', 'like', "%{$search}%")
                    ->orWhere('ign', 'like', "%{$search}%")
                    ->orWhere('game_uid', 'like', "%{$search}%");
            });
        }

        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }

        $limit = min(max((int) $request->query('limit', 200), 1), 500);
        $players = $query->limit($limit)->get([
            'id', 'name', 'email', 'ign', 'game_uid', 'avatar_url',
            'wallet_balance', 'role', 'status', 'created_at',
        ]);

        return response()->json(['players' => $players]);
    }

    public function showPlayer(Request $request, User $user): JsonResponse
    {
        if ($user->role !== 'Player') {
            return response()->json(['message' => 'User is not a player account.'], 404);
        }

        return response()->json([
            'player' => $user->only([
                'id', 'name', 'email', 'ign', 'game_uid', 'avatar_url',
                'wallet_balance', 'role', 'status', 'created_at',
            ]),
        ]);
    }

    public function updatePlayerStatus(Request $request, User $user): JsonResponse
    {
        if ($user->role !== 'Player') {
            return response()->json(['message' => 'Only player accounts can be updated here.'], 422);
        }

        $validated = $request->validate([
            'status' => ['required', 'string', 'in:Active,Pending,Revoked,Suspended'],
        ]);

        if ($validated['status'] === 'Revoked' && (float) $user->wallet_balance > 0) {
            return response()->json(['message' => 'Cannot revoke a player with a non-zero wallet balance.'], 422);
        }

        $user->update(['status' => $validated['status']]);

        return response()->json([
            'message' => 'Player status updated.',
            'player' => $user->fresh(),
        ]);
    }

    public function inviteStaff(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name'  => ['required', 'string', 'max:255'],
            'email' => ['required', 'string', 'email', 'max:255', 'unique:users'],
            'role'  => ['required', 'string', 'in:Admin,Moderator,Host,Player'],
        ]);

        $user = User::create([
            'name'           => $validated['name'],
            'email'          => $validated['email'],
            'password'       => Hash::make(Str::random(32)),
            'status'         => 'Pending',
        ]);
        $user->forceFill([
            'role' => $validated['role'],
            'wallet_balance' => 0.00,
        ])->save();

        return response()->json([
            'message' => 'Invitation sent successfully!',
            'user'    => $user,
        ], 201);
    }

    public function revokeStaff(User $user): JsonResponse
    {
        if (! in_array($user->role, ['Admin', 'Moderator', 'Host'], true)) {
            return response()->json(['message' => 'User is not a staff member.'], 422);
        }

        if ((float) $user->wallet_balance > 0) {
            return response()->json(['message' => 'Cannot revoke staff with a non-zero wallet balance.'], 422);
        }

        $user->update(['status' => 'Revoked', 'role' => 'Player']);

        return response()->json([
            'message' => 'Staff access revoked successfully.',
        ]);
    }

    // ── Team Management ──────────────────────────────────────────────

    public function listTeams(): JsonResponse
    {
        $teams = Team::orderBy('points', 'desc')->get();
        return response()->json([
            'teams' => $teams,
        ]);
    }

    public function createTeam(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name'        => ['required', 'string', 'max:255'],
            'tag'         => ['required', 'string', 'max:10'],
            'game'        => ['required', 'string', 'max:100'],
            'points'      => ['nullable', 'integer'],
            'is_verified' => ['nullable', 'boolean'],
            'members'     => ['required', 'array'],
        ]);

        $team = Team::create([
            'name'        => $validated['name'],
            'tag'         => $validated['tag'],
            'game'        => $validated['game'],
            'points'      => $validated['points'] ?? 0,
            'is_verified' => $validated['is_verified'] ?? true,
            'members'     => $validated['members'],
        ]);

        return response()->json([
            'message' => 'Team registered successfully!',
            'team'    => $team,
        ], 201);
    }

    // ── Scrim Management ─────────────────────────────────────────────

    public function listScrims(): JsonResponse
    {
        $scrims = Scrim::orderBy('created_at', 'desc')->get();
        return response()->json([
            'scrims' => $scrims,
        ]);
    }

    public function createScrim(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'teams'  => ['required', 'string', 'max:255'],
            'game'   => ['required', 'string', 'max:100'],
            'time'   => ['required', 'string', 'max:100'],
            'status' => ['required', 'string', 'in:Open,Full,Finished'],
        ]);

        $scrim = Scrim::create($validated);

        return response()->json([
            'message' => 'Scrim room created successfully!',
            'scrim'   => $scrim,
        ], 201);
    }

    // ── Notification Alerts Feed ─────────────────────────────────────

    public function listNotifications(Request $request): JsonResponse
    {
        $role = strtolower((string) $request->user()?->role);
        $query = Notification::orderBy('created_at', 'desc');

        if (! in_array($role, ['admin', 'moderator', 'host'], true)) {
            $query->where(function ($q) use ($request) {
                $q->where('user_id', $request->user()->id)
                    ->orWhereNull('user_id');
            });
        }

        $notifications = $query->get();
        return response()->json([
            'notifications' => $notifications,
        ]);
    }

    public function markAllRead(Request $request): JsonResponse
    {
        Notification::query()
            ->where('user_id', $request->user()->id)
            ->where('unread', true)
            ->update(['unread' => false]);

        return response()->json([
            'message' => 'All notifications marked as read.',
        ]);
    }

    public function markNotificationRead(Request $request, Notification $notification): JsonResponse
    {
        if ($notification->user_id !== null && $notification->user_id !== $request->user()->id) {
            return response()->json(['message' => 'Unauthorized'], 403);
        }

        $notification->update(['unread' => false]);

        return response()->json([
            'message' => 'Notification marked as read.',
        ]);
    }

    public function createNotification(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'title' => ['required', 'string', 'max:255'],
            'message' => ['required', 'string', 'max:2000'],
            'user_id' => ['nullable', 'integer', 'exists:users,id'],
            'type' => ['nullable', 'string', 'max:100'],
            'deep_link' => ['nullable', 'string', 'max:255'],
            'image' => ['nullable', 'image', 'mimes:jpeg,png,jpg,gif', 'max:10240'],
        ]);

        $deepLink = $validated['deep_link'] ?? null;
        if ($request->hasFile('image')) {
            $diskName = config('filesystems.default', 'public');
            $path = $request->file('image')->store('notifications', $diskName);
            $deepLink = \Illuminate\Support\Facades\Storage::disk($diskName)->url($path);
        }

        $notification = Notification::create([
            'user_id' => $validated['user_id'] ?? null,
            'title' => $validated['title'],
            'message' => $validated['message'],
            'type' => $validated['type'] ?? 'broadcast',
            'deep_link' => $deepLink,
            'time' => 'Just Now',
            'unread' => true,
        ]);

        return response()->json([
            'message' => 'Notification published.',
            'notification' => $notification,
        ], 201);
    }

    public function deleteNotification(Notification $notification): JsonResponse
    {
        $notification->delete();
        return response()->json([
            'message' => 'Notification deleted successfully.',
        ]);
    }

    // ── Wallet and Cash Ledgers ──────────────────────────────────────

    public function listTransactions(Request $request): JsonResponse
    {
        $query = Transaction::with('user:id,name,email,ign,game_uid')
            ->orderBy('created_at', 'desc');

        if ($type = $request->query('type')) {
            $query->where('transaction_type', $type);
        }
        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }
        if ($userId = $request->query('user_id')) {
            $query->where('user_id', $userId);
        }

        $transactions = $query->limit((int) $request->query('limit', 100))->get();

        return response()->json([
            'transactions' => $transactions,
        ]);
    }

    public function listWithdrawals(): JsonResponse
    {
        $transactions = Transaction::with('user:id,name,email,ign,game_uid,wallet_balance')
            ->where('transaction_type', 'withdraw')
            ->where('status', 'pending')
            ->orderBy('created_at', 'asc')
            ->get();

        return response()->json(['withdrawals' => $transactions]);
    }

    public function withdraw(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'amount'    => ['required', 'numeric', 'min:10'],
            'recipient' => ['required', 'string', 'min:3'],
        ]);

        $user = $request->user();

        try {
            $transaction = DB::transaction(function () use ($user, $validated) {
                $locked = User::query()->whereKey($user->id)->lockForUpdate()->firstOrFail();

                if ((float) $locked->wallet_balance < $validated['amount']) {
                    throw new \RuntimeException('Insufficient wallet balance!');
                }

                $locked->decrement('wallet_balance', $validated['amount']);

                return Transaction::create([
                    'id'               => 'ADM-' . strtoupper(Str::random(10)),
                    'user_id'          => $locked->id,
                    'type'             => 'Outflow',
                    'transaction_type' => 'withdraw',
                    'payment_method'   => 'bank_transfer',
                    'amount'           => '-Rs. ' . number_format($validated['amount']),
                    'amount_numeric'   => -((float) $validated['amount']),
                    'description'      => 'Admin withdrawal to ' . $validated['recipient'],
                    'date'             => 'Just Now',
                    'status'           => 'pending',
                    'recipient_name'   => $validated['recipient'],
                ]);
            });
        } catch (\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        BattlyCache::flushWallet($user->id);
        BattlyCache::flushAdmin();

        return response()->json([
            'message' => 'Withdrawal request submitted!',
            'balance' => $user->fresh()->wallet_balance,
            'transaction' => $transaction,
        ]);
    }

    public function approveWithdrawal(Request $request, Transaction $transaction): JsonResponse
    {
        if ($transaction->transaction_type !== 'withdraw') {
            return response()->json(['message' => 'Transaction is not a withdrawal.'], 422);
        }

        if ($transaction->status !== 'pending') {
            return response()->json(['message' => 'Only pending withdrawals can be approved.'], 422);
        }

        $transaction->update([
            'status' => 'completed',
            'reviewed_by' => (string) $request->user()->id,
            'reviewed_at' => now(),
            'admin_note' => $request->input('note'),
        ]);

        Notification::create([
            'user_id' => $transaction->user_id,
            'title' => 'Withdrawal Approved',
            'message' => 'Your withdrawal ' . $transaction->id . ' has been approved.',
            'type' => 'wallet',
            'deep_link' => 'wallet',
            'time' => 'Just Now',
            'unread' => true,
            'metadata' => ['transaction_id' => $transaction->id],
        ]);

        BattlyCache::flushAdmin();

        return response()->json(['message' => 'Withdrawal approved.', 'transaction' => $transaction->fresh()]);
    }

    public function rejectWithdrawal(Request $request, Transaction $transaction): JsonResponse
    {
        if ($transaction->transaction_type !== 'withdraw') {
            return response()->json(['message' => 'Transaction is not a withdrawal.'], 422);
        }
        if ($transaction->status !== 'pending') {
            return response()->json(['message' => 'Only pending withdrawals can be rejected.'], 422);
        }

        DB::transaction(function () use ($request, $transaction): void {
            $amount = abs((float) $transaction->amount_numeric);
            $transaction->user->increment('wallet_balance', $amount);
            $transaction->update([
                'status' => 'rejected',
                'reviewed_by' => (string) $request->user()->id,
                'reviewed_at' => now(),
                'admin_note' => $request->input('note', 'Rejected by admin.'),
            ]);
        });

        Notification::create([
            'user_id' => $transaction->user_id,
            'title' => 'Withdrawal Rejected',
            'message' => 'Your withdrawal ' . $transaction->id . ' was rejected and refunded.',
            'type' => 'wallet',
            'deep_link' => 'wallet',
            'time' => 'Just Now',
            'unread' => true,
            'metadata' => ['transaction_id' => $transaction->id],
        ]);

        BattlyCache::flushWallet($transaction->user_id);
        BattlyCache::flushAdmin();

        return response()->json(['message' => 'Withdrawal rejected and refunded.', 'transaction' => $transaction->fresh()]);
    }

    public function adjustWallet(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'user_id' => ['required', 'integer', 'exists:users,id'],
            'amount' => ['required', 'numeric', 'not_in:0'],
            'reason' => ['required', 'string', 'max:255'],
        ]);

        $user = User::findOrFail($validated['user_id']);
        $amount = (float) $validated['amount'];

        try {
            DB::transaction(function () use ($request, $user, $amount, $validated): void {
                $locked = User::query()->whereKey($user->id)->lockForUpdate()->firstOrFail();
                $newBalance = (float) $locked->wallet_balance + $amount;
                if ($newBalance < 0) {
                    throw new \RuntimeException('Adjustment would result in a negative balance.');
                }

                $locked->increment('wallet_balance', $amount);
                Transaction::create([
                    'id' => 'ADJ-' . strtoupper(Str::random(10)),
                    'user_id' => $user->id,
                    'type' => $amount >= 0 ? 'Inflow' : 'Outflow',
                    'transaction_type' => $amount >= 0 ? 'refund' : 'adjustment',
                    'payment_method' => 'admin',
                    'amount' => ($amount >= 0 ? '+Rs. ' : '-Rs. ') . number_format(abs($amount)),
                    'amount_numeric' => $amount,
                    'description' => $validated['reason'],
                    'date' => 'Just Now',
                    'status' => 'completed',
                    'reviewed_by' => (string) $request->user()->id,
                    'reviewed_at' => now(),
                ]);
            });
        } catch (\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        BattlyCache::flushWallet($user->id);
        BattlyCache::flushAdmin();

        return response()->json(['message' => 'Wallet adjusted.', 'user' => $user->fresh()]);
    }

    public function transferWallet(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'source_user_id' => ['required', 'integer', 'exists:users,id'],
            'target_user_id' => ['required', 'integer', 'exists:users,id', 'different:source_user_id'],
            'amount' => ['required', 'numeric', 'min:0.01'],
            'reason' => ['required', 'string', 'max:255'],
        ]);

        $sourceId = (int) $validated['source_user_id'];
        $targetId = (int) $validated['target_user_id'];
        $amount = (float) $validated['amount'];
        $reason = $validated['reason'];

        try {
            DB::transaction(function () use ($request, $sourceId, $targetId, $amount, $reason): void {
                $source = User::query()->whereKey($sourceId)->lockForUpdate()->firstOrFail();
                $target = User::query()->whereKey($targetId)->lockForUpdate()->firstOrFail();

                if ((float) $source->wallet_balance < $amount) {
                    throw new \RuntimeException('Insufficient balance on source wallet.');
                }

                $source->decrement('wallet_balance', $amount);
                $target->increment('wallet_balance', $amount);

                $ref = strtoupper(Str::random(8));
                Transaction::create([
                    'id' => 'XFR-' . $ref . '-OUT',
                    'user_id' => $source->id,
                    'type' => 'Outflow',
                    'transaction_type' => 'transfer',
                    'payment_method' => 'admin',
                    'amount' => '-Rs. ' . number_format($amount),
                    'amount_numeric' => -$amount,
                    'description' => "Transfer to User #{$targetId} — {$reason}",
                    'date' => 'Just Now',
                    'status' => 'completed',
                    'reviewed_by' => (string) $request->user()->id,
                    'reviewed_at' => now(),
                ]);
                Transaction::create([
                    'id' => 'XFR-' . $ref . '-IN',
                    'user_id' => $target->id,
                    'type' => 'Inflow',
                    'transaction_type' => 'transfer',
                    'payment_method' => 'admin',
                    'amount' => '+Rs. ' . number_format($amount),
                    'amount_numeric' => $amount,
                    'description' => "Transfer from User #{$sourceId} — {$reason}",
                    'date' => 'Just Now',
                    'status' => 'completed',
                    'reviewed_by' => (string) $request->user()->id,
                    'reviewed_at' => now(),
                ]);
            });
        } catch (\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        BattlyCache::flushWallet($sourceId);
        BattlyCache::flushWallet($targetId);
        BattlyCache::flushAdmin();

        return response()->json(['message' => 'Transfer completed.']);
    }

    public function stats(Request $request): JsonResponse
    {
        $stats = BattlyCache::remember(
            BattlyCache::TAG_ADMIN,
            'admin:stats',
            BattlyCache::TTL_ADMIN,
            fn (): array => $this->buildStatsPayload(),
        );

        return response()->json($stats);
    }

    public function overview(Request $request): JsonResponse
    {
        $overview = BattlyCache::remember(
            BattlyCache::TAG_ADMIN,
            'admin:overview',
            BattlyCache::TTL_ADMIN,
            function (): array {
                $stats = $this->buildStatsPayload();

                $pendingResultApprovals = Tournament::query()
                    ->whereNotNull('custom_settings->results_submitted_at')
                    ->whereNull('custom_settings->results_approved_at')
                    ->count();

                return array_merge($stats, [
                    'pendingMatchVerifications' => GameMatch::where('status', 'pending_verification')->count(),
                    'pendingResultApprovals' => $pendingResultApprovals,
                    'openDisputes' => MatchDispute::whereIn('status', ['open', 'under_review'])->count(),
                    'openReports' => PlayerReport::whereIn('status', ['open', 'under_review'])->count(),
                    'pendingWithdrawals' => Transaction::where('transaction_type', 'withdraw')
                        ->where('status', 'pending')
                        ->count(),
                    'openSupportTickets' => SupportTicket::whereIn('status', ['open', 'pending'])->count(),
                ]);
            },
        );

        return response()->json($overview);
    }

    private function buildStatsPayload(): array
    {
        $totalUsers = User::count();
        $activeTournaments = Tournament::whereNotIn('status', ['completed', 'cancelled'])->count();
        $matchesPlayed = GameMatch::count();
        $totalRevenue = Transaction::where('type', 'Inflow')
            ->where('status', 'completed')
            ->sum('amount_numeric');

        $totalPrizePool = 0;
        foreach (Tournament::all(['prize_pool']) as $t) {
            $totalPrizePool += (float) preg_replace('/[^0-9.]/', '', (string) $t->prize_pool);
        }

        return [
            'totalUsers' => $totalUsers,
            'activeTournaments' => $activeTournaments,
            'matchesPlayed' => $matchesPlayed,
            'totalRevenue' => (float) $totalRevenue,
            'totalPrizePool' => $totalPrizePool,
            'newUsers' => User::where('created_at', '>=', now()->subDays(7))->count(),
            'totalTransactions' => Transaction::count(),
            'openTickets' => SupportTicket::whereIn('status', ['open', 'pending'])->count(),
        ];
    }
}
