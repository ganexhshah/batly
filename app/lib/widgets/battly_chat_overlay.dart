import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../core/cache_debug.dart';
import 'floating_chat_panel.dart';
import '../core/theme/battly_theme.dart';

/// Global draggable chat bubble + expandable chat panel overlay.
class BattlyChatOverlay extends StatefulWidget {
  const BattlyChatOverlay({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  State<BattlyChatOverlay> createState() => _BattlyChatOverlayState();
}

/// Wraps the app and enables chat overlay only for logged-in users with a game profile.
class BattlyChatOverlayHost extends StatefulWidget {
  const BattlyChatOverlayHost({super.key, required this.child});

  final Widget child;

  @override
  State<BattlyChatOverlayHost> createState() => _BattlyChatOverlayHostState();
}

class _BattlyChatOverlayHostState extends State<BattlyChatOverlayHost> {
  bool _enabled = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final token = await AuthService.getToken();
    final user = token == null ? null : await AuthService.getCachedUser();
    final hasProfile = user != null &&
        (user['game_uid']?.toString().trim().isNotEmpty ?? false) &&
        (user['ign']?.toString().trim().isNotEmpty ?? false);

    if (!mounted) return;
    setState(() {
      _enabled = token != null && hasProfile;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return widget.child;
    return BattlyChatOverlay(enabled: _enabled, child: widget.child);
  }
}

class _BattlyChatOverlayState extends State<BattlyChatOverlay> {
  static const double _bubbleSize = 56;
  static const double _margin = 16;

  bool _expanded = false;
  bool _fullScreen = false;
  Offset? _bubbleOffset;
  int _totalUnread = 0;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _loadUnreadCount();
  }

  @override
  void didUpdateWidget(covariant BattlyChatOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) {
      _loadUnreadCount();
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final conversations = await ChatService.getConversations();
      var total = 0;
      for (final c in conversations) {
        total += c['unread_count'] as int? ?? 0;
      }
      if (mounted) setState(() => _totalUnread = total);
    } catch (e, st) {
      logCacheRefreshFailure('chatOverlayUnread', e, st);
    }
  }

  Offset _defaultOffset(Size screen, EdgeInsets padding) {
    return Offset(
      screen.width - _bubbleSize - _margin - padding.right,
      screen.height - _bubbleSize - _margin - padding.bottom - 72,
    );
  }

  void _togglePanel() {
    setState(() {
      _expanded = !_expanded;
      if (!_expanded) _fullScreen = false;
    });
    if (!_expanded) _loadUnreadCount();
  }

  void _closePanel() {
    setState(() {
      _expanded = false;
      _fullScreen = false;
    });
    _loadUnreadCount();
  }

  void _toggleFullScreen() {
    setState(() => _fullScreen = !_fullScreen);
  }

  double _safeClamp(double value, double min, double max) {
    if (max < min) return min;
    return value.clamp(min, max);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = Size(constraints.maxWidth, constraints.maxHeight);
        if (screen.width < 200 || screen.height < 200) {
          return widget.child;
        }

        final padding = MediaQuery.paddingOf(context);
        final offset = _bubbleOffset ?? _defaultOffset(screen, padding);

        final panelWidth = _safeClamp(
          screen.width * 0.92,
          200,
          screen.width - _margin * 2,
        );
        final panelHeight = _safeClamp(
          screen.height * 0.55,
          240,
          screen.height - padding.top - padding.bottom - _bubbleSize - _margin * 3,
        );

        final bubbleLeftMax = screen.width - _bubbleSize - _margin;
        final bubbleTopMax = screen.height - _bubbleSize - _margin;
        final bubbleLeft = _safeClamp(offset.dx, _margin, bubbleLeftMax);
        final bubbleTop = _safeClamp(offset.dy, padding.top + _margin, bubbleTopMax);

        final panelLeft = _safeClamp(
          bubbleLeft + _bubbleSize / 2 - panelWidth / 2,
          _margin,
          screen.width - panelWidth - _margin,
        );
        final panelTop = _safeClamp(
          bubbleTop - panelHeight - 12,
          padding.top + _margin,
          screen.height - panelHeight - _margin,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (_expanded && !_fullScreen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closePanel,
                  child: Container(color: Colors.black.withValues(alpha: 0.35)),
                ),
              ),
            if (_expanded && _fullScreen)
              Positioned.fill(
                child: SafeArea(
                  child: FloatingChatPanel(
                    isFullScreen: true,
                    onClose: _closePanel,
                    onToggleFullScreen: _toggleFullScreen,
                  ),
                ),
              )
            else if (_expanded)
              Positioned(
                left: panelLeft,
                top: panelTop,
                child: FloatingChatPanel(
                  maxWidth: panelWidth,
                  maxHeight: panelHeight,
                  onClose: _closePanel,
                  onToggleFullScreen: _toggleFullScreen,
                ),
              ),
            if (!_fullScreen)
              Positioned(
              left: bubbleLeft,
              top: bubbleTop,
              child: _DraggableChatBubble(
                size: _bubbleSize,
                expanded: _expanded,
                unreadCount: _totalUnread,
                onDrag: (delta, size, pad) {
                  final current = _bubbleOffset ?? _defaultOffset(size, pad);
                  final maxLeft = size.width - _bubbleSize - _margin;
                  final maxTop = size.height - _bubbleSize - _margin;
                  setState(() {
                    _bubbleOffset = Offset(
                      _safeClamp(current.dx + delta.dx, _margin, maxLeft),
                      _safeClamp(current.dy + delta.dy, pad.top + _margin, maxTop),
                    );
                  });
                },
                onTap: _togglePanel,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DraggableChatBubble extends StatefulWidget {
  const _DraggableChatBubble({
    required this.size,
    required this.expanded,
    required this.unreadCount,
    required this.onDrag,
    required this.onTap,
  });

  final double size;
  final bool expanded;
  final int unreadCount;
  final void Function(Offset delta, Size screen, EdgeInsets padding) onDrag;
  final VoidCallback onTap;

  @override
  State<_DraggableChatBubble> createState() => _DraggableChatBubbleState();
}

class _DraggableChatBubbleState extends State<_DraggableChatBubble> {
  Offset _dragDelta = Offset.zero;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);

    return GestureDetector(
      onPanStart: (_) {
        setState(() {
          _dragging = true;
          _dragDelta = Offset.zero;
        });
      },
      onPanUpdate: (details) {
        _dragDelta += details.delta;
        widget.onDrag(details.delta, screen, padding);
      },
      onPanEnd: (_) {
        final moved = _dragDelta.distance;
        setState(() => _dragging = false);
        if (moved < 8) widget.onTap();
      },
      child: Material(
        elevation: widget.expanded ? 8 : 6,
        shadowColor: const Color(0xFFFF6B00).withValues(alpha: 0.35),
        color: widget.expanded ? context.battly.elevatedSurface : const Color(0xFFFF6B00),
        shape: const CircleBorder(),
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                widget.expanded ? Icons.close_rounded : Icons.chat_bubble_rounded,
                color: Colors.white,
                size: widget.expanded ? 26 : 24,
              ),
              if (!widget.expanded && widget.unreadCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.battlyScaffold, width: 1.5),
                    ),
                    child: Text(
                      widget.unreadCount > 9 ? '9+' : '${widget.unreadCount}',
                      style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              if (_dragging)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
