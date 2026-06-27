import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/responsive/responsive.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/esewa_web_return.dart';
import 'services/local_cache.dart';
import 'services/api_service.dart';
import 'services/theme_service.dart';
import 'firebase_options.dart';
import 'auth/game_setup_screen.dart';
import 'core/root_scaffold_messenger.dart';
import 'services/push_notification_service.dart';
import 'services/wallet_service.dart';
import 'core/cache_debug.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (DefaultFirebaseOptions.isConfigured) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } else if (kDebugMode) {
    debugPrint(
      'Firebase is not configured for this platform. '
      'Run: dart pub global activate flutterfire_cli && '
      'flutterfire configure --project=zone-e4bb4',
    );
  }
  // Warm disk cache after first frame so startup stays smooth.
  unawaited(LocalCache.warm());
  await ThemeService.instance.load();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _themeService = ThemeService.instance;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleEsewaReturn());
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  Future<void> _handleEsewaReturn() async {
    if (!kIsWeb) return;

    final status = takeEsewaReturnStatus();
    if (status == null) return;

    clearEsewaQueryParams();

    if (status == 'success') {
      final transactionId = takeEsewaReturnTransactionId();
      if (transactionId != null && transactionId.isNotEmpty) {
        try {
          final txn = await WalletService.waitForDepositCompletion(transactionId);
          if (txn['status'] == 'completed') {
            await AuthService.getUser();
            rootScaffoldMessengerKey.currentState?.showSnackBar(
              SnackBar(
                backgroundColor: const Color(0xFF4CAF50),
                content: Text(
                  'eSewa payment successful. Your wallet has been updated.',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
            );
            return;
          }
        } catch (e, st) {
          logCacheRefreshFailure('esewaReturnVerify', e, st);
        }
      }
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFE53935),
          content: Text(
            'Payment received but wallet verification failed. Check your transaction history.',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
        ),
      );
      return;
    }

    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFE53935),
        content: Text(
          'eSewa payment failed or was cancelled.',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final poppins = GoogleFonts.poppinsTextTheme();
    return MaterialApp(
      title: 'Battly',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      scrollBehavior: const AppScrollBehavior(),
      themeMode: _themeService.themeMode,
      theme: ThemeService.buildLightTheme(poppins),
      darkTheme: ThemeService.buildDarkTheme(
        GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      ),
      home: const AuthGate(),
    );
  }
}

/// Checks if the user is already logged in and routes accordingly.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;
  bool _isLoggedIn = false;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await AuthService.getToken();

    if (token == null) {
      if (!mounted) return;
      setState(() => _checking = false);
      return;
    }

    final user = await AuthService.getUser() ?? await AuthService.getCachedUser();
    if (!mounted) return;

    if (user == null) {
      await AuthService.logout();
      setState(() {
        _isLoggedIn = false;
        _userData = null;
        _checking = false;
      });
      return;
    }

    setState(() {
      _isLoggedIn = true;
      _userData = user;
      _checking = false;
    });
    unawaited(ApiService.warmHomeCache());
    unawaited(PushNotificationService.initialize());
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B00)),
          ),
        ),
      );
    }

    if (_isLoggedIn && _userData != null) {
      final hasGameProfile = _userData!['game_uid'] != null &&
          _userData!['game_uid'].toString().trim().isNotEmpty &&
          _userData!['ign'] != null &&
          _userData!['ign'].toString().trim().isNotEmpty;

      if (!hasGameProfile) {
        return GameSetupScreen(user: _userData!);
      }

      return HomeScreen(
        customName: _userData!['ign'] as String? ?? _userData!['name'] as String?,
        customIGN: 'UID: ${_userData!['game_uid']}',
        customAvatarUrl: _userData!['avatar_url'] as String?,
      );
    }

    return const SplashScreen();
  }
}
