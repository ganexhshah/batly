import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/battly_theme.dart';

// -----------------------------------------------------------------------------
// CATEGORY CARD
// -----------------------------------------------------------------------------
class CategoryCard extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Widget? customIcon;
  final VoidCallback onTap;

  const CategoryCard({
    super.key,
    required this.label,
    this.icon,
    this.customIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: const Color(0xFFFF6B00).withValues(alpha: 0.15),
          highlightColor: const Color(0xFFFF6B00).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (customIcon != null)
                  customIcon!
                else if (icon != null)
                  Icon(
                    icon,
                    color: const Color(0xFFFF6B00),
                    size: 26,
                  ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: GoogleFonts.poppins(color: context.battlyOnSurface,
                    fontSize: 11,
                    fontWeight: FontWeight.w500, // Medium for buttons/nav
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
