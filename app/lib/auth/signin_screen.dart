import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/responsive/responsive.dart';
import '../services/auth_service.dart';
import '../screens/home_screen.dart';
import '../screens/profile/terms_of_service_screen.dart';
import '../screens/profile/privacy_policy_screen.dart';
import 'game_setup_screen.dart';
import '../core/theme/battly_theme.dart';
import '../widgets/battly_asset_image.dart';

class SigninScreen extends StatefulWidget {
  const SigninScreen({super.key});

  @override
  State<SigninScreen> createState() => _SigninScreenState();
}

class _SigninScreenState extends State<SigninScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await AuthService.loginWithGoogle();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Login Success',
            style: GoogleFonts.poppins(color: context.battlyOnSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: const Color(0xFF4CAF50), // Green for success
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      final user = result['user'] as Map<String, dynamic>;
      final hasGameProfile = user['game_uid'] != null &&
          user['game_uid'].toString().trim().isNotEmpty &&
          user['ign'] != null &&
          user['ign'].toString().trim().isNotEmpty;

      if (!hasGameProfile) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => GameSetupScreen(user: user),
          ),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              customName: user['ign'] as String? ?? user['name'] as String?,
              customIGN: 'UID: ${user['game_uid']}',
              customAvatarUrl: user['avatar_url'] as String?,
            ),
          ),
          (route) => false,
        );
      }
    } else {
      setState(() {
        _errorMessage = result['error'] as String? ?? 'Google Sign-In failed';
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          const Positioned.fill(
            child: BattlyAssetImage(
              assetPath: 'assets/background/bg1.png',
              fit: BoxFit.cover,
              fallbackIcon: Icons.landscape_outlined,
            ),
          ),
          // Gradient Dark Overlay to ensure text readability
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.black.withValues(alpha: 0.6),
                    Colors.black.withValues(alpha: 0.9),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: ResponsiveContent(
                        maxWidth: AppBreakpoints.formMaxWidth,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 30.0),
                        child: Column(
                          children: [
                            const SizedBox(height: 60),
                            // Battly Logo
                            Center(
                              child: BattlyAssetImage(
                                assetPath: 'assets/logo/logo.png',
                                height: 140,
                                fit: BoxFit.contain,
                                fallbackIcon: Icons.videogame_asset,
                                fallbackColor: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 30),
                            // Welcome Text
                            Text(
                              'Welcome Back!',
                              style: GoogleFonts.poppins(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Login to continue and join the battle.',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.normal,
                                color: context.battlyMuted,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 35),

                            // Error Message
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

                            const SizedBox(height: 20),

                            // Continue with Google Button
                            InkWell(
                              onTap: _isLoading ? null : _handleGoogleSignIn,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: context.battlyBorder,
                                    width: 1.0,
                                  ),
                                ),
                                child: _isLoading
                                    ? const Center(
                                        child: SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4285F4)),
                                          ),
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Image.network(
                                            'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3c/Google_Favicon_2025.svg/120px-Google_Favicon_2025.svg.png',
                                            width: 24,
                                            height: 24,
                                            errorBuilder: (context, error, stackTrace) {
                                              return const Icon(Icons.g_mobiledata, color: Color(0xFF4285F4), size: 28);
                                            },
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Continue with Google',
                                            style: GoogleFonts.poppins(
                                              color: const Color(0xFF202124),
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Spacer to push the terms text to the very bottom
                            const Spacer(),
                            const SizedBox(height: 24),

                            // Terms and conditions link
                            Padding(
                              padding: const EdgeInsets.only(bottom: 20.0),
                              child: Text.rich(
                                TextSpan(
                                  text: 'By continuing, you agree to our\n',
                                  style: GoogleFonts.poppins(
                                    color: context.battlyMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.normal,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'Terms of Service',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFFFF6B00),
                                        fontWeight: FontWeight.bold,
                                      ),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => const TermsOfServiceScreen(),
                                            ),
                                          );
                                        },
                                    ),
                                    const TextSpan(text: ' and '),
                                    TextSpan(
                                      text: 'Privacy Policy',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFFFF6B00),
                                        fontWeight: FontWeight.bold,
                                      ),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => const PrivacyPolicyScreen(),
                                            ),
                                          );
                                        },
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }
            ),
          ),
        ],
      ),
    );
  }
}
