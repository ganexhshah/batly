<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Tournament extends Model
{
    use HasFactory;

    protected $fillable = [
        'title',
        'game',
        'stage',
        'type',
        'mode',
        'prize_pool',
        'entry_fee',
        'max_players',
        'current_players',
        'starts_at',
        'status',
        'image_path',
        'logo_asset',
        'is_featured',
        'custom_settings',
        'created_by',
    ];

    protected function casts(): array
    {
        return [
            'starts_at' => 'datetime',
            'is_featured' => 'boolean',
            'current_players' => 'integer',
            'max_players' => 'integer',
            'custom_settings' => 'array',
        ];
    }

    // ── Relationships ────────────────────────────────────────────────

    public function gameMatches(): HasMany
    {
        return $this->hasMany(GameMatch::class);
    }

    public function registrations(): HasMany
    {
        return $this->hasMany(TournamentRegistration::class);
    }

    public function chatMessages(): HasMany
    {
        return $this->hasMany(TournamentChatMessage::class);
    }

    public function participants(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'tournament_registrations')
            ->withPivot(['status', 'entry_fee_paid', 'transaction_id'])
            ->withTimestamps();
    }

    public function activeParticipants(): BelongsToMany
    {
        return $this->participants()->wherePivot('status', 'registered');
    }

    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    // ── Scopes ───────────────────────────────────────────────────────

    public function scopeFeatured($query)
    {
        return $query->where('is_featured', true);
    }

    public function scopeUpcoming($query)
    {
        return $query->whereIn('status', ['upcoming', 'registration']);
    }

    public function scopeLive($query)
    {
        return $query->where('status', 'live');
    }

    public function scopeCompleted($query)
    {
        return $query->where('status', 'completed');
    }
}
