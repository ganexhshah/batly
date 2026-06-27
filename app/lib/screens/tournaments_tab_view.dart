import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/responsive/responsive.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import '../widgets/app_network_image.dart';
import '../widgets/lobby_tournament_card.dart';
import '../widgets/battly_filter_sheet.dart';
import '../widgets/battly_search_sheet.dart';
import '../widgets/skeleton_widgets.dart';
import 'tournament/tournament_screen.dart';
import 'tournament/create_tournament_screen.dart';
import '../core/theme/battly_theme.dart';

class TournamentsTabView extends StatefulWidget {
  const TournamentsTabView({super.key});

  @override
  State<TournamentsTabView> createState() => _TournamentsTabViewState();
}

class _TournamentsTabViewState extends State<TournamentsTabView> {
  bool _loading = true;
  List<UpcomingTournament> _tournaments = [];

  String _selectedType = 'All';
  String _selectedMode = 'All';
  String _selectedEntryFee = 'All';

  List<UpcomingTournament> get _filteredTournaments {
    return _tournaments.where((t) {
      final matchesType =
          _selectedType == 'All' ||
          t.type.toLowerCase() == _selectedType.toLowerCase();
      final matchesMode =
          _selectedMode == 'All' ||
          t.mode.toLowerCase() == _selectedMode.toLowerCase();

      bool matchesFee = true;
      if (_selectedEntryFee == 'Free') {
        matchesFee =
            t.entryFee.toLowerCase().contains('free') || t.entryFee == 'NPR 0';
      } else if (_selectedEntryFee == 'Paid') {
        matchesFee =
            !t.entryFee.toLowerCase().contains('free') && t.entryFee != 'NPR 0';
      }

      return matchesType && matchesMode && matchesFee;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _showCachedTournaments();
    _fetchTournaments();
  }

  Future<void> _showCachedTournaments() async {
    final cached = await ApiService.peekUpcomingTournaments();
    if (cached.isEmpty || !mounted) return;
    setState(() {
      _tournaments = cached;
      _loading = false;
    });
  }

  Future<void> _fetchTournaments({bool forceRefresh = false}) async {
    try {
      final results = forceRefresh
          ? await ApiService.forceUpcomingTournaments()
          : await ApiService.getUpcomingTournaments();
      if (mounted) {
        setState(() {
          _tournaments = results;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFE53935),
            content: Text(
              'Failed to load tournaments: ${e.toString()}',
              style: GoogleFonts.poppins(color: context.battlyOnSurface),
            ),
          ),
        );
      }
    }
  }

  Future<void> _onRefresh() => _fetchTournaments(forceRefresh: true);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: context.battlyScaffold,
        appBar: AppBar(
          backgroundColor: context.battlyScaffold,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            'Tournaments',
            style: GoogleFonts.poppins(color: context.battlyOnSurface,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(
                Icons.search_rounded,
                color: Colors.white,
                size: 24,
              ),
              onPressed: () {
                showBattlySearchSheet(
                  context,
                  items: _tournaments,
                  onSelected: (selectedItem) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            TournamentScreen(tournament: selectedItem),
                      ),
                    );
                  },
                );
              },
            ),
            IconButton(
              icon: Icon(
                Icons.tune_rounded,
                color:
                    (_selectedType != 'All' ||
                        _selectedMode != 'All' ||
                        _selectedEntryFee != 'All')
                    ? const Color(0xFFFF6B00)
                    : Colors.white,
                size: 24,
              ),
              onPressed: () {
                showBattlyFilterSheet(
                  context,
                  initialType: _selectedType,
                  initialMode: _selectedMode,
                  initialFee: _selectedEntryFee,
                  onApply: (type, mode, fee) {
                    setState(() {
                      _selectedType = type;
                      _selectedMode = mode;
                      _selectedEntryFee = fee;
                    });
                  },
                );
              },
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: const Color(0xFFFF6B00),
                labelColor: const Color(0xFFFF6B00),
                unselectedLabelColor: context.battlyMuted,
                labelStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                unselectedLabelStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'All'),
                  Tab(text: 'Upcoming'),
                  Tab(text: 'Live'),
                  Tab(text: 'Completed'),
                ],
              ),
            ),
          ),
        ),
        body: _loading
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: List.generate(
                  4,
                  (_) => const SkeletonTournamentCard(),
                ),
              )
            : TabBarView(
                children: [
                  _buildAllTabContent(),
                  _buildUpcomingTabContent(),
                  _buildLiveTabContent(),
                  _buildCompletedTabContent(),
                ],
              ),
      ),
    );
  }

  Widget _buildAllTabContent() {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: const Color(0xFFFF6B00),
      backgroundColor: context.battly.elevatedSurface,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LobbyFeaturedBanner(allTournaments: _tournaments),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ResponsiveContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Text(
                    'Upcoming Tournaments',
                    style: GoogleFonts.poppins(color: context.battlyOnSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _filteredTournaments.isEmpty
                      ? const _TournamentEmptyState(
                          message:
                              'No tournaments found\nmatching current filters.',
                        )
                      : ResponsiveColumns(
                          mediumColumns: 2,
                          expandedColumns: 2,
                          children: _filteredTournaments
                              .map(
                                (t) => LobbyTournamentCard(
                                  tournament: t,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            TournamentScreen(tournament: t),
                                      ),
                                    );
                                  },
                                ),
                              )
                              .toList(),
                        ),
                  const SizedBox(height: 12),
                  CreateTournamentCard(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateTournamentScreen(),
                        ),
                      );
                      if (result == true) {
                        _fetchTournaments(forceRefresh: true);
                      }
                    },
                  ),
                ],
              ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingTabContent() {
    final upcomingOnly = _filteredTournaments
        .where(
          (t) =>
              ['UPCOMING', 'REGISTRATION'].contains(t.statusText.toUpperCase()),
        )
        .toList();
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: const Color(0xFFFF6B00),
      backgroundColor: context.battly.elevatedSurface,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Upcoming Matches Only',
              style: GoogleFonts.poppins(color: context.battlyOnSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (upcomingOnly.isEmpty)
              const _TournamentEmptyState(
                message: 'No upcoming matches\nmatching current filters.',
              )
            else
              Column(
                children: upcomingOnly
                    .map(
                      (t) => LobbyTournamentCard(
                        tournament: t,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  TournamentScreen(tournament: t),
                            ),
                          );
                        },
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveTabContent() {
    final liveOnly = _filteredTournaments
        .where((t) => t.statusText.toUpperCase() == 'LIVE')
        .toList();
    return _buildStatusList(liveOnly, 'No live tournaments running right now.');
  }

  Widget _buildCompletedTabContent() {
    final completedOnly = _filteredTournaments
        .where((t) => t.statusText.toUpperCase() == 'COMPLETED')
        .toList();
    return _buildStatusList(completedOnly, 'No completed tournaments yet.');
  }

  Widget _buildStatusList(List<UpcomingTournament> items, String emptyText) {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: const Color(0xFFFF6B00),
      backgroundColor: context.battly.elevatedSurface,
      child: items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              children: [_TournamentEmptyState(message: emptyText)],
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: items
                  .map(
                    (t) => LobbyTournamentCard(
                      tournament: t,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                TournamentScreen(tournament: t),
                          ),
                        );
                      },
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

// -----------------------------------------------------------------------------
// LOBBY FEATURED TROPHY BANNER
// -----------------------------------------------------------------------------
class LobbyFeaturedBanner extends StatefulWidget {
  final List<UpcomingTournament> allTournaments;
  const LobbyFeaturedBanner({super.key, required this.allTournaments});

  @override
  State<LobbyFeaturedBanner> createState() => _LobbyFeaturedBannerState();
}

class _LobbyFeaturedBannerState extends State<LobbyFeaturedBanner> {
  bool _loading = true;
  List<FeaturedTournament> _featured = [];
  int _currentIndex = 0;
  Timer? _timer;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadFeatured();
  }

  Future<void> _loadFeatured() async {
    try {
      final data = await ApiService.forceBanners();
      if (mounted) {
        setState(() {
          _featured = data;
          _loading = false;
        });
        _startAutoPlay();
      }
    } catch (_) {
      try {
        final cachedData = await ApiService.getBanners();
        if (mounted) {
          setState(() {
            _featured = cachedData;
            _loading = false;
          });
          _startAutoPlay();
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _loading = false;
          });
        }
      }
    }
  }

  void _startAutoPlay() {
    if (_featured.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients) {
        final nextPage = (_currentIndex + 1) % _featured.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleSlideTap(FeaturedTournament f) async {
    if (f.id == null) return;

    final match = widget.allTournaments.firstWhere(
      (t) => t.id == f.id,
      orElse: () => UpcomingTournament(
        id: f.id,
        title: f.title,
        type: 'Squad',
        mode: 'Battle Royale',
        dateText: f.dateText,
        currentPlayers: 0,
        maxPlayers: 100,
        prizePool: f.prizePool,
        entryFee: 'Free',
        statusText: f.isLive ? 'LIVE' : 'UPCOMING',
        timerDuration: Duration.zero,
      ),
    );

    final bool foundInList = widget.allTournaments.any((t) => t.id == f.id);

    if (foundInList) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TournamentScreen(tournament: match),
        ),
      );
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B00)),
          ),
        ),
      );

      try {
        final fullTournament = await ApiService.getTournament(f.id!);
        if (mounted) {
          Navigator.pop(context); // Dismiss loading dialog
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  TournamentScreen(tournament: fullTournament),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Dismiss loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFE53935),
              content: Text(
                'Failed to load tournament details: $e',
                style: GoogleFonts.poppins(color: context.battlyOnSurface),
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bannerHeight = context.isExpanded ? 220.0 : 180.0;

    if (_loading) {
      return SizedBox(
        height: bannerHeight,
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B00)),
          ),
        ),
      );
    }

    if (_featured.isEmpty) {
      return _buildFallbackBanner(bannerHeight);
    }

    return SizedBox(
      height: bannerHeight,
      width: double.infinity,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemCount: _featured.length,
            itemBuilder: (context, index) {
              return _buildSlideItem(_featured[index]);
            },
          ),
          if (_featured.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_featured.length, (index) {
                  final isActive = index == _currentIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFFFF6B00)
                          : const Color(0xFF3E4351),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSlideItem(FeaturedTournament f) {
    final hasImage = f.imagePath.trim().isNotEmpty;

    return GestureDetector(
      onTap: () => _handleSlideTap(f),
      child: Stack(
        children: [
          Positioned.fill(
            child: hasImage
                ? _buildBannerImage(f.imagePath)
                : _buildTextBannerBackground(),
          ),
          if (hasImage)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.95),
                      Colors.black.withValues(alpha: 0.6),
                      Colors.black.withValues(alpha: 0.15),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),
          if (f.isLive)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'LIVE',
                      style: GoogleFonts.poppins(color: context.battlyOnSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Featured Tournament',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFFF6B00),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  f.title,
                  style: GoogleFonts.poppins(color: context.battlyOnSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    height: 1.1,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  'Prize Pool: ${f.prizePool} • ${f.dateText}',
                  style: GoogleFonts.poppins(
                    color: context.battlyMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerImage(String imagePath) {
    final uri = Uri.tryParse(imagePath);
    final isNetworkImage = uri != null && uri.hasScheme;

    if (isNetworkImage) {
      return AppNetworkImage(
        url: imagePath,
        fit: BoxFit.cover,
        alignment: const Alignment(0.4, -0.2),
        errorWidget: _buildTextBannerBackground(),
      );
    }

    return Image.asset(
      imagePath,
      fit: BoxFit.cover,
      alignment: const Alignment(0.4, -0.2),
      errorBuilder: (context, error, stackTrace) =>
          _buildTextBannerBackground(),
    );
  }

  Widget _buildTextBannerBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/background/tournment.png',
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withValues(alpha: 0.85),
                Colors.black.withValues(alpha: 0.55),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackBanner(double height) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.battlyCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.battlyBorder, width: 1),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/background/tournment.png',
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.95),
                    Colors.black.withValues(alpha: 0.6),
                    Colors.black.withValues(alpha: 0.15),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Battly Championship',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFFF6B00),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'THE BATTLE\nAWAITS',
                  style: GoogleFonts.poppins(color: context.battlyOnSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Compete. Conquer. Win.',
                  style: GoogleFonts.poppins(
                    color: context.battlyMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// CREATE TOURNAMENT CARD
// -----------------------------------------------------------------------------
class CreateTournamentCard extends StatelessWidget {
  final VoidCallback onTap;
  const CreateTournamentCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.battly.elevatedSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Clipboard icon with orange "+" badge
          SizedBox(
            width: 38,
            height: 38,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF252830),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.assignment_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                Positioned(
                  bottom: -3,
                  right: -3,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Color(0xFFFF6B00),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 10),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Your Tournament',
                  style: GoogleFonts.poppins(color: context.battlyOnSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Organize your own tournament and compete with others.',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF8A8F9E),
                    fontSize: 10,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Create Now button
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B00),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Create Now',
                style: GoogleFonts.poppins(color: context.battlyOnSurface,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────
class _TournamentEmptyState extends StatelessWidget {
  final String message;
  const _TournamentEmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.52,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/background/tournment.png',
              width: 180,
              height: 180,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: context.battlyMuted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
