import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/responsive/responsive.dart';
import 'transaction_history_screen.dart';
import '../../widgets/transaction_details_sheet.dart';
import '../../widgets/skeleton_widgets.dart';
import '../../services/wallet_service.dart';
import '../../services/auth_service.dart';
import '../../core/auth_errors.dart';
import '../../services/local_cache.dart';
import '../../auth/signin_screen.dart';
import '../../widgets/add_money_sheet.dart';
import '../../widgets/withdraw_sheet.dart';
import '../../widgets/transfer_sheet.dart';
import '../../widgets/wallet_balance_card.dart';
import '../../core/cache_debug.dart';
import '../../core/theme/battly_theme.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _showBalance = true;
  bool _isLoading = true;
  String? _errorMessage;
  double _balance = 0.0;
  double _winningBalance = 0.0;
  List<TransactionRecord> _recentTransactions = [];

  @override
  void initState() {
    super.initState();
    _showCachedWallet();
    _loadWalletData();
  }

  Future<void> _showCachedWallet() async {
    try {
      final balanceRaw = await LocalCache.read('cache_wallet_balance');
      final txnRaw = await LocalCache.read('cache_wallet_transactions');
      if (balanceRaw == null || !mounted) return;

      final balanceData = jsonDecode(balanceRaw) as Map<String, dynamic>;
      final txnData = txnRaw != null ? jsonDecode(txnRaw) as Map<String, dynamic> : null;
      final rawTxns = txnData?['transactions'] as List? ?? [];

      setState(() {
        _balance = (balanceData['balance'] ?? 0).toDouble();
        _winningBalance = (balanceData['winning_balance'] ?? 0).toDouble();
        _recentTransactions = rawTxns.map((json) {
          return TransactionRecord.fromJson(json as Map<String, dynamic>);
        }).toList();
        _isLoading = false;
      });
    } catch (e, st) {
      logCacheRefreshFailure('walletPeekBalance', e, st);
    }
  }

  Future<void> _loadWalletData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        WalletService.getBalance(),
        WalletService.getTransactions(perPage: 5),
      ]);

      final balanceData = results[0];
      final txnData = results[1];

      final List<dynamic> rawTxns = txnData['transactions'] ?? [];

      setState(() {
        _balance = (balanceData['balance'] ?? 0).toDouble();
        _winningBalance = (balanceData['winning_balance'] ?? 0).toDouble();
        _recentTransactions = rawTxns.map((json) {
          return TransactionRecord.fromJson(json as Map<String, dynamic>);
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (AuthErrors.isAuthException(e)) {
        await AuthService.logout();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const SigninScreen()),
            (route) => false,
          );
        }
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load wallet data. Pull to refresh.';
      });
    }
  }

  String _formatBalance(double amount) {
    return 'NPR ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  Widget _buildBalanceCardsCarousel() {
    final cardWidth = MediaQuery.sizeOf(context).width * 0.78;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      clipBehavior: Clip.none,
      child: Row(
        children: [
          SizedBox(
            width: cardWidth,
            child: WalletBalanceCard(
              balance: _balance,
              showBalance: _showBalance,
              onToggleVisibility: () {
                setState(() => _showBalance = !_showBalance);
              },
              formatBalance: _formatBalance,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: cardWidth,
            child: WalletBalanceCard(
              balance: _winningBalance,
              showBalance: _showBalance,
              onToggleVisibility: () {
                setState(() => _showBalance = !_showBalance);
              },
              formatBalance: _formatBalance,
              title: 'WINNING BALANCE',
              subtitle: 'Available for instant withdrawals',
              barColor: const Color(0xFFFFB300),
              imageAsset: walletWithdrawalCardImage,
              fallbackIcon: Icons.account_balance_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCardsSkeleton() {
    final cardWidth = MediaQuery.sizeOf(context).width * 0.78;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      clipBehavior: Clip.none,
      child: Row(
        children: [
          SizedBox(width: cardWidth, child: const SkeletonWalletCard()),
          const SizedBox(width: 12),
          SizedBox(width: cardWidth, child: const SkeletonWalletCard()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.battly.navBar,
      appBar: AppBar(
        backgroundColor: context.battly.navBar,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 12,
        title: Text(
          'Wallet',
          style: GoogleFonts.poppins(color: context.battlyOnSurface,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TransactionHistoryScreen(),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.assignment_outlined,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Transaction History',
                    style: GoogleFonts.poppins(color: context.battlyOnSurface.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white54,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/background/bg1.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const SizedBox(),
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.88),
            ),
          ),
          Positioned.fill(
            child: _isLoading
                ? SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBalanceCardsSkeleton(),
                        const SizedBox(height: 28),
                        Container(
                          height: 14,
                          width: 120,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E222A),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...List.generate(4, (_) => const SkeletonTransactionItem()),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadWalletData,
                    color: const Color(0xFFFF6B00),
                    backgroundColor: context.battly.elevatedSurface,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: ResponsiveContent(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          _buildBalanceCardsCarousel(),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            _buildErrorBanner(),
                          ],
                          const SizedBox(height: 28),
                          Text(
                            'Quick Actions',
                            style: GoogleFonts.poppins(color: context.battlyOnSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildQuickActionItem(
                                icon: Icons.add_card_rounded,
                                label: 'Add Money',
                                onTap: () async {
                                  final result = await showAddMoneySheet(context);
                                  if (result == true) _loadWalletData();
                                },
                              ),
                              _buildQuickActionItem(
                                icon: Icons.account_balance_rounded,
                                label: 'Withdraw',
                                onTap: () async {
                                  final result =
                                      await showWithdrawSheet(context, balance: _winningBalance);
                                  if (result == true) _loadWalletData();
                                },
                              ),
                              _buildQuickActionItem(
                                icon: Icons.swap_horiz_rounded,
                                label: 'Transfer',
                                onTap: () async {
                                  final result =
                                      await showTransferSheet(context, balance: _balance);
                                  if (result == true) _loadWalletData();
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          _buildSectionHeader(
                            'Recent Transactions',
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const TransactionHistoryScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          if (_recentTransactions.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Text(
                                  'No transactions yet',
                                  style: GoogleFonts.poppins(
                                    color: context.battlyMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            )
                          else
                            Column(
                              children: _recentTransactions
                                  .map((item) => _buildTransactionItem(item))
                                  .toList(),
                            ),
                          const SizedBox(height: 24),
                          _buildPromoBanner(),
                          const SizedBox(height: 8),
                        ],
                      ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE53935).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFE53935), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.poppins(
                color: const Color(0xFFE53935),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onViewAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(color: context.battlyOnSurface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        InkWell(
          onTap: onViewAll,
          child: Row(
            children: [
              Text(
                'View All',
                style: GoogleFonts.poppins(
                  color: const Color(0xFFFF6B00),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFFF6B00),
                size: 16,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: context.battlyCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.battlyBorder, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B00).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFFFF6B00), size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(color: context.battlyOnSurface,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        color: context.battlyCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.battlyBorder, width: 1.5),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 8,
            top: 10,
            bottom: 10,
            child: Image.asset(
              'assets/img/invite.png',
              width: 110,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const SizedBox(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invite Friends & Earn Rewards',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFFF6B00),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Invite your friends and earn exciting bonuses!',
                      style: GoogleFonts.poppins(
                        color: context.battlyMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF6B00),
                    side: BorderSide(color: Color(0xFFFF6B00), width: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Invite Now',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(TransactionRecord record) {
    IconData iconData;
    Color iconColor;

    switch (record.type) {
      case TransactionType.deposit:
        iconData = Icons.arrow_upward_rounded;
        iconColor = const Color(0xFF4CAF50);
        break;
      case TransactionType.withdraw:
        iconData = Icons.arrow_downward_rounded;
        iconColor = const Color(0xFFE53935);
        break;
      case TransactionType.winnings:
        iconData = Icons.emoji_events_outlined;
        iconColor = const Color(0xFFFFD700);
        break;
      case TransactionType.refund:
        iconData = Icons.settings_backup_restore_rounded;
        iconColor = const Color(0xFF2196F3);
        break;
      case TransactionType.spend:
        iconData = Icons.sports_esports_rounded;
        iconColor = const Color(0xFFFF6B00);
        break;
    }

    final String amountText = record.amount >= 0
        ? '+ NPR ${record.amount.abs().toStringAsFixed(0)}'
        : '- NPR ${record.amount.abs().toStringAsFixed(0)}';

    final Color amountColor = record.amount >= 0
        ? const Color(0xFF4CAF50)
        : const Color(0xFFE53935);

    return GestureDetector(
      onTap: () => showTransactionDetailsSheet(context, record, _formatDate(record.dateTime)),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.battlyCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.title,
                    style: GoogleFonts.poppins(color: context.battlyOnSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    record.subtitle,
                    style: GoogleFonts.poppins(
                      color: context.battlyMuted,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(record.dateTime),
                    style: GoogleFonts.poppins(
                      color: const Color(0x80A0A0A0),
                      fontSize: 8.5,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  amountText,
                  style: GoogleFonts.poppins(
                    color: amountColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                _buildStatusPill(record.status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(TransactionStatus status) {
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: textColor,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(dt.year, dt.month, dt.day);

    int hour = dt.hour;
    String amPm = "AM";
    if (hour >= 12) {
      amPm = "PM";
      if (hour > 12) hour -= 12;
    } else if (hour == 0) {
      hour = 12;
    }
    String timeStr = "$hour:${dt.minute.toString().padLeft(2, '0')} $amPm";

    if (dateToCheck == today) {
      return "Today • $timeStr";
    } else if (dateToCheck == yesterday) {
      return "Yesterday • $timeStr";
    } else {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return "${dt.day} ${months[dt.month - 1]}, ${dt.year} • $timeStr";
    }
  }
}
