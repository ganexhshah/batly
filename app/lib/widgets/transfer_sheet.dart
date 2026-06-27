import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth/signin_screen.dart';
import '../core/root_scaffold_messenger.dart';
import '../core/responsive/responsive.dart';
import '../core/theme/battly_theme.dart';
import '../services/auth_service.dart';
import '../services/wallet_service.dart';
import 'wallet_sheet_widgets.dart';

Future<bool?> showTransferSheet(
  BuildContext context, {
  required double balance,
}) {
  return showAdaptiveSheet<bool>(
    context: context,
    isScrollControlled: true,
    maxWidth: 520,
    builder: (_) => _TransferSheet(balance: balance),
  );
}

class _TransferSheet extends StatefulWidget {
  final double balance;

  const _TransferSheet({required this.balance});

  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet> {
  final _searchController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  List<Map<String, dynamic>> _searchResults = [];
  Map<String, dynamic>? _verifiedRecipient;
  bool _hasSearched = false;
  bool _isSearching = false;
  bool _isTransferring = false;

  @override
  void dispose() {
    _searchController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
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

  void _showSuccess(double amount, String recipientName, String txnId) {
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF4CAF50),
        content: Text(
          'NPR ${amount.toStringAsFixed(0)} sent to $recipientName. Ref: $txnId',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
      ),
    );
    Navigator.pop(context, true);
  }

  Future<void> _searchRecipient(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _verifiedRecipient = null;
      _searchResults = [];
    });

    try {
      final results = await WalletService.searchRecipient(cleanQuery);
      if (!mounted) return;

      Map<String, dynamic>? autoPick;
      if (results.length == 1) {
        autoPick = results.first;
      } else {
        for (final r in results) {
          final id = r['id']?.toString() ?? '';
          final name = (r['name'] ?? '').toLowerCase();
          final ign = (r['ign'] ?? '').toLowerCase();
          if (id == cleanQuery ||
              name == cleanQuery.toLowerCase() ||
              ign == cleanQuery.toLowerCase()) {
            autoPick = r;
            break;
          }
        }
      }

      setState(() {
        _isSearching = false;
        _searchResults = results;
        _verifiedRecipient = autoPick;
        if (autoPick != null) {
          _searchController.text =
              autoPick['name'] ?? autoPick['ign'] ?? '';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSearching = false);
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
      _showError('Search failed. Please try again.');
    }
  }

  void _selectRecipient(Map<String, dynamic> recipient) {
    setState(() {
      _verifiedRecipient = recipient;
      _searchController.text = recipient['name'] ?? recipient['ign'] ?? '';
      _hasSearched = true;
    });
  }

  Future<void> _handleTransfer() async {
    if (_verifiedRecipient == null) {
      _showError('Please verify a recipient first');
      return;
    }

    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _showError('Please enter an amount');
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount < 50) {
      _showError('Minimum transfer is NPR 50');
      return;
    }
    if (amount > widget.balance) {
      _showError('Insufficient balance');
      return;
    }

    setState(() => _isTransferring = true);

    try {
      final result = await WalletService.transfer(
        recipientId: _verifiedRecipient!['id'] as int,
        amount: amount,
        note: _noteController.text.trim().isNotEmpty
            ? _noteController.text.trim()
            : null,
      );
      if (!mounted) return;
      setState(() => _isTransferring = false);

      final txnData = result['transaction'] as Map<String, dynamic>? ?? {};
      final txnId = txnData['transaction_code'] ??
          txnData['reference_id'] ??
          'TR-${DateTime.now().millisecondsSinceEpoch}';
      final recipientName =
          _verifiedRecipient!['name'] ?? _verifiedRecipient!['ign'] ?? 'Player';

      _showSuccess(amount, recipientName, txnId.toString());
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTransferring = false);
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
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;

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
                  title: 'Transfer',
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
                const WalletSheetLabel('RECIPIENT'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: context.battlyCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _verifiedRecipient != null
                          ? const Color(0xFF4CAF50)
                          : context.battlyBorder,
                      width: _verifiedRecipient != null ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: GoogleFonts.poppins(
                            color: context.battlyOnSurface,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Player name, IGN, or ID',
                            hintStyle: GoogleFonts.poppins(
                              color: context.battlyMuted.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                            prefixIcon: Icon(
                              Icons.person_search_rounded,
                              color: context.battlyMuted,
                              size: 18,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onChanged: (_) {
                            if (_hasSearched) {
                              setState(() {
                                _hasSearched = false;
                                _verifiedRecipient = null;
                                _searchResults = [];
                              });
                            }
                          },
                          onSubmitted: _searchRecipient,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: TextButton(
                          onPressed: _isSearching
                              ? null
                              : () => _searchRecipient(_searchController.text),
                          style: TextButton.styleFrom(
                            backgroundColor:
                                const Color(0xFFFF6B00).withValues(alpha: 0.15),
                            foregroundColor: const Color(0xFFFF6B00),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Verify',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isSearching) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFFF6B00),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Searching...',
                        style: GoogleFonts.poppins(
                          color: context.battlyMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
                if (_hasSearched &&
                    _verifiedRecipient == null &&
                    !_isSearching &&
                    _searchResults.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ..._searchResults.map(_buildSearchResult),
                ],
                if (_hasSearched &&
                    _verifiedRecipient == null &&
                    !_isSearching &&
                    _searchResults.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Player not found.',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFE53935),
                      fontSize: 11,
                    ),
                  ),
                ],
                if (_verifiedRecipient != null) ...[
                  const SizedBox(height: 10),
                  _buildVerifiedChip(_verifiedRecipient!),
                ],
                const SizedBox(height: 20),
                const WalletSheetLabel('AMOUNT (NPR)'),
                const SizedBox(height: 8),
                WalletAmountField(controller: _amountController),
                const SizedBox(height: 16),
                const WalletSheetLabel('NOTE (OPTIONAL)'),
                const SizedBox(height: 8),
                WalletTextField(
                  controller: _noteController,
                  hint: 'e.g. entry fee',
                  maxLength: 60,
                  prefixIcon: Icons.edit_outlined,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isTransferring ? null : _handleTransfer,
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
                    child: _isTransferring
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Confirm Transfer',
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

  Widget _buildVerifiedChip(Map<String, dynamic> recipient) {
    final name = recipient['name'] ?? recipient['ign'] ?? 'Player';
    final id = recipient['id']?.toString() ?? '';
    final avatar = recipient['avatar_url'] as String?;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF4CAF50).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: context.battlyBorder,
            backgroundImage: avatar != null && avatar.isNotEmpty
                ? NetworkImage(avatar)
                : null,
            child: avatar == null || avatar.isEmpty
                ? Icon(Icons.person, color: context.battlyMuted, size: 18)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    color: context.battlyOnSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'ID: $id',
                  style: GoogleFonts.poppins(
                    color: context.battlyMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 20),
        ],
      ),
    );
  }

  Widget _buildSearchResult(Map<String, dynamic> recipient) {
    final name = recipient['name'] ?? recipient['ign'] ?? 'Player';
    final id = recipient['id']?.toString() ?? '';

    return GestureDetector(
      onTap: () => _selectRecipient(recipient),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.battlyCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.battlyBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.person_outline, color: context.battlyMuted, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      color: context.battlyOnSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'ID: $id',
                    style: GoogleFonts.poppins(
                      color: context.battlyMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.battlyMuted, size: 18),
          ],
        ),
      ),
    );
  }
}
