import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/cache_debug.dart';
import '../core/theme/battly_theme.dart';
import 'esewa_checkout_result.dart';

Future<EsewaCheckoutResult?> showEsewaCheckoutSheet(
  BuildContext context, {
  required String checkoutUrl,
  required String amountText,
  required String transactionId,
}) {
  return showModalBottomSheet<EsewaCheckoutResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return _EsewaCheckoutSheet(
        checkoutUrl: checkoutUrl,
        amountText: amountText,
        transactionId: transactionId,
      );
    },
  );
}

class _EsewaCheckoutSheet extends StatefulWidget {
  const _EsewaCheckoutSheet({
    required this.checkoutUrl,
    required this.amountText,
    required this.transactionId,
  });

  final String checkoutUrl;
  final String amountText;
  final String transactionId;

  @override
  State<_EsewaCheckoutSheet> createState() => _EsewaCheckoutSheetState();
}

class _EsewaCheckoutSheetState extends State<_EsewaCheckoutSheet> {
  late final WebViewController _controller;
  int _loadingProgress = 0;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'BattlyEsewa',
        onMessageReceived: (message) => _handleJavaScriptMessage(message.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() => _loadingProgress = progress);
          },
          onNavigationRequest: (request) {
            _handleCheckoutUrl(request.url);
            return NavigationDecision.navigate;
          },
          onPageFinished: (url) async {
            await _installMessageBridge();
            _handleCheckoutUrl(url);
          },
          onWebResourceError: (error) {
            if (_completed || !mounted) return;
            Navigator.of(context).pop(
              EsewaCheckoutResult(
                message: error.description.isEmpty
                    ? 'Unable to load eSewa checkout.'
                    : error.description,
              ),
            );
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  Future<void> _installMessageBridge() async {
    try {
      await _controller.runJavaScript('''
        (function () {
          if (window.__battlyEsewaBridgeInstalled) return;
          window.__battlyEsewaBridgeInstalled = true;
          var originalPostMessage = window.postMessage;
          window.postMessage = function(message, targetOrigin, transfer) {
            try {
              BattlyEsewa.postMessage(
                typeof message === 'string' ? message : JSON.stringify(message)
              );
            } catch (error, st) {
              logCacheRefreshFailure('esewaJsBridge', error, st);
            }
            if (originalPostMessage) {
              return originalPostMessage.call(window, message, targetOrigin, transfer);
            }
          };
        })();
      ''');
    } catch (e, st) {
      logCacheRefreshFailure('esewaInstallBridge', e, st);
    }
  }

  void _handleJavaScriptMessage(String rawMessage) {
    if (_completed || !mounted) return;

    try {
      final decoded = jsonDecode(rawMessage);
      if (decoded is! Map<String, dynamic>) return;

      final type = decoded['type'] as String?;
      final referenceId = decoded['referenceId'] as String?;
      if (type == 'esewa_success') {
        _completed = true;
        Navigator.of(context).pop(
          EsewaCheckoutResult(success: true, referenceId: referenceId),
        );
        return;
      }

      if (type == 'esewa_failure') {
        _completed = true;
        Navigator.of(context).pop(
          const EsewaCheckoutResult(message: 'Payment failed or was cancelled.'),
        );
      }
    } catch (e, st) {
      logCacheRefreshFailure('esewaInstallBridge', e, st);
    }
  }

  void _handleCheckoutUrl(String url) {
    if (_completed || !mounted) return;

    final uri = Uri.tryParse(url);
    if (uri == null) return;

    if (!_isAllowedReturnHost(uri.host)) return;

    final path = uri.path.toLowerCase();
    if (path.contains('/esewa/success') || path.contains('esewa/success')) {
      _completed = true;
      Navigator.of(context).pop(
        EsewaCheckoutResult(
          success: true,
          referenceId: uri.queryParameters['reference_id'] ??
              uri.queryParameters['refId'] ??
              widget.transactionId,
        ),
      );
      return;
    }

    if (path.contains('/esewa/failure') || path.contains('esewa/failure')) {
      _completed = true;
      Navigator.of(context).pop(
        const EsewaCheckoutResult(message: 'Payment failed or was cancelled.'),
      );
    }
  }

  bool _isAllowedReturnHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == '127.0.0.1' ||
        normalized == 'localhost' ||
        normalized.contains('battly');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _loadingProgress / 100;

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: Container(
          decoration: BoxDecoration(
            color: context.battlyScaffold,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: context.battlyBorder, width: 1.5),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Complete eSewa payment',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: context.battlyOnSurface,
                              ),
                            ),
                            Text(
                              'NPR ${widget.amountText}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: context.battlyMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('esewa_checkout_close'),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(
                        const EsewaCheckoutResult(
                          cancelled: true,
                          message: 'Payment cancelled.',
                        ),
                      ),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              if (_loadingProgress < 100)
                LinearProgressIndicator(
                  value: progress <= 0 ? null : progress,
                  minHeight: 2,
                  color: const Color(0xFFFF6B00),
                  backgroundColor: context.battlyBorder.withValues(alpha: 0.3),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: WebViewWidget(controller: _controller),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
