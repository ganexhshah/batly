import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_models.dart';
import '../core/theme/battly_theme.dart';

void showBattlySearchSheet(
  BuildContext context, {
  required List<UpcomingTournament> items,
  required void Function(UpcomingTournament selectedItem) onSelected,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    isScrollControlled: true,
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return _BattlySearchSheetContent(
            items: items,
            onSelected: onSelected,
            scrollController: scrollController,
          );
        },
      );
    },
  );
}

class _BattlySearchSheetContent extends StatefulWidget {
  final List<UpcomingTournament> items;
  final void Function(UpcomingTournament selectedItem) onSelected;
  final ScrollController scrollController;

  const _BattlySearchSheetContent({
    required this.items,
    required this.onSelected,
    required this.scrollController,
  });

  @override
  State<_BattlySearchSheetContent> createState() => _BattlySearchSheetContentState();
}

class _BattlySearchSheetContentState extends State<_BattlySearchSheetContent> {
  late final TextEditingController _searchController;
  late List<UpcomingTournament> _filteredList;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filteredList = List.from(widget.items);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _filteredList = widget.items.where((t) {
        final matchesTitle = t.title.toLowerCase().contains(query.toLowerCase());
        final matchesMode = t.mode.toLowerCase().contains(query.toLowerCase());
        final matchesType = t.type.toLowerCase().contains(query.toLowerCase());
        return matchesTitle || matchesMode || matchesType;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF0F1115),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(color: Color(0xFF2B2F3A), width: 1.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          // Handle Bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF3E4351),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          
          // Title and Close Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Search Tournaments',
                style: GoogleFonts.poppins(color: context.battlyOnSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Color(0xFF1E222A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFFA0A0A0),
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Search Input Text Field
          TextField(
            controller: _searchController,
            autofocus: true,
            style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 13),
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Type tournament title, mode, or type...',
              hintStyle: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFFF6B00), size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, color: Color(0xFFA0A0A0), size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              fillColor: context.battlyCard,
              filled: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFF2B2F3A), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFFFF6B00), width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFF2B2F3A), width: 1),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Results List / Empty State
          Expanded(
            child: _filteredList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.search_off_rounded,
                          color: Color(0xFFA0A0A0),
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No results found',
                          style: GoogleFonts.poppins(
                            color: context.battlyMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try searching for another keyword.',
                          style: GoogleFonts.poppins(
                            color: context.battlyMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: widget.scrollController,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _filteredList.length,
                    itemBuilder: (context, index) {
                      final t = _filteredList[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: context.battlyCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.battlyBorder, width: 1),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          leading: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: context.battlyScaffold,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Image.asset(
                              t.logoAsset ?? 'assets/logo/battly_cup.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.emoji_events,
                                color: Color(0xFFFF6B00),
                                size: 24,
                              ),
                            ),
                          ),
                          title: Text(
                            t.title,
                            style: GoogleFonts.poppins(color: context.battlyOnSurface,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Row(
                              children: [
                                // Type Tag (e.g. Squad)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF6B00).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: const Color(0xFFFF6B00).withValues(alpha: 0.3),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Text(
                                    t.type,
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFFFF6B00),
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Mode / Prize
                                Text(
                                  '${t.mode} • ${t.prizePool}',
                                  style: GoogleFonts.poppins(
                                    color: context.battlyMuted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFFA0A0A0),
                            size: 20,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            widget.onSelected(t);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
