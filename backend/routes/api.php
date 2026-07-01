<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\MatchController;
use App\Http\Controllers\Api\MatchFlowController;
use App\Http\Controllers\Api\TournamentController;
use App\Http\Controllers\Api\AdminController;
use App\Http\Controllers\Api\WalletController;
use App\Http\Controllers\Api\BannerController;
use App\Http\Controllers\Api\SupportController;
use App\Http\Controllers\Api\UserController;
use App\Http\Controllers\Api\ChatController;
use App\Http\Controllers\Api\HealthController;
use App\Http\Controllers\Api\TeamInviteController;
use App\Http\Controllers\Api\DisputeController;
use App\Http\Controllers\Api\TournamentChatController;
use App\Http\Controllers\Api\TopUpController;
use App\Http\Controllers\Api\AdminTopUpController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes — Battly Backend
|--------------------------------------------------------------------------
|
| All routes are prefixed with /api automatically by Laravel.
|
*/

// Fallback route named 'login' for Laravel's auth redirection logic
Route::get('/login', [AuthController::class, 'unauthenticated'])->name('login');

// ── Public Routes ────────────────────────────────────────────────────

Route::middleware('throttle:10,1')->group(function () {
    Route::post('/register', [AuthController::class, 'register']);
    Route::post('/login', [AuthController::class, 'login']);
    Route::post('/auth/google', [AuthController::class, 'googleAuth']);
});

// Public tournament endpoints (optional auth for owner/registration flags)
Route::middleware(['optional.sanctum', 'throttle:120,1'])->group(function () {
    Route::get('/tournaments', [TournamentController::class, 'index']);
    Route::get('/tournaments/featured', [TournamentController::class, 'featured']);
    Route::get('/tournaments/{tournament}', [TournamentController::class, 'show']);
});

// Public banner endpoints
Route::middleware('throttle:120,1')->get('/banners', [BannerController::class, 'index']);

Route::middleware('throttle:120,1')->group(function () {
    Route::get('/top-up/games', [TopUpController::class, 'games']);
    Route::get('/top-up/games/{slug}/packages', [TopUpController::class, 'packages']);
});

Route::middleware('throttle:30,1')->get('/health', [HealthController::class, 'show']);

// ── Authenticated Routes ─────────────────────────────────────────────

Route::middleware(['auth:sanctum', 'active.account', 'throttle:120,1'])->group(function () {
    // Auth / Profile
    Route::get('/user', [AuthController::class, 'user']);
    Route::put('/user', [AuthController::class, 'updateProfile']);
    Route::post('/user/fcm-token', [AuthController::class, 'registerFcmToken']);
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::delete('/user', [AuthController::class, 'deleteAccount']);

    // Public player profiles & chat
    Route::get('/users/{user}', [UserController::class, 'show']);
    Route::get('/conversations', [ChatController::class, 'index']);
    Route::post('/conversations', [ChatController::class, 'start']);
    Route::get('/conversations/{conversation}/messages', [ChatController::class, 'messages']);
    Route::post('/conversations/{conversation}/messages', [ChatController::class, 'send']);

    // ── Notifications ────────────────────────────────────────────────
    Route::get('/notifications', [AdminController::class, 'listNotifications']);
    Route::post('/notifications/mark-read', [AdminController::class, 'markAllRead']);
    Route::post('/notifications/{notification}/mark-read', [AdminController::class, 'markNotificationRead']);

    // Tournament registration & creation
    Route::post('/tournaments/{tournament}/register', [TournamentController::class, 'register']);
    Route::post('/tournaments/{tournament}/leave', [TournamentController::class, 'leave']);
    Route::patch('/tournaments/{tournament}/ready', [TournamentController::class, 'setReady']);
    Route::post('/tournaments', [TournamentController::class, 'store']);
    Route::get('/tournaments/my', [TournamentController::class, 'myTournaments']);

    // Game top-up orders
    Route::post('/top-up/orders', [TopUpController::class, 'createOrder']);
    Route::get('/top-up/orders', [TopUpController::class, 'indexOrders']);
    Route::get('/top-up/orders/{order}', [TopUpController::class, 'showOrder']);
    Route::post('/top-up/orders/{order}/pay/wallet', [TopUpController::class, 'payWallet']);
    Route::post('/top-up/orders/{order}/pay/esewa', [TopUpController::class, 'payEsewa']);

    // Team invites (2v2 / 3v3 / 4v4)
    Route::get('/tournaments/{tournament}/team-invites', [TeamInviteController::class, 'index']);
    Route::post('/tournaments/{tournament}/team-invites', [TeamInviteController::class, 'store']);
    Route::post('/tournaments/{tournament}/team-invites/{invite}/respond', [TeamInviteController::class, 'respond']);

    // Disputes & anti-cheat reports
    Route::get('/disputes', [DisputeController::class, 'index']);
    Route::post('/tournaments/{tournament}/disputes', [DisputeController::class, 'store']);
    Route::post('/tournaments/{tournament}/reports', [DisputeController::class, 'reportPlayer']);

    // Tournament lobby chat (registered players + owner)
    Route::get('/tournaments/my/lobby-chats', [TournamentChatController::class, 'myLobbyChats']);
    Route::get('/tournaments/{tournament}/chat/status', [TournamentChatController::class, 'status']);
    Route::get('/tournaments/{tournament}/chat/messages', [TournamentChatController::class, 'messages']);
    Route::post('/tournaments/{tournament}/chat/messages', [TournamentChatController::class, 'send']);
    Route::delete('/tournaments/{tournament}/chat/messages/{message}', [TournamentChatController::class, 'destroy']);

    // Tournament management (owner only)
    Route::delete('/tournaments/{tournament}/participants/{user}', [TournamentController::class, 'removeParticipant']);
    Route::patch('/tournaments/{tournament}/room-code', [TournamentController::class, 'updateRoomCode']);
    Route::patch('/tournaments/{tournament}/status', [TournamentController::class, 'updateStatus']);
    Route::get('/tournaments/{tournament}/ready-status', [TournamentController::class, 'readyStatus']);
    Route::get('/tournaments/{tournament}/match-flow', [MatchFlowController::class, 'show']);
    Route::post('/tournaments/{tournament}/match-flow/confirm-in-game', [MatchFlowController::class, 'confirmInGame']);
    Route::post('/tournaments/{tournament}/match-flow/stop', [MatchFlowController::class, 'stop']);
    Route::post('/tournaments/{tournament}/match-flow/acknowledge-stop', [MatchFlowController::class, 'acknowledgeStop']);
    Route::post('/tournaments/{tournament}/match-flow/vote-winner', [MatchFlowController::class, 'voteWinner']);
    Route::post('/tournaments/{tournament}/match-flow/submit-proof', [MatchFlowController::class, 'submitProof']);
    Route::post('/tournaments/{tournament}/cancel-underfilled', [TournamentController::class, 'cancelUnderfilled']);
    Route::get('/tournaments/{tournament}/results', [TournamentController::class, 'results']);
    Route::post('/tournaments/{tournament}/publish-results', [TournamentController::class, 'publishResults']);

    // Match history
    Route::get('/matches', [MatchController::class, 'index']);
    Route::get('/matches/{match}', [MatchController::class, 'show']);
    Route::post('/matches/{match}/submit-result', [MatchController::class, 'submitResult']);
    Route::get('/matches/{match}/verification-status', [MatchController::class, 'verificationStatus']);
    Route::post('/tournaments/{tournament}/submit-result', [MatchController::class, 'submitTournamentResult']);

    // Support
    Route::get('/support/tickets', [SupportController::class, 'index']);
    Route::post('/support/tickets', [SupportController::class, 'store']);

    // ── Wallet (Mobile App) ───────────────────────────────────────────
    Route::get('/wallet/balance', [WalletController::class, 'balance']);
    Route::get('/wallet/transactions', [WalletController::class, 'transactions']);
    Route::get('/wallet/transactions/{id}', [WalletController::class, 'transactionShow']);
    Route::post('/wallet/deposit/initiate', [WalletController::class, 'depositInitiate']);
    Route::post('/wallet/deposit/confirm', [WalletController::class, 'depositConfirm']);
    Route::post('/wallet/withdraw', [WalletController::class, 'withdraw']);
    Route::get('/wallet/search-recipient', [WalletController::class, 'searchRecipient']);
    Route::post('/wallet/transfer', [WalletController::class, 'transfer']);

    // ── Staff console (admin + moderator + host) ─────────────────────────
    Route::middleware('staff')->group(function () {
        Route::get('/admin/stats', [AdminController::class, 'stats']);
        Route::get('/admin/overview', [AdminController::class, 'overview']);

        Route::get('/teams', [AdminController::class, 'listTeams']);
        Route::get('/scrims', [AdminController::class, 'listScrims']);
        Route::post('/scrims', [AdminController::class, 'createScrim']);

        Route::get('/admin/wallet/transactions', [AdminController::class, 'listTransactions']);
        Route::get('/admin/wallet/withdrawals', [AdminController::class, 'listWithdrawals']);

        Route::post('/admin/tournaments', [TournamentController::class, 'store']);
        Route::put('/admin/tournaments/{tournament}', [TournamentController::class, 'update']);

        Route::get('/admin/matches', [MatchController::class, 'listAllMatches']);
        Route::post('/admin/matches/{match}/verify', [MatchController::class, 'verifyMatch']);
        Route::post('/admin/matches/{match}/reject', [MatchController::class, 'rejectMatch']);
        Route::get('/admin/tournaments/pending-results', [TournamentController::class, 'pendingResults']);

        Route::get('/admin/disputes', [DisputeController::class, 'adminIndex']);
        Route::get('/admin/support/tickets', [SupportController::class, 'adminIndex']);

        Route::get('/admin/players', [AdminController::class, 'listPlayers']);
        Route::get('/admin/players/{user}', [AdminController::class, 'showPlayer']);
    });

    // ── Moderator console (admin + moderator) ────────────────────────────
    Route::middleware('moderator')->group(function () {
        Route::post('/teams', [AdminController::class, 'createTeam']);

        Route::post('/admin/tournaments/{tournament}/approve-results', [TournamentController::class, 'approveResults']);
        Route::post('/admin/tournaments/{tournament}/reject-results', [TournamentController::class, 'rejectResults']);
        Route::post('/admin/tournaments/{tournament}/cancel', [TournamentController::class, 'adminCancel']);
        Route::post('/admin/tournaments/{tournament}/resolve-stop', [MatchFlowController::class, 'resolveStop']);
        Route::post('/admin/tournaments/{tournament}/match-flow/declare-winner', [MatchFlowController::class, 'declareWinner']);

        Route::post('/notifications', [AdminController::class, 'createNotification']);
        Route::delete('/notifications/{notification}', [AdminController::class, 'deleteNotification']);

        Route::post('/admin/wallet/withdraw', [AdminController::class, 'withdraw']);
        Route::post('/admin/wallet/withdrawals/{transaction}/approve', [AdminController::class, 'approveWithdrawal']);
        Route::post('/admin/wallet/withdrawals/{transaction}/reject', [AdminController::class, 'rejectWithdrawal']);

        Route::post('/admin/disputes/{dispute}/resolve', [DisputeController::class, 'adminResolve']);
        Route::post('/admin/reports/{report}/resolve', [DisputeController::class, 'adminResolveReport']);

        Route::put('/admin/support/tickets/{ticket}', [SupportController::class, 'adminUpdate']);
    });

    // ── Admin-only console ───────────────────────────────────────────────
    Route::middleware('admin')->group(function () {
        Route::get('/admin/users', [AdminController::class, 'listStaff']);
        Route::post('/admin/users/invite', [AdminController::class, 'inviteStaff']);
        Route::delete('/admin/users/{user}/revoke', [AdminController::class, 'revokeStaff']);

        Route::post('/admin/wallet/adjust', [AdminController::class, 'adjustWallet']);
        Route::post('/admin/wallet/transfer', [AdminController::class, 'transferWallet']);

        Route::patch('/admin/players/{user}/status', [AdminController::class, 'updatePlayerStatus']);

        Route::delete('/admin/tournaments/{tournament}', [TournamentController::class, 'destroy']);

        Route::post('/banners', [BannerController::class, 'store']);
        Route::post('/banners/{banner}', [BannerController::class, 'update']);
        Route::delete('/banners/{banner}', [BannerController::class, 'destroy']);

        // Home carousel (Zone admin — same handlers as banners)
        Route::get('/admin/home-carousel', [BannerController::class, 'index']);
        Route::post('/admin/home-carousel', [BannerController::class, 'store']);
        Route::post('/admin/home-carousel/{banner}', [BannerController::class, 'update']);
        Route::delete('/admin/home-carousel/{banner}', [BannerController::class, 'destroy']);

        Route::get('/admin/top-up/games', [AdminTopUpController::class, 'listGames']);
        Route::post('/admin/top-up/games', [AdminTopUpController::class, 'storeGame']);
        Route::post('/admin/top-up/games/{game}', [AdminTopUpController::class, 'updateGame']);
        Route::delete('/admin/top-up/games/{game}', [AdminTopUpController::class, 'deleteGame']);
        Route::get('/admin/top-up/packages', [AdminTopUpController::class, 'listPackages']);
        Route::post('/admin/top-up/packages', [AdminTopUpController::class, 'storePackage']);
        Route::post('/admin/top-up/packages/{package}', [AdminTopUpController::class, 'updatePackage']);
        Route::delete('/admin/top-up/packages/{package}', [AdminTopUpController::class, 'deletePackage']);
        Route::get('/admin/top-up/orders', [AdminTopUpController::class, 'listOrders']);
        Route::post('/admin/top-up/orders/{order}/complete', [AdminTopUpController::class, 'completeOrder']);
        Route::post('/admin/top-up/orders/{order}/reject', [AdminTopUpController::class, 'rejectOrder']);
    });
});
