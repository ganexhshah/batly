<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class GameMatch extends Model
{
    use HasFactory;

    protected $table = 'game_matches';

    protected $fillable = [
        'tournament_id',
        'user_id',
        'round_name',
        'map_name',
        'round_time',
        'rank',
        'kills',
        'points',
        'status',
        'proof_images',
        'notes',
        'verified_by',
        'verified_at',
        'rejected_reason',
        'prize_amount',
        'prize_transaction_id',
        'played_at',
    ];

    protected function casts(): array
    {
        return [
            'played_at' => 'datetime',
            'verified_at' => 'datetime',
            'proof_images' => 'array',
            'prize_amount' => 'float',
        ];
    }

    // ── Relationships ────────────────────────────────────────────────

    public function tournament(): BelongsTo
    {
        return $this->belongsTo(Tournament::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function verifier(): BelongsTo
    {
        return $this->belongsTo(User::class, 'verified_by');
    }
}
