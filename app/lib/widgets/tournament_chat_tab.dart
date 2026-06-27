import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../models/app_models.dart';
import '../services/api_config.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'app_network_image.dart';
import '../core/theme/battly_theme.dart';

/// Group chat for registered tournament players — lobby Q&A before/during match.
class TournamentChatTab extends StatefulWidget {
  final UpcomingTournament tournament;

  const TournamentChatTab({super.key, required this.tournament});

  @override
  State<TournamentChatTab> createState() => _TournamentChatTabState();
}

class _TournamentChatTabState extends State<TournamentChatTab> {
  static const _quickPrompts = [
    'Room?',
    'When start?',
    'Need teammate?',
  ];

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];

  int? _currentUserId;
  bool _loading = true;
  bool _sending = false;
  bool _chatOpen = true;
  String? _closedReason;
  String? _accessError;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _chatOpen = widget.tournament.chatOpen;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final cached = await AuthService.getCachedUser();
    _currentUserId = cached?['id'] as int?;
    await _loadChat(silent: false);
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _loadChat(silent: true));
  }

  Future<void> _loadChat({required bool silent}) async {
    final id = widget.tournament.id;
    if (id == null) return;

    try {
      final status = await ApiService.getTournamentChatStatus(id);
      final data = await ApiService.getTournamentChatMessages(id);
      if (!mounted) return;

      final open = status['open'] as bool? ?? data['open'] as bool? ?? false;
      setState(() {
        _accessError = null;
        _chatOpen = open;
        _closedReason = status['closed_reason'] as String? ?? data['closed_reason'] as String?;
        _messages
          ..clear()
          ..addAll(List<Map<String, dynamic>>.from(data['messages'] ?? []));
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      final isAccessDenied = message.toLowerCase().contains('registered');
      setState(() {
        _loading = false;
        if (isAccessDenied) {
          _chatOpen = false;
          _accessError = 'Only registered players can use lobby chat.';
          _closedReason = _accessError;
        } else if (!silent) {
          _accessError = 'Could not load lobby chat.';
          _closedReason = _accessError;
        }
      });
    }
  }

  Future<void> _sendMessage([String? preset]) async {
    final text = (preset ?? _messageController.text).trim();
    final id = widget.tournament.id;
    if (text.isEmpty || id == null || _sending || !_chatOpen) return;

    setState(() => _sending = true);
    if (preset == null) _messageController.clear();

    final res = await ApiService.sendTournamentChatMessage(id, body: text);
    if (!mounted) return;

    if (res['success'] == true && res['message'] is Map) {
      setState(() {
        _messages.add(Map<String, dynamic>.from(res['message'] as Map));
        _sending = false;
      });
      _scrollToBottom();
    } else {
      setState(() => _sending = false);
      if (preset == null) _messageController.text = text;
      _showError(res['error'] as String? ?? 'Failed to send message');
    }
  }

  Future<void> _pickAndSendImage() async {
    final id = widget.tournament.id;
    if (id == null || _sending || !_chatOpen) return;

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _sending = true);

    final bytes = await picked.readAsBytes();
    final res = await ApiService.sendTournamentChatMessage(
      id,
      imageBytes: bytes,
      imageFilename: picked.name,
    );
    if (!mounted) return;

    if (res['success'] == true && res['message'] is Map) {
      setState(() {
        _messages.add(Map<String, dynamic>.from(res['message'] as Map));
        _sending = false;
      });
      _scrollToBottom();
    } else {
      setState(() => _sending = false);
      _showError(res['error'] as String? ?? 'Failed to send image');
    }
  }

  String _resolveImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      if (url.contains('://localhost') || url.contains('://127.0.0.1')) {
        try {
          final uri = Uri.parse(url);
          return '${ApiConfig.baseUrl}${uri.path}';
        } catch (_) {
          return url;
        }
      }
      return url;
    }
    final cleanPath = url.startsWith('/') ? url.substring(1) : url;
    return '${ApiConfig.baseUrl}/$cleanPath';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFE53935),
        content: Text(message, style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold)),
      ),
    );
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
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)));
    }

    if (_accessError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, color: Color(0xFFA0A0A0), size: 40),
              const SizedBox(height: 12),
              Text(
                _accessError!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (!_chatOpen)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.battlyCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.battlyBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, color: Color(0xFFA0A0A0), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _closedReason ?? 'Lobby chat is closed — match ended.',
                    style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 11, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        if (_chatOpen) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickPrompts.map((prompt) {
                return ActionChip(
                  label: Text(prompt, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                  backgroundColor: context.battlyCard,
                  side: BorderSide(color: Color(0xFF2B2F3A)),
                  labelStyle: const TextStyle(color: Color(0xFFFF6B00)),
                  onPressed: _sending ? null : () => _sendMessage(prompt),
                );
              }).toList(),
            ),
          ),
        ],
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.forum_outlined, color: const Color(0xFF6B6F7A).withValues(alpha: 0.8), size: 40),
                        const SizedBox(height: 12),
                        Text(
                          _chatOpen ? 'Ask about room, start time, or teammates.' : 'Chat history is read-only.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 12, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final senderId = msg['user_id'] as int?;
                    final isMine = senderId != null && senderId == _currentUserId;
                    return _GroupMessageBubble(
                      body: msg['body'] as String? ?? '',
                      imageUrl: _resolveImageUrl(msg['image_url'] as String?),
                      senderName: msg['sender_name'] as String? ?? 'Player',
                      time: _formatTime(msg['created_at'] as String?),
                      isMine: isMine,
                      isOwner: msg['is_owner'] as bool? ?? false,
                    );
                  },
                ),
        ),
        if (_chatOpen)
          Container(
            padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + MediaQuery.paddingOf(context).bottom),
            decoration: BoxDecoration(
              color: Color(0xFF0F1115),
              border: Border(top: BorderSide(color: Color(0xFF2B2F3A))),
            ),
            child: Row(
              children: [
                Material(
                  color: context.battlyCard,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    onTap: _sending ? null : _pickAndSendImage,
                    borderRadius: BorderRadius.circular(24),
                    child: const SizedBox(
                      width: 46,
                      height: 46,
                      child: Icon(Icons.add_rounded, color: Color(0xFFFF6B00), size: 26),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 14),
                    maxLines: 3,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Message lobby...',
                      hintStyle: GoogleFonts.poppins(color: const Color(0xFF6B6F7A), fontSize: 13),
                      filled: true,
                      fillColor: context.battlyCard,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Color(0xFF2B2F3A)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Color(0xFF2B2F3A)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Color(0xFFFF6B00)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: const Color(0xFFFF6B00),
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    onTap: _sending ? null : () => _sendMessage(),
                    borderRadius: BorderRadius.circular(24),
                    child: SizedBox(
                      width: 46,
                      height: 46,
                      child: _sending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
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

class _GroupMessageBubble extends StatelessWidget {
  final String body;
  final String imageUrl;
  final String senderName;
  final String time;
  final bool isMine;
  final bool isOwner;

  const _GroupMessageBubble({
    required this.body,
    required this.imageUrl,
    required this.senderName,
    required this.time,
    required this.isMine,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFFFF6B00) : context.battlyCard,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMine ? 14 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 14),
          ),
          border: isMine ? null : Border.all(color: context.battlyBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Text(
                isOwner ? '$senderName • Host' : senderName,
                style: GoogleFonts.poppins(
                  color: isOwner ? const Color(0xFF4CAF50) : const Color(0xFFFF6B00),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (!isMine) const SizedBox(height: 2),
            if (imageUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AppNetworkImage(
                  url: imageUrl,
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
              if (body.isNotEmpty) const SizedBox(height: 6),
            ],
            if (body.isNotEmpty)
              Text(
                body,
                style: GoogleFonts.poppins(
                  color: isMine ? Colors.white : const Color(0xFFE8E8E8),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            if (time.isNotEmpty) ...[
              const SizedBox(height: 4),
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
