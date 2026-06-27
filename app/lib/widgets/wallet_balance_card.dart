import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/battly_theme.dart';

const walletBalanceCardImage = 'assets/img/payg (3).png';
const walletWithdrawalCardImage = 'assets/img/withdarwal.png';

class WalletBalanceCard extends StatelessWidget {
  final double balance;
  final bool showBalance;
  final VoidCallback onToggleVisibility;
  final String Function(double) formatBalance;
  final String title;
  final String subtitle;
  final Color? barColor;
  final String imageAsset;
  final IconData fallbackIcon;
  final double? width;

  const WalletBalanceCard({
    super.key,
    required this.balance,
    required this.showBalance,
    required this.onToggleVisibility,
    required this.formatBalance,
    this.title = 'WALLET BALANCE',
    this.subtitle = 'Available for entry fees & transfers',
    this.barColor,
    this.imageAsset = walletBalanceCardImage,
    this.fallbackIcon = Icons.account_balance_wallet_outlined,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveBarColor = barColor ?? Theme.of(context).colorScheme.primary;

    return Container(
      width: width ?? double.infinity,
      decoration: BoxDecoration(
        color: context.battlyCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.battlyBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 3,
              child: ColoredBox(color: effectiveBarColor),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.poppins(
                                color: context.battlyMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const Spacer(),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: onToggleVisibility,
                                borderRadius: BorderRadius.circular(20),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    showBalance
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 18,
                                    color: context.battlyMuted,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          showBalance ? formatBalance(balance) : '••••••',
                          style: GoogleFonts.poppins(
                            color: context.battlyOnSurface,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            height: 1.05,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: GoogleFonts.poppins(
                            color: context.battlyMuted,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 96,
                    height: 96,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? context.battlyScaffold.withValues(alpha: 0.6)
                          : context.battlyScaffold,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Image.asset(
                      imageAsset,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        fallbackIcon,
                        color: effectiveBarColor,
                        size: 36,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
