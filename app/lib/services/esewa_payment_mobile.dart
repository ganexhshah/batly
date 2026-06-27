import 'package:flutter/material.dart';

import '../widgets/esewa_checkout_sheet.dart';

Future<void> startEsewaPayment({
  required BuildContext context,
  required String transactionId,
  required String amountText,
  required double amount,
  required String baseUrl,
  String checkoutUrl = '',
  String returnUrl = '',
  required Future<void> Function(String referenceId) onSuccess,
  required void Function(String message) onFailure,
  required void Function(String message) onCancelled,
}) async {
  final resolvedCheckout = checkoutUrl.isNotEmpty
      ? checkoutUrl
      : '$baseUrl/esewa/checkout/$transactionId';

  final result = await showEsewaCheckoutSheet(
    context,
    checkoutUrl: resolvedCheckout,
    amountText: amountText,
    transactionId: transactionId,
  );

  if (result == null || result.cancelled) {
    onCancelled('Payment cancelled.');
    return;
  }

  if (result.success) {
    await onSuccess(result.referenceId ?? transactionId);
    return;
  }

  onFailure(result.message ?? 'Payment failed.');
}
