<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;

class HealthController extends Controller
{
    public function show(): JsonResponse
    {
        $dbOk = false;
        try {
            DB::connection()->getPdo();
            DB::select('select 1');
            $dbOk = true;
        } catch (\Throwable) {
            $dbOk = false;
        }

        $healthy = $dbOk;

        return response()->json([
            'status' => $healthy ? 'ok' : 'degraded',
        ], $healthy ? 200 : 503);
    }
}
