import 'package:flutter/material.dart';

import 'esewa_checkout_result.dart';

Future<EsewaCheckoutResult?> showEsewaCheckoutSheet(
  BuildContext context, {
  required String checkoutUrl,
  required String amountText,
  required String transactionId,
}) {
  throw UnsupportedError('eSewa checkout is not supported on this platform.');
}
