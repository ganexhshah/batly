<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('tournament_registrations', function (Blueprint $table) {
            $table->foreignId('team_captain_id')->nullable()->after('user_id')->constrained('users')->nullOnDelete();
            $table->boolean('is_ready')->default(false)->after('transaction_id');
            $table->timestamp('ready_at')->nullable()->after('is_ready');
            $table->timestamp('left_at')->nullable()->after('ready_at');
        });

        Schema::table('transactions', function (Blueprint $table) {
            $table->string('reference_type')->nullable()->after('reference_id');
            $table->unsignedBigInteger('reference_entity_id')->nullable()->after('reference_type');
        });

        Schema::create('team_invites', function (Blueprint $table) {
            $table->id();
            $table->foreignId('tournament_id')->constrained('tournaments')->cascadeOnDelete();
            $table->foreignId('captain_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('invitee_id')->constrained('users')->cascadeOnDelete();
            $table->string('status')->default('pending'); // pending, accepted, declined
            $table->timestamp('responded_at')->nullable();
            $table->timestamps();

            $table->unique(['tournament_id', 'invitee_id']);
        });

        Schema::create('match_disputes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('tournament_id')->constrained('tournaments')->cascadeOnDelete();
            $table->foreignId('game_match_id')->nullable()->constrained('game_matches')->nullOnDelete();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('type'); // wrong_result, wrong_rank, wrong_kills
            $table->text('reason');
            $table->json('proof_images')->nullable();
            $table->string('status')->default('open'); // open, under_review, resolved, dismissed
            $table->text('admin_note')->nullable();
            $table->foreignId('resolved_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('resolved_at')->nullable();
            $table->timestamps();
        });

        Schema::create('player_reports', function (Blueprint $table) {
            $table->id();
            $table->foreignId('tournament_id')->constrained('tournaments')->cascadeOnDelete();
            $table->foreignId('reporter_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('reported_user_id')->constrained('users')->cascadeOnDelete();
            $table->text('reason');
            $table->json('proof_images')->nullable();
            $table->string('status')->default('open'); // open, under_review, action_taken, dismissed
            $table->text('admin_note')->nullable();
            $table->foreignId('resolved_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('resolved_at')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('player_reports');
        Schema::dropIfExists('match_disputes');
        Schema::dropIfExists('team_invites');

        Schema::table('transactions', function (Blueprint $table) {
            $table->dropColumn(['reference_type', 'reference_entity_id']);
        });

        Schema::table('tournament_registrations', function (Blueprint $table) {
            $table->dropConstrainedForeignId('team_captain_id');
            $table->dropColumn(['is_ready', 'ready_at', 'left_at']);
        });
    }
};
