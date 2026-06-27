<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Transaction extends Model
{
    use HasFactory;

    public $incrementing = false;
    protected $keyType = 'string';

    protected $casts = [
        'amount_numeric' => 'float',
    ];

    protected $fillable = [
        'id',
        'user_id',
        'type',
        'transaction_type',
        'payment_method',
        'reference_id',
        'reference_type',
        'reference_entity_id',
        'recipient_name',
        'recipient_id',
        'amount',
        'amount_numeric',
        'description',
        'date',
        'status',
        'product_code',
        'transaction_code',
        'reviewed_by',
        'reviewed_at',
        'admin_note',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
