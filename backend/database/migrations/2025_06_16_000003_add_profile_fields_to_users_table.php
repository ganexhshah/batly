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
        Schema::table('users', function (Blueprint $table) {
            $table->string('ign')->nullable()->after('name');           // In-Game Name
            $table->string('game_uid')->nullable()->after('ign');       // Game UID
            $table->string('avatar_url')->nullable()->after('game_uid');
            $table->decimal('wallet_balance', 12, 2)->default(0)->after('avatar_url');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['ign', 'game_uid', 'avatar_url', 'wallet_balance']);
        });
    }
};
