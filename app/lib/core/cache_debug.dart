import 'package:flutter/foundation.dart';

/// Logs stale-while-revalidate background failures in debug builds only.
void logCacheRefreshFailure(String context, Object error, [StackTrace? stack]) {
  if (!kDebugMode) return;
  debugPrint('[CacheRefresh:$context] $error');
  if (stack != null) {
    debugPrintStack(stackTrace: stack, label: context);
  }
}
