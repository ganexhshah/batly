import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart' show AuthorizationStatus, FirebaseMessaging;
import '../core/firebase_guard.dart';
import '../services/api_service.dart';
import '../core/theme/battly_theme.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _pushNotifications = true;
  bool _matchReminders = true;
  bool _walletCredits = true;
  bool _walletWithdrawals = true;
  bool _chatAlerts = true;
  bool _supportAlerts = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    // Probe actual Firebase AuthorizationStatus from system settings
    final settings = await FirebaseGuard.messagingSettings();
    final bool systemAuthorized = settings != null &&
        (settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional);

    setState(() {
      // Switch remains on only if cached preference is true and system permission is authorized
      _pushNotifications = (prefs.getBool('settings_push_notifications') ?? true) && systemAuthorized;
      _matchReminders = prefs.getBool('settings_match_reminders') ?? true;
      _walletCredits = prefs.getBool('settings_wallet_credits') ?? true;
      _walletWithdrawals = prefs.getBool('settings_wallet_withdrawals') ?? true;
      _chatAlerts = prefs.getBool('settings_chat_alerts') ?? true;
      _supportAlerts = prefs.getBool('settings_support_alerts') ?? true;
    });
  }

  Future<void> _togglePushNotifications(bool val) async {
    if (val) {
      final settings = await FirebaseGuard.requestMessagingPermission();

      if (settings == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFE53935),
            content: Text(
              'Push notifications are not available on this platform.',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
            ),
          ),
        );
        return;
      }

      final bool authorized = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (!authorized) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFE53935),
              content: Text(
                'Permission Denied. Please enable notifications in system settings.',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
              ),
            ),
          );
        }
        setState(() => _pushNotifications = false);
        _saveSetting('settings_push_notifications', false);
        return;
      }
    }

    setState(() => _pushNotifications = val);
    _saveSetting('settings_push_notifications', val);

    if (val && FirebaseGuard.messagingAvailable) {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await ApiService.registerFcmToken(token);
        }
      } catch (_) {}
    }
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
          'Notification Settings',
          style: GoogleFonts.poppins(
            color: context.battlyOnSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            _buildSectionHeader('MASTER CONTROL'),
            _buildSettingTile(
              title: 'Master Push Notifications',
              subtitle: 'Allow all in-app and push notification cards',
              icon: Icons.notifications_active_rounded,
              value: _pushNotifications,
              onChanged: _togglePushNotifications,
            ),
            const SizedBox(height: 24),

            // Only show detailed config if master control is enabled
            AnimatedOpacity(
              opacity: _pushNotifications ? 1.0 : 0.5,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_pushNotifications,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('TOURNAMENTS & MATCHES'),
                    _buildSettingTile(
                      title: 'Match Reminders',
                      subtitle: 'Get alerts before your match starts',
                      icon: Icons.timer_outlined,
                      value: _matchReminders,
                      onChanged: (val) {
                        setState(() => _matchReminders = val);
                        _saveSetting('settings_match_reminders', val);
                      },
                    ),
                    const SizedBox(height: 24),

                    _buildSectionHeader('WALLET ACTIVITIES'),
                    _buildSettingTile(
                      title: 'Wallet Deposits & Credits',
                      subtitle: 'Alerts when funds are added to your wallet',
                      icon: Icons.arrow_downward_rounded,
                      value: _walletCredits,
                      onChanged: (val) {
                        setState(() => _walletCredits = val);
                        _saveSetting('settings_wallet_credits', val);
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildSettingTile(
                      title: 'Withdrawals & Charges',
                      subtitle: 'Alerts on payout approvals and debits',
                      icon: Icons.arrow_upward_rounded,
                      value: _walletWithdrawals,
                      onChanged: (val) {
                        setState(() => _walletWithdrawals = val);
                        _saveSetting('settings_wallet_withdrawals', val);
                      },
                    ),
                    const SizedBox(height: 24),

                    _buildSectionHeader('SOCIAL & SUPPORT'),
                    _buildSettingTile(
                      title: 'Chat Alerts',
                      subtitle: 'Receive notifications for new messages',
                      icon: Icons.chat_bubble_outline_rounded,
                      value: _chatAlerts,
                      onChanged: (val) {
                        setState(() => _chatAlerts = val);
                        _saveSetting('settings_chat_alerts', val);
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildSettingTile(
                      title: 'Support Replies',
                      subtitle: 'Notifications when tickets are resolved',
                      icon: Icons.support_agent_rounded,
                      value: _supportAlerts,
                      onChanged: (val) {
                        setState(() => _supportAlerts = val);
                        _saveSetting('settings_support_alerts', val);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          color: context.battlyMuted,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: context.battlyCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.battlyBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E222A),
              borderRadius: BorderRadius.circular(8),
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
                  style: GoogleFonts.poppins(
                    color: context.battlyOnSurface,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    color: context.battlyMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: const Color(0xFFFF6B00),
            activeTrackColor: const Color(0xFFFF6B00).withValues(alpha: 0.3),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
