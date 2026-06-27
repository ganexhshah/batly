<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Notification extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'title',
        'message',
        'type',
        'deep_link',
        'metadata',
        'time',
        'unread',
    ];

    protected function casts(): array
    {
        return [
            'unread' => 'boolean',
            'metadata' => 'array',
        ];
    }
}
