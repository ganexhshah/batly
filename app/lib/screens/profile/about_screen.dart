import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'terms_of_service_screen.dart';
import 'privacy_policy_screen.dart';
import '../../core/theme/battly_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.battlyScaffold,
      appBar: AppBar(
        backgroundColor: context.battlyScaffold,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 48,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        titleSpacing: 12,
        title: Text(
          'About Us',
          style: GoogleFonts.poppins(color: context.battlyOnSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            // Neon logo card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.battlyCard,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFF6B00), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B00).withValues(alpha: 0.15),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Image.asset(
                'assets/logo/logo.png',
                height: 52,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.sports_esports_rounded,
                  color: Color(0xFFFF6B00),
                  size: 52,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // App Name & Version
            Text(
              'BATTLY',
              style: GoogleFonts.poppins(color: context.battlyOnSurface,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Version 1.4.2 (Stable)',
              style: GoogleFonts.poppins(
                color: const Color(0xFFFF6B00),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 28),

            // Description Paragraph
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.battlyCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.battlyBorder),
              ),
              child: Text(
                'Battly is a state-of-the-art esports tournament and scrim matchmaking application. We allow players from all over South Asia to register, matchmake, compete, and climb leaderboard tournaments in their favorite mobile shooter and battle royale games while securing transaction earnings and prizes.',
                style: GoogleFonts.poppins(
                  color: context.battlyMuted,
                  fontSize: 11.5,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 28),

            // Document Links List
            _buildAboutActionTile(
              context,
              label: 'Terms of Service',
              icon: Icons.description_outlined,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TermsOfServiceScreen()),
              ),
            ),
            const SizedBox(height: 8),
            _buildAboutActionTile(
              context,
              label: 'Privacy Policy',
              icon: Icons.privacy_tip_outlined,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
              ),
            ),
            const SizedBox(height: 8),
            _buildAboutActionTile(
              context,
              label: 'Open Source Licenses',
              icon: Icons.code_rounded,
              onTap: () => _showModal(context, 'Open Source Licenses', 'Lists of open-source packages and flutter packages licensed under MIT...'),
            ),
            const SizedBox(height: 36),

            // Connect with us
            Text(
              'CONNECT WITH US',
              style: GoogleFonts.poppins(
                color: context.battlyMuted,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 16),

            // Social Buttons Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSocialIcon(context, Icons.discord, 'Discord'),
                const SizedBox(width: 16),
                _buildSocialIcon(context, Icons.facebook_rounded, 'Facebook'),
                const SizedBox(width: 16),
                _buildSocialIcon(context, Icons.alternate_email_rounded, 'Twitter'),
                const SizedBox(width: 16),
                _buildSocialIcon(context, Icons.video_camera_back_rounded, 'YouTube'),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutActionTile(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.battlyCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.battlyBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFFF6B00), size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialIcon(BuildContext context, IconData icon, String platform) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.battlyCard,
        shape: BoxShape.circle,
        border: Border.all(color: context.battlyBorder),
      ),
      child: Icon(icon, color: Colors.white70, size: 20),
    );
  }

  void _showModal(BuildContext context, String title, String content) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Color(0xFF0F1115),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: Border(top: BorderSide(color: Color(0xFF2B2F3A), width: 1.5)),
          ),
          padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 20),
              Text(
                title,
                style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                content,
                style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B00),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Close', style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
