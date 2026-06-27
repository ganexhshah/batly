import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../models/app_models.dart';
import '../../core/theme/battly_theme.dart';

class MyMatchesScreen extends StatefulWidget {
  const MyMatchesScreen({super.key});

  @override
  State<MyMatchesScreen> createState() => _MyMatchesScreenState();
}

class _MyMatchesScreenState extends State<MyMatchesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['All', 'Completed', 'Upcoming'];

  bool _isLoading = true;
  String? _errorMessage;
  List<RecentMatch> _matches = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadMatches();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMatches() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final list = await ApiService.getRecentMatches();
      if (mounted) {
        setState(() {
          _matches = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load match history: $e';
        });
      }
    }
  }

  List<RecentMatch> _getFilteredMatches() {
    final activeTab = _tabs[_tabController.index];
    if (activeTab == 'Completed') {
      return _matches.where((m) => m.rankString != 'Pending').toList();
    } else if (activeTab == 'Upcoming') {
      return _matches.where((m) => m.rankString == 'Pending').toList();
    }
    return _matches;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredMatches();

    return Scaffold(
      backgroundColor: context.battlyScaffold,
      appBar: AppBar(
        backgroundColor: context.battlyScaffold,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 48,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        titleSpacing: 12,
        title: Text(
          'My Matches',
          style: GoogleFonts.poppins(color: context.battlyOnSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: Column(
        children: [
          // Tab bar selection
          TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFFFF6B00),
            indicatorWeight: 3,
            labelColor: Colors.white,
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelColor: context.battlyMuted,
            unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13),
            dividerColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            tabs: _tabs.map((name) => Tab(text: name)).toList(),
          ),
          const SizedBox(height: 12),

          // Matches List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B00)),
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _errorMessage!,
                              style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _loadMatches,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF6B00),
                              ),
                              child: Text('Retry', style: GoogleFonts.poppins(color: context.battlyOnSurface)),
                            ),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                        ? Center(
                            child: Text(
                              'No matches found in this tab',
                              style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 13),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadMatches,
                            color: const Color(0xFFFF6B00),
                            backgroundColor: context.battlyCard,
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                return _buildMatchCard(item);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchCard(RecentMatch record) {
    final isCompleted = record.rankString != 'Pending';
    final mode = record.type;
    
    double prizeReward = 0.0;
    if (record.rankString.startsWith('#1/')) {
      prizeReward = 1500.0;
    } else if (record.rankString.startsWith('#3/')) {
      prizeReward = 300.0;
    } else if (record.rankString.startsWith('#1/2')) {
      prizeReward = 100.0;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.battlyCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.battlyBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title + Status Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  record.title,
                  style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 13, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isCompleted 
                      ? const Color(0xFF4CAF50).withValues(alpha: 0.12)
                      : const Color(0xFFFF9800).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isCompleted ? 'COMPLETED' : 'UPCOMING',
                  style: GoogleFonts.poppins(
                    color: isCompleted ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          
          // Mode Details
          Text(
            mode,
            style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 10),
          ),
          const SizedBox(height: 12),

          // Divider
          Container(height: 1, color: context.battlyBorder),
          const SizedBox(height: 12),

          // Footer: Placement, Kills, Reward details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PLACEMENT',
                    style: GoogleFonts.poppins(color: const Color(0x60A0A0A0), fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    record.rankString,
                    style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'KILLS',
                    style: GoogleFonts.poppins(color: const Color(0x60A0A0A0), fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    record.killsText,
                    style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'REWARD',
                    style: GoogleFonts.poppins(color: const Color(0x60A0A0A0), fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    prizeReward > 0 
                        ? '+ NPR ${prizeReward.toStringAsFixed(0)}'
                        : 'NPR 0',
                    style: GoogleFonts.poppins(
                      color: prizeReward > 0 ? const Color(0xFF4CAF50) : context.battlyMuted, 
                      fontSize: 12, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          
          // Date details
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Icon(Icons.access_time_rounded, color: Color(0x60A0A0A0), size: 10),
              const SizedBox(width: 4),
              Text(
                record.dateText,
                style: GoogleFonts.poppins(color: const Color(0x60A0A0A0), fontSize: 8.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
