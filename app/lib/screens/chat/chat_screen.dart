import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../core/theme/battly_theme.dart';

class ChatScreen extends StatefulWidget {
  final int recipientId;
  final String recipientName;
  final String? recipientAvatarUrl;
  final int? conversationId;

  const ChatScreen({
    super.key,
    required this.recipientId,
    required this.recipientName,
    this.recipientAvatarUrl,
    this.conversationId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];

  int? _conversationId;
  int? _currentUserId;
  bool _isLoading = true;
  bool _isSending = false;
  bool _pollError = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final cached = await AuthService.getCachedUser();
      _currentUserId = cached?['id'] as int?;

      if (_conversationId == null) {
        final convo = await ChatService.startConversation(widget.recipientId);
        _conversationId = convo['id'] as int?;
      }

      await _loadMessages(silent: false);
      _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _loadMessages(silent: true));
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Could not open chat: $e');
      }
    }
  }

  Future<void> _loadMessages({required bool silent}) async {
    final id = _conversationId;
    if (id == null) return;

    try {
      final messages = await ChatService.getMessages(id);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(messages);
        _isLoading = false;
        _pollError = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (silent && mounted) {
        setState(() => _pollError = true);
      } else if (!silent && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final id = _conversationId;
    if (text.isEmpty || id == null || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      final sent = await ChatService.sendMessage(conversationId: id, body: text);
      if (!mounted) return;
      setState(() {
        _messages.add(sent);
        _isSending = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      _messageController.text = text;
      _showError('Failed to send message');
    }
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
    return Scaffold(
      backgroundColor: context.battly.navBar,
      appBar: AppBar(
        backgroundColor: context.battlyScaffold,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: context.battlyCard,
              backgroundImage: (widget.recipientAvatarUrl != null && widget.recipientAvatarUrl!.isNotEmpty)
                  ? NetworkImage(widget.recipientAvatarUrl!)
                  : null,
              child: (widget.recipientAvatarUrl == null || widget.recipientAvatarUrl!.isEmpty)
                  ? Text(
                      widget.recipientName.isNotEmpty ? widget.recipientName[0].toUpperCase() : 'P',
                      style: GoogleFonts.poppins(color: const Color(0xFFFF6B00), fontWeight: FontWeight.bold, fontSize: 12),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.recipientName,
                style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_pollError)
            Material(
              color: const Color(0xFF2A1F0A),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off_rounded, color: Color(0xFFFF9800), size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Could not refresh messages',
                        style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 11),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _loadMessages(silent: false),
                      child: Text(
                        'Retry',
                        style: GoogleFonts.poppins(color: const Color(0xFFFF6B00), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)))
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          'Say hello to ${widget.recipientName}!',
                          style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final senderId = msg['sender_id'] as int?;
                          final isMine = senderId != null && senderId == _currentUserId;
                          return _MessageBubble(
                            body: msg['body'] as String? ?? '',
                            time: _formatTime(msg['created_at'] as String?),
                            isMine: isMine,
                          );
                        },
                      ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + MediaQuery.paddingOf(context).bottom),
            decoration: BoxDecoration(
              color: Color(0xFF0F1115),
              border: Border(top: BorderSide(color: Color(0xFF2B2F3A))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 14),
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
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
                    onTap: _isSending ? null : _sendMessage,
                    borderRadius: BorderRadius.circular(24),
                    child: SizedBox(
                      width: 46,
                      height: 46,
                      child: _isSending
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
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String body;
  final String time;
  final bool isMine;

  const _MessageBubble({
    required this.body,
    required this.time,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
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
