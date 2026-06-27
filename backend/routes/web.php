<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\WalletController;

Route::get('/', function () {
    return view('welcome');
});

Route::get('/esewa/checkout/{transaction_id}', [WalletController::class, 'esewaCheckout'])->name('esewa.checkout');
Route::any('/esewa/success/{transaction_id?}', [WalletController::class, 'esewaSuccess'])->name('esewa.success');
Route::any('/esewa/failure/{transaction_id?}', [WalletController::class, 'esewaFailure'])->name('esewa.failure');
