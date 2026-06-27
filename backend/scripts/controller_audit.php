<?php

putenv('APP_ENV=local');
putenv('DB_CONNECTION=sqlite');
putenv('DB_DATABASE=:memory:');
putenv('CACHE_STORE=array');
putenv('REDIS_CLIENT=predis');
putenv('CACHE_STORE=array');
putenv('REDIS_CLIENT=predis');

require __DIR__.'/../vendor/autoload.php';

$app = require __DIR__.'/../bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
config([
    'database.default' => 'sqlite',
    'database.connections.sqlite.database' => ':memory:',
    'cache.default' => 'array',
]);
Illuminate\Support\Facades\Artisan::call('migrate', ['--force' => true]);

$logPath = dirname(__DIR__, 2).'/debug-0e79e7.log';

function audit_log(string $hypothesisId, string $location, string $message, array $data): void
{
    global $logPath;
    file_put_contents($logPath, json_encode([
        'sessionId' => '0e79e7',
        'hypothesisId' => $hypothesisId,
        'runId' => 'controller-audit',
        'location' => $location,
        'message' => $message,
        'data' => $data,
        'timestamp' => (int) round(microtime(true) * 1000),
    ]).PHP_EOL, FILE_APPEND | LOCK_EX);
}

$tournamentController = app(App\Http\Controllers\Api\TournamentController::class);
$authController = app(App\Http\Controllers\Api\AuthController::class);
$owner = App\Models\User::factory()->create();
$results = [];

// A: enum (DB only)
App\Models\Transaction::create([
    'id' => 'WDR-AUDIT2', 'user_id' => App\Models\User::factory()->create()->id,
    'type' => 'Outflow', 'transaction_type' => 'withdraw', 'payment_method' => 'bank',
    'amount' => '-Rs. 50', 'amount_numeric' => -50, 'description' => 'audit', 'date' => 'Now', 'status' => 'pending',
]);
$results['A'] = [
    'bug_confirmed' => App\Models\Transaction::where('transaction_type', 'withdrawal')->count() === 0,
];
audit_log('A', 'controller_audit.php', 'withdrawal enum', $results['A']);

// B: double leave via controller
$player = App\Models\User::factory()->create();
$t = App\Models\Tournament::create([
    'title' => 'Leave', 'game' => 'FF', 'mode' => 'Solo', 'entry_fee' => '0',
    'prize_pool' => '100', 'max_players' => 10, 'current_players' => 1,
    'status' => 'registration', 'created_by' => $owner->id, 'starts_at' => now()->addDay(),
]);
App\Models\TournamentRegistration::create([
    'tournament_id' => $t->id, 'user_id' => $player->id, 'status' => 'registered', 'entry_fee_paid' => 0,
]);
$req = Illuminate\Http\Request::create('/api/tournaments/'.$t->id.'/leave', 'POST');
$req->setUserResolver(fn () => $player);
$r1 = null;
$r2 = null;
try {
    $r1 = $tournamentController->leave($req, $t);
    $after1 = $t->fresh()->current_players;
    $r2 = $tournamentController->leave($req, $t);
    $after2 = $t->fresh()->current_players;
} catch (Throwable $e) {
    $after1 = $t->fresh()->current_players;
    $regStatus = App\Models\TournamentRegistration::where('tournament_id', $t->id)->where('user_id', $player->id)->value('status');
    $r2 = $tournamentController->leave($req, $t);
    $after2 = $t->fresh()->current_players;
    $results['B'] = [
        'bug_confirmed' => $r2 && $r2->getStatusCode() === 200 && $after2 < $after1,
        'first_status' => $r1?->getStatusCode(),
        'second_status' => $r2?->getStatusCode(),
        'after_first' => $after1,
        'after_second' => $after2,
        'reg_status_after_first' => $regStatus ?? null,
        'note' => 'first leave may throw on cache flush without Redis',
    ];
    audit_log('B', 'controller_audit.php', 'double leave', $results['B']);
    goto skip_b;
}
$results['B'] = [
    'bug_confirmed' => $r1->getStatusCode() === 200 && $r2->getStatusCode() === 200 && $after2 < $after1,
    'first_status' => $r1->getStatusCode(),
    'second_status' => $r2->getStatusCode(),
    'after_first' => $after1,
    'after_second' => $after2,
];
audit_log('B', 'controller_audit.php', 'double leave', $results['B']);
skip_b:

// C: suspended login
App\Models\User::factory()->create([
    'email' => 'suspended@audit.test',
    'password' => Illuminate\Support\Facades\Hash::make('pass1234'),
    'status' => 'Suspended',
    'role' => 'Player',
]);
$loginReq = Illuminate\Http\Request::create('/api/login', 'POST', [
    'email' => 'suspended@audit.test',
    'password' => 'pass1234',
]);
$loginResp = $authController->login($loginReq);
$results['C'] = [
    'bug_confirmed' => $loginResp->getStatusCode() === 200,
    'status' => $loginResp->getStatusCode(),
];
audit_log('C', 'controller_audit.php', 'suspended login', $results['C']);

// D: re-register after left
$player2 = App\Models\User::factory()->create();
$t2 = App\Models\Tournament::create([
    'title' => 'Re-reg', 'game' => 'FF', 'mode' => 'Solo', 'entry_fee' => '0',
    'prize_pool' => '100', 'max_players' => 10, 'current_players' => 0,
    'status' => 'registration', 'created_by' => $owner->id, 'starts_at' => now()->addDay(),
]);
App\Models\TournamentRegistration::create([
    'tournament_id' => $t2->id, 'user_id' => $player2->id, 'status' => 'left', 'entry_fee_paid' => 0,
]);
$regReq = Illuminate\Http\Request::create('/api/tournaments/'.$t2->id.'/register', 'POST');
$regReq->setUserResolver(fn () => $player2);
$regResp = $tournamentController->register($regReq, $t2);
$results['D'] = [
    'bug_confirmed' => $regResp->getStatusCode() === 409,
    'status' => $regResp->getStatusCode(),
    'message' => $regResp->getData(true)['message'] ?? null,
];
audit_log('D', 'controller_audit.php', 'reregister', $results['D']);

// E: leave when already left
$player3 = App\Models\User::factory()->create();
$t3 = App\Models\Tournament::create([
    'title' => 'Left', 'game' => 'FF', 'mode' => 'Solo', 'entry_fee' => '0',
    'prize_pool' => '100', 'max_players' => 1, 'current_players' => 0,
    'status' => 'registration', 'created_by' => $owner->id, 'starts_at' => now()->addDay(),
]);
App\Models\TournamentRegistration::create([
    'tournament_id' => $t3->id, 'user_id' => $player3->id, 'status' => 'left', 'entry_fee_paid' => 0,
]);
$leaveReq = Illuminate\Http\Request::create('/api/tournaments/'.$t3->id.'/leave', 'POST');
$leaveReq->setUserResolver(fn () => $player3);
$leaveResp = $tournamentController->leave($leaveReq, $t3);
$results['E'] = [
    'bug_confirmed' => $leaveResp->getStatusCode() === 200,
    'status' => $leaveResp->getStatusCode(),
];
audit_log('E', 'controller_audit.php', 'leave when left', $results['E']);

echo json_encode(['results' => $results], JSON_PRETTY_PRINT).PHP_EOL;
