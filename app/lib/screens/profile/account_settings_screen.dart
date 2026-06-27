import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../core/theme/battly_theme.dart';

class AccountSettingsScreen extends StatefulWidget {
  final String? customName;
  final String? customIGN;
  final String? customAvatarUrl;

  const AccountSettingsScreen({
    super.key,
    this.customName,
    this.customIGN,
    this.customAvatarUrl,
  });

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _ignController;
  late final TextEditingController _gameUidController;
  late final TextEditingController _emailController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customName ?? '');
    _ignController = TextEditingController(text: widget.customIGN ?? '');
    _gameUidController = TextEditingController();
    _emailController = TextEditingController();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ignController.dispose();
    _gameUidController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final cached = await AuthService.getCachedUser();
    if (cached != null) {
      setState(() {
        _nameController.text = cached['name'] ?? widget.customName ?? '';
        _ignController.text = cached['ign'] ?? widget.customIGN ?? '';
        _gameUidController.text = cached['game_uid'] ?? '';
        _emailController.text = cached['email'] ?? '';
      });
    }
    final fresh = await AuthService.getUser();
    if (fresh != null && mounted) {
      setState(() {
        _nameController.text = fresh['name'] ?? '';
        _ignController.text = fresh['ign'] ?? '';
        _gameUidController.text = fresh['game_uid'] ?? '';
        _emailController.text = fresh['email'] ?? '';
        _isLoading = false;
      });
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleSave() async {
    final name = _nameController.text.trim();
    final ign = _ignController.text.trim();
    final gameUid = _gameUidController.text.trim();

    if (name.isEmpty) {
      _showError('Name cannot be empty');
      return;
    }
    if (ign.isEmpty) {
      _showError('In-Game Name (IGN) cannot be empty');
      return;
    }
    if (gameUid.isEmpty) {
      _showError('Game UID cannot be empty');
      return;
    }

    // Show dynamic loader dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.battlyCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.battlyBorder, width: 1.5),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B00)),
                ),
                SizedBox(height: 16),
                Text(
                  'Updating profile details...',
                  style: TextStyle(color: Colors.white70, fontSize: 13, decoration: TextDecoration.none),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      final res = await AuthService.updateProfile(
        name: name,
        ign: ign,
        gameUid: gameUid,
        avatarUrl: widget.customAvatarUrl,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loader

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF4CAF50),
            content: Text(
              'Profile updated successfully!',
              style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        // Return back
        Navigator.pop(context, true);
      } else {
        _showError(res['error'] ?? 'Profile update failed');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loader
      _showError('Error updating profile: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFE53935),
        content: Text(message, style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 13, fontWeight: FontWeight.w500)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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
          'Account Settings',
          style: GoogleFonts.poppins(color: context.battlyOnSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B00)),
              ),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Styled header details card
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFFF6B00), width: 2),
                          ),
                          child: ClipOval(
                            child: widget.customAvatarUrl != null && widget.customAvatarUrl!.isNotEmpty
                                ? Image.network(
                                    widget.customAvatarUrl!,
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
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Color(0xFFFF6B00),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Form Title
                  Text(
                    'PERSONAL DATA',
                    style: GoogleFonts.poppins(
                      color: context.battlyMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Display Name
                  _buildInputField(
                    controller: _nameController,
                    label: 'DISPLAY NAME',
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 16),

                  // In-Game Name (IGN)
                  _buildInputField(
                    controller: _ignController,
                    label: 'IN-GAME NAME (IGN)',
                    icon: Icons.sports_esports_outlined,
                  ),
                  const SizedBox(height: 16),

                  // Game UID
                  _buildInputField(
                    controller: _gameUidController,
                    label: 'GAME UID (FOR MATCH VERIFICATION)',
                    icon: Icons.tag_rounded,
                  ),
                  const SizedBox(height: 16),

                  // Email Address
                  _buildInputField(
                    controller: _emailController,
                    label: 'EMAIL ADDRESS (READ-ONLY)',
                    icon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    readOnly: true,
                  ),
                  const SizedBox(height: 40),

                  // Save CTA Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B00),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Save Changes',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.battlyCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.battlyBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: context.battlyMuted,
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            readOnly: readOnly,
            style: GoogleFonts.poppins(
              color: readOnly ? const Color(0x80FFFFFF) : Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
              prefixIcon: Icon(icon, color: context.battlyMuted, size: 18),
              prefixIconConstraints: const BoxConstraints(minWidth: 30, minHeight: 0),
            ),
          ),
        ],
      ),
    );
  }
}
