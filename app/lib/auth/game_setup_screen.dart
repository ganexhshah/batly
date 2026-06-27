import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../screens/home_screen.dart';
import 'signin_screen.dart';
import '../core/theme/battly_theme.dart';

class GameSetupScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const GameSetupScreen({super.key, required this.user});

  @override
  State<GameSetupScreen> createState() => _GameSetupScreenState();
}

class _GameSetupScreenState extends State<GameSetupScreen> {
  final _ignController = TextEditingController();
  final _uidController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _ignController.dispose();
    _uidController.dispose();
    super.dispose();
  }

  // Retrieve text from clipboard and paste it into the controller
  Future<void> _pasteFromClipboard(TextEditingController controller, {bool isNumeric = false}) async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData != null && clipboardData.text != null) {
        String text = clipboardData.text!.trim();
        if (isNumeric) {
          // Remove non-digit characters
          text = text.replaceAll(RegExp(r'\D'), '');
        }
        setState(() {
          controller.text = text;
          // Move cursor to the end
          controller.selection = TextSelection.fromPosition(
            TextPosition(offset: text.length),
          );
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pasted from clipboard!',
              style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 13),
            ),
            backgroundColor: const Color(0xFF1F222B),
            duration: const Duration(seconds: 1),
          ),
        );
      } else {
        _showToast('Clipboard is empty');
      }
    } catch (e) {
      _showToast('Failed to paste from clipboard');
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 13)),
        backgroundColor: const Color(0xFFFF4E8E),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleSave() async {
    final ign = _ignController.text.trim();
    final uid = _uidController.text.trim();

    // Validation checks
    if (ign.isEmpty) {
      setState(() => _errorMessage = 'Please enter your In-Game Name (IGN)');
      return;
    }

    if (uid.isEmpty) {
      setState(() => _errorMessage = 'Please enter your Game UID');
      return;
    }

    // UID must be between 7 and 11 digits
    if (uid.length < 7 || uid.length > 11) {
      setState(() => _errorMessage = 'Game UID must be between 7 and 11 digits (current length: ${uid.length})');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await AuthService.updateProfile(
      ign: ign,
      gameUid: uid,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      final updatedUser = result['user'] as Map<String, dynamic>;
      
      // Navigate to HomeScreen and clear navigation history
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(
            customName: updatedUser['ign'] as String? ?? updatedUser['name'] as String?,
            customIGN: 'UID: ${updatedUser['game_uid']}',
            customAvatarUrl: updatedUser['avatar_url'] as String?,
          ),
        ),
        (route) => false,
      );
    } else {
      setState(() {
        _errorMessage = result['error'] as String? ?? 'Failed to update game profile';
      });
    }
  }

  Future<void> _handleLogout() async {
    setState(() {
      _isLoading = true;
    });
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const SigninScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      backgroundColor: context.battlyScaffold,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                    const SizedBox(height: 24),
                    // Header Logo and Logout Option
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Image.asset(
                          'assets/logo/logo.png',
                          height: 48,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.videogame_asset_rounded, color: Color(0xFFFF6B00), size: 36),
                        ),
                        TextButton.icon(
                          onPressed: _isLoading ? null : _handleLogout,
                          icon: const Icon(Icons.logout_rounded, color: Color(0xFFFF4E8E), size: 16),
                          label: Text(
                            'Logout',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFFFF4E8E),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Titles
                    Text(
                      'Complete Gaming Profile',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Connect your in-game identity to begin competing in Battly tournaments.',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: context.battlyMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Display user identity card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.battlyCard.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.battlyBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFFF6B00), width: 1.5),
                            ),
                            child: ClipOval(
                              child: widget.user['avatar_url'] != null
                                  ? Image.network(
                                      widget.user['avatar_url']!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => const Icon(
                                        Icons.person_rounded,
                                        color: Color(0xFFFF6B00),
                                        size: 28,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person_rounded,
                                      color: Color(0xFFFF6B00),
                                      size: 28,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.user['name'] ?? 'Google User',
                                  style: GoogleFonts.poppins(color: context.battlyOnSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.user['email'] ?? '',
                                  style: GoogleFonts.poppins(
                                    color: context.battlyMuted,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Error Message
                    if (_errorMessage != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4E8E).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFF4E8E).withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFFF4E8E),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // IGN Label and Input Field
                    _buildFieldLabel('IGN (In-Game Name)'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _ignController,
                      hintText: 'e.g., Shroud, Mortal, Faker',
                      icon: Icons.sports_esports_outlined,
                      keyboardType: TextInputType.text,
                    ),
                    const SizedBox(height: 20),

                    // UID Label and Input Field
                    _buildFieldLabel('Game UID'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _uidController,
                      hintText: 'Numeric UID (7-11 digits)',
                      icon: Icons.fingerprint_rounded,
                      keyboardType: TextInputType.number,
                      isNumeric: true,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Must be between 7 and 11 digits numbers.',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Save Button
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B00), Color(0xFFFF8C00)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B00).withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _isLoading ? null : _handleSave,
                        child: _isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                'Save & Continue',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(height: bottomInset),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(color: context.battlyOnSurface,
        fontWeight: FontWeight.bold,
        fontSize: 14,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required TextInputType keyboardType,
    bool isNumeric = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.battlyBorder),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: isNumeric ? [FilteringTextInputFormatter.digitsOnly] : null,
        style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.w400),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.poppins(color: context.battlyMuted, fontWeight: FontWeight.w400, fontSize: 13.5),
          prefixIcon: Icon(icon, color: const Color(0xFFFF6B00), size: 20),
          suffixIcon: IconButton(
            icon: const Icon(Icons.content_paste_rounded, color: Color(0xFFFF6B00), size: 20),
            onPressed: () => _pasteFromClipboard(controller, isNumeric: isNumeric),
            tooltip: 'Paste from clipboard',
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
