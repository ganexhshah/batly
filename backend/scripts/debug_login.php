<?php

putenv('APP_ENV=testing');
putenv('DB_CONNECTION=sqlite');
putenv('DB_DATABASE=:memory:');

require __DIR__.'/../vendor/autoload.php';

$app = require __DIR__.'/../bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
config(['database.default' => 'sqlite', 'database.connections.sqlite.database' => ':memory:']);
Illuminate\Support\Facades\Artisan::call('migrate', ['--force' => true]);

$user = App\Models\User::factory()->create([
    'email' => 'plain@test.com',
    'password' => Illuminate\Support\Facades\Hash::make('password'),
]);

$kernel = $app->make(Illuminate\Contracts\Http\Kernel::class);
$response = $kernel->handle(
    Illuminate\Http\Request::create('/api/login', 'POST', [], [], [], [
        'HTTP_ACCEPT' => 'application/json',
        'CONTENT_TYPE' => 'application/json',
    ], json_encode(['email' => 'plain@test.com', 'password' => 'password']))
);

echo 'STATUS: '.$response->getStatusCode().PHP_EOL;
echo $response->getContent().PHP_EOL;
