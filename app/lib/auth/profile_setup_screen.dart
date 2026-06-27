import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/home_screen.dart';
import '../services/auth_service.dart';
import '../core/theme/battly_theme.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ignController = TextEditingController();
  final _uidController = TextEditingController();

  String? _selectedAvatarUrl;
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  final List<String> _avatarPresets = [
    'https://img.icons8.com/color/96/pubg.png',
    'https://img.icons8.com/color/96/ninja.png',
    'https://img.icons8.com/color/96/ghost.png',
    'https://img.icons8.com/color/96/skeleton.png',
    'https://img.icons8.com/color/96/viking.png',
    'https://img.icons8.com/color/96/astronaut.png',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _ignController.dispose();
    _uidController.dispose();
    super.dispose();
  }

  void _selectAvatarDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.battly.elevatedSurface,
          title: Text(
            'Choose Gaming Avatar',
            style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _avatarPresets.length,
              itemBuilder: (context, index) {
                final url = _avatarPresets[index];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedAvatarUrl = url;
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.battlyCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _selectedAvatarUrl == url ? const Color(0xFFFF6B00) : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Image.network(url),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitProfile() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final ign = _ignController.text.trim().isNotEmpty ? _ignController.text.trim() : 'BATTLY_PRO';
    final uid = _uidController.text.trim().isNotEmpty ? _uidController.text.trim() : '982173';

    // Validate
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter your name');
      return;
    }
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email');
      return;
    }
    if (password.length < 8) {
      setState(() => _errorMessage = 'Password must be at least 8 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await AuthService.register(
      name: name,
      email: email,
      password: password,
      passwordConfirmation: password,
      ign: ign,
      gameUid: uid,
      avatarUrl: _selectedAvatarUrl,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      final user = result['user'] as Map<String, dynamic>;
      // Navigate to HomeScreen and clear routing history
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(
            customName: user['ign'] as String? ?? user['name'] as String?,
            customIGN: 'UID: ${user['game_uid'] ?? uid}',
            customAvatarUrl: user['avatar_url'] as String? ?? _selectedAvatarUrl,
          ),
        ),
        (route) => false,
      );
    } else {
      setState(() {
        // Show specific validation errors if available
        final errors = result['errors'];
        if (errors is Map) {
          final messages = <String>[];
          errors.forEach((key, value) {
            if (value is List) {
              messages.addAll(value.map((e) => e.toString()));
            }
          });
          _errorMessage = messages.isNotEmpty ? messages.join('\n') : (result['error'] as String? ?? 'Registration failed');
        } else {
          _errorMessage = result['error'] as String? ?? 'Registration failed';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/background/bg1.png',
              fit: BoxFit.cover,
            ),
          ),
          // Dark Overlay
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.8),
            ),
          ),
          // Content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Bar (Back button and Logo)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Image.asset(
                          'assets/logo/logo.png',
                          height: 50,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.videogame_asset, color: Color(0xFFFF6B00), size: 36),
                        ),
                        const SizedBox(width: 48), // Spacer to offset the back button
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Header Text
                    Center(
                      child: Column(
                        children: [
                          Text(
                            "Create Your Account",
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Set up your profile to get started",
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              color: context.battlyMuted,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Error message
                    if (_errorMessage != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
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

                    // Profile picture selector
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _selectAvatarDialog,
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: context.battly.elevatedSurface,
                                    border: Border.all(color: const Color(0xFFFF6B00), width: 1.5),
                                  ),
                                  padding: _selectedAvatarUrl == null
                                      ? const EdgeInsets.all(22.0)
                                      : const EdgeInsets.all(10.0),
                                  child: _selectedAvatarUrl == null
                                      ? const Icon(
                                          Icons.camera_alt_outlined,
                                          color: Color(0xFFA0A0A0),
                                          size: 36,
                                        )
                                      : Image.network(_selectedAvatarUrl!),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFFF6B00),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                )
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Choose Avatar',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: context.battlyMuted,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Account Fields
                    _buildInputFieldLabel('Name'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _nameController,
                      hintText: 'Enter your full name',
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 16),

                    _buildInputFieldLabel('Email'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _emailController,
                      hintText: 'Enter your email address',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),

                    _buildInputFieldLabel('Password'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.battlyBorder),
                      ),
                      child: TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.w400),
                        decoration: InputDecoration(
                          hintText: 'Create a password (min 8 chars)',
                          hintStyle: GoogleFonts.poppins(color: context.battlyMuted, fontWeight: FontWeight.w400),
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFFFF6B00)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: context.battlyMuted,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() => _obscurePassword = !_obscurePassword);
                            },
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Gaming Profile Fields
                    Row(
                      children: [
                        const Icon(Icons.sports_esports_outlined, color: Color(0xFFFF6B00), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Gaming Profile',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFFFD700),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    _buildInputFieldLabel('IGN (In Game Name)'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _ignController,
                      hintText: 'Enter your in-game name',
                      icon: Icons.sports_esports_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildInputFieldLabel('UID'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _uidController,
                      hintText: 'Enter your game UID',
                      icon: Icons.fingerprint_rounded,
                    ),
                    const SizedBox(height: 30),

                    // Continue Button
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B00), Color(0xFFFF8C00)],
                        ),
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
                        onPressed: _isLoading ? null : _submitProfile,
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
                                'Create Account',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        'You can change this later in settings',
                        style: GoogleFonts.poppins(
                          color: context.battlyMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(height: bottomInset),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputFieldLabel(String labelText) {
    return Text(
      labelText,
      style: GoogleFonts.poppins(color: context.battlyOnSurface,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
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
        style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.w400),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.poppins(color: context.battlyMuted, fontWeight: FontWeight.w400),
          prefixIcon: Icon(icon, color: const Color(0xFFFF6B00)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
