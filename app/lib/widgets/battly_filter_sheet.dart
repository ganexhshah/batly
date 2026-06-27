import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/responsive/responsive.dart';
import '../core/theme/battly_theme.dart';

void showBattlyFilterSheet(
  BuildContext context, {
  required String initialType,
  required String initialMode,
  required String initialFee,
  required void Function(String type, String mode, String fee) onApply,
}) {
  String tempType = initialType;
  String tempMode = initialMode;
  String tempFee = initialFee;

  showAdaptiveSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
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
                    Text(
                      'Filter Tournaments',
                      style: GoogleFonts.poppins(color: context.battlyOnSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setSheetState(() {
                          tempType = 'All';
                          tempMode = 'All';
                          tempFee = 'All';
                        });
                      },
                      child: Text(
                        'Reset All',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFFF6B00),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // TEAM TYPE Filters
                Text(
                  'TEAM TYPE',
                  style: GoogleFonts.poppins(
                    color: context.battlyMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: ['All', 'Solo', 'Duo', 'Squad'].map((type) {
                    final selected = tempType == type;
                    return GestureDetector(
                      onTap: () => setSheetState(() => tempType = type),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFFFF6B00).withValues(alpha: 0.1) : context.battlyCard,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected ? const Color(0xFFFF6B00) : context.battlyBorder,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          type,
                          style: GoogleFonts.poppins(
                            color: selected ? const Color(0xFFFF6B00) : Colors.white,
                            fontSize: 11,
                            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                
                // GAME MODE Filters
                Text(
                  'GAME MODE',
                  style: GoogleFonts.poppins(
                    color: context.battlyMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: ['All', 'Battle Royale', 'TDM'].map((mode) {
                    final selected = tempMode == mode;
                    return GestureDetector(
                      onTap: () => setSheetState(() => tempMode = mode),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFFFF6B00).withValues(alpha: 0.1) : context.battlyCard,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected ? const Color(0xFFFF6B00) : context.battlyBorder,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          mode,
                          style: GoogleFonts.poppins(
                            color: selected ? const Color(0xFFFF6B00) : Colors.white,
                            fontSize: 11,
                            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                
                // ENTRY FEE Filters
                Text(
                  'ENTRY FEE',
                  style: GoogleFonts.poppins(
                    color: context.battlyMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: ['All', 'Free', 'Paid'].map((fee) {
                    final selected = tempFee == fee;
                    return GestureDetector(
                      onTap: () => setSheetState(() => tempFee = fee),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFFFF6B00).withValues(alpha: 0.1) : context.battlyCard,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected ? const Color(0xFFFF6B00) : context.battlyBorder,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          fee,
                          style: GoogleFonts.poppins(
                            color: selected ? const Color(0xFFFF6B00) : Colors.white,
                            fontSize: 11,
                            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
                
                // Apply Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      onApply(tempType, tempMode, tempFee);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B00),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Apply Filters',
                      style: GoogleFonts.poppins(color: context.battlyOnSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
