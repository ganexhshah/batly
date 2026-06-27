import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/responsive/responsive.dart';
import '../core/theme/battly_theme.dart';
import '../services/wallet_service.dart';

/// Shows an adaptive confirmation sheet for wallet deduction.
///
/// Returns `true` if the user confirms the deduction, `false` otherwise.
Future<bool?> showWalletDeductionConfirmSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required double deductionAmount,
  String actionButtonLabel = 'Confirm & Deduct',
}) {
  return showAdaptiveSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return WalletDeductionConfirmationSheet(
        title: title,
        subtitle: subtitle,
        deductionAmount: deductionAmount,
        actionButtonLabel: actionButtonLabel,
      );
    },
  );
}

class WalletDeductionConfirmationSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final double deductionAmount;
  final String actionButtonLabel;

  const WalletDeductionConfirmationSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.deductionAmount,
    required this.actionButtonLabel,
  });

  @override
  State<WalletDeductionConfirmationSheet> createState() =>
      _WalletDeductionConfirmationSheetState();
}

class _WalletDeductionConfirmationSheetState
    extends State<WalletDeductionConfirmationSheet> {
  double? _walletBalance;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchBalance();
  }

  Future<void> _fetchBalance() async {
    try {
      final balanceData = await WalletService.getBalance();
      if (mounted) {
        setState(() {
          _walletBalance = (balanceData['balance'] ?? 0).toDouble();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load wallet balance';
          _isLoading = false;
        });
      }
    }
  }

  Widget _feeRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: context.battlyMuted,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: valueColor,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final double entryFeeRaw = widget.deductionAmount;
    final bool hasInsufficientBalance =
        _walletBalance != null && _walletBalance! < entryFeeRaw;

    return Container(
      decoration: BoxDecoration(
        color: context.battlyScaffold,
        borderRadius: context.useNavigationRail
            ? BorderRadius.circular(24)
            : const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
        border: Border.all(color: context.battlyBorder, width: 1.5),
      ),
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle indicator
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

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: GoogleFonts.poppins(
                    color: context.battlyOnSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context, false),
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white70, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Subtitle
          Text(
            widget.subtitle,
            style: GoogleFonts.poppins(
              color: context.battlyMuted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Content Area
          if (_isLoading)
            const SizedBox(
              height: 100,
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFFF6B00),
                ),
              ),
            )
          else if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Color(0xFFE53935), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFE53935),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.battly.elevatedSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.battlyBorder),
              ),
              child: Column(
                children: [
                  _feeRow(
                    'Entry Fee',
                    'NPR ${entryFeeRaw.toInt()}',
                    const Color(0xFFFF6B00),
                  ),
                  const SizedBox(height: 10),
                  Divider(color: context.battlyBorder, height: 1),
                  const SizedBox(height: 10),
                  _feeRow(
                    'Current Wallet Balance',
                    'NPR ${_walletBalance!.toInt()}',
                    hasInsufficientBalance
                        ? const Color(0xFFE53935)
                        : Colors.greenAccent,
                  ),
                  const SizedBox(height: 10),
                  Divider(color: context.battlyBorder, height: 1),
                  const SizedBox(height: 10),
                  _feeRow(
                    'Remaining Balance',
                    'NPR ${(_walletBalance! - entryFeeRaw).toInt()}',
                    (_walletBalance! - entryFeeRaw) >= 0
                        ? Colors.white
                        : const Color(0xFFE53935),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Warning Container if Insufficient Balance
            if (hasInsufficientBalance) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFE53935).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFE53935),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Insufficient balance to cover the entry fee. Please top up your wallet.',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFE53935),
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.battlyMuted,
                      side: BorderSide(color: context.battlyBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: hasInsufficientBalance
                        ? null
                        : () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B00),
                      disabledBackgroundColor:
                          const Color(0xFFFF6B00).withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: Text(
                      widget.actionButtonLabel,
                      style: GoogleFonts.poppins(
                        color: hasInsufficientBalance
                            ? context.battlyMuted
                            : context.battlyOnSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
