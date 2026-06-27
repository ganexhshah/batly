<?php

putenv('APP_ENV=local');
putenv('DB_CONNECTION=sqlite');
putenv('DB_DATABASE=:memory:');

require __DIR__.'/../vendor/autoload.php';
$app = require __DIR__.'/../bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
config(['database.default' => 'sqlite', 'database.connections.sqlite.database' => ':memory:']);
Illuminate\Support\Facades\Artisan::call('migrate', ['--force' => true]);

$auth = app(App\Http\Controllers\Api\AuthController::class);
$tournament = app(App\Http\Controllers\Api\TournamentController::class);
$dispute = app(App\Http\Controllers\Api\DisputeController::class);
$owner = App\Models\User::factory()->create(['wallet_balance' => 500]);

function req(string $method, string $path, array $data = [], ?App\Models\User $user = null): Illuminate\Http\Request
{
    $r = Illuminate\Http\Request::create($path, $method, $data);
    if ($user) {
        $r->setUserResolver(fn () => $user);
    }

    return $r;
}

$results = [];

// C: suspended login blocked
App\Models\User::factory()->create([
    'email' => 's@t.com', 'password' => Illuminate\Support\Facades\Hash::make('pass1234'),
    'status' => 'Suspended', 'role' => 'Player',
]);
$rC = $auth->login(req('POST', '/api/login', ['email' => 's@t.com', 'password' => 'pass1234']));
$results['C_suspended_login'] = $rC->getStatusCode() === 403;

// E: leave when already left -> 422
$p2 = App\Models\User::factory()->create();
$t2 = App\Models\Tournament::create([
    'title' => 'L', 'game' => 'FF', 'mode' => 'Solo', 'entry_fee' => '0', 'prize_pool' => '1',
    'max_players' => 1, 'current_players' => 0, 'status' => 'registration', 'created_by' => $owner->id, 'starts_at' => now()->addDay(),
]);
App\Models\TournamentRegistration::create(['tournament_id' => $t2->id, 'user_id' => $p2->id, 'status' => 'left', 'entry_fee_paid' => 0]);
$rE = $tournament->leave(req('POST', '/api/tournaments/'.$t2->id.'/leave', [], $p2), $t2);
$results['E_leave_when_left'] = $rE->getStatusCode() === 422;

// A: withdraw enum query
App\Models\Transaction::create([
    'id' => 'W1', 'user_id' => App\Models\User::factory()->create()->id, 'type' => 'Outflow',
    'transaction_type' => 'withdraw', 'payment_method' => 'b', 'amount' => '-1', 'amount_numeric' => -1,
    'description' => 'x', 'date' => 'n', 'status' => 'pending',
]);
$results['A_withdraw_enum'] = App\Models\Transaction::where('transaction_type', 'withdraw')->where('status', 'pending')->count() === 1;

// P1-7/8: publishResults rejects invalid user + duplicate ranks
$host = App\Models\User::factory()->create(['role' => 'host']);
$pReg = App\Models\User::factory()->create();
$tPub = App\Models\Tournament::create([
    'title' => 'Pub', 'game' => 'FF', 'mode' => 'Solo', 'entry_fee' => '0', 'prize_pool' => '100',
    'max_players' => 10, 'current_players' => 1, 'status' => 'live', 'created_by' => $host->id, 'starts_at' => now()->addHour(),
    'custom_settings' => [],
]);
App\Models\TournamentRegistration::create(['tournament_id' => $tPub->id, 'user_id' => $host->id, 'status' => 'registered', 'entry_fee_paid' => 0]);
App\Models\TournamentRegistration::create(['tournament_id' => $tPub->id, 'user_id' => $pReg->id, 'status' => 'registered', 'entry_fee_paid' => 0]);
$rInvalid = $tournament->publishResults(req('POST', '/x', [
    'results' => [['user_id' => 99999, 'rank' => 1, 'kills' => 0, 'points' => 10]],
], $host), $tPub);
$results['P7_invalid_user'] = $rInvalid->getStatusCode() === 422;
$rDup = $tournament->publishResults(req('POST', '/x', [
    'results' => [
        ['user_id' => $host->id, 'rank' => 1, 'kills' => 1, 'points' => 10],
        ['user_id' => $pReg->id, 'rank' => 1, 'kills' => 0, 'points' => 5],
    ],
], $host), $tPub);
$results['P8_duplicate_rank'] = $rDup->getStatusCode() === 422;

// P1-9: results() unauthorized
$outsider = App\Models\User::factory()->create();
$rRes = $tournament->results(req('GET', '/x', [], $outsider), $tPub);
$results['P9_results_auth'] = $rRes->getStatusCode() === 403;

// P1-10: deleteAccount blocks positive balance
$rich = App\Models\User::factory()->create(['wallet_balance' => 100]);
$rDel = $auth->deleteAccount(req('DELETE', '/api/user', [], $rich));
$results['P10_delete_balance'] = $rDel->getStatusCode() === 422;

// P0-5/P1-11: approveResults requires pending + idempotent guard
$mod = App\Models\User::factory()->create(['role' => 'moderator']);
$tAppr = App\Models\Tournament::create([
    'title' => 'Appr', 'game' => 'FF', 'mode' => 'Solo', 'entry_fee' => '0', 'prize_pool' => '100',
    'max_players' => 10, 'current_players' => 1, 'status' => 'live', 'created_by' => $host->id, 'starts_at' => now()->addHour(),
    'custom_settings' => ['results_submitted_at' => now()->toIso8601String()],
]);
$rNoPending = $tournament->approveResults(req('POST', '/x', [], $mod), $tAppr);
$results['P5_no_pending'] = $rNoPending->getStatusCode() === 422;
$tAppr->update(['custom_settings' => ['results_submitted_at' => now()->toIso8601String(), 'results_approved_at' => now()->toIso8601String()]]);
$rAlready = $tournament->approveResults(req('POST', '/x', [], $mod), $tAppr->fresh());
$results['P11_idempotent'] = $rAlready->getStatusCode() === 422;

// P0-4/P2-15: host update strips status/is_featured and merges custom_settings
$hostUser = App\Models\User::factory()->create(['role' => 'host']);
$tUpd = App\Models\Tournament::create([
    'title' => 'Upd', 'game' => 'FF', 'mode' => 'Solo', 'entry_fee' => '0', 'prize_pool' => '1',
    'max_players' => 10, 'current_players' => 0, 'status' => 'registration', 'created_by' => $hostUser->id, 'starts_at' => now()->addDay(),
    'is_featured' => false,
    'custom_settings' => ['match_flow' => ['phase' => 'ready'], 'map' => 'Bermuda'],
]);
$tournament->update(req('PUT', '/api/admin/tournaments/'.$tUpd->id, [
    'status' => 'live',
    'is_featured' => true,
    'custom_settings' => ['map' => 'Purgatory', 'evil_key' => 'hack'],
], $hostUser), $tUpd);
$fresh = $tUpd->fresh();
$results['P4_host_status'] = $fresh->status === 'registration';
$results['P4_host_featured'] = $fresh->is_featured === false;
$results['P15_merge_settings'] = ($fresh->custom_settings['map'] ?? null) === 'Purgatory'
    && isset($fresh->custom_settings['match_flow'])
    && ! isset($fresh->custom_settings['evil_key']);

// P2-14: reportPlayer requires reported participant
$reporter = App\Models\User::factory()->create();
$outsider2 = App\Models\User::factory()->create();
$tRep = App\Models\Tournament::create([
    'title' => 'Rep', 'game' => 'FF', 'mode' => 'Solo', 'entry_fee' => '0', 'prize_pool' => '1',
    'max_players' => 10, 'current_players' => 1, 'status' => 'live', 'created_by' => $host->id, 'starts_at' => now()->addHour(),
]);
App\Models\TournamentRegistration::create(['tournament_id' => $tRep->id, 'user_id' => $reporter->id, 'status' => 'registered', 'entry_fee_paid' => 0]);
$rRep = $dispute->reportPlayer(req('POST', '/x', ['reported_user_id' => $outsider2->id, 'reason' => 'cheat'], $reporter), $tRep);
$results['P14_report_participant'] = $rRep->getStatusCode() === 422;

// P0-1: store rolls back on insufficient balance
$poor = App\Models\User::factory()->create(['wallet_balance' => 0, 'role' => 'host']);
$beforeCount = App\Models\Tournament::count();
$rStore = $tournament->store(req('POST', '/api/admin/tournaments', [
    'title' => 'X', 'game' => 'FF', 'stage' => '1', 'type' => 'Solo', 'mode' => 'Solo',
    'prize_pool' => '100', 'entry_fee' => '50', 'max_players' => 10, 'starts_at' => now()->addDay()->toIso8601String(),
    'status' => 'registration',
], $poor));
$results['P1_store_wallet'] = $rStore->getStatusCode() === 422 && App\Models\Tournament::count() === $beforeCount;

// P2-16: eSewa empty secret
$results['P16_esewa'] = App\Services\EsewaService::verifyCallbackSignature(['signed_field_names' => 'total_amount', 'total_amount' => '1']) === false;

// P2-20: BattlyCache flush no throw without Redis
$cacheOk = true;
try {
    App\Services\BattlyCache::flush(App\Services\BattlyCache::TAG_TOURNAMENTS);
} catch (\Throwable) {
    $cacheOk = false;
}
$results['P20_cache'] = $cacheOk;

$allPass = ! in_array(false, $results, true);

echo json_encode($results + ['all_pass' => $allPass], JSON_PRETTY_PRINT).PHP_EOL;
exit($allPass ? 0 : 1);
