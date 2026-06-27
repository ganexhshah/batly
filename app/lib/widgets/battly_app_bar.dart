import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/battly_theme.dart';
import 'app_network_image.dart';

// -----------------------------------------------------------------------------
// BATTLY APP BAR
// -----------------------------------------------------------------------------
class BattlyAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? username;
  final String? customAvatarUrl;
  final VoidCallback? onMenuPressed;
  final VoidCallback? onNotificationPressed;
  final VoidCallback? onProfilePressed;
  final bool isScrolled;

  const BattlyAppBar({
    super.key,
    this.username,
    this.customAvatarUrl,
    this.onMenuPressed,
    this.onNotificationPressed,
    this.onProfilePressed,
    this.isScrolled = false,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = context.battlyOnSurface;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isScrolled ? context.battlyScaffold : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isScrolled ? context.battlyBorder : Colors.transparent,
              width: 1.0,
            ),
          ),
        ),
      ),
      titleSpacing: 20,
      automaticallyImplyLeading: false,
      centerTitle: false,
      title: Text(
        'Hi, ${username ?? 'Gamer'}',
        style: GoogleFonts.poppins(
          color: onSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: Badge(
            alignment: const Alignment(0.5, -0.5),
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Icon(Icons.notifications_none_rounded, color: onSurface, size: 28),
          ),
          onPressed: onNotificationPressed,
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onProfilePressed,
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: AppAvatar(
              imageUrl: customAvatarUrl,
              radius: 18,
              fallbackIconSize: 18,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
