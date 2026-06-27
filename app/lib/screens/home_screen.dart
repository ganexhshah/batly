import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/cache_debug.dart';
import '../core/responsive/responsive.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/local_cache.dart';
import '../models/app_models.dart';
import '../widgets/crossed_rifles_icon.dart';
import '../widgets/app_network_image.dart';
import '../widgets/battly_app_bar.dart';
import '../widgets/featured_carousel.dart';
import '../widgets/category_card.dart';
import '../widgets/tournament_card.dart';
import '../widgets/battly_navigation_bar.dart';
import '../widgets/battly_navigation_rail.dart';
import '../widgets/skeleton_widgets.dart';
import '../widgets/battly_asset_image.dart';
import '../widgets/query_error_view.dart';
import '../widgets/app_notification_popup.dart';
import '../auth/signin_screen.dart';
import 'tournament/tournament_screen.dart';
import 'tournaments_tab_view.dart';
import 'wallet/wallet_screen.dart';
import 'profile/profile_screen.dart';
import 'profile/my_matches_screen.dart';
import 'notification_screen.dart';
import '../core/theme/battly_theme.dart';

class HomeScreen extends StatefulWidget {
  final String? customName;
  final String? customIGN;
  final String? customAvatarUrl;

  const HomeScreen({
    super.key,
    this.customName,
    this.customIGN,
    this.customAvatarUrl,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isScrolled = false;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadUser().then((_) {
      _checkAndShowPopupNotifications();
    });
  }

  Future<void> _loadUser() async {
    final cached = await AuthService.getCachedUser();
    if (cached != null && mounted) {
      setState(() {
        _user = cached;
      });
    }
    final fresh = await AuthService.getUser();
    if (fresh != null && mounted) {
      setState(() {
        _user = fresh;
      });
    }
  }

  Future<void> _checkAndShowPopupNotifications() async {
    try {
      final notifications = await ApiService.getNotifications();
      final bannerNotifications = notifications.where((n) => n['type'] == 'banner').toList();
      if (bannerNotifications.isEmpty) return;

      // Read dismissed list from cache
      final String? cachedDismissed = await LocalCache.read('dismissed_popup_ids');
      List<int> dismissedIds = [];
      if (cachedDismissed != null && cachedDismissed.isNotEmpty) {
        try {
          final decoded = jsonDecode(cachedDismissed);
          if (decoded is List) {
            dismissedIds = decoded.map((e) => int.tryParse(e.toString()) ?? 0).where((id) => id != 0).toList();
          }
        } catch (e, st) {
          logCacheRefreshFailure('dismissedPopupIds', e, st);
        }
      }

      // Loop and show popups sequentially (load like 1, 2, 3...)
      for (final n in bannerNotifications) {
        if (!mounted) return;
        final id = n['id'] is int ? n['id'] : int.tryParse(n['id']?.toString() ?? '') ?? 0;
        if (id != 0 && !dismissedIds.contains(id)) {
          final title = n['title'] ?? 'Alert';
          final message = n['message'] ?? '';
          final deepLink = n['deep_link'];

          // Wait a slight delay for page transitions to settle or previous sheet to fully dismiss
          await Future.delayed(const Duration(milliseconds: 650));
          if (!mounted) return;

          final completer = Completer<void>();

          showAppNotificationPopup(
            context,
            id: id,
            title: title,
            message: message,
            deepLink: deepLink,
            onClosed: (doNotShowAgain) async {
              if (doNotShowAgain) {
                dismissedIds.add(id);
                await LocalCache.write('dismissed_popup_ids', jsonEncode(dismissedIds));
              }
              completer.complete();
            },
          );

          await completer.future;
        }
      }
    } catch (_) {
      // Fail silently for in-app popups to avoid interrupting the user experience
    }
  }

  void _showProfileInfoSheet(BuildContext context) {
    final avatarUrl = _user?['avatar_url'] ?? widget.customAvatarUrl;
    final name = _user?['name'] ?? widget.customName ?? 'BattlyWarrior';
    final email = _user?['email'] ?? 'N/A';
    final ign = _user?['ign'] ?? widget.customIGN ?? 'N/A';
    final gameUid = _user?['game_uid'] ?? 'N/A';

    showAdaptiveSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: context.battlyScaffold,
            borderRadius: context.useNavigationRail
                ? BorderRadius.circular(24)
                : const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
            border: Border.all(color: context.battlyBorder, width: 1.5),
          ),
          padding: const EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: 32,
          ),
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
                    border: Border.all(
                      color: const Color(0xFFFF6B00),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6B00).withValues(alpha: 0.2),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: avatarUrl != null && avatarUrl.isNotEmpty
                        ? AppNetworkImage(
                            url: avatarUrl,
                            fit: BoxFit.cover,
                            errorWidget: Container(
                              color: const Color(0xFF1E222A),
                              child: const Icon(
                                Icons.person,
                                color: Colors.white54,
                                size: 40,
                              ),
                            ),
                          )
                        : BattlyAssetImage(
                            assetPath: 'assets/logo/profile_avatar.png',
                            fit: BoxFit.cover,
                            fallbackIcon: Icons.person,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Details List
              _buildDetailRow(Icons.person_outline_rounded, 'Full Name', name),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.email_outlined, 'Email Address', email),
              const SizedBox(height: 12),
              _buildDetailRow(
                Icons.sports_esports_outlined,
                'Game Name (IGN)',
                ign,
              ),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.fingerprint_rounded, 'Game UID', gameUid),
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
    final isOverview = _currentIndex == 0;
    final avatarUrl = _user?['avatar_url'] ?? widget.customAvatarUrl;
    final username = _user?['name'] ?? widget.customName;

    final tabViews = [
      OverviewTabView(
        customAvatarUrl: avatarUrl,
        onTabChanged: (index) {
          setState(() {
            // Remap if overview triggers index 4 (now Profile is 3) or 2 (now Wallet is 2, matches is removed)
            int targetIndex = index;
            if (index == 4) {
              targetIndex = 3;
            } else if (index == 2) {
              // Redirect category matches click to profile or open screen, handled in CategoryCard onTap
              targetIndex = 0;
            }
            _currentIndex = targetIndex;
            _isScrolled = false; // Reset scroll state when changing tabs
          });
        },
      ),
      const TournamentsTabView(),
      const WalletScreen(),
      ProfileScreen(
        customName: _user?['name'] ?? widget.customName,
        customIGN: _user?['ign'] ?? widget.customIGN,
        customAvatarUrl: avatarUrl,
      ),
    ];

    final useRail = context.useNavigationRail;

    final body = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (isOverview && notification is ScrollUpdateNotification) {
          final offset = notification.metrics.pixels;
          final shouldBeScrolled = offset > 10.0;
          if (shouldBeScrolled != _isScrolled) {
            setState(() {
              _isScrolled = shouldBeScrolled;
            });
          }
        }
        return false;
      },
      child: tabViews[_currentIndex],
    );

    if (useRail) {
      return Scaffold(
        extendBodyBehindAppBar: isOverview,
        appBar: isOverview
            ? BattlyAppBar(
                username: username,
                customAvatarUrl: avatarUrl,
                isScrolled: _isScrolled,
                onProfilePressed: () {
                  _showProfileInfoSheet(context);
                },
                onNotificationPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationScreen(),
                    ),
                  ).then((_) {
                    _loadUser();
                  });
                },
              )
            : null,
        body: Row(
          children: [
            BattlyNavigationRail(
              currentIndex: _currentIndex,
              onTap: _onNavTap,
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: isOverview,
      appBar: isOverview
          ? BattlyAppBar(
              username: username,
              customAvatarUrl: avatarUrl,
              isScrolled: _isScrolled,
              onProfilePressed: () {
                _showProfileInfoSheet(context);
              },
              onNotificationPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationScreen(),
                  ),
                ).then((_) {
                  _loadUser();
                });
              },
            )
          : null,
      body: body,
      bottomNavigationBar: BattlyNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
    );
  }

  void _onNavTap(int index) {
    setState(() {
      _currentIndex = index;
      _isScrolled = false;
      if (index == 3 || index == 2) {
        _loadUser();
      }
    });
  }
}

// -----------------------------------------------------------------------------
// OVERVIEW TAB VIEW
// -----------------------------------------------------------------------------
class OverviewTabView extends StatefulWidget {
  final String? customAvatarUrl;
  final ValueChanged<int>? onTabChanged;

  const OverviewTabView({super.key, this.customAvatarUrl, this.onTabChanged});

  @override
  State<OverviewTabView> createState() => _OverviewTabViewState();
}

class _OverviewTabViewState extends State<OverviewTabView> {
  bool _loading = true;
  String? _error;
  List<FeaturedTournament> _featured = [];
  List<UpcomingTournament> _upcoming = [];
  List<RecentMatch> _recent = [];

  @override
  void initState() {
    super.initState();
    _showCachedHomeData();
    _fetchHomeData();
  }

  Future<void> _showCachedHomeData() async {
    final snapshot = await ApiService.peekHomeData();
    if (!mounted || snapshot == null || snapshot.isEmpty) return;
    setState(() {
      _featured = snapshot.banners;
      _upcoming = snapshot.upcoming;
      _recent = snapshot.matches;
      _loading = false;
    });
  }

  Future<void> _fetchHomeData({bool forceRefresh = false}) async {
    try {
      final results = await Future.wait<List<dynamic>>([
        _safeHomeList(
          forceRefresh ? ApiService.forceBanners() : ApiService.getBanners(),
          _featured,
        ),
        _safeHomeList(
          forceRefresh
              ? ApiService.forceUpcomingTournaments()
              : ApiService.getUpcomingTournaments(),
          _upcoming,
        ),
        _safeHomeList(
          forceRefresh
              ? ApiService.forceRecentMatches()
              : ApiService.getRecentMatches(),
          _recent,
        ),
      ]);

      if (mounted) {
        setState(() {
          _featured = results[0] as List<FeaturedTournament>;
          _upcoming = results[1] as List<UpcomingTournament>;
          _recent = results[2] as List<RecentMatch>;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        final err = e.toString();
        if (err.contains('401') || err.contains('403')) {
          await AuthService.logout();
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const SigninScreen()),
              (route) => false,
            );
          }
          return;
        }

        setState(() {
          _loading = false;
          _error = err.replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _onRefresh() => _fetchHomeData(forceRefresh: true);

  Future<List<T>> _safeHomeList<T>(
    Future<List<T>> request,
    List<T> fallback,
  ) async {
    try {
      return await request;
    } catch (e) {
      if (e.toString().contains('401') || e.toString().contains('403')) {
        rethrow;
      }
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SkeletonHomeOverview();
    }

    if (_error != null && _featured.isEmpty && _upcoming.isEmpty && _recent.isEmpty) {
      return QueryErrorView(
        message: _error,
        onRetry: () {
          setState(() {
            _error = null;
            _loading = true;
          });
          _fetchHomeData(forceRefresh: true);
        },
      );
    }

    return Stack(
      children: [
        // Background Image
        const Positioned.fill(
          child: BattlyAssetImage(
            assetPath: 'assets/background/bg1.png',
            fit: BoxFit.cover,
            fallbackIcon: Icons.landscape_outlined,
          ),
        ),
        // Dark Overlay
        Positioned.fill(
          child: Container(color: Colors.black.withValues(alpha: 0.88)),
        ),
        // Content view with pull-to-refresh
        Positioned.fill(
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            color: const Color(0xFFFF6B00),
            backgroundColor: context.battly.elevatedSurface,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Featured Carousel Banner (Full Bleed)
                  FeaturedCarousel(items: _featured),
                  const SizedBox(height: 24),
                  // Remaining Page Content (Padded)
                  ResponsiveContent(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category Cards Row
                        Row(
                          children: [
                            CategoryCard(
                              label: 'Tournaments',
                              icon: Icons.emoji_events_outlined,
                              onTap: () {
                                if (widget.onTabChanged != null) {
                                  widget.onTabChanged!(1);
                                }
                              },
                            ),
                            CategoryCard(
                              label: 'Scrims',
                              customIcon: const CrossedRiflesIcon(
                                color: Color(0xFFFF6B00),
                                size: 26,
                              ),
                              onTap: () {
                                if (widget.onTabChanged != null) {
                                  widget.onTabChanged!(1);
                                }
                              },
                            ),
                            CategoryCard(
                              label: 'My Matches',
                              icon: Icons.calendar_month_outlined,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const MyMatchesScreen(),
                                  ),
                                );
                              },
                            ),
                            CategoryCard(
                              label: 'Friends',
                              icon: Icons.people_outline_rounded,
                              onTap: () {
                                if (widget.onTabChanged != null) {
                                  widget.onTabChanged!(3);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        _buildSectionHeader('Upcoming Tournaments', () {
                          if (widget.onTabChanged != null) {
                            widget.onTabChanged!(1);
                          }
                        }),
                        const SizedBox(height: 12),
                        if (_upcoming.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  BattlyAssetImage(
                                    assetPath: 'assets/background/tournment.png',
                                    width: 140,
                                    height: 140,
                                    fit: BoxFit.contain,
                                    fallbackIcon: Icons.emoji_events_outlined,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No upcoming tournaments',
                                    style: GoogleFonts.poppins(
                                      color: context.battlyMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ResponsiveColumns(
                            mediumColumns: 2,
                            expandedColumns: 2,
                            children: _upcoming
                                .map(
                                  (item) => TournamentCard(
                                    tournament: item,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              TournamentScreen(
                                                tournament: item,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                )
                                .toList(),
                          ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onViewAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(color: context.battlyOnSurface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        InkWell(
          onTap: onViewAll,
          child: Row(
            children: [
              Text(
                'View All',
                style: GoogleFonts.poppins(
                  color: const Color(0xFFFF6B00),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFFF6B00),
                size: 16,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// PROFILE / SETTINGS TAB
// -----------------------------------------------------------------------------
class ProfileTabView extends StatefulWidget {
  final String? customName;
  final String? customIGN;
  final String? customAvatarUrl;

  const ProfileTabView({
    super.key,
    this.customName,
    this.customIGN,
    this.customAvatarUrl,
  });

  @override
  State<ProfileTabView> createState() => _ProfileTabViewState();
}

class _ProfileTabViewState extends State<ProfileTabView> {
  bool _biometricsEnabled = true;
  bool _autoLockEnabled = false;

  @override
  Widget build(BuildContext context) {
    final name = widget.customName ?? 'BATTLY_PRO';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Control Panel',
            style: GoogleFonts.poppins(
              color: context.battlyMuted,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Profile',
            style: GoogleFonts.poppins(color: context.battlyOnSurface,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 30),
          // Profile Details Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  context.battlyBorder.withValues(alpha: 0.6),
                  context.battly.elevatedSurface,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: context.battlyBorder, width: 1.5),
            ),
            child: Row(
              children: [
                AppAvatar(
                  imageUrl: widget.customAvatarUrl,
                  radius: 35,
                  fallbackIconSize: 36,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.poppins(color: context.battlyOnSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.customIGN ?? 'UID: 982173',
                        style: GoogleFonts.poppins(
                          color: context.battlyMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFFFD700,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Verified Identity',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFFFD700),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 35),
          // Security Settings Group
          Text(
            'Security',
            style: GoogleFonts.poppins(color: context.battlyOnSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildSettingsThemeSwitch(
            title: 'Biometric Login',
            subtitle: 'Use FaceID or Fingerprint sensor',
            value: _biometricsEnabled,
            onChanged: (val) {
              setState(() {
                _biometricsEnabled = val;
              });
            },
            icon: Icons.fingerprint_rounded,
          ),
          _buildSettingsThemeSwitch(
            title: 'Auto-Lock Wallet',
            subtitle: 'Lock when app runs in background',
            value: _autoLockEnabled,
            onChanged: (val) {
              setState(() {
                _autoLockEnabled = val;
              });
            },
            icon: Icons.lock_outline_rounded,
          ),
          const SizedBox(height: 25),
          // General Preferences Group
          Text(
            'Preferences',
            style: GoogleFonts.poppins(color: context.battlyOnSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildActionSetting(
            title: 'Default Currency',
            subtitle: 'NPR - Nepalese Rupee',
            icon: Icons.monetization_on_outlined,
            onTap: () {},
          ),
          _buildActionSetting(
            title: 'Connected Networks',
            subtitle: 'Battly Core Lobby, Guild Alliance',
            icon: Icons.lan_outlined,
            onTap: () {},
          ),
          const SizedBox(height: 30),
          // Sign Out Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Color(0xFFFF4E8E), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.logout_rounded, color: Color(0xFFFF4E8E)),
              label: Text(
                'Disconnect Profile',
                style: GoogleFonts.poppins(
                  color: const Color(0xFFFF4E8E),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () async {
                await AuthService.logout();
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const SigninScreen()),
                  (route) => false,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsThemeSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.battly.elevatedSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.battlyBorder, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B00).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFFFF6B00), size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    color: context.battlyMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
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

  Widget _buildActionSetting({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.battly.elevatedSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.battlyBorder, width: 1),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          onTap: onTap,
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B00).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFFFF6B00), size: 22),
          ),
          title: Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: GoogleFonts.poppins(
              color: context.battlyMuted,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios_rounded,
            color: Colors.white54,
            size: 16,
          ),
        ),
      ),
    );
  }
}
