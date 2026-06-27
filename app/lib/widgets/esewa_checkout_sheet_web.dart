import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/battly_theme.dart';
import 'esewa_checkout_result.dart';

int _esewaCheckoutViewId = 0;

Future<EsewaCheckoutResult?> showEsewaCheckoutSheet(
  BuildContext context, {
  required String checkoutUrl,
  required String amountText,
  required String transactionId,
}) {
  return showDialog<EsewaCheckoutResult>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return _EsewaCheckoutDialog(
        checkoutUrl: checkoutUrl,
        amountText: amountText,
        transactionId: transactionId,
      );
    },
  );
}

class _EsewaCheckoutDialog extends StatefulWidget {
  const _EsewaCheckoutDialog({
    required this.checkoutUrl,
    required this.amountText,
    required this.transactionId,
  });

  final String checkoutUrl;
  final String amountText;
  final String transactionId;

  @override
  State<_EsewaCheckoutDialog> createState() => _EsewaCheckoutDialogState();
}

class _EsewaCheckoutDialogState extends State<_EsewaCheckoutDialog> {
  late final String _viewType;
  StreamSubscription<html.MessageEvent>? _messageSubscription;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'battly-esewa-checkout-${_esewaCheckoutViewId++}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (viewId) {
      final frame = html.IFrameElement()
        ..src = widget.checkoutUrl
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'payment *; fullscreen *';
      return frame;
    });

    _messageSubscription = html.window.onMessage.listen((event) {
      final result = _parseMessage(event.data);
      if (result == null || _completed || !mounted) return;
      _completed = true;
      Navigator.of(context).pop(result);
    });
  }

  EsewaCheckoutResult? _parseMessage(Object? data) {
    dynamic decoded = data;
    if (decoded is String) {
      try {
        decoded = jsonDecode(decoded);
      } catch (_) {
        return null;
      }
    }

    if (decoded is! Map) return null;

    final type = decoded['type']?.toString();
    final referenceId = decoded['referenceId']?.toString();
    if (type == 'esewa_success') {
      return EsewaCheckoutResult(
        success: true,
        referenceId: referenceId ?? widget.transactionId,
      );
    }

    if (type == 'esewa_failure') {
      return const EsewaCheckoutResult(
        message: 'Payment failed or was cancelled.',
      );
    }

    return null;
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 820),
        decoration: BoxDecoration(
          color: context.battlyScaffold,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.battlyBorder, width: 1.5),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
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
                          const SizedBox(height: 4),
                          Text(
                            'NPR ${widget.amountText}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
            const Divider(height: 1),
            const SizedBox(height: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: HtmlElementView(
                    key: Key('esewa_checkout_frame'),
                    viewType: _viewType,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
