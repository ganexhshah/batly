import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_messaging/firebase_messaging.dart' show AuthorizationStatus;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../widgets/skeleton_widgets.dart';
import '../widgets/app_network_image.dart';
import '../core/responsive/responsive.dart';
import '../core/theme/battly_theme.dart';
import '../core/firebase_guard.dart';
import '../core/notification_navigation.dart';
import '../core/cache_debug.dart';
import 'notification_settings_screen.dart';

class NotificationItem {
  final int id;
  final String title;
  final String subtitle;
  final String time;
  final IconData icon;
  final Color iconColor;
  final bool isUnread;
  final String category; // Matches, Tournaments, System, Rewards
  final bool isNew;
  final String group; // Today, Yesterday, Earlier
  final String? deepLink;
  final String? type;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.icon,
    required this.iconColor,
    this.isUnread = false,
    required this.category,
    this.isNew = false,
    required this.group,
    this.deepLink,
    this.type,
  });

  NotificationItem copyWith({bool? isUnread}) {
    return NotificationItem(
      id: id,
      title: title,
      subtitle: subtitle,
      time: time,
      icon: icon,
      iconColor: iconColor,
      isUnread: isUnread ?? this.isUnread,
      category: category,
      isNew: isNew,
      group: group,
      deepLink: deepLink,
      type: type,
    );
  }
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  String _selectedCategory = 'All';
  bool _isLoading = true;
  String? _errorMessage;
  List<NotificationItem> _notifications = [];
  bool _firebaseNotificationsEnabled = false;

  final List<Map<String, dynamic>> _categories = const [
    {'name': 'All', 'icon': Icons.notifications_none_rounded},
    {'name': 'Matches', 'icon': Icons.sports_kabaddi_rounded},
    {'name': 'Tournaments', 'icon': Icons.emoji_events_outlined},
    {'name': 'System', 'icon': Icons.settings_outlined},
    {'name': 'Rewards', 'icon': Icons.card_giftcard_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _checkFirebasePermissions();
  }

  Future<void> _checkFirebasePermissions() async {
    try {
      final settings = await FirebaseGuard.messagingSettings();
      if (settings == null) return;
      final bool authorized = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (mounted) {
        setState(() {
          _firebaseNotificationsEnabled = authorized;
        });
      }
    } catch (e, st) {
      logCacheRefreshFailure('firebaseNotificationSettings', e, st);
    }
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final list = await ApiService.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = list.map((json) => _mapJsonToNotificationItem(json as Map<String, dynamic>)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load notifications. Pull to refresh.';
        });
      }
    }
  }

  void _markAllAsRead() async {
    try {
      await ApiService.markNotificationsRead();
      _loadNotifications();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF4CAF50),
          content: Text('All notifications marked as read', style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFE53935),
          content: Text('Failed to mark notifications read', style: GoogleFonts.poppins(color: context.battlyOnSurface)),
        ),
      );
    }
  }

  String _getNotificationGroup(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(dt.year, dt.month, dt.day);

    if (dateToCheck == today) {
      return 'Today';
    } else if (dateToCheck == yesterday) {
      return 'Yesterday';
    } else {
      return 'Earlier';
    }
  }

  String _formatNotificationTime(DateTime dt) {
    int hour = dt.hour;
    String amPm = "AM";
    if (hour >= 12) {
      amPm = "PM";
      if (hour > 12) hour -= 12;
    } else if (hour == 0) {
      hour = 12;
    }
    String timeStr = "$hour:${dt.minute.toString().padLeft(2, '0')} $amPm";
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(dt.year, dt.month, dt.day);

    if (dateToCheck == today || dateToCheck == yesterday) {
      return timeStr;
    } else {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return "${dt.day} ${months[dt.month - 1]}, ${dt.year} • $timeStr";
    }
  }

  String _getCategory(String title, String message) {
    final combined = '$title $message'.toLowerCase();
    if (combined.contains('won') || combined.contains('reward') || combined.contains('credited') || combined.contains('bonus') || combined.contains('wallet') || combined.contains('priz')) {
      return 'Rewards';
    } else if (combined.contains('match') || combined.contains('scrim')) {
      return 'Matches';
    } else if (combined.contains('tournament') || combined.contains('registered')) {
      return 'Tournaments';
    } else {
      return 'System';
    }
  }

  NotificationItem _mapJsonToNotificationItem(Map<String, dynamic> json) {
    final title = json['title'] ?? 'Notification';
    final message = json['message'] ?? '';
    final isUnread = json['unread'] ?? true;
    
    DateTime dt;
    try {
      dt = DateTime.parse(json['created_at'] ?? '');
    } catch (_) {
      dt = DateTime.now();
    }

    final category = _getCategory(title, message);
    
    IconData icon;
    Color iconColor;
    switch (category) {
      case 'Tournaments':
        icon = Icons.emoji_events_rounded;
        iconColor = const Color(0xFFFFD700);
        break;
      case 'Matches':
        icon = Icons.sports_esports_outlined;
        iconColor = const Color(0xFFAB47BC);
        break;
      case 'Rewards':
        icon = Icons.card_giftcard_rounded;
        iconColor = const Color(0xFFFF9800);
        break;
      default:
        icon = Icons.settings_rounded;
        iconColor = context.battlyMuted;
    }

    return NotificationItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: title,
      subtitle: message,
      time: _formatNotificationTime(dt),
      icon: icon,
      iconColor: iconColor,
      isUnread: isUnread,
      category: category,
      isNew: isUnread,
      group: _getNotificationGroup(dt),
      deepLink: json['deep_link'],
      type: json['type'],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter the notifications list
    final filtered = _notifications.where((n) {
      if (_selectedCategory == 'All') return true;
      return n.category == _selectedCategory;
    }).toList();

    final todayItems = filtered.where((n) => n.group == 'Today').toList();
    final yesterdayItems = filtered.where((n) => n.group == 'Yesterday').toList();
    final earlierItems = filtered.where((n) => n.group == 'Earlier').toList();

    return Scaffold(
      backgroundColor: context.battly.navBar,
      appBar: AppBar(
        backgroundColor: context.battly.navBar,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 48,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: context.battlyOnSurface, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(color: context.battlyOnSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationSettingsScreen(),
                ),
              );
              _checkFirebasePermissions();
            },
            icon: Icon(Icons.settings_outlined, color: context.battlyOnSurface, size: 20),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                children: [
                  // Skeleton category chips
                  Row(
                    children: List.generate(
                        4,
                        (i) => Container(
                              margin: EdgeInsets.only(right: i < 3 ? 8 : 0),
                              width: 70,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            )),
                  ),
                  const SizedBox(height: 20),
                  // Skeleton notification group container
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF101216),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF222630)),
                    ),
                    child: Column(
                      children: List.generate(
                        6,
                        (i) => Column(
                          children: [
                            const SkeletonNotificationItem(),
                            if (i < 5)
                              Container(height: 1, color: const Color(0xFF1F222A)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFE53935), size: 40),
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadNotifications,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B00),
                        ),
                        child: Text(
                          'Retry',
                          style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  color: const Color(0xFFFF6B00),
                  backgroundColor: const Color(0xFF101216),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. FILTER CATEGORY TAGS BAR
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: _categories.map((cat) {
                              final isSelected = _selectedCategory == cat['name'];
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedCategory = cat['name'];
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFFFF6B00).withValues(alpha: 0.08) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFFFF6B00) : const Color(0xFF222630),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        cat['icon'] as IconData,
                                        color: isSelected ? const Color(0xFFFF6B00) : context.battlyMuted,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        cat['name'] as String,
                                        style: GoogleFonts.poppins(
                                          color: isSelected ? Colors.white : context.battlyMuted,
                                          fontSize: 10.5,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 2. NOTIFICATION LIST GROUPINGS
                        _buildGroupSection('Today', todayItems),
                        _buildGroupSection('Yesterday', yesterdayItems),
                        _buildGroupSection('Earlier', earlierItems),

                        if (filtered.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40.0),
                              child: Text(
                                'No notifications in this category',
                                style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 13),
                              ),
                            ),
                          ),

                        // 3. PROMO CARD BANNER
                        if (!_firebaseNotificationsEnabled) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF101216),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF222630)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Never miss an update!',
                                        style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Enable push notifications to get instant updates about matches, rewards and more.',
                                        style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 10, height: 1.4),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  children: [
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const Icon(Icons.notifications_active_rounded, color: Color(0xFFFF9800), size: 28),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                              color: Color(0xFFFF3D00),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text(
                                              '1',
                                              style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 7, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    SizedBox(
                                      height: 28,
                                      child: OutlinedButton(
                                        onPressed: () async {
                                          try {
                                            final settings = await FirebaseGuard.requestMessagingPermission();
                                            if (settings == null) {
                                              if (!context.mounted) return;
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
                                            if (authorized) {
                                              final prefs = await SharedPreferences.getInstance();
                                              await prefs.setBool('settings_push_notifications', true);
                                              await _checkFirebasePermissions();
                                              if (!context.mounted) return;
                                              final scaffoldMessenger = ScaffoldMessenger.of(context);
                                              final onSurfaceColor = context.battlyOnSurface;
                                              scaffoldMessenger.showSnackBar(
                                                SnackBar(
                                                  backgroundColor: const Color(0xFF4CAF50),
                                                  content: Text('Push notifications enabled!', style: GoogleFonts.poppins(color: onSurfaceColor, fontWeight: FontWeight.bold)),
                                                ),
                                              );
                                            } else {
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  backgroundColor: const Color(0xFFE53935),
                                                  content: Text('Permission Denied. Please enable notifications in system settings.', style: GoogleFonts.poppins(color: Colors.white, fontSize: 12)),
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                backgroundColor: const Color(0xFFE53935),
                                                content: Text('Error requesting notifications permission.', style: GoogleFonts.poppins(color: Colors.white, fontSize: 12)),
                                              ),
                                            );
                                          }
                                        },
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: Color(0xFFFF9800), width: 1.2),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                        ),
                                        child: Text(
                                          'Enable Now',
                                          style: GoogleFonts.poppins(color: const Color(0xFFFF9800), fontSize: 9.5, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // 4. MARK ALL AS READ FOOTER
                        if (_notifications.any((n) => n.isUnread))
                          GestureDetector(
                            onTap: _markAllAsRead,
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.done_all_rounded, color: Color(0x60A0A0A0), size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Mark all as read',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0x60A0A0A0),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildGroupSection(String groupName, List<NotificationItem> items) {
    if (items.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          groupName,
          style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF101216),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF222630)),
          ),
          child: Column(
            children: List.generate(items.length, (idx) {
              final item = items[idx];
              return Column(
                children: [
                  _buildNotificationRow(item),
                  if (idx < items.length - 1)
                    Container(height: 1, color: const Color(0xFF1F222A)),
                ],
              );
            }),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  void _showNotificationDetailSheet(BuildContext context, NotificationItem item) {
    if (item.isUnread) {
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == item.id);
        if (index != -1) {
          _notifications[index] = _notifications[index].copyWith(isUnread: false);
        }
      });
      ApiService.markNotificationRead(item.id).catchError((e, st) {
        logCacheRefreshFailure('markNotificationRead', e, st);
      });
    }

    final bool hasImage = isNotificationImageUrl(item.deepLink);
    final tournamentId = parseTournamentDeepLink(item.deepLink);

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
          padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 24),
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
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: item.iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(item.icon, color: item.iconColor, size: 13),
                        const SizedBox(width: 6),
                        Text(
                          item.category.toUpperCase(),
                          style: GoogleFonts.poppins(
                            color: item.iconColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    item.time,
                    style: GoogleFonts.poppins(
                      color: const Color(0x60A0A0A0),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Text(
                item.title,
                style: GoogleFonts.poppins(
                  color: context.battlyOnSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),

              if (hasImage) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AppNetworkImage(
                    url: item.deepLink!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: Container(
                      height: 160,
                      width: double.infinity,
                      color: const Color(0xFF1E222A),
                      child: const Icon(
                        Icons.broken_image_rounded,
                        color: Colors.white24,
                        size: 40,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              Text(
                item.subtitle,
                style: GoogleFonts.poppins(
                  color: context.battlyMuted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              if (tournamentId != null) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      openTournamentDeepLink(context, item.deepLink);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B00),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Open Tournament',
                      style: GoogleFonts.poppins(
                        color: context.battlyOnSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

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
                    style: GoogleFonts.poppins(
                      color: context.battlyOnSurface,
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

  Widget _buildNotificationRow(NotificationItem item) {
    return GestureDetector(
      onTap: () => _showNotificationDetailSheet(context, item),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: item.iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: item.iconColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.isNew) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B00).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'NEW',
                          style: GoogleFonts.poppins(color: const Color(0xFFFF6B00), fontSize: 7, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        item.title,
                        style: GoogleFonts.poppins(color: context.battlyOnSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: GoogleFonts.poppins(
                    color: context.battlyMuted,
                    fontSize: 9.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.time,
                style: GoogleFonts.poppins(
                  color: const Color(0x60A0A0A0),
                  fontSize: 8.5,
                ),
              ),
              const SizedBox(height: 6),
              if (item.isUnread)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Color(0xFFFF6B00),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ],
      ),
     ),
    );
  }
}
