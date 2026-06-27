import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../core/theme/battly_theme.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  bool _loadingTickets = true;
  String? _ticketsError;
  List<Map<String, dynamic>> _tickets = [];

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    setState(() {
      _loadingTickets = true;
      _ticketsError = null;
    });
    try {
      final tickets = await ApiService.getSupportTickets();
      if (!mounted) return;
      setState(() {
        _tickets = tickets;
        _loadingTickets = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ticketsError = e.toString().replaceFirst('Exception: ', '');
        _loadingTickets = false;
      });
    }
  }

  Future<void> _handleSubmit() async {
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();

    if (subject.isEmpty) {
      _showSnackBar('Please specify a subject', const Color(0xFFE53935));
      return;
    }
    if (message.isEmpty) {
      _showSnackBar('Please write your query details', const Color(0xFFE53935));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.battlyCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.battlyBorder, width: 1.5),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B00)),
                ),
                SizedBox(height: 16),
                Text(
                  'Submitting your ticket...',
                  style: TextStyle(color: Colors.white70, fontSize: 13, decoration: TextDecoration.none),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      await ApiService.createSupportTicket(
        subject: subject,
        message: message,
        category: 'mobile_app',
      );
      if (!mounted) return;
      Navigator.pop(context);

      _showSnackBar('Support ticket submitted successfully!', const Color(0xFF4CAF50));
      _subjectController.clear();
      _messageController.clear();
      _loadTickets();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''), const Color(0xFFE53935));
    }
  }

  void _showSnackBar(String text, Color bgColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: bgColor,
        content: Text(
          text,
          style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _startLiveChat() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.battlyCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Color(0xFF2B2F3A), width: 1.5),
          ),
          title: const Icon(Icons.support_agent_rounded, color: Color(0xFFFF6B00), size: 48),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Live Chat Support',
                style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 8),
              Text(
                'Submit a support ticket below and our team will respond as soon as possible.',
                style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 11.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'OK',
                style: GoogleFonts.poppins(color: context.battlyMuted, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  String _ticketStatusLabel(String? status) {
    switch (status?.toLowerCase()) {
      case 'resolved':
      case 'closed':
        return 'Resolved';
      case 'in_progress':
        return 'In Progress';
      default:
        return 'Open';
    }
  }

  Color _ticketStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'resolved':
      case 'closed':
        return const Color(0xFF4CAF50);
      case 'in_progress':
        return const Color(0xFFFF9800);
      default:
        return const Color(0xFF2196F3);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Support & Help',
          style: GoogleFonts.poppins(color: context.battlyOnSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF23140C), Color(0xFF15181E)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.battlyBorder),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B00).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.support_agent_rounded, color: Color(0xFFFF6B00), size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Have a direct query?',
                          style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 13.5, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Speak directly with support staff.',
                          style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _startLiveChat,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B00),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      'Chat Live',
                      style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            Text(
              'YOUR TICKETS',
              style: GoogleFonts.poppins(
                color: context.battlyMuted,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            if (_loadingTickets)
              const Center(child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: Color(0xFFFF6B00)),
              ))
            else if (_ticketsError != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.battlyCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.battlyBorder),
                ),
                child: Column(
                  children: [
                    Text(_ticketsError!, style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 12)),
                    const SizedBox(height: 8),
                    TextButton(onPressed: _loadTickets, child: const Text('Retry')),
                  ],
                ),
              )
            else if (_tickets.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.battlyCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.battlyBorder),
                ),
                child: Text(
                  'No support tickets yet.',
                  style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 12),
                ),
              )
            else
              ..._tickets.map(_buildTicketTile),
            const SizedBox(height: 28),

            Text(
              'FREQUENTLY ASKED QUESTIONS',
              style: GoogleFonts.poppins(
                color: context.battlyMuted,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            _buildFAQTile(
              question: 'How do I withdraw my winnings?',
              answer: 'Go to Wallet > Withdraw, select your method (eSewa, Khalti, or Bank Transfer), enter the amount, and fill in your details. Winnings will be processed within 24 hours.',
            ),
            const SizedBox(height: 8),
            _buildFAQTile(
              question: 'What is the minimum P2P transfer amount?',
              answer: 'The minimum balance transfer amount to another verified player on Battly is NPR 50.',
            ),
            const SizedBox(height: 8),
            _buildFAQTile(
              question: 'My payment deposit failed, what should I do?',
              answer: 'If money was deducted from your wallet but not added to your Battly account, please raise a ticket below or start a Live Chat with your Txn ID. We will resolve it instantly.',
            ),
            const SizedBox(height: 28),

            Text(
              'SUBMIT A SUPPORT TICKET',
              style: GoogleFonts.poppins(
                color: context.battlyMuted,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.battlyCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.battlyBorder),
              ),
              child: Column(
                children: [
                  _buildFormTextField(
                    controller: _subjectController,
                    hintText: 'Enter ticket subject (e.g. Withdrawal Issue)',
                    icon: Icons.title_rounded,
                  ),
                  const SizedBox(height: 14),
                  _buildFormTextField(
                    controller: _messageController,
                    hintText: 'Explain your issue in detail...',
                    icon: Icons.chat_bubble_outline_rounded,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B00),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        'Submit Ticket',
                        style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketTile(Map<String, dynamic> ticket) {
    final subject = ticket['subject'] as String? ?? 'Support ticket';
    final status = ticket['status'] as String?;
    final createdAt = ticket['created_at'] as String?;
    final statusColor = _ticketStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.battlyCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.battlyBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                if (createdAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    createdAt,
                    style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _ticketStatusLabel(status),
              style: GoogleFonts.poppins(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQTile({required String question, required String answer}) {
    return Container(
      decoration: BoxDecoration(
        color: context.battlyCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.battlyBorder),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: const Color(0xFFFF6B00),
          collapsedIconColor: Colors.white70,
          title: Text(
            question,
            style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 12.5, fontWeight: FontWeight.bold),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
              child: Text(
                answer,
                style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 11, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.battlyScaffold,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.battlyBorder),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: GoogleFonts.poppins(color: context.battlyOnSurface, fontSize: 12.5),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 11.5),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(bottom: 0.0),
            child: Icon(icon, color: context.battlyMuted, size: 18),
          ),
        ),
      ),
    );
  }
}
