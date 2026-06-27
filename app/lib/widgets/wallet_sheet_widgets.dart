import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/battly_theme.dart';

class WalletSheetHandle extends StatelessWidget {
  const WalletSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: context.battlyBorder,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class WalletSheetHeader extends StatelessWidget {
  final String title;
  final VoidCallback onClose;

  const WalletSheetHeader({
    super.key,
    required this.title,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.poppins(
              color: context.battlyOnSurface,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        IconButton(
          onPressed: onClose,
          icon: Icon(Icons.close_rounded, color: context.battlyMuted),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class WalletSheetLabel extends StatelessWidget {
  final String text;

  const WalletSheetLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        color: context.battlyMuted,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }
}

class WalletAmountField extends StatelessWidget {
  final TextEditingController controller;
  final bool autofocus;

  const WalletAmountField({
    super.key,
    required this.controller,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: context.battlyCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.battlyBorder),
      ),
      child: Row(
        children: [
          Text(
            'Rs.',
            style: GoogleFonts.poppins(
              color: context.battlyOnSurface,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.poppins(
                color: context.battlyOnSurface,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: '0',
                hintStyle: GoogleFonts.poppins(
                  color: context.battlyMuted.withValues(alpha: 0.5),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WalletTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final IconData? prefixIcon;
  final int? maxLength;

  const WalletTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.prefixIcon,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.battlyCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.battlyBorder),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLength: maxLength,
        style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            color: context.battlyMuted.withValues(alpha: 0.6),
            fontSize: 14,
          ),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: context.battlyMuted, size: 18)
              : null,
          border: InputBorder.none,
          counterStyle: GoogleFonts.poppins(
            color: context.battlyMuted.withValues(alpha: 0.5),
            fontSize: 9,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class WalletPaymentMethodTile extends StatelessWidget {
  final String name;
  final String logo;
  final bool isSelected;
  final VoidCallback onTap;

  const WalletPaymentMethodTile({
    super.key,
    required this.name,
    required this.logo,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: context.battlyCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF6B00) : context.battlyBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              height: 44,
              width: double.infinity,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: context.battlyScaffold,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Image.asset(
                logo,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.account_balance_wallet_outlined,
                  color: isSelected
                      ? const Color(0xFFFF6B00)
                      : context.battlyMuted,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: GoogleFonts.poppins(
                color: context.battlyOnSurface,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? const Color(0xFFFF6B00) : context.battlyMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
