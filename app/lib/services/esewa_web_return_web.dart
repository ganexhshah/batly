import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Removes eSewa query params from the browser URL after handling a redirect.
void clearEsewaQueryParams() {
  if (!kIsWeb) return;

  final uri = Uri.base;
  if (!uri.queryParameters.containsKey('esewa_status')) return;

  final cleaned = uri.replace(queryParameters: {});
  final path = '${cleaned.path}${cleaned.hasQuery ? '?${cleaned.query}' : ''}';
  web.window.history.replaceState(null, '', path);
}

String? takeEsewaReturnStatus() {
  if (!kIsWeb) return null;
  return Uri.base.queryParameters['esewa_status'];
}

String? takeEsewaReturnTransactionId() {
  if (!kIsWeb) return null;
  return Uri.base.queryParameters['transaction_id'];
}

String webReturnUrl() {
  final uri = Uri.base;
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: uri.path.isEmpty ? '/' : uri.path,
  ).toString();
}
