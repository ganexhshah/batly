<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('transactions', function (Blueprint $table) {
            // Add better categorization
            $table->string('transaction_type')->nullable()->after('type'); // deposit, withdraw, transfer, winnings, refund, spend
            $table->string('payment_method')->nullable()->after('transaction_type'); // esewa, khalti, ime_pay, connect_ips, bank_transfer
            $table->string('reference_id')->nullable()->after('payment_method'); // eSewa ref ID, etc.
            $table->string('recipient_name')->nullable()->after('reference_id');
            $table->unsignedBigInteger('recipient_id')->nullable()->after('recipient_name');
            $table->decimal('amount_numeric', 12, 2)->nullable()->after('amount'); // proper decimal for calculations
            $table->string('product_code')->nullable()->after('reference_id'); // eSewa product code
            $table->string('transaction_code')->nullable()->after('product_code'); // eSewa transaction code
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('transactions', function (Blueprint $table) {
            $table->dropColumn([
                'transaction_type',
                'payment_method',
                'reference_id',
                'recipient_name',
                'recipient_id',
                'amount_numeric',
                'product_code',
                'transaction_code',
            ]);
        });
    }
};