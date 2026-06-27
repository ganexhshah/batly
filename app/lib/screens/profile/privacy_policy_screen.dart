import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/battly_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
          'Privacy Policy',
          style: GoogleFonts.poppins(color: context.battlyOnSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last Updated: June 21, 2026',
              style: GoogleFonts.poppins(
                color: const Color(0xFFFF6B00),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'At Battly, we respect your privacy and are committed to protecting your personal data. This Privacy Policy describes how we collect, use, share, and protect your personal information when you use our mobile application and related gaming services.',
              style: GoogleFonts.poppins(
                color: context.battlyMuted,
                fontSize: 12.5,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              title: '1. Information We Collect',
              body: 'We collect several types of information from and about our users, including:\n• Account Registration Details: Email address, username (IGN), Game UID, avatar URL, and profile names when registering or signing in via Google.\n• Transaction Information: Record of deposits, withdrawals, and wallet transactions (amount, timestamp, reference code, status).\n• Device and Usage Data: IP address, operating system, and system performance logs to verify device identity and prevent multi-account cheating.\n• Matchmaking details: Your match results, tournament logs, rankings, and team affiliations.',
            ),
            _buildSection(
              context,
              title: '2. How We Use Your Information',
              body: 'We use the collected information for purposes such as:\n• Running and coordinating tournaments, matchmaking lobbies, and leaderboards.\n• Processing transactions, verified payouts, and secure deposits through external payment gateways.\n• Detecting and preventing cheating, exploit abuses, multi-accounting, and fraudulent activity.\n• Sending you in-app notifications and alerts regarding your matches and wallet transactions.\n• Improving application performance and debugging technical errors.',
            ),
            _buildSection(
              context,
              title: '3. Data Sharing & Third-Party Integration',
              body: 'We do not sell your personal data. We share information only in specific circumstances:\n• With Payment Gateways: We transmit payment details (e.g. transaction ID, amount) to verified services (eSewa, Khalti) to confirm and complete transactions.\n• For Compliance: When required by local authorities to comply with taxation laws, identity regulations, or anti-money laundering policies.\n• With Firebase: For authentication services (Google Sign-In) and push notifications.',
            ),
            _buildSection(
              context,
              title: '4. Data Security & Retention',
              body: 'We implement industry-standard encryption protocols (such as SSL/TLS) to secure data in transit. Your authentication tokens are stored locally on your device in secure keychains or shared preferences. We retain your data as long as your account remains active. If you delete your account, your profile data, transaction logs, and match records are permanently removed from our active database systems.',
            ),
            _buildSection(
              context,
              title: '5. Your Rights & Account Deletion',
              body: 'You have the right to access the personal information we hold, update incorrect profiles, or request account deletion. You can edit your IGN, Game UID, and name through the Account Settings screen. You can permanently delete your account directly inside the Profile screen, which deletes all related data immediately and securely.',
            ),
            _buildSection(
              context,
              title: '6. Changes to this Policy',
              body: 'We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy page and updating the "Last Updated" date at the top of the screen.',
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'We keep your data secure so you can focus on the game.',
                style: GoogleFonts.poppins(color: context.battlyOnSurface.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(color: context.battlyOnSurface,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: GoogleFonts.poppins(
              color: context.battlyMuted,
              fontSize: 12,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
