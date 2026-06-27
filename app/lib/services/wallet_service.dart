import 'dart:convert';
import 'api_config.dart';
import 'auth_service.dart';
import 'app_http_client.dart';
import 'local_cache.dart';
import '../core/cache_debug.dart';

/// WalletService handles all wallet-related API calls to the Battly Laravel backend.
class WalletService {
  static const _kBalanceKey = 'cache_wallet_balance';
  static const _kTransactionsKey = 'cache_wallet_transactions';

  static Future<String?> _readCache(String key) => LocalCache.read(key);

  static Future<void> _writeCache(String key, String value) => LocalCache.write(key, value);

  // ── Balance ──────────────────────────────────────────────────────────

  /// Fetch wallet balance — cached for instant wallet tab paint.
  static Future<Map<String, dynamic>> getBalance() async {
    final cached = await _readCache(_kBalanceKey);
    if (cached != null) {
      _refreshBalance();
      return jsonDecode(cached) as Map<String, dynamic>;
    }
    return _fetchBalance();
  }

  static Future<void> invalidateCache() async {
    await LocalCache.remove(_kBalanceKey);
    await LocalCache.remove(_kTransactionsKey);
  }

  static Future<Map<String, dynamic>> _fetchBalance() async {
    final headers = await _authHeaders();
    final response = await AppHttpClient.instance.get(
      Uri.parse('${ApiConfig.apiUrl}/wallet/balance'),
      headers: headers,
    ).timeout(ApiConfig.timeout);

    if (response.statusCode == 200) {
      await _writeCache(_kBalanceKey, response.body);
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch balance: ${response.statusCode}');
  }

  static Future<void> _refreshBalance({void Function(Object error)? onError}) async {
    try {
      await _fetchBalance();
    } catch (e) {
      onError?.call(e);
    }
  }

  static Future<Map<String, dynamic>> forceBalance() => _fetchBalance();

  // ── Transactions ────────────────────────────────────────────────────

  /// Fetch paginated transactions with optional filters.
  static Future<Map<String, dynamic>> getTransactions({
    String? type,
    String? status,
    int page = 1,
    int perPage = 20,
  }) async {
    final cacheKey = page == 1 && perPage <= 5 ? _kTransactionsKey : null;
    if (cacheKey != null) {
      final cached = await _readCache(cacheKey);
      if (cached != null) {
        _refreshTransactions(perPage: perPage);
        return jsonDecode(cached) as Map<String, dynamic>;
      }
    }
    return _fetchTransactions(type: type, status: status, page: page, perPage: perPage);
  }

  static Future<Map<String, dynamic>> _fetchTransactions({
    String? type,
    String? status,
    int page = 1,
    int perPage = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (type != null) queryParams['type'] = type;
    if (status != null) queryParams['status'] = status;

    final uri = Uri.parse('${ApiConfig.apiUrl}/wallet/transactions')
        .replace(queryParameters: queryParams);
    final headers = await _authHeaders();
    final response = await AppHttpClient.instance.get(uri, headers: headers)
        .timeout(ApiConfig.timeout);

    if (response.statusCode == 200) {
      if (page == 1 && perPage <= 5) {
        await _writeCache(_kTransactionsKey, response.body);
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch transactions: ${response.statusCode}');
  }

  static Future<void> _refreshTransactions({int perPage = 5}) async {
    try {
      await _fetchTransactions(page: 1, perPage: perPage);
    } catch (e, st) {
      logCacheRefreshFailure('walletTransactions', e, st);
    }
  }

  static Future<Map<String, dynamic>> forceTransactions({int perPage = 5}) =>
      _fetchTransactions(page: 1, perPage: perPage);

  /// Fetch a single transaction by ID.
  static Future<Map<String, dynamic>> getTransaction(String id) async {
    final headers = await _authHeaders();
    final response = await AppHttpClient.instance.get(
      Uri.parse('${ApiConfig.apiUrl}/wallet/transactions/$id'),
      headers: headers,
    ).timeout(ApiConfig.timeout);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to fetch transaction: ${response.statusCode}');
  }

  // ── Deposit ─────────────────────────────────────────────────────────

  /// Initiate a deposit — creates a pending transaction and returns
  /// the data needed by the eSewa/Khalti payment SDK.
  static Future<Map<String, dynamic>> initiateDeposit({
    required double amount,
    required String paymentMethod,
  }) async {
    final headers = await _authHeaders();
    final response = await AppHttpClient.instance.post(
      Uri.parse('${ApiConfig.apiUrl}/wallet/deposit/initiate'),
      headers: headers,
      body: jsonEncode({
        'amount': amount,
        'payment_method': paymentMethod,
      }),
    ).timeout(ApiConfig.timeout);

    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      await invalidateCache();
      return data;
    }
    throw Exception(data['message'] ?? 'Deposit initiation failed');
  }

  /// Confirm a deposit after payment gateway callback.
  static Future<Map<String, dynamic>> confirmDeposit({
    required String transactionId,
    String? referenceId,
    String? transactionCode,
    required String status,
  }) async {
    final headers = await _authHeaders();
    final response = await AppHttpClient.instance.post(
      Uri.parse('${ApiConfig.apiUrl}/wallet/deposit/confirm'),
      headers: headers,
      body: jsonEncode({
        'transaction_id': transactionId,
        'reference_id': referenceId,
        'transaction_code': transactionCode,
        'status': status,
      }),
    ).timeout(ApiConfig.timeout);

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      await invalidateCache();
      return data;
    }
    throw Exception(data['message'] ?? 'Deposit confirmation failed');
  }

  /// Poll transaction status until deposit completes or fails.
  static Future<Map<String, dynamic>> waitForDepositCompletion(
    String transactionId, {
    Duration timeout = const Duration(minutes: 2),
    Duration interval = const Duration(seconds: 2),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      final data = await getTransaction(transactionId);
      final txn = data['transaction'] as Map<String, dynamic>? ?? data;
      final status = txn['status'] as String? ?? '';

      if (status == 'completed') {
        await invalidateCache();
        return txn;
      }
      if (status == 'failed' || status == 'cancelled') {
        await invalidateCache();
        throw Exception('Deposit $status');
      }

      await Future.delayed(interval);
    }

    throw Exception('Deposit verification timed out');
  }

  // ── Withdraw ────────────────────────────────────────────────────────

  /// Submit a withdrawal request.
  static Future<Map<String, dynamic>> withdraw({
    required double amount,
    required String paymentMethod,
    required String recipient,
    String? bankName,
    String? accountNumber,
    String? accountName,
  }) async {
    final headers = await _authHeaders();
    final body = <String, dynamic>{
      'amount': amount,
      'payment_method': paymentMethod,
      'recipient': recipient,
    };
    if (bankName != null) body['bank_name'] = bankName;
    if (accountNumber != null) body['account_number'] = accountNumber;
    if (accountName != null) body['account_name'] = accountName;

    final response = await AppHttpClient.instance.post(
      Uri.parse('${ApiConfig.apiUrl}/wallet/withdraw'),
      headers: headers,
      body: jsonEncode(body),
    ).timeout(ApiConfig.timeout);

    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      await invalidateCache();
      return data;
    }
    throw Exception(data['message'] ?? 'Withdrawal failed');
  }

  // ── Transfer ────────────────────────────────────────────────────────

  /// Search for a recipient by name, game UID, or IGN.
  static Future<List<Map<String, dynamic>>> searchRecipient(String query) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('${ApiConfig.apiUrl}/wallet/search-recipient')
        .replace(queryParameters: {'query': query});
    final response = await AppHttpClient.instance.get(uri, headers: headers)
        .timeout(ApiConfig.timeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['users'] ?? []);
    }
    throw Exception('Search failed: ${response.statusCode}');
  }

  /// Transfer funds to another user.
  static Future<Map<String, dynamic>> transfer({
    required int recipientId,
    required double amount,
    String? note,
  }) async {
    final headers = await _authHeaders();
    final response = await AppHttpClient.instance.post(
      Uri.parse('${ApiConfig.apiUrl}/wallet/transfer'),
      headers: headers,
      body: jsonEncode({
        'recipient_id': recipientId,
        'amount': amount,
        'note': note,
      }),
    ).timeout(ApiConfig.timeout);

    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      await invalidateCache();
      return data;
    }
    throw Exception(data['message'] ?? 'Transfer failed');
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  static Future<Map<String, String>> _authHeaders() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}