import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/theme_service.dart';
import '../../core/theme/battly_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _emailUpdates = false;
  bool _biometrics = true;
  bool _secureTransfers = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _pushNotifications = prefs.getBool('settings_push_notifications') ?? _pushNotifications;
      _emailUpdates = prefs.getBool('settings_email_updates') ?? _emailUpdates;
      _biometrics = prefs.getBool('settings_biometrics') ?? _biometrics;
      _secureTransfers = prefs.getBool('settings_secure_transfers') ?? _secureTransfers;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

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
          'Settings',
          style: GoogleFonts.poppins(color: context.battlyOnSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Notifications
            _buildSectionHeader('NOTIFICATIONS'),
            _buildSettingTile(
              title: 'Push Notifications',
              subtitle: 'Alerts for matches, tournaments & coins',
              icon: Icons.notifications_active_rounded,
              value: _pushNotifications,
              onChanged: (val) {
                setState(() => _pushNotifications = val);
                _saveSetting('settings_push_notifications', val);
              },
            ),
            const SizedBox(height: 8),
            _buildSettingTile(
              title: 'Email Updates',
              subtitle: 'Weekly match stats and newsletters',
              icon: Icons.email_rounded,
              value: _emailUpdates,
              onChanged: (val) {
                setState(() => _emailUpdates = val);
                _saveSetting('settings_email_updates', val);
              },
            ),
            const SizedBox(height: 24),

            // Section 2: Appearance & Preferences
            _buildSectionHeader('PREFERENCES'),
            ListenableBuilder(
              listenable: ThemeService.instance,
              builder: (context, _) {
                final isDark = ThemeService.instance.isDarkMode;
                return _buildSettingTile(
                  title: 'Dark Mode',
                  subtitle: isDark ? 'Neon dark theme is on' : 'Light theme is on',
                  icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  value: isDark,
                  onChanged: (val) => ThemeService.instance.setDarkMode(val),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildActionTile(
              title: 'App Language',
              subtitle: 'Selected language: English',
              icon: Icons.language_rounded,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: context.battlyCard,
                    content: Text('English is selected by default', style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 13)),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Section 3: Security & Privacy
            _buildSectionHeader('SECURITY & PRIVACY'),
            _buildSettingTile(
              title: 'Biometric Authentication',
              subtitle: 'Unlock wallet using FaceID or Fingerprint',
              icon: Icons.fingerprint_rounded,
              value: _biometrics,
              onChanged: (val) {
                setState(() => _biometrics = val);
                _saveSetting('settings_biometrics', val);
              },
            ),
            const SizedBox(height: 8),
            _buildSettingTile(
              title: 'Secure Transfers',
              subtitle: 'Ask for verification pin on P2P transfers',
              icon: Icons.security_rounded,
              value: _secureTransfers,
              onChanged: (val) {
                setState(() => _secureTransfers = val);
                _saveSetting('settings_secure_transfers', val);
              },
            ),
            const SizedBox(height: 40),

            // App details at bottom
            Center(
              child: Column(
                children: [
                  Text(
                    'BATTLY GAMING ENGINE',
                    style: GoogleFonts.poppins(
                      color: const Color(0x60A0A0A0),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Version 1.4.2 • Build 8271',
                    style: GoogleFonts.poppins(
                      color: const Color(0x40A0A0A0),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 10.0),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          color: context.battlyMuted,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.battlyCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.battlyBorder, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B00).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFFFF6B00), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 9.5),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFFFF6B00),
            activeTrackColor: const Color(0xFFFF6B00).withValues(alpha: 0.2),
            inactiveThumbColor: Colors.grey[400],
            inactiveTrackColor: context.battlyBorder,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.battlyCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.battlyBorder, width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B00).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFFFF6B00), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 9.5),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 14),
          ],
        ),
      ),
    );
  }
}
