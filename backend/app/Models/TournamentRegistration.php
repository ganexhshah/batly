<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class TournamentRegistration extends Model
{
    use HasFactory;

    protected $fillable = [
        'tournament_id',
        'user_id',
        'team_captain_id',
        'status',
        'entry_fee_paid',
        'transaction_id',
        'is_ready',
        'ready_at',
        'left_at',
    ];

    protected $casts = [
        'entry_fee_paid' => 'float',
        'is_ready' => 'boolean',
        'ready_at' => 'datetime',
        'left_at' => 'datetime',
    ];

    public function tournament(): BelongsTo
    {
        return $this->belongsTo(Tournament::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
