<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Banner extends Model
{
    use HasFactory;

    protected $fillable = [
        'title',
        'prize_pool',
        'date_text',
        'is_live',
        'image_path',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'is_live' => 'boolean',
            'is_active' => 'boolean',
        ];
    }

    /**
     * Scope for active banners.
     */
    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }
}
