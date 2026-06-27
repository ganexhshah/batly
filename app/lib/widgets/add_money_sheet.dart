import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth/signin_screen.dart';
import '../core/root_scaffold_messenger.dart';
import '../core/responsive/responsive.dart';
import '../core/theme/battly_theme.dart';
import '../services/api_config.dart';
import '../services/auth_service.dart';
import '../services/esewa_payment.dart';
import '../services/esewa_web_return.dart';
import '../services/wallet_service.dart';
import 'wallet_sheet_widgets.dart';

const _esewaLogo = 'assets/img/esewa-logo-png_seeklogo-469833.png';

/// Opens a compact add-money sheet (amount + eSewa).
Future<bool?> showAddMoneySheet(BuildContext context) {
  return showAdaptiveSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => const _AddMoneySheet(),
  );
}

class _AddMoneySheet extends StatefulWidget {
  const _AddMoneySheet();

  @override
  State<_AddMoneySheet> createState() => _AddMoneySheetState();
}

class _AddMoneySheetState extends State<_AddMoneySheet> {
  final _amountController = TextEditingController();
  String _selectedMethod = 'esewa';
  bool _isProcessing = false;

  static const _methods = [
    {'id': 'esewa', 'name': 'eSewa', 'logo': _esewaLogo},
  ];

  @override
  void dispose() {
    _amountController.dispose();
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFE53935),
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
      ),
    );
  }

  void _showSuccess(String amountText) {
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF4CAF50),
        content: Text(
          'NPR $amountText added via ${_methodLabel(_selectedMethod)}.',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
      ),
    );
    Navigator.pop(context, true);
  }

  Future<void> _handlePay() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _showError('Please enter an amount');
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount < 50) {
      _showError('Minimum deposit is NPR 50');
      return;
    }
    if (amount > 50000) {
      _showError('Maximum deposit is NPR 50,000');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final initData = await WalletService.initiateDeposit(
        amount: amount,
        paymentMethod: _selectedMethod,
      );

      final transactionId = initData['transaction']['id'] as String;
      final checkoutUrl = initData['esewa']?['checkout_url'] as String? ??
          '${ApiConfig.baseUrl}/esewa/checkout/$transactionId';

      if (!mounted) return;

      await startEsewaPayment(
        context: context,
        transactionId: transactionId,
        amountText: amountText,
        amount: amount,
        baseUrl: ApiConfig.baseUrl,
        checkoutUrl: checkoutUrl,
        returnUrl: kIsWeb ? webReturnUrl() : '',
        onSuccess: (referenceId) async {
          try {
            await WalletService.waitForDepositCompletion(transactionId);
            await AuthService.getUser();
            if (!mounted) return;
            setState(() => _isProcessing = false);
            _showSuccess(amountText);
          } catch (e) {
            if (!mounted) return;
            setState(() => _isProcessing = false);
            _showError('Payment verification failed: $e');
          }
        },
        onFailure: (message) {
          if (!mounted) return;
          setState(() => _isProcessing = false);
          _showError(message);
        },
        onCancelled: (message) {
          if (!mounted) return;
          setState(() => _isProcessing = false);
          _showError(message);
        },
      );
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
      _showError('Failed to start payment: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
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
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WalletSheetHandle(),
            const SizedBox(height: 16),
            WalletSheetHeader(
              title: 'Add Money',
              onClose: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
            const WalletSheetLabel('ENTER AMOUNT (NPR)'),
            const SizedBox(height: 8),
            WalletAmountField(
              controller: _amountController,
              autofocus: true,
            ),
            const SizedBox(height: 20),
            const WalletSheetLabel('PAYMENT METHOD'),
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
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _handlePay,
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
                        'Pay with ${_methodLabel(_selectedMethod)}',
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
    );
  }
}
