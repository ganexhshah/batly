<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Team extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'tag',
        'game',
        'points',
        'is_verified',
        'members',
    ];

    protected function casts(): array
    {
        return [
            'is_verified' => 'boolean',
            'points' => 'integer',
            'members' => 'array',
        ];
    }
}
