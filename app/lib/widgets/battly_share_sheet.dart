import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/battly_theme.dart';

void showBattlyShareSheet(BuildContext context, {required String title, required String shareText}) {
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
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
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
            // Social channels row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildShareOption(
                    context,
                    icon: Icons.link_rounded,
                    label: 'Copy Link',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      Clipboard.setData(ClipboardData(text: shareText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF4CAF50),
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, color: Colors.white),
                              const SizedBox(width: 8),
                              Text('Link copied to clipboard!', style: GoogleFonts.poppins(color: context.battlyOnSurface)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  _buildShareOption(
                    context,
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'WhatsApp',
                    color: const Color(0xFF25D366),
                    onTap: () => _simulateSocialShare(context, 'WhatsApp'),
                  ),
                  _buildShareOption(
                    context,
                    icon: Icons.alternate_email_rounded,
                    label: 'Discord',
                    color: const Color(0xFF5865F2),
                    onTap: () => _simulateSocialShare(context, 'Discord'),
                  ),
                  _buildShareOption(
                    context,
                    icon: Icons.telegram_rounded,
                    label: 'Telegram',
                    color: const Color(0xFF0088CC),
                    onTap: () => _simulateSocialShare(context, 'Telegram'),
                  ),
                  _buildShareOption(
                    context,
                    icon: Icons.camera_alt_outlined,
                    label: 'Instagram',
                    color: const Color(0xFFE1306C),
                    onTap: () => _simulateSocialShare(context, 'Instagram'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Send to Friends',
              style: GoogleFonts.poppins(color: context.battlyOnSurface,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.battlyCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.battlyBorder),
              ),
              child: Text(
                'Friend sharing will appear here after real friends are loaded from the backend.',
                style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 11),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildShareOption(
  BuildContext context, {
  required IconData icon,
  required String label,
  required Color color,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.only(right: 20.0),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 10, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    ),
  );
}

void _simulateSocialShare(BuildContext context, String platform) {
  Navigator.pop(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: const Color(0xFFFF6B00),
      content: Row(
        children: [
          const Icon(Icons.share_outlined, color: Colors.white),
          const SizedBox(width: 8),
          Text('Opening $platform...', style: GoogleFonts.poppins(color: context.battlyOnSurface)),
        ],
      ),
    ),
  );
}

