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
        Schema::create('tournaments', function (Blueprint $table) {
            $table->id();
            $table->string('title');
            $table->string('game')->default('BGMI');
            $table->string('stage')->default('Quarter Final');
            $table->enum('type', ['Solo', 'Duo', 'Squad'])->default('Squad');
            $table->string('mode')->default('Battle Royale');
            $table->string('prize_pool');             // e.g. "NPR 50,000"
            $table->string('entry_fee')->nullable();  // e.g. "NPR 200"
            $table->integer('max_players')->default(64);
            $table->integer('current_players')->default(0);
            $table->timestamp('starts_at');
            $table->enum('status', ['registration', 'upcoming', 'live', 'completed'])->default('upcoming');
            $table->string('image_path')->nullable(); // Background image asset
            $table->string('logo_asset')->nullable(); // Logo image asset
            $table->boolean('is_featured')->default(false);
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('tournaments');
    }
};
