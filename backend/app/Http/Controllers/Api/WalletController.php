<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Transaction;
use App\Models\User;
use App\Services\BattlyCache;
use App\Services\EsewaService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class WalletController extends Controller
{
    public function balance(Request $request): JsonResponse
    {
        $user = $request->user();
        $payload = BattlyCache::remember(
            BattlyCache::TAG_WALLET,
            BattlyCache::walletBalanceKey($user->id),
            BattlyCache::TTL_WALLET,
            fn () => [
                'balance' => (float) $user->fresh()->wallet_balance,
                'winning_balance' => (float) $user->fresh()->winning_balance,
                'currency' => 'NPR',
            ],
        );

        return response()->json($payload);
    }

    public function transactions(Request $request): JsonResponse
    {
        $page = max(1, (int) $request->query('page', 1));
        $perPage = min(50, max(1, (int) $request->query('per_page', 20)));

        $query = $request->user()
            ->transactions()
            ->orderByDesc('created_at');

        if ($type = $request->query('type')) {
            $query->where('transaction_type', $type);
        }
        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }

        $paginator = $query->paginate($perPage, ['*'], 'page', $page);

        return response()->json([
            'transactions' => collect($paginator->items())
                ->map(fn (Transaction $t) => $this->formatTransaction($t))
                ->values()
                ->all(),
            'pagination' => [
                'current_page' => $paginator->currentPage(),
                'last_page' => $paginator->lastPage(),
                'total' => $paginator->total(),
            ],
        ]);
    }

    public function transactionShow(Request $request, string $id): JsonResponse
    {
        $transaction = $request->user()
            ->transactions()
            ->where('id', $id)
            ->firstOrFail();

        return response()->json([
            'transaction' => $this->formatTransaction($transaction),
        ]);
    }

    public function depositInitiate(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'amount' => ['required', 'numeric', 'min:50', 'max:50000'],
            'payment_method' => ['required', 'string', 'in:esewa,khalti,ime_pay,connect_ips,bank'],
        ]);

        $user = $request->user();
        $amount = round((float) $validated['amount'], 2);
        $transactionId = 'DEP-' . strtoupper(Str::random(10));
        $productCode = config('services.esewa.product_code', 'EPAYTEST');

        $transaction = Transaction::create([
            'id' => $transactionId,
            'user_id' => $user->id,
            'type' => 'Inflow',
            'transaction_type' => 'deposit',
            'payment_method' => $validated['payment_method'],
            'amount' => '+Rs. ' . number_format($amount),
            'amount_numeric' => $amount,
            'description' => 'Wallet deposit via ' . $this->formatPaymentMethod($validated['payment_method']),
            'date' => 'Just Now',
            'status' => 'pending',
            'product_code' => $productCode,
        ]);

        return response()->json([
            'transaction' => $this->formatTransaction($transaction),
            'esewa' => [
                'product_code' => $productCode,
                'checkout_url' => url('/esewa/checkout/' . $transactionId),
            ],
        ], 201);
    }

    public function depositConfirm(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'transaction_id' => ['required', 'string'],
            'reference_id' => ['nullable', 'string', 'max:255'],
            'transaction_code' => ['nullable', 'string', 'max:255'],
            'status' => ['required', 'string', 'in:completed,failed,cancelled'],
        ]);

        $user = $request->user();
        $transaction = Transaction::query()
            ->where('id', $validated['transaction_id'])
            ->where('user_id', $user->id)
            ->where('transaction_type', 'deposit')
            ->firstOrFail();

        if ($transaction->status === 'completed') {
            return response()->json([
                'message' => 'Deposit already confirmed',
                'balance' => (float) $user->fresh()->wallet_balance,
                'transaction' => $this->formatTransaction($transaction),
            ]);
        }

        if ($validated['status'] !== 'completed') {
            $transaction->update([
                'status' => $validated['status'],
                'reference_id' => $validated['reference_id'] ?? null,
                'transaction_code' => $validated['transaction_code'] ?? null,
            ]);

            return response()->json([
                'message' => 'Deposit marked as ' . $validated['status'],
                'transaction' => $this->formatTransaction($transaction->fresh()),
            ]);
        }

        return response()->json([
            'message' => 'Deposit completion must be verified by the payment gateway. Poll GET /wallet/transactions/{id} for status.',
        ], 403);
    }

    public function withdraw(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'amount' => ['required', 'numeric', 'min:100'],
            'payment_method' => ['required', 'string', 'in:esewa,khalti,ime_pay,bank_transfer,bank'],
            'recipient' => ['required', 'string', 'max:255'],
            'bank_name' => ['nullable', 'string', 'max:255'],
            'account_number' => ['nullable', 'string', 'max:255'],
            'account_name' => ['nullable', 'string', 'max:255'],
        ]);

        $user = $request->user();
        $amount = round((float) $validated['amount'], 2);
        $transactionId = 'WTH-' . strtoupper(Str::random(10));

        try {
            $transaction = DB::transaction(function () use ($user, $amount, $validated, $transactionId) {
                $locked = User::query()->whereKey($user->id)->lockForUpdate()->firstOrFail();
                if ((float) $locked->wallet_balance < $amount) {
                    throw new \RuntimeException('Insufficient balance');
                }

                $locked->decrement('wallet_balance', $amount);

                return Transaction::create([
                    'id' => $transactionId,
                    'user_id' => $locked->id,
                    'type' => 'Outflow',
                    'transaction_type' => 'withdraw',
                    'payment_method' => $validated['payment_method'],
                    'amount' => '-Rs. ' . number_format($amount),
                    'amount_numeric' => -$amount,
                    'description' => 'Withdrawal to ' . $validated['recipient'],
                    'date' => 'Just Now',
                    'status' => 'pending',
                    'recipient_name' => $validated['recipient'],
                ]);
            });
        } catch (\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        BattlyCache::flushWallet($user->id);
        BattlyCache::flushAdmin();

        return response()->json([
            'message' => 'Withdrawal request submitted',
            'balance' => (float) $user->fresh()->wallet_balance,
            'transaction' => $this->formatTransaction($transaction),
        ], 201);
    }

    public function searchRecipient(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'query' => ['required', 'string', 'min:2', 'max:100'],
        ]);

        $query = trim($validated['query']);
        $authId = $request->user()->id;

        $users = User::query()
            ->where('id', '!=', $authId)
            ->where(function ($q) use ($query): void {
                $q->where('name', 'ilike', "%{$query}%")
                    ->orWhere('ign', 'ilike', "%{$query}%")
                    ->orWhere('game_uid', 'ilike', "%{$query}%");
            })
            ->limit(10)
            ->get(['id', 'name', 'ign', 'game_uid', 'avatar_url']);

        return response()->json([
            'users' => $users->map(fn (User $u) => [
                'id' => $u->id,
                'name' => $u->name,
                'ign' => $u->ign,
                'game_uid' => $u->game_uid,
                'avatar_url' => $u->avatar_url,
            ])->values(),
        ]);
    }

    public function transfer(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'recipient_id' => ['required', 'integer', 'exists:users,id'],
            'amount' => ['required', 'numeric', 'min:50'],
            'note' => ['nullable', 'string', 'max:255'],
        ]);

        $sender = $request->user();
        $amount = round((float) $validated['amount'], 2);
        $recipientId = (int) $validated['recipient_id'];

        if ($sender->id === $recipientId) {
            return response()->json(['message' => 'Cannot transfer to yourself'], 422);
        }

        $senderTxId = 'TRF-' . strtoupper(Str::random(10));
        $recipientTxId = 'TRF-' . strtoupper(Str::random(10));

        try {
            DB::transaction(function () use ($sender, $recipientId, $amount, $validated, $senderTxId, $recipientTxId): void {
                $ids = [$sender->id, $recipientId];
                sort($ids);
                $lockedUsers = User::query()->whereIn('id', $ids)->lockForUpdate()->get()->keyBy('id');
                $senderLocked = $lockedUsers->get($sender->id);
                $recipientLocked = $lockedUsers->get($recipientId);

                if (! $senderLocked || ! $recipientLocked) {
                    throw new \RuntimeException('Recipient not found');
                }

                if ((float) $senderLocked->wallet_balance < $amount) {
                    throw new \RuntimeException('Insufficient balance');
                }

                $senderLocked->decrement('wallet_balance', $amount);
                $recipientLocked->increment('wallet_balance', $amount);

                Transaction::create([
                    'id' => $senderTxId,
                    'user_id' => $senderLocked->id,
                    'type' => 'Outflow',
                    'transaction_type' => 'transfer',
                    'payment_method' => 'wallet',
                    'amount' => '-Rs. ' . number_format($amount),
                    'amount_numeric' => -$amount,
                    'description' => $validated['note'] ?? ('Transfer to ' . ($recipientLocked->ign ?: $recipientLocked->name)),
                    'date' => 'Just Now',
                    'status' => 'completed',
                    'recipient_id' => $recipientLocked->id,
                    'recipient_name' => $recipientLocked->ign ?: $recipientLocked->name,
                ]);

                Transaction::create([
                    'id' => $recipientTxId,
                    'user_id' => $recipientLocked->id,
                    'type' => 'Inflow',
                    'transaction_type' => 'transfer',
                    'payment_method' => 'wallet',
                    'amount' => '+Rs. ' . number_format($amount),
                    'amount_numeric' => $amount,
                    'description' => $validated['note'] ?? ('Transfer from ' . ($senderLocked->ign ?: $senderLocked->name)),
                    'date' => 'Just Now',
                    'status' => 'completed',
                    'recipient_id' => $senderLocked->id,
                    'recipient_name' => $senderLocked->ign ?: $senderLocked->name,
                ]);
            });
        } catch (\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        BattlyCache::flushWallet($sender->id);
        BattlyCache::flushWallet($recipientId);

        $senderTransaction = Transaction::find($senderTxId);

        return response()->json([
            'message' => 'Transfer successful',
            'balance' => (float) $sender->fresh()->wallet_balance,
            'transaction' => $senderTransaction ? $this->formatTransaction($senderTransaction) : null,
        ], 201);
    }

    public function esewaCheckout(Request $request, string $transactionId): Response
    {
        $transaction = Transaction::query()
            ->where('id', $transactionId)
            ->where('transaction_type', 'deposit')
            ->firstOrFail();

        $amount = number_format(abs((float) $transaction->amount_numeric), 2, '.', '');
        $productCode = EsewaService::productCode();
        $returnUrl = $request->query('return_url');
        $gatewayUrl = EsewaService::gatewayUrl();

        if (EsewaService::isAllowedReturnUrl(is_string($returnUrl) ? $returnUrl : null)) {
            EsewaService::rememberReturnUrl($transactionId, (string) $returnUrl);
        }

        $fields = [
            'amount' => $amount,
            'tax_amount' => '0',
            'total_amount' => $amount,
            'transaction_uuid' => $transaction->id,
            'product_code' => $productCode,
            'product_service_charge' => '0',
            'product_delivery_charge' => '0',
            'success_url' => url('/esewa/success/' . $transactionId),
            'failure_url' => url('/esewa/failure/' . $transactionId),
            'signed_field_names' => 'total_amount,transaction_uuid,product_code',
        ];

        if (EsewaService::secretKey() !== '') {
            $fields['signature'] = EsewaService::signRequest($fields);
        }

        $inputs = collect($fields)
            ->map(fn ($value, $key) => '<input type="hidden" name="' . e($key) . '" value="' . e($value) . '">')
            ->implode('');

        $html = <<<HTML
<!DOCTYPE html>
<html><head><title>Battly eSewa Checkout</title></head>
<body onload="document.forms[0].submit()">
<form method="POST" action="{$gatewayUrl}">
{$inputs}
<p>Redirecting to eSewa...</p>
</form>
</body></html>
HTML;

        return response($html, 200)->header('Content-Type', 'text/html');
    }

    public function esewaSuccess(Request $request, ?string $transactionId = null): Response|RedirectResponse
    {
        $returnUrl = $transactionId
            ? EsewaService::pullReturnUrl($transactionId)
            : null;
        $returnUrl ??= EsewaService::isAllowedReturnUrl($request->query('return_url'))
            ? (string) $request->query('return_url')
            : null;

        $transactionId ??= $request->input('transaction_uuid')
            ?? $request->input('oid')
            ?? $request->input('productId');
        $referenceId = $request->input('refId') ?? $request->input('reference_id');

        $payload = EsewaService::parseCallbackPayload($request);
        $verified = false;
        if ($payload !== null && EsewaService::verifyCallbackSignature($payload)) {
            $transactionId = $payload['transaction_uuid'] ?? $transactionId;
            $referenceId = $payload['transaction_code'] ?? $referenceId;

            if (($payload['status'] ?? '') === 'COMPLETE' && $transactionId) {
                $this->completeDepositTransaction((string) $transactionId, $referenceId ? (string) $referenceId : null);
                $verified = true;
            }
        }

        if (! $verified && $transactionId) {
            // Do not credit without verified gateway signature; client polls transaction status.
        }

        $depositCompleted = $transactionId
            ? Transaction::query()
                ->where('id', $transactionId)
                ->where('transaction_type', 'deposit')
                ->where('status', 'completed')
                ->exists()
            : false;

        if ($returnUrl !== null && str_contains($returnUrl, '?data=')) {
            $returnUrl = explode('?data=', $returnUrl, 2)[0];
        }

        if (EsewaService::isAllowedReturnUrl($returnUrl)) {
            $redirect = $this->appendQuery((string) $returnUrl, [
                'esewa_status' => $depositCompleted ? 'success' : 'pending',
                'transaction_id' => $transactionId,
            ]);

            return redirect()->away($redirect);
        }

        return response($this->esewaEmbedHtml('esewa_success', $referenceId ? (string) $referenceId : ''), 200)
            ->header('Content-Type', 'text/html');
    }

    public function esewaFailure(Request $request, ?string $transactionId = null): Response|RedirectResponse
    {
        $returnUrl = $transactionId
            ? EsewaService::pullReturnUrl($transactionId)
            : null;
        $returnUrl ??= EsewaService::isAllowedReturnUrl($request->query('return_url'))
            ? (string) $request->query('return_url')
            : null;

        $payload = EsewaService::parseCallbackPayload($request);
        $transactionId ??= $request->input('transaction_uuid') ?? $request->input('oid');

        if ($payload !== null) {
            $transactionId = $payload['transaction_uuid'] ?? $transactionId;
        }

        if ($transactionId) {
            Transaction::query()
                ->where('id', $transactionId)
                ->where('transaction_type', 'deposit')
                ->where('status', 'pending')
                ->update(['status' => 'failed']);
        }

        if ($returnUrl !== null && str_contains($returnUrl, '?data=')) {
            $returnUrl = explode('?data=', $returnUrl, 2)[0];
        }

        if (EsewaService::isAllowedReturnUrl($returnUrl)) {
            $redirect = $this->appendQuery((string) $returnUrl, [
                'esewa_status' => 'failure',
                'transaction_id' => $transactionId,
            ]);

            return redirect()->away($redirect);
        }

        return response($this->esewaEmbedHtml('esewa_failure'), 200)
            ->header('Content-Type', 'text/html');
    }

    private function completeDepositTransaction(string $transactionId, ?string $referenceId): void
    {
        DB::transaction(function () use ($transactionId, $referenceId): void {
            $transaction = Transaction::query()
                ->where('id', $transactionId)
                ->where('transaction_type', 'deposit')
                ->lockForUpdate()
                ->first();

            if (! $transaction || $transaction->status === 'completed') {
                return;
            }

            $user = User::query()->whereKey($transaction->user_id)->lockForUpdate()->first();
            if (! $user) {
                return;
            }

            $amount = abs((float) $transaction->amount_numeric);
            $user->increment('wallet_balance', $amount);
            $transaction->update([
                'status' => 'completed',
                'reference_id' => $referenceId,
                'transaction_code' => $referenceId,
                'date' => 'Just Now',
            ]);
        });

        $transaction = Transaction::query()->find($transactionId);
        if ($transaction?->user_id) {
            BattlyCache::flushWallet($transaction->user_id);
            BattlyCache::flushAdmin();
        }
    }

    private function esewaEmbedHtml(string $eventType, string $referenceId = ''): string
    {
        $payload = json_encode([
            'type' => $eventType,
            'referenceId' => $referenceId,
        ], JSON_THROW_ON_ERROR);
        $title = $eventType === 'esewa_success'
            ? 'Payment successful'
            : 'Payment failed or was cancelled';

        return <<<HTML
<!DOCTYPE html>
<html><head><title>{$title}</title></head>
<body>
<h2>{$title}</h2>
<script>
(function () {
  var payload = {$payload};
  if (window.parent !== window) {
    window.parent.postMessage(JSON.stringify(payload), '*');
  }
})();
</script>
</body></html>
HTML;
    }

    /** @param array<string, mixed> $params */
    private function appendQuery(string $url, array $params): string
    {
        $separator = str_contains($url, '?') ? '&' : '?';

        return $url . $separator . http_build_query($params);
    }

    private function formatTransaction(Transaction $transaction): array
    {
        return [
            'id' => $transaction->id,
            'type' => $transaction->type,
            'transaction_type' => $transaction->transaction_type,
            'payment_method' => $transaction->payment_method,
            'amount' => $transaction->amount,
            'amount_numeric' => (float) $transaction->amount_numeric,
            'description' => $transaction->description,
            'date' => $transaction->date,
            'status' => $transaction->status,
            'reference_id' => $transaction->reference_id,
            'transaction_code' => $transaction->transaction_code,
            'recipient_name' => $transaction->recipient_name,
            'recipient_id' => $transaction->recipient_id,
            'created_at' => $transaction->created_at?->toIso8601String(),
        ];
    }

    private function formatPaymentMethod(string $method): string
    {
        return match ($method) {
            'ime_pay' => 'IME Pay',
            'connect_ips' => 'Connect IPS',
            'bank_transfer', 'bank' => 'Bank Transfer',
            default => ucfirst(str_replace('_', ' ', $method)),
        };
    }
}
