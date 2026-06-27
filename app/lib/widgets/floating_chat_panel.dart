import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import 'app_network_image.dart';
import 'tournament_chat_tab.dart';
import '../core/theme/battly_theme.dart';

/// In-overlay chat: conversation list + active thread.
class FloatingChatPanel extends StatefulWidget {
  const FloatingChatPanel({
    super.key,
    required this.onClose,
    this.maxHeight,
    this.maxWidth,
    this.isFullScreen = false,
    this.onToggleFullScreen,
  });

  final VoidCallback onClose;
  final double? maxHeight;
  final double? maxWidth;
  final bool isFullScreen;
  final VoidCallback? onToggleFullScreen;

  @override
  State<FloatingChatPanel> createState() => _FloatingChatPanelState();
}

class _FloatingChatPanelState extends State<FloatingChatPanel> {
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _lobbyChats = [];
  bool _loading = true;
  String? _error;

  int? _activeConversationId;
  int? _activeRecipientId;
  String _activeRecipientName = '';
  UpcomingTournament? _activeLobbyTournament;

  bool get _inThread => _activeConversationId != null || _activeLobbyTournament != null;

  String get _headerTitle {
    if (_activeLobbyTournament != null) return _activeLobbyTournament!.title;
    if (_activeConversationId != null) return _activeRecipientName;
    return 'Messages';
  }

  @override
  void initState() {
    super.initState();
    _showCachedInbox();
    _loadInbox();
  }

  Future<void> _showCachedInbox() async {
    final results = await Future.wait([
      ChatService.peekConversations(),
      ApiService.peekLobbyChats(),
    ]);
    if (!mounted) return;
    final conversations = results[0];
    final lobbyChats = results[1];
    if (conversations.isEmpty && lobbyChats.isEmpty) return;
    setState(() {
      _conversations = conversations;
      _lobbyChats = lobbyChats;
      _loading = false;
    });
  }

  Future<void> _loadInbox() async {
    if (_conversations.isEmpty && _lobbyChats.isEmpty) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
    final results = await Future.wait<List<dynamic>>([
      ChatService.getConversations(),
      ApiService.getMyLobbyChats(),
    ]);
      if (!mounted) return;
      setState(() {
        _conversations = results[0] as List<Map<String, dynamic>>;
        _lobbyChats = results[1] as List<Map<String, dynamic>>;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load chats';
      });
    }
  }

  void _openConversation(Map<String, dynamic> conversation) {
    final other = conversation['other_user'] as Map<String, dynamic>?;
    setState(() {
      _activeLobbyTournament = null;
      _activeConversationId = conversation['id'] as int?;
      _activeRecipientId = other?['id'] as int?;
      _activeRecipientName = other?['ign'] as String? ?? other?['name'] as String? ?? 'Player';
    });
  }

  void _openLobbyChat(Map<String, dynamic> lobby) {
    final id = lobby['tournament_id'] as int?;
    if (id == null) return;
    setState(() {
      _activeConversationId = null;
      _activeRecipientId = null;
      _activeRecipientName = '';
      _activeLobbyTournament = UpcomingTournament.lobbyChat(
        id: id,
        title: lobby['title'] as String? ?? 'Lobby',
        chatOpen: lobby['chat_open'] as bool? ?? false,
      );
    });
  }

  void _closeThread() {
    setState(() {
      _activeConversationId = null;
      _activeRecipientId = null;
      _activeRecipientName = '';
      _activeLobbyTournament = null;
    });
    _loadInbox();
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        _FloatingChatHeader(
          title: _headerTitle,
          subtitle: _activeLobbyTournament != null ? 'Lobby chat' : null,
          showBack: _inThread,
          onBack: _closeThread,
          onClose: widget.onClose,
          onRefresh: !_inThread ? _loadInbox : null,
          isFullScreen: widget.isFullScreen,
          onToggleFullScreen: widget.onToggleFullScreen,
        ),
        Expanded(
          child: _activeLobbyTournament != null
              ? TournamentChatTab(tournament: _activeLobbyTournament!)
              : _activeConversationId != null && _activeRecipientId != null
                  ? _FloatingChatThread(
                      conversationId: _activeConversationId!,
                      recipientId: _activeRecipientId!,
                      recipientName: _activeRecipientName,
                    )
                  : _buildInboxList(),
        ),
      ],
    );

    if (widget.isFullScreen) {
      return Material(
        color: context.battlyScaffold,
        child: SizedBox.expand(child: content),
      );
    }

    final width = widget.maxWidth ?? 340.0;
    final height = widget.maxHeight ?? 460.0;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: context.battlyScaffold,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.battlyBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: content,
      ),
    );
  }

  Widget _buildInboxList() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF6B00), strokeWidth: 2),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(_error!, style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 13)),
        ),
      );
    }
    if (_lobbyChats.isEmpty && _conversations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline_rounded, color: const Color(0xFF6B6F7A).withValues(alpha: 0.8), size: 36),
              const SizedBox(height: 10),
              Text(
                'No chats yet',
                style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'Join a tournament lobby or message players from their profile.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: const Color(0xFF6B6F7A), fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (_lobbyChats.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
            child: Text(
              'LOBBY CHATS',
              style: GoogleFonts.poppins(
                color: const Color(0xFF6B6F7A),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
              ),
            ),
          ),
          ..._lobbyChats.map((lobby) => _LobbyChatTile(
                lobby: lobby,
                onTap: () => _openLobbyChat(lobby),
              )),
          if (_conversations.isNotEmpty) Divider(height: 16, color: Color(0xFF1E222A)),
        ],
        if (_conversations.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
            child: Text(
              'DIRECT MESSAGES',
              style: GoogleFonts.poppins(
                color: const Color(0xFF6B6F7A),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
              ),
            ),
          ),
          ..._conversations.map((c) => Column(
                children: [
                  _ConversationTile(
                    conversation: c,
                    onTap: () => _openConversation(c),
                  ),
                  Divider(height: 1, color: Color(0xFF1E222A)),
                ],
              )),
        ],
      ],
    );
  }
}

class _FloatingChatHeader extends StatelessWidget {
  const _FloatingChatHeader({
    required this.title,
    required this.showBack,
    required this.onBack,
    required this.onClose,
    this.subtitle,
    this.onRefresh,
    this.isFullScreen = false,
    this.onToggleFullScreen,
  });

  final String title;
  final String? subtitle;
  final bool showBack;
  final VoidCallback onBack;
  final VoidCallback onClose;
  final VoidCallback? onRefresh;
  final bool isFullScreen;
  final VoidCallback? onToggleFullScreen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Color(0xFF15181E),
        border: Border(bottom: BorderSide(color: Color(0xFF2B2F3A))),
      ),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              onPressed: onBack,
              visualDensity: VisualDensity.compact,
            )
          else
            const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: GoogleFonts.poppins(color: const Color(0xFF4CAF50), fontSize: 10, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (onRefresh != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFFA0A0A0), size: 20),
              onPressed: onRefresh,
              visualDensity: VisualDensity.compact,
            ),
          if (onToggleFullScreen != null)
            IconButton(
              icon: Icon(
                isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                color: context.battlyMuted,
                size: 20,
              ),
              onPressed: onToggleFullScreen,
              visualDensity: VisualDensity.compact,
            ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Color(0xFFA0A0A0), size: 20),
            onPressed: onClose,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _LobbyChatTile extends StatelessWidget {
  const _LobbyChatTile({
    required this.lobby,
    required this.onTap,
  });

  final Map<String, dynamic> lobby;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = lobby['title'] as String? ?? 'Lobby';
    final statusText = lobby['status_text'] as String? ?? 'UPCOMING';
    final chatOpen = lobby['chat_open'] as bool? ?? false;
    final closedReason = lobby['closed_reason'] as String?;
    final last = lobby['last_message'] as Map<String, dynamic>?;
    final preview = !chatOpen
        ? (closedReason ?? 'Chat ended — match finished')
        : last != null
            ? '${last['sender_name'] as String? ?? 'Player'}: ${last['body'] as String? ?? ''}'
            : 'Open lobby chat';
    final isLive = statusText.toLowerCase() == 'live';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.35)),
              ),
              child: const Icon(Icons.groups_rounded, color: Color(0xFF4CAF50), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.poppins(color: context.battlyOnSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isLive ? const Color(0xFFE53935) : context.battlyBorder)
                              .withValues(alpha: isLive ? 0.2 : 1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusText,
                          style: GoogleFonts.poppins(
                            color: isLive ? const Color(0xFFE53935) : context.battlyMuted,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    style: GoogleFonts.poppins(
                      color: chatOpen ? const Color(0xFF6B6F7A) : const Color(0xFFE53935),
                      fontSize: 11,
                      fontStyle: chatOpen ? FontStyle.normal : FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF6B6F7A), size: 18),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.onTap,
  });

  final Map<String, dynamic> conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final other = conversation['other_user'] as Map<String, dynamic>?;
    final name = other?['ign'] as String? ?? other?['name'] as String? ?? 'Player';
    final avatar = other?['avatar_url'] as String?;
    final last = conversation['last_message'] as Map<String, dynamic>?;
    final preview = last?['body'] as String? ?? 'Start chatting';
    final unread = conversation['unread_count'] as int? ?? 0;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            AppAvatar(imageUrl: avatar, radius: 20, fallbackIconSize: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.poppins(color: context.battlyOnSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    style: GoogleFonts.poppins(color: const Color(0xFF6B6F7A), fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (unread > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B00),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  unread > 9 ? '9+' : '$unread',
                  style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FloatingChatThread extends StatefulWidget {
  const _FloatingChatThread({
    required this.conversationId,
    required this.recipientId,
    required this.recipientName,
  });

  final int conversationId;
  final int recipientId;
  final String recipientName;

  @override
  State<_FloatingChatThread> createState() => _FloatingChatThreadState();
}

class _FloatingChatThreadState extends State<_FloatingChatThread> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];

  int? _currentUserId;
  bool _loading = true;
  bool _sending = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final cached = await AuthService.getCachedUser();
    _currentUserId = AuthService.parseUserId(cached);
    await _loadMessages(silent: false);
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _loadMessages(silent: true));
  }

  Future<void> _loadMessages({required bool silent}) async {
    try {
      final messages = await ChatService.getMessages(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(messages);
        _loading = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (!silent && mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _controller.clear();

    try {
      final sent = await ChatService.sendMessage(conversationId: widget.conversationId, body: text);
      if (!mounted) return;
      setState(() {
        _messages.add(sent);
        _sending = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      _controller.text = text;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $ampm';
    } catch (_) {
      return '';
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00), strokeWidth: 2))
              : _messages.isEmpty
                  ? Center(
                      child: Text(
                        'Say hello to ${widget.recipientName}!',
                        style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 12),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final senderId = msg['sender_id'] as int?;
                        final isMine = senderId != null && senderId == _currentUserId;
                        return _FloatingMessageBubble(
                          body: msg['body'] as String? ?? '',
                          time: _formatTime(msg['created_at'] as String?),
                          isMine: isMine,
                        );
                      },
                    ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          decoration: BoxDecoration(
            color: Color(0xFF0F1115),
            border: Border(top: BorderSide(color: Color(0xFF2B2F3A))),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 13),
                  maxLines: 3,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: GoogleFonts.poppins(color: const Color(0xFF6B6F7A), fontSize: 12),
                    filled: true,
                    fillColor: context.battlyCard,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: Color(0xFF2B2F3A)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: Color(0xFF2B2F3A)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: Color(0xFFFF6B00)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Material(
                color: const Color(0xFFFF6B00),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: _sending ? null : _sendMessage,
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: _sending
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FloatingMessageBubble extends StatelessWidget {
  const _FloatingMessageBubble({
    required this.body,
    required this.time,
    required this.isMine,
  });

  final String body;
  final String time;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 240),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFFFF6B00) : context.battlyCard,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isMine ? 12 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 12),
          ),
          border: isMine ? null : Border.all(color: context.battlyBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              body,
              style: GoogleFonts.poppins(
                color: isMine ? Colors.white : const Color(0xFFE8E8E8),
                fontSize: 12,
                height: 1.3,
              ),
            ),
            if (time.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                time,
                style: GoogleFonts.poppins(
                  color: isMine ? Colors.white70 : const Color(0xFF6B6F7A),
                  fontSize: 9,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
