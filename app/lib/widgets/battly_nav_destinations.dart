import 'package:flutter/material.dart';

class BattlyNavDestination {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const BattlyNavDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

const List<BattlyNavDestination> battlyNavDestinations = [
  BattlyNavDestination(
    icon: Icons.home_outlined,
    activeIcon: Icons.home,
    label: 'Home',
  ),
  BattlyNavDestination(
    icon: Icons.emoji_events_outlined,
    activeIcon: Icons.emoji_events,
    label: 'Tournaments',
  ),
  BattlyNavDestination(
    icon: Icons.account_balance_wallet_outlined,
    activeIcon: Icons.account_balance_wallet,
    label: 'Wallet',
  ),
  BattlyNavDestination(
    icon: Icons.person_outline_rounded,
    activeIcon: Icons.person,
    label: 'Profile',
  ),
];
