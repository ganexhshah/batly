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
        Schema::create('transactions', function (Blueprint $table) {
            $table->string('id')->primary(); // TX-XXXX custom string format matching UI
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('type'); // Inflow / Outflow
            $table->string('amount');
            $table->string('description');
            $table->string('date');
            $table->string('status')->default('Completed'); // Completed / Pending
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('transactions');
    }
};
