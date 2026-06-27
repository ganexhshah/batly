import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/wallet/transaction_history_screen.dart';
import 'battly_share_sheet.dart';
import '../core/theme/battly_theme.dart';

void showTransactionDetailsSheet(BuildContext context, TransactionRecord record, String formattedDate) {
  IconData iconData;
  Color iconColor;
  String typeLabel;

  switch (record.type) {
    case TransactionType.deposit:
      iconData = Icons.arrow_upward_rounded;
      iconColor = const Color(0xFF4CAF50);
      typeLabel = 'Deposit';
      break;
    case TransactionType.withdraw:
      iconData = Icons.arrow_downward_rounded;
      iconColor = const Color(0xFFE53935);
      typeLabel = 'Withdrawal';
      break;
    case TransactionType.winnings:
      iconData = Icons.emoji_events_outlined;
      iconColor = const Color(0xFFFFD700);
      typeLabel = 'Tournament Winnings';
      break;
    case TransactionType.refund:
      iconData = Icons.settings_backup_restore_rounded;
      iconColor = const Color(0xFF2196F3);
      typeLabel = 'Refund';
      break;
    case TransactionType.spend:
      iconData = Icons.sports_esports_rounded;
      iconColor = const Color(0xFFFF6B00);
      typeLabel = 'Entry Fee';
      break;
  }

  final String amountText = record.amount >= 0
      ? '+ NPR ${record.amount.toStringAsFixed(0)}'
      : '- NPR ${record.amount.abs().toStringAsFixed(0)}';

  final Color amountColor = record.amount >= 0
      ? const Color(0xFF4CAF50)
      : const Color(0xFFE53935);

  // Use real transaction ID from backend data
  final String txnId = record.transactionCode ?? record.referenceId ?? record.id;

  // Build the receipt share message text
  final String shareText = '''
🧾 BATTLY TRANSACTION RECEIPT
--------------------------
Type: $typeLabel
Amount: $amountText
Status: ${record.status.name.toUpperCase()}
Date: $formattedDate
Txn ID: $txnId
--------------------------
Thank you for playing on Battly!
''';

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    isScrollControlled: true,
    builder: (context) {
      return Container(
        decoration: BoxDecoration(
          color: Color(0xFF0F1115),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          border: Border(
            top: BorderSide(color: Color(0xFF2B2F3A), width: 1.5),
          ),
        ),
        padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF3E4351),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Title Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transaction Details',
                  style: GoogleFonts.poppins(color: context.battlyOnSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Color(0xFF1E222A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, color: Color(0xFFA0A0A0), size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // RECEIPT BLOCK
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: context.battlyCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.battlyBorder, width: 1),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Circle Icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(iconData, color: iconColor, size: 28),
                  ),
                  const SizedBox(height: 12),
                  // Amount
                  Text(
                    amountText,
                    style: GoogleFonts.poppins(
                      color: amountColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Status badge
                  _buildDetailsStatusBadge(record.status),
                  const SizedBox(height: 20),
                  // Dashed separator line
                  Row(
                    children: List.generate(
                      24,
                      (index) => Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          height: 1,
                          color: context.battlyBorder,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Detail Rows
                  _buildReceiptDetailRow(context, 'Transaction Type', typeLabel),
                  const SizedBox(height: 12),
                  _buildReceiptDetailRow(
                    context,
                    'Description',
                    record.subtitle.isNotEmpty ? record.subtitle : record.title,
                  ),
                  const SizedBox(height: 12),
                  _buildReceiptDetailRow(context, 'Date & Time', formattedDate),
                  if (record.paymentMethod != null) ...[
                    const SizedBox(height: 12),
                    _buildReceiptDetailRow(
                      context,
                      'Payment Method',
                      _formatPaymentMethod(record.paymentMethod!),
                    ),
                  ],
                  if (record.recipientName != null) ...[
                    const SizedBox(height: 12),
                    _buildReceiptDetailRow(context, 'Recipient', record.recipientName!),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Transaction ID',
                        style: GoogleFonts.poppins(
                          color: context.battlyMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Text(
                                txnId,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: context.battlyOnSurface,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: txnId));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: const Color(0xFF4CAF50),
                                    duration: const Duration(seconds: 1),
                                    content: Text(
                                      'Copied ID: $txnId',
                                      style: GoogleFonts.poppins(color: context.battlyOnSurface),
                                    ),
                                  ),
                                );
                              },
                              child: const Icon(
                                Icons.copy_rounded,
                                color: Color(0xFFFF6B00),
                                size: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Share & Close Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Color(0xFF2B2F3A), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // Close details sheet first
                      showBattlyShareSheet(
                        context,
                        title: 'Share Receipt',
                        shareText: shareText,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B00),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.share_outlined, size: 16),
                    label: Text(
                      'Share Receipt',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

String _formatPaymentMethod(String method) {
  switch (method) {
    case 'esewa': return 'eSewa';
    case 'khalti': return 'Khalti';
    case 'ime_pay': return 'IME Pay';
    case 'connect_ips': return 'Connect IPS';
    case 'bank_transfer': return 'Bank Transfer';
    default: return method;
  }
}

Widget _buildReceiptDetailRow(BuildContext context, String label, String value) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: GoogleFonts.poppins(
          color: context.battlyMuted,
          fontSize: 12,
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Text(
          value,
          textAlign: TextAlign.end,
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
          style: GoogleFonts.poppins(
            color: context.battlyOnSurface,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ],
  );
}

Widget _buildDetailsStatusBadge(TransactionStatus status) {
  Color textColor;
  Color bgColor;
  String label;

  switch (status) {
    case TransactionStatus.completed:
      label = 'Completed';
      textColor = const Color(0xFF4CAF50);
      bgColor = const Color(0xFF4CAF50).withValues(alpha: 0.12);
      break;
    case TransactionStatus.pending:
      label = 'Pending';
      textColor = const Color(0xFFFF9800);
      bgColor = const Color(0xFFFF9800).withValues(alpha: 0.12);
      break;
    case TransactionStatus.failed:
      label = 'Failed';
      textColor = const Color(0xFFE53935);
      bgColor = const Color(0xFFE53935).withValues(alpha: 0.12);
      break;
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: GoogleFonts.poppins(
        color: textColor,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
