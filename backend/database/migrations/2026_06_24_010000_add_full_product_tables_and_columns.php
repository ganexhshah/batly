<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (DB::getDriverName() === 'pgsql') {
            DB::statement('ALTER TABLE tournaments ALTER COLUMN status TYPE VARCHAR(50)');
        }

        Schema::create('tournament_registrations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('tournament_id')->constrained('tournaments')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('status')->default('registered');
            $table->decimal('entry_fee_paid', 12, 2)->default(0);
            $table->string('transaction_id')->nullable();
            $table->timestamps();

            $table->unique(['tournament_id', 'user_id']);
        });

        Schema::table('game_matches', function (Blueprint $table) {
            $table->string('round_name')->nullable()->after('user_id');
            $table->string('map_name')->nullable()->after('round_name');
            $table->string('round_time')->nullable()->after('map_name');
            $table->integer('points')->nullable()->after('kills');
            $table->string('status')->default('scheduled')->after('points');
            $table->json('proof_images')->nullable()->after('status');
            $table->text('notes')->nullable()->after('proof_images');
            $table->foreignId('verified_by')->nullable()->after('notes')->constrained('users')->nullOnDelete();
            $table->timestamp('verified_at')->nullable()->after('verified_by');
            $table->text('rejected_reason')->nullable()->after('verified_at');
            $table->decimal('prize_amount', 12, 2)->default(0)->after('rejected_reason');
            $table->string('prize_transaction_id')->nullable()->after('prize_amount');
        });

        Schema::table('notifications', function (Blueprint $table) {
            $table->foreignId('user_id')->nullable()->before('title')->constrained('users')->cascadeOnDelete();
            $table->string('type')->default('system')->after('message');
            $table->string('deep_link')->nullable()->after('type');
            $table->json('metadata')->nullable()->after('deep_link');
        });

        Schema::table('transactions', function (Blueprint $table) {
            $table->string('reviewed_by')->nullable()->after('transaction_code');
            $table->timestamp('reviewed_at')->nullable()->after('reviewed_by');
            $table->text('admin_note')->nullable()->after('reviewed_at');
        });

        Schema::create('support_tickets', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('subject');
            $table->text('message');
            $table->string('category')->default('general');
            $table->string('status')->default('open');
            $table->string('priority')->default('normal');
            $table->text('admin_reply')->nullable();
            $table->foreignId('assigned_to')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('resolved_at')->nullable();
            $table->timestamps();
        });

        DB::table('game_matches')->orderBy('id')->chunkById(100, function ($matches): void {
            foreach ($matches as $match) {
                DB::table('tournament_registrations')->updateOrInsert(
                    [
                        'tournament_id' => $match->tournament_id,
                        'user_id' => $match->user_id,
                    ],
                    [
                        'status' => 'registered',
                        'entry_fee_paid' => 0,
                        'created_at' => $match->created_at,
                        'updated_at' => $match->updated_at,
                    ],
                );
            }
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('support_tickets');

        Schema::table('transactions', function (Blueprint $table) {
            $table->dropColumn(['reviewed_by', 'reviewed_at', 'admin_note']);
        });

        Schema::table('notifications', function (Blueprint $table) {
            $table->dropConstrainedForeignId('user_id');
            $table->dropColumn(['type', 'deep_link', 'metadata']);
        });

        Schema::table('game_matches', function (Blueprint $table) {
            $table->dropConstrainedForeignId('verified_by');
            $table->dropColumn([
                'round_name',
                'map_name',
                'round_time',
                'points',
                'status',
                'proof_images',
                'notes',
                'verified_at',
                'rejected_reason',
                'prize_amount',
                'prize_transaction_id',
            ]);
        });

        Schema::dropIfExists('tournament_registrations');
    }
};
