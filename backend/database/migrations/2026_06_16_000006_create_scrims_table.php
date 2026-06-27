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
        Schema::create('scrims', function (Blueprint $table) {
            $table->id();
            $table->string('teams'); // Matchup, e.g. "Team Apex vs Alpha Squad"
            $table->string('game');
            $table->string('time');
            $table->string('status')->default('Open'); // 'Open', 'Full', 'Finished'
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('scrims');
    }
};
