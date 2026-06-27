import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../services/wallet_service.dart';
import '../../core/cache_debug.dart';
import 'manage_tournament_screen.dart';
import '../../core/theme/battly_theme.dart';
import '../../widgets/match_room_rules_sheet.dart';
import '../../widgets/wallet_deduction_confirmation.dart';

class CreateTournamentScreen extends StatefulWidget {
  const CreateTournamentScreen({super.key});

  @override
  State<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // State Variables
  String _roomType = 'Custom Room'; // Custom Room, Lone Wolf
  String _teamSize =
      '1v1'; // 1v1, 2v2, 3v3, 4v4 (Custom Room) or 1v2 (Lone Wolf)
  bool _throwableLimit = true; // Yes/No. Always true for Lone Wolf
  bool _characterSkill = true; // Yes/No
  String _skillOption =
      'except_trio'; // 'except_trio' (except Dmitri, Ryden, Orion) or 'custom_list'

  // Selected characters list
  final List<String> _allCharacters = [
    'Tatsuya',
    'Alok',
    'Iris',
    'Xayne',
    'Homer',
    'Kenta',
    'Dmitri',
    'Skyler',
    'Chrono',
    'K',
    'Clu',
    'Steffie',
    'A124',
    'Wukong',
    'Santino',
    'Nero',
    'Oscar',
    'Koda',
    'Kassie',
    'Ignis',
    'Orion',
    'Ryden',
  ];
  late List<String> _allowedCharacters;

  bool _hostMode = false;
  bool _gunAttributes = true;
  int _rounds = 7; // 7 or 13
  String _defaultCoin = 'Default Coin'; // Default Coin, 9950

  final TextEditingController _titleController = TextEditingController(
    text: 'Free Fire Custom Match',
  );
  final TextEditingController _creatorController = TextEditingController(
    text: 'Room Maker',
  );
  final TextEditingController _entryFeeController = TextEditingController(
    text: '100',
  );

  bool _acceptedRules = false;
  bool _isSubmitting = false;
  double? _walletBalance;

  @override
  void initState() {
    super.initState();
    // Default to allow all except Dmitri, Ryden, Orion for the trio option,
    // but start allowedCharacters list empty so user can select manually in custom_list mode
    _allowedCharacters = [];
    _loadWalletBalance();
  }

  Future<void> _loadWalletBalance() async {
    try {
      final balanceData = await WalletService.getBalance();
      if (mounted) {
        setState(() {
          _walletBalance = (balanceData['balance'] ?? 0).toDouble();
        });
      }
    } catch (e, st) {
      logCacheRefreshFailure('createTournamentWallet', e, st);
    }
  }

  void _onRoomTypeChanged(String type) {
    if (_roomType == type) return;
    setState(() {
      _roomType = type;
      if (_roomType == 'Lone Wolf') {
        _teamSize = '1v2';
        _throwableLimit = true; // locked to Yes for Lone Wolf
      } else {
        _teamSize = '1v1';
      }
    });
  }

  int get _maxPlayers {
    if (_roomType == 'Lone Wolf') return 3; // 1v2 is 3 players
    switch (_teamSize) {
      case '1v1':
        return 2;
      case '2v2':
        return 4;
      case '3v3':
        return 6;
      case '4v4':
        return 8;
      default:
        return 2;
    }
  }

  double get _calculatedWinnings {
    final entry = double.tryParse(_entryFeeController.text) ?? 0.0;
    if (entry <= 0) return 0.0;

    final totalCollected = entry * _maxPlayers;
    return totalCollected * 0.9;
  }

  Widget _feeRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: context.battlyMuted,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: valueColor,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedRules) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFE53935),
          content: Text(
            'You must accept the rules and regulations.',
            style: GoogleFonts.poppins(color: context.battlyOnSurface),
          ),
        ),
      );
      return;
    }

    final entryFeeRaw = double.tryParse(_entryFeeController.text) ?? 0.0;

    // If entry fee is set, confirm wallet deduction
    if (entryFeeRaw > 0) {
      final confirmed = await showWalletDeductionConfirmSheet(
        context,
        title: 'Entry Fee Confirmation',
        subtitle: 'You will be charged the entry fee as room maker.',
        deductionAmount: entryFeeRaw,
        actionButtonLabel: 'Confirm & Create',
      );

      if (confirmed != true) return;
    }

    setState(() => _isSubmitting = true);

    try {
      final entryFeeVal = double.tryParse(_entryFeeController.text) ?? 0.0;
      final prizePoolVal = _calculatedWinnings;

      // Handle character skill list properly depending on option chosen
      List<String> characterList = [];
      if (_characterSkill) {
        if (_skillOption == 'except_trio') {
          characterList = _allCharacters
              .where((c) => c != 'Dmitri' && c != 'Ryden' && c != 'Orion')
              .toList();
        } else {
          characterList = _allowedCharacters;
        }
      }

      final customSettingsMap = {
        'room_type': _roomType,
        'team_size': _teamSize,
        'throwable_limit': _throwableLimit ? 'Yes' : 'No',
        'character_skill': _characterSkill ? 'Yes' : 'No',
        'skill_allowance_mode': _characterSkill
            ? (_skillOption == 'except_trio'
                  ? 'Except Dmitri, Ryden, Orion'
                  : 'Selected Active Skills Only')
            : 'None',
        'allowed_characters': characterList,
        'host_mode': _hostMode ? 'Yes' : 'No',
        'gun_attributes': _gunAttributes ? 'Yes' : 'No',
        'rounds': _rounds,
        'default_coin': _defaultCoin,
        'room_maker': _creatorController.text.trim(),
        'prize_distribution': 'winner_takes_all',
      };

      final Map<String, dynamic> requestData = {
        'title': _titleController.text.trim(),
        'game': 'Free Fire',
        'stage': '$_roomType [$_teamSize]',
        'type': _teamSize == '1v1'
            ? 'Solo'
            : _teamSize == '2v2'
            ? 'Duo'
            : 'Squad',
        'mode': _roomType,
        'prize_pool': 'NPR ${prizePoolVal.toInt()}',
        'entry_fee': entryFeeVal > 0 ? 'NPR ${entryFeeVal.toInt()}' : 'Free',
        'max_players': _maxPlayers,
        'starts_at': DateTime.now()
            .add(const Duration(minutes: 30))
            .toIso8601String(),
        'status': 'registration',
        'logo_asset': 'assets/logo/battly_cup.png',
        'image_path': 'assets/background/featured_gamer.png',
        'custom_settings': customSettingsMap,
      };

      final created = await ApiService.createTournament(requestData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF4CAF50),
            content: Text(
              'Match room created! You are registered as room maker.',
              style: GoogleFonts.poppins(color: context.battlyOnSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
        // Navigate directly into the tournament screen so the Manage button
        // is visible immediately. Pop this screen first, then push tournament.
        Navigator.pop(context, true);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ManageTournamentScreen(
              tournament: created,
              participants: const [],
              onRefresh: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFE53935),
            content: Text(
              'Failed to create match: $e',
              style: GoogleFonts.poppins(color: context.battlyOnSurface),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.battly.navBar,
      appBar: AppBar(
        backgroundColor: context.battly.navBar,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create Match Room',
          style: GoogleFonts.poppins(color: context.battlyOnSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HOST YOUR CUSTOM LOBBY',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFFF6B00),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Set up your custom rules. Once published, your lobby will be shown to other players in the app.',
                        style: GoogleFonts.poppins(
                          color: context.battlyMuted,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Match Title Input
                      _buildLabel('Lobby / Match Title'),
                      TextFormField(
                        controller: _titleController,
                        style: GoogleFonts.poppins(color: context.battlyOnSurface,
                          fontSize: 13,
                        ),
                        decoration: _buildInputDecoration(
                          'e.g. Free Fire custom cash match',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Title is required'
                            : null,
                      ),
                      const SizedBox(height: 18),

                      // Room Type Selector - sliding capsule tab layout
                      _buildLabel('Room Type'),
                      Container(
                        height: 50,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: context.battlyCard,
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(color: context.battlyBorder),
                        ),
                        child: Stack(
                          children: [
                            AnimatedAlign(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              alignment: _roomType == 'Custom Room'
                                  ? Alignment.centerLeft
                                  : Alignment.centerRight,
                              child: FractionallySizedBox(
                                widthFactor: 0.5,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF6B00),
                                    borderRadius: BorderRadius.circular(21),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFFFF6B00,
                                        ).withValues(alpha: 0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () =>
                                        _onRoomTypeChanged('Custom Room'),
                                    behavior: HitTestBehavior.opaque,
                                    child: Center(
                                      child: Text(
                                        'Custom Room',
                                        style: GoogleFonts.poppins(
                                          color: _roomType == 'Custom Room'
                                              ? Colors.white
                                              : context.battlyMuted,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () =>
                                        _onRoomTypeChanged('Lone Wolf'),
                                    behavior: HitTestBehavior.opaque,
                                    child: Center(
                                      child: Text(
                                        'Lone Wolf',
                                        style: GoogleFonts.poppins(
                                          color: _roomType == 'Lone Wolf'
                                              ? Colors.white
                                              : context.battlyMuted,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Animated container that expands/collapses room-specific settings
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_roomType == 'Custom Room') ...[
                              // Team Size
                              _buildLabel('Team Size'),
                              Row(
                                children: ['1v1', '2v2', '3v3', '4v4'].map((
                                  size,
                                ) {
                                  final isSel = _teamSize == size;
                                  return Expanded(
                                    child: GestureDetector(
                                      onTap: () =>
                                          setState(() => _teamSize = size),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 4.0,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12.0,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSel
                                              ? const Color(0xFFFF6B00)
                                              : context.battlyCard,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: isSel
                                                ? const Color(0xFFFF6B00)
                                                : context.battlyBorder,
                                          ),
                                          boxShadow: isSel
                                              ? [
                                                  BoxShadow(
                                                    color: const Color(
                                                      0xFFFF6B00,
                                                    ).withValues(alpha: 0.2),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 3),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          size,
                                          style: GoogleFonts.poppins(
                                            color: isSel
                                                ? Colors.white
                                                : context.battlyMuted,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 18),

                              // Throwable Limit
                              _buildLabel('Throwable Limit'),
                              _buildYesNoToggle(
                                value: _throwableLimit,
                                onChanged: (val) =>
                                    setState(() => _throwableLimit = val),
                              ),
                              const SizedBox(height: 18),
                            ] else ...[
                              // Lone Wolf configuration panel
                              _buildLabel('Match Configuration (Lone Wolf)'),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16.0),
                                decoration: BoxDecoration(
                                  color: context.battlyCard,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: context.battlyBorder,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildStaticSettingRow(
                                      'Team Size Mode',
                                      '1v2 Match Locked',
                                    ),
                                    Divider(
                                      color: Color(0xFF2B2F3A),
                                      height: 20,
                                    ),
                                    _buildStaticSettingRow(
                                      'Throwable Limit',
                                      'Locked to YES',
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                            ],
                          ],
                        ),
                      ),

                      // Character Skills
                      _buildLabel('Character Skills'),
                      _buildYesNoToggle(
                        value: _characterSkill,
                        onChanged: (val) =>
                            setState(() => _characterSkill = val),
                      ),

                      // Animated expansion of Character Skill suboptions
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_characterSkill) ...[
                              const SizedBox(height: 12),
                              // Card 1
                              GestureDetector(
                                onTap: () => setState(() {
                                  _skillOption = 'except_trio';
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.battlyCard,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _skillOption == 'except_trio'
                                          ? const Color(0xFFFF6B00)
                                          : context.battlyBorder,
                                      width: 1.5,
                                    ),
                                    boxShadow: _skillOption == 'except_trio'
                                        ? [
                                            BoxShadow(
                                              color: const Color(
                                                0xFFFF6B00,
                                              ).withValues(alpha: 0.15),
                                              blurRadius: 10,
                                              offset: const Offset(0, 3),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Allow all active skills except Dmitri, Ryden, Orion',
                                        style: GoogleFonts.poppins(
                                          color: _skillOption == 'except_trio'
                                              ? Colors.white
                                              : context.battlyMuted,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Standard balanced tournament rules',
                                        style: GoogleFonts.poppins(
                                          color: const Color(0x60A0A0A0),
                                          fontSize: 9.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              // Card 2
                              GestureDetector(
                                onTap: () => setState(() {
                                  _skillOption = 'custom_list';
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.battlyCard,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _skillOption == 'custom_list'
                                          ? const Color(0xFFFF6B00)
                                          : context.battlyBorder,
                                      width: 1.5,
                                    ),
                                    boxShadow: _skillOption == 'custom_list'
                                        ? [
                                            BoxShadow(
                                              color: const Color(
                                                0xFFFF6B00,
                                              ).withValues(alpha: 0.15),
                                              blurRadius: 10,
                                              offset: const Offset(0, 3),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Select allowed active characters',
                                        style: GoogleFonts.poppins(
                                          color: _skillOption == 'custom_list'
                                              ? Colors.white
                                              : context.battlyMuted,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Manually select allowed active character skills',
                                        style: GoogleFonts.poppins(
                                          color: const Color(0x60A0A0A0),
                                          fontSize: 9.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Expandable Chip Wrap for character selection
                              AnimatedSize(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_skillOption == 'custom_list') ...[
                                      const SizedBox(height: 16),
                                      Text(
                                        'Allowed Active Characters (Select one or more):',
                                        style: GoogleFonts.poppins(
                                          color: context.battlyMuted,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: _allCharacters
                                            .map(
                                              (char) =>
                                                  _buildCharacterChip(char),
                                            )
                                            .toList(),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Host Mode
                      _buildLabel('Host Mode'),
                      _buildYesNoToggle(
                        value: _hostMode,
                        onChanged: (val) => setState(() => _hostMode = val),
                      ),
                      const SizedBox(height: 18),

                      // Gun Attributes
                      _buildLabel('Gun Attributes'),
                      _buildYesNoToggle(
                        value: _gunAttributes,
                        onChanged: (val) =>
                            setState(() => _gunAttributes = val),
                      ),
                      const SizedBox(height: 18),

                      // Match Rounds
                      _buildLabel('Rounds'),
                      Row(
                        children: [7, 13].map((r) {
                          final isSel = _rounds == r;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _rounds = r),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4.0,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12.0,
                                ),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? const Color(0xFFFF6B00)
                                      : context.battlyCard,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSel
                                        ? const Color(0xFFFF6B00)
                                        : context.battlyBorder,
                                  ),
                                  boxShadow: isSel
                                      ? [
                                          BoxShadow(
                                            color: const Color(
                                              0xFFFF6B00,
                                            ).withValues(alpha: 0.15),
                                            blurRadius: 6,
                                          ),
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '$r Rounds',
                                  style: GoogleFonts.poppins(
                                    color: isSel
                                        ? Colors.white
                                        : context.battlyMuted,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),

                      // Default Coin
                      _buildLabel('Default Coins'),
                      Row(
                        children: ['Default Coin', '9950'].map((coin) {
                          final isSel = _defaultCoin == coin;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _defaultCoin = coin),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4.0,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12.0,
                                ),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? const Color(0xFFFF6B00)
                                      : context.battlyCard,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSel
                                        ? const Color(0xFFFF6B00)
                                        : context.battlyBorder,
                                  ),
                                  boxShadow: isSel
                                      ? [
                                          BoxShadow(
                                            color: const Color(
                                              0xFFFF6B00,
                                            ).withValues(alpha: 0.15),
                                            blurRadius: 6,
                                          ),
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  coin,
                                  style: GoogleFonts.poppins(
                                    color: isSel
                                        ? Colors.white
                                        : context.battlyMuted,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),

                      // Room Creator
                      _buildLabel('Room Creator / Maker'),
                      TextFormField(
                        controller: _creatorController,
                        style: GoogleFonts.poppins(color: context.battlyOnSurface,
                          fontSize: 13,
                        ),
                        decoration: _buildInputDecoration(
                          'Your in-game / host name',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Room Creator is required'
                            : null,
                      ),
                      const SizedBox(height: 18),

                      // Entry Fee
                      _buildLabel('Entry Fee (NPR)'),
                      TextFormField(
                        controller: _entryFeeController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.poppins(color: context.battlyOnSurface,
                          fontSize: 13,
                        ),
                        decoration: _buildInputDecoration('0 for free entry'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Entry fee is required';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Must be a valid number';
                          }
                          return null;
                        },
                        onChanged: (val) {
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 18),

                      // Live Wallet Deduction & Balance Summary
                      if ((double.tryParse(_entryFeeController.text) ?? 0.0) > 0) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: context.battlyCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: context.battlyBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.account_balance_wallet_outlined,
                                    color: Color(0xFFFF6B00),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'WALLET DEDUCTION ESTIMATE',
                                    style: GoogleFonts.poppins(
                                      color: context.battlyOnSurface,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _feeRow(
                                'Deduction (Entry Fee)',
                                'NPR ${(double.tryParse(_entryFeeController.text) ?? 0.0).toInt()}',
                                const Color(0xFFFF6B00),
                              ),
                              const SizedBox(height: 8),
                              _feeRow(
                                'Your Wallet Balance',
                                _walletBalance == null
                                    ? 'Loading...'
                                    : 'NPR ${_walletBalance!.toInt()}',
                                _walletBalance == null
                                    ? context.battlyMuted
                                    : (_walletBalance! >= (double.tryParse(_entryFeeController.text) ?? 0.0)
                                        ? Colors.greenAccent
                                        : const Color(0xFFE53935)),
                              ),
                              if (_walletBalance != null &&
                                  _walletBalance! < (double.tryParse(_entryFeeController.text) ?? 0.0)) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE53935).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFE53935).withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.warning_amber_rounded,
                                        color: Color(0xFFE53935),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Insufficient balance. Please top up your wallet.',
                                          style: GoogleFonts.poppins(
                                            color: const Color(0xFFE53935),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // calculated winnings display panel
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFFF6B00,
                          ).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(
                              0xFFFF6B00,
                            ).withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'TOTAL WINNINGS / PRIZE POOL',
                                      style: GoogleFonts.poppins(
                                        color: context.battlyMuted,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Calculated based on $_maxPlayers players',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0x80A0A0A0),
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'NPR ${_calculatedWinnings.toInt()}',
                                  style: GoogleFonts.poppins(color: context.battlyOnSurface,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Divider(color: Color(0xFF2B2F3A)),
                            const SizedBox(height: 4),
                            Text(
                              'Platform commission of 10% applied automatically to the total entry fee collections.',
                              style: GoogleFonts.poppins(
                                color: const Color(0x80A0A0A0),
                                fontSize: 8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Rules & Regulations — tap to open sheet
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            final accepted = await showMatchRoomRulesSheet(context);
                            if (accepted == true && mounted) {
                              setState(() => _acceptedRules = true);
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: context.battlyCard,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: context.battlyBorder),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF6B00)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.article_outlined,
                                    color: Color(0xFFFF6B00),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Rules & Regulations',
                                        style: GoogleFonts.poppins(
                                          color: context.battlyOnSurface,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Tap to read hosting rules',
                                        style: GoogleFonts.poppins(
                                          color: context.battlyMuted,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: context.battlyMuted,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      CheckboxListTile(
                        value: _acceptedRules,
                        onChanged: (val) =>
                            setState(() => _acceptedRules = val ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        activeColor: const Color(0xFFFF6B00),
                        checkColor: Colors.white,
                        title: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'I agree that I have read all the ',
                                style: GoogleFonts.poppins(
                                  color: context.battlyMuted,
                                  fontSize: 11,
                                ),
                              ),
                              TextSpan(
                                text: 'Rules & Regulations',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFFFF6B00),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Color(0xFFFF6B00),
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () async {
                                    final accepted =
                                        await showMatchRoomRulesSheet(context);
                                    if (accepted == true && mounted) {
                                      setState(() => _acceptedRules = true);
                                    }
                                  },
                              ),
                              TextSpan(
                                text: ' for hosting custom match rooms.',
                                style: GoogleFonts.poppins(
                                  color: context.battlyMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // Bottom sticky publish button
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Color(0xFF0F1115),
                  border: Border(
                    top: BorderSide(color: Color(0xFF2B2F3A), width: 1.0),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B00),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      disabledBackgroundColor: const Color(0xFF3E4351),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Publish Match Room',
                            style: GoogleFonts.poppins(color: context.battlyOnSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 2),
      child: Text(
        text,
        style: GoogleFonts.poppins(color: context.battlyOnSurface.withValues(alpha: 0.7),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildYesNoToggle({
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.battlyCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.battlyBorder),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: value ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B00),
                  borderRadius: BorderRadius.circular(19),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B00).withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(true),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Text(
                      'YES',
                      style: GoogleFonts.poppins(
                        color: value ? Colors.white : context.battlyMuted,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(false),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Text(
                      'NO',
                      style: GoogleFonts.poppins(
                        color: !value ? Colors.white : context.battlyMuted,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterChip(String name) {
    final isSelected = _allowedCharacters.contains(name);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _allowedCharacters.remove(name);
          } else {
            _allowedCharacters.add(name);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF6B00).withValues(alpha: 0.15)
              : context.battlyCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF6B00)
                : context.battlyBorder,
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF6B00).withValues(alpha: 0.1),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
        child: Text(
          name,
          style: GoogleFonts.poppins(
            color: isSelected ? Colors.white : context.battlyMuted,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildStaticSettingRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: context.battlyMuted,
            fontSize: 12,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B00).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            value,
            style: GoogleFonts.poppins(
              color: const Color(0xFFFF6B00),
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(
        color: const Color(0x60A0A0A0),
        fontSize: 12,
      ),
      filled: true,
      fillColor: context.battlyCard,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Color(0xFF2B2F3A)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Color(0xFFFF6B00), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Color(0xFF2B2F3A)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Color(0xFFE53935)),
      ),
      errorStyle: GoogleFonts.poppins(
        color: const Color(0xFFE53935),
        fontSize: 10,
      ),
    );
  }
}
