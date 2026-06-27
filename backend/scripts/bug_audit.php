<?php

/**
 * Backend bug audit — writes NDJSON to debug-0e79e7.log (session 0e79e7).
 * Run: php scripts/bug_audit.php
 */

use App\Models\Tournament;
use App\Models\TournamentRegistration;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Support\Facades\Hash;

require __DIR__.'/../vendor/autoload.php';

$logPath = dirname(__DIR__, 2).'/debug-0e79e7.log';

function audit_log(string $hypothesisId, string $location, string $message, array $data): void
{
    global $logPath;
    $line = json_encode([
        'sessionId' => '0e79e7',
        'hypothesisId' => $hypothesisId,
        'runId' => 'audit-script',
        'location' => $location,
        'message' => $message,
        'data' => $data,
        'timestamp' => (int) round(microtime(true) * 1000),
    ], JSON_UNESCAPED_SLASHES);
    file_put_contents($logPath, $line.PHP_EOL, FILE_APPEND | LOCK_EX);
}

$_SERVER['APP_ENV'] = 'testing';
putenv('APP_ENV=testing');
putenv('DB_CONNECTION=sqlite');
putenv('DB_DATABASE=:memory:');
putenv('DB_URL=');

$app = require __DIR__.'/../bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

config(['database.default' => 'sqlite', 'database.connections.sqlite.database' => ':memory:']);
Illuminate\Support\Facades\Artisan::call('migrate', ['--force' => true]);

$kernel = $app->make(Illuminate\Contracts\Http\Kernel::class);
$authRequest = function (User $user, string $method, string $uri, array $json = []) use ($kernel) {
    $req = Illuminate\Http\Request::create($uri, $method, [], [], [], [
        'HTTP_ACCEPT' => 'application/json',
        'CONTENT_TYPE' => 'application/json',
        'HTTP_AUTHORIZATION' => 'Bearer '.$user->createToken('audit')->plainTextToken,
    ], $json ? json_encode($json) : null);
    $resp = $kernel->handle($req);

    return $resp;
};

$results = [];
$owner = User::factory()->create();

// A: pendingWithdrawals enum
Transaction::create([
    'id' => 'WDR-AUDIT',
    'user_id' => User::factory()->create()->id,
    'type' => 'Outflow',
    'transaction_type' => 'withdraw',
    'payment_method' => 'bank',
    'amount' => '-Rs. 50',
    'amount_numeric' => -50,
    'description' => 'audit',
    'date' => 'Now',
    'status' => 'pending',
]);
$wrong = Transaction::where('transaction_type', 'withdrawal')->where('status', 'pending')->count();
$right = Transaction::where('transaction_type', 'withdraw')->where('status', 'pending')->count();
$results['A'] = ['bug_confirmed' => $wrong === 0 && $right === 1, 'wrong' => $wrong, 'right' => $right];
audit_log('A', 'bug_audit.php:pendingWithdrawals', 'enum mismatch', $results['A']);

// B: double leave
$player = User::factory()->create();
$t = Tournament::create([
    'title' => 'Audit Leave', 'game' => 'FF', 'mode' => 'Solo', 'entry_fee' => '0',
    'prize_pool' => '100', 'max_players' => 10, 'current_players' => 1,
    'status' => 'registration', 'created_by' => $owner->id, 'starts_at' => now()->addDay(),
]);
TournamentRegistration::create([
    'tournament_id' => $t->id, 'user_id' => $player->id, 'status' => 'registered', 'entry_fee_paid' => 0,
]);
$r1 = $authRequest($player, 'POST', "/api/tournaments/{$t->id}/leave");
$after1 = $t->fresh()->current_players;
$r2 = $authRequest($player, 'POST', "/api/tournaments/{$t->id}/leave");
$after2 = $t->fresh()->current_players;
$results['B'] = [
    'bug_confirmed' => $r1->getStatusCode() === 200 && $r2->getStatusCode() === 200 && $after2 < $after1,
    'first_status' => $r1->getStatusCode(),
    'second_status' => $r2->getStatusCode(),
    'after_first' => $after1,
    'after_second' => $after2,
];
audit_log('B', 'bug_audit.php:doubleLeave', 'player count', $results['B']);

// C: suspended login
User::factory()->create([
    'email' => 'suspended@audit.test',
    'password' => Hash::make('pass1234'),
    'status' => 'Suspended',
    'role' => 'Player',
]);
$loginResp = $authRequest(
    User::where('email', 'suspended@audit.test')->first(),
    'POST',
    '/api/login',
    ['email' => 'suspended@audit.test', 'password' => 'pass1234']
);
$loginBody = json_decode($loginResp->getContent(), true);
$results['C'] = [
    'bug_confirmed' => $loginResp->getStatusCode() === 200,
    'status' => $loginResp->getStatusCode(),
    'body' => $loginBody,
];
audit_log('C', 'bug_audit.php:suspendedLogin', 'login status', $results['C']);

// D: re-register after leave
$player2 = User::factory()->create();
$t2 = Tournament::create([
    'title' => 'Re-reg', 'game' => 'FF', 'mode' => 'Solo', 'entry_fee' => '0',
    'prize_pool' => '100', 'max_players' => 10, 'current_players' => 0,
    'status' => 'registration', 'created_by' => $owner->id, 'starts_at' => now()->addDay(),
]);
TournamentRegistration::create([
    'tournament_id' => $t2->id, 'user_id' => $player2->id, 'status' => 'left', 'entry_fee_paid' => 0,
]);
$regResp = $authRequest($player2, 'POST', "/api/tournaments/{$t2->id}/register");
$regBody = json_decode($regResp->getContent(), true);
$results['D'] = [
    'bug_confirmed' => $regResp->getStatusCode() === 409,
    'status' => $regResp->getStatusCode(),
    'message' => $regBody['message'] ?? null,
];
audit_log('D', 'bug_audit.php:reregister', 're-register blocked', $results['D']);

// E: leave when already left
$player3 = User::factory()->create();
$t3 = Tournament::create([
    'title' => 'Left guard', 'game' => 'FF', 'mode' => 'Solo', 'entry_fee' => '0',
    'prize_pool' => '100', 'max_players' => 1, 'current_players' => 0,
    'status' => 'registration', 'created_by' => $owner->id, 'starts_at' => now()->addDay(),
]);
TournamentRegistration::create([
    'tournament_id' => $t3->id, 'user_id' => $player3->id, 'status' => 'left', 'entry_fee_paid' => 0,
]);
$leaveResp = $authRequest($player3, 'POST', "/api/tournaments/{$t3->id}/leave");
$results['E'] = ['bug_confirmed' => $leaveResp->getStatusCode() === 200, 'status' => $leaveResp->getStatusCode()];
audit_log('E', 'bug_audit.php:leaveWhenLeft', 'leave on left status', $results['E']);

echo json_encode(['audit_complete' => true, 'results' => $results], JSON_PRETTY_PRINT).PHP_EOL;
