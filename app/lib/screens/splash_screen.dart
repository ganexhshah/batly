import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth/signin_screen.dart';
import '../core/theme/battly_theme.dart';
import '../services/auth_service.dart';
import '../services/local_cache.dart';
import '../widgets/battly_asset_image.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _progress = 0.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startLoading();
  }

  void _startLoading() {
    const totalSteps = 40;
    const duration = Duration(milliseconds: 600);
    final stepDuration = duration ~/ totalSteps;

    _timer = Timer.periodic(stepDuration, (timer) {
      if (!mounted) return;
      setState(() {
        _progress += 1 / totalSteps;
        if (_progress >= 1.0) {
          _progress = 1.0;
        }
      });
    });

    Future.wait([
      Future.delayed(const Duration(milliseconds: 600)),
      Future.wait([
        AuthService.getToken(),
        LocalCache.warm(),
      ]),
    ]).then((_) {
      _timer?.cancel();
      if (!mounted) return;
      setState(() => _progress = 1.0);
      _navigateToSignin();
    });
  }

  void _navigateToSignin() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const SigninScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: BattlyAssetImage(
              assetPath: 'assets/background/bg1.png',
              fit: BoxFit.cover,
              fallbackIcon: Icons.landscape_outlined,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.75),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),
                Center(
                  child: BattlyAssetImage(
                    assetPath: 'assets/logo/logo.png',
                    height: 200,
                    fit: BoxFit.contain,
                    fallbackIcon: Icons.videogame_asset,
                    fallbackColor: primary,
                  ),
                ),
                const Spacer(flex: 2),
                Text(
                  'LOADING...',
                  style: GoogleFonts.poppins(
                    color: primary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 50.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 6,
                      width: double.infinity,
                      color: context.battly.elevatedSurface,
                      child: Stack(
                        children: [
                          FractionallySizedBox(
                            widthFactor: _progress,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [primary, const Color(0xFFFFD700)],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                Padding(
                  padding: const EdgeInsets.only(bottom: 30.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildBottomCategoryItem('TOURNAMENTS', Icons.emoji_events_outlined, primary),
                      _buildBottomCategoryItem('SCRIMS', Icons.gps_fixed_rounded, primary),
                      _buildBottomCategoryItem('COMMUNITY', Icons.people_outline_rounded, primary),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCategoryItem(String label, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: context.battlyMuted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
