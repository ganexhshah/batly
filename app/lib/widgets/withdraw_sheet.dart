import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth/signin_screen.dart';
import '../core/root_scaffold_messenger.dart';
import '../core/responsive/responsive.dart';
import '../core/theme/battly_theme.dart';
import '../services/auth_service.dart';
import '../services/wallet_service.dart';
import 'wallet_sheet_widgets.dart';

const _esewaLogo = 'assets/img/esewa-logo-png_seeklogo-469833.png';

Future<bool?> showWithdrawSheet(
  BuildContext context, {
  required double balance,
}) {
  return showAdaptiveSheet<bool>(
    context: context,
    isScrollControlled: true,
    maxWidth: 520,
    builder: (_) => _WithdrawSheet(balance: balance),
  );
}

class _WithdrawSheet extends StatefulWidget {
  final double balance;

  const _WithdrawSheet({required this.balance});

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  final _amountController = TextEditingController();
  final _walletNumberController = TextEditingController();
  String _selectedMethod = 'esewa';
  bool _isProcessing = false;

  static const _methods = [
    {'id': 'esewa', 'name': 'eSewa', 'logo': _esewaLogo},
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _walletNumberController.dispose();
    super.dispose();
  }

  String _methodLabel(String id) {
    switch (id) {
      case 'esewa':
        return 'eSewa';
      default:
        return id;
    }
  }

  String _formatBalance(double amount) {
    return 'NPR ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFE53935),
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
      ),
    );
  }

  void _showSuccess(double amount, Map<String, dynamic> result) {
    final ref = result['transaction']?['id'];
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFFF9800),
        content: Text(
          ref != null
              ? 'Withdrawal of NPR ${amount.toStringAsFixed(0)} submitted. Ref: $ref'
              : 'Withdrawal of NPR ${amount.toStringAsFixed(0)} submitted. Processing within 24h.',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
      ),
    );
    Navigator.pop(context, true);
  }

  Future<void> _handleWithdraw() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _showError('Please enter an amount');
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount < 100) {
      _showError('Minimum withdrawal is NPR 100');
      return;
    }
    if (amount > widget.balance) {
      _showError('Insufficient wallet balance');
      return;
    }

    final number = _walletNumberController.text.trim();
    if (number.length != 10 || double.tryParse(number) == null) {
      _showError('Enter a valid 10-digit ${_methodLabel(_selectedMethod)} number');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final result = await WalletService.withdraw(
        amount: amount,
        paymentMethod: _selectedMethod,
        recipient: number,
      );
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showSuccess(amount, result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      if (e.toString().contains('401') ||
          e.toString().toLowerCase().contains('unauthenticated')) {
        await AuthService.logout();
        if (!mounted) return;
        Navigator.pop(context);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const SigninScreen()),
          (_) => false,
        );
        return;
      }
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WalletSheetHandle(),
                const SizedBox(height: 16),
                WalletSheetHeader(
                  title: 'Withdraw',
                  onClose: () => Navigator.pop(context),
                ),
                const SizedBox(height: 8),
                Text(
                  'Available: ${_formatBalance(widget.balance)}',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFFFD700),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const WalletSheetLabel('ENTER AMOUNT (NPR)'),
                const SizedBox(height: 8),
                WalletAmountField(controller: _amountController),
                const SizedBox(height: 20),
                const WalletSheetLabel('WITHDRAW TO'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final method in _methods) ...[
                      Expanded(
                        child: WalletPaymentMethodTile(
                          name: method['name']!,
                          logo: method['logo']!,
                          isSelected: _selectedMethod == method['id'],
                          onTap: () => setState(() => _selectedMethod = method['id']!),
                        ),
                      ),
                      if (method != _methods.last) const SizedBox(width: 10),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                WalletSheetLabel('${_methodLabel(_selectedMethod).toUpperCase()} NUMBER'),
                const SizedBox(height: 8),
                WalletTextField(
                  controller: _walletNumberController,
                  hint: '98XXXXXXXX',
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Processed within 24 hours',
                  style: GoogleFonts.poppins(
                    color: context.battlyMuted,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _handleWithdraw,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B00),
                      disabledBackgroundColor:
                          const Color(0xFFFF6B00).withValues(alpha: 0.5),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Submit Withdrawal',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
