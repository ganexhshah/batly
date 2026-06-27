import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/battly_theme.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

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
          'Terms of Service',
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
              'Welcome to Battly. Please read these Terms of Service ("Terms") carefully before using the Battly mobile application and platform services. By creating an account or participating in any tournament, you agree to be bound by these Terms.',
              style: GoogleFonts.poppins(
                color: context.battlyMuted,
                fontSize: 12.5,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              title: '1. User Eligibility & Accounts',
              body: 'To use Battly, you must register for an account using a valid email address or authenticated Google login. You are responsible for keeping your account details, passwords, and security tokens confidential. Only one account per player is allowed. Multi-accounting, account sharing, or using automated scripts to register is strictly prohibited and will result in permanent suspension.',
            ),
            _buildSection(
              context,
              title: '2. Scrims & Tournament Rules',
              body: 'Battly hosts competitive tournaments and matchmaking scrims. All participants must strictly adhere to the guidelines set for individual games. Cheating, using hacks, exploit exploitation, emulators (unless explicitly permitted), colluding with other teams, or showing unsportsmanlike behavior will lead to immediate disqualification and forfeiture of any accrued rewards.',
            ),
            _buildSection(
              context,
              title: '3. Wallet Deposits & Withdrawals',
              body: 'The Battly wallet is used to deposit entry fees and receive tournament winnings. All deposit payments initiated through integration gateways (eSewa, Khalti, etc.) are subject to verification. Withdrawal requests are processed within 24 hours of approval. You are responsible for ensuring that the recipient information (e.g. mobile wallet number or bank transfer details) is input correctly. Fees and taxation might apply to transactions depending on regional laws.',
            ),
            _buildSection(
              context,
              title: '4. Code of Conduct',
              body: 'Players must maintain a respectful and welcoming environment. In-app communication, usernames, IGNs, and avatars must not contain offensive, derogatory, harassing, or sexually explicit content. Harassment of staff, moderators, or other players will result in a temporary ban or account deletion.',
            ),
            _buildSection(
              context,
              title: '5. Account Revocation & Deletion',
              body: 'We reserve the right to suspend or permanently revoke your account access at any time for violation of these Terms or suspected fraudulent activities. You may delete your account permanently at any time through the Profile screen after withdrawing any remaining wallet balance. Account deletion removes your profile, match history, and stats from our active systems.',
            ),
            _buildSection(
              context,
              title: '6. Limitation of Liability',
              body: 'Battly is provided on an "as is" and "as available" basis. We are not liable for any transaction failures, gateway maintenance downtime, network latency during match results validation, or losses arising from user error (such as inputting the wrong transfer ID).',
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Thank you for playing fair and joining Battly!',
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
