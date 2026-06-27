import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'settings_screen.dart';
import 'account_settings_screen.dart';
import 'about_screen.dart';
import 'my_matches_screen.dart';
import 'support_screen.dart';
import '../../services/auth_service.dart';
import '../../services/wallet_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/skeleton_widgets.dart';
import '../../auth/signin_screen.dart';
import '../../core/theme/battly_theme.dart';

class ProfileScreen extends StatefulWidget {
  final String? customName;
  final String? customIGN;
  final String? customAvatarUrl;

  const ProfileScreen({
    super.key,
    this.customName,
    this.customIGN,
    this.customAvatarUrl,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _name;
  String? _ign;
  String? _avatarUrl;
  String? _gameUid;
  String? _email;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    final cached = await AuthService.getCachedUser();
    if (cached != null && mounted) {
      setState(() {
        _name = cached['name'];
        _ign = cached['ign'];
        _avatarUrl = cached['avatar_url'];
        _gameUid = cached['game_uid'];
        _email = cached['email'];
        _isLoading = false;
      });
    }
    final fresh = await AuthService.getUser();
    if (fresh != null && mounted) {
      setState(() {
        _name = fresh['name'];
        _ign = fresh['ign'];
        _avatarUrl = fresh['avatar_url'];
        _gameUid = fresh['game_uid'];
        _email = fresh['email'];
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _copyIdToClipboard(String profileId) {
    Clipboard.setData(ClipboardData(text: profileId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'ID $profileId copied to clipboard!',
          style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.w500, fontSize: 13),
        ),
        backgroundColor: const Color(0xFFFF6B00),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.battlyCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Color(0xFF2B2F3A), width: 1.5),
        ),
        title: Text(
          'Confirm Logout',
          style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          'Are you sure you want to log out of your account?',
          style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: context.battlyOnSurface.withValues(alpha: 0.7))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B00),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Logout', style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      await AuthService.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const SigninScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _handleDeleteAccount() async {
    double walletBalance = 0;
    try {
      final balanceData = await WalletService.getBalance();
      walletBalance = (balanceData['balance'] ?? 0).toDouble();
    } catch (_) {
      // Proceed — server enforces balance policy.
    }

    if (walletBalance > 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFE53935),
          content: Text(
            'Withdraw your wallet balance (NPR ${walletBalance.toStringAsFixed(0)}) before deleting your account.',
            style: GoogleFonts.poppins(color: context.battlyOnSurface),
          ),
        ),
      );
      return;
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.battlyCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Color(0xFFFF4E8E), width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4E8E), size: 22),
            const SizedBox(width: 8),
            Text(
              'Delete Account?',
              style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'This action is permanent and cannot be undone. All your match history and tournament records will be deleted. You must withdraw any wallet balance before deleting your account.',
          style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: context.battlyOnSurface.withValues(alpha: 0.7))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4E8E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Delete', style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      final result = await AuthService.deleteAccount();
      
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF4CAF50),
            content: Text('Account successfully deleted.', style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold)),
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const SigninScreen()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFE53935),
            content: Text(result['error'] ?? 'Failed to delete account.', style: GoogleFonts.poppins(color: context.battlyOnSurface)),
          ),
        );
      }
    }
  }

  void _showProfileInfoSheet(BuildContext context) {
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
          padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 32),
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
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Profile Details',
                  style: GoogleFonts.poppins(color: context.battlyOnSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Profile Image / Avatar
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFF6B00), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6B00).withValues(alpha: 0.2),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _avatarUrl != null && _avatarUrl!.isNotEmpty
                        ? Image.network(
                            _avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: const Color(0xFF1E222A),
                              child: const Icon(Icons.person, color: Colors.white54, size: 40),
                            ),
                          )
                        : Image.asset(
                            'assets/logo/profile_avatar.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: const Color(0xFF1E222A),
                              child: const Icon(Icons.person, color: Colors.white54, size: 40),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Details List
              _buildDetailRow(Icons.person_outline_rounded, 'Full Name', _name ?? 'N/A'),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.email_outlined, 'Email Address', _email ?? 'N/A'),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.sports_esports_outlined, 'Game Name (IGN)', _ign ?? 'N/A'),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.fingerprint_rounded, 'Game UID', _gameUid ?? 'N/A'),
              const SizedBox(height: 32),
              // Close button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B00),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Close',
                    style: GoogleFonts.poppins(color: context.battlyOnSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: context.battlyMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(color: context.battlyOnSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _name ?? widget.customName ?? 'BattlyWarrior';
    final profileId = _gameUid ?? '7865421';
    final avatarUrl = _avatarUrl ?? widget.customAvatarUrl;
    final screenBg = context.battly.profileBackground;
    final colorScheme = Theme.of(context).colorScheme;
    final mutedText = colorScheme.onSurface.withValues(alpha: 0.55);

    return Scaffold(
      backgroundColor: screenBg,
      appBar: AppBar(
        backgroundColor: screenBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        title: Text(
          'Profile',
          style: GoogleFonts.poppins(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: colorScheme.onSurface, size: 24),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.edit_note_rounded, color: colorScheme.onSurface, size: 26),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AccountSettingsScreen(
                    customName: name,
                    customIGN: _ign ?? widget.customIGN,
                    customAvatarUrl: avatarUrl,
                  ),
                ),
              ).then((_) {
                _loadUserProfile();
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserProfile,
        color: const Color(0xFFFF6B00),
        backgroundColor: context.battly.elevatedSurface,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.only(left: 12, right: 12, top: 10, bottom: 24),
          child: _isLoading
              ? const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: SkeletonProfileHeader(),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── User Profile Header ─────────────────────────────
                    GestureDetector(
                      onTap: () => _showProfileInfoSheet(context),
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          // Avatar with neon glow border
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFF6B00).withValues(alpha: 0.3),
                                      blurRadius: 16,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                  border: Border.all(
                                    color: const Color(0xFFFF6B00),
                                    width: 2.0,
                                  ),
                                ),
                                child: ClipOval(
                                  child: avatarUrl != null && avatarUrl.isNotEmpty
                                      ? Image.network(
                                          avatarUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            color: const Color(0xFF1E222A),
                                            child: const Icon(Icons.person, color: Colors.white54, size: 48),
                                          ),
                                        )
                                      : Image.asset(
                                          'assets/logo/profile_avatar.png',
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            color: const Color(0xFF1E222A),
                                            child: const Icon(Icons.person, color: Colors.white54, size: 48),
                                          ),
                                        ),
                                ),
                              ),
                              // Camera Edit Badge
                              GestureDetector(
                                onTap: () {
                                  // Change profile picture
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E222A),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFFF6B00), width: 1),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_outlined,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
  
                          // User ID, level details, name
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Name with verified badge
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        name,
                                        style: GoogleFonts.poppins(
                                          color: colorScheme.onSurface,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (_gameUid != null && _gameUid!.trim().isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Icon(
                                        Icons.verified,
                                        color: colorScheme.primary,
                                        size: 18,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
  
                                // ID with copy option
                                GestureDetector(
                                  onTap: () => _copyIdToClipboard(profileId),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'ID: $profileId',
                                        style: GoogleFonts.poppins(
                                          color: mutedText,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.content_copy_rounded,
                                        color: Color(0xFFA0A0A0),
                                        size: 13,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Menu Items ─────────────────────────────────────
                    Column(
                      children: [
                         _buildMenuItem(
                          icon: Icons.person_outline_rounded,
                          title: 'Profile Info',
                          subtitle: 'View profile details',
                          onTap: () => _showProfileInfoSheet(context),
                        ),
                        _buildDarkModeToggle(),
                        _buildMenuItem(
                          icon: Icons.settings_outlined,
                          title: 'Account Settings',
                          subtitle: 'Privacy, security and more',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AccountSettingsScreen(
                                  customName: name,
                                  customIGN: _ign ?? widget.customIGN,
                                  customAvatarUrl: avatarUrl,
                                ),
                              ),
                            ).then((_) => _loadUserProfile());
                          },
                        ),
                        _buildMenuItem(
                          icon: Icons.calendar_month_outlined,
                          title: 'My Matches',
                          subtitle: 'View your matches logs and stats',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const MyMatchesScreen()),
                            );
                          },
                        ),
                        _buildMenuItem(
                          icon: Icons.support_agent_rounded,
                          title: 'Help & Support',
                          subtitle: 'Contact support, collapsible FAQs',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SupportScreen()),
                            );
                          },
                        ),
                        _buildMenuItem(
                          icon: Icons.info_outline_rounded,
                          title: 'About Us',
                          subtitle: 'App details, socials and documents',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const AboutScreen()),
                            );
                          },
                        ),
                        _buildMenuItem(
                          icon: Icons.logout_rounded,
                          title: 'Logout',
                          subtitle: 'Log out of your session',
                          color: const Color(0xFFFF9800),
                          onTap: _handleLogout,
                        ),
                        _buildMenuItem(
                          icon: Icons.delete_forever_rounded,
                          title: 'Delete Account',
                          subtitle: 'Permanently delete your account data',
                          color: const Color(0xFFFF4E8E),
                          onTap: _handleDeleteAccount,
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildDarkModeToggle() {
    final colorScheme = Theme.of(context).colorScheme;
    final mutedText = colorScheme.onSurface.withValues(alpha: 0.55);

    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        final isDark = ThemeService.instance.isDarkMode;
        return Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 12.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B00).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: const Color(0xFFFF6B00),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dark Mode',
                        style: GoogleFonts.poppins(
                          color: colorScheme.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isDark ? 'Neon dark theme is on' : 'Light theme is on',
                        style: GoogleFonts.poppins(color: mutedText, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isDark,
                  onChanged: (value) => ThemeService.instance.setDarkMode(value),
                  activeThumbColor: const Color(0xFFFF6B00),
                  activeTrackColor: const Color(0xFFFF6B00).withValues(alpha: 0.2),
                  inactiveThumbColor: Colors.grey[400],
                  inactiveTrackColor: context.battlyBorder,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
  }) {
    final themeColor = color ?? const Color(0xFFFF6B00);
    final colorScheme = Theme.of(context).colorScheme;
    final mutedText = colorScheme.onSurface.withValues(alpha: 0.55);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 12.0),
          child: Row(
            children: [
              // Styled Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: themeColor, size: 20),
              ),
              const SizedBox(width: 14),
              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        color: colorScheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        color: mutedText,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              // Chevron
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFA0A0A0),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOM HEXAGON PAINTER
// ─────────────────────────────────────────────────────────────────────────────
class HexagonPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  HexagonPainter({required this.color, this.strokeWidth = 2.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final path = Path();
    final w = size.width;
    final h = size.height;
    path.moveTo(w * 0.5, 0);
    path.lineTo(w, h * 0.25);
    path.lineTo(w, h * 0.75);
    path.lineTo(w * 0.5, h);
    path.lineTo(0, h * 0.75);
    path.lineTo(0, h * 0.25);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
