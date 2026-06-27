import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/transaction_details_sheet.dart';
import '../../services/wallet_service.dart';
import '../../core/theme/battly_theme.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['All', 'Deposits', 'Withdrawals', 'Winnings', 'Refunds'];

  // Active Filter Values
  String _filterStatus = 'All';
  String _filterDateRange = 'All';
  String _filterSort = 'Newest First';

  bool _isLoading = true;
  String? _errorMessage;
  List<TransactionRecord> _allTransactions = [];

  // Pagination
  int _currentPage = 1;
  int _lastPage = 1;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadTransactions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions({bool loadMore = false}) async {
    if (loadMore) {
      if (_currentPage >= _lastPage) return;
      setState(() => _isLoadingMore = true);
      _currentPage++;
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _currentPage = 1;
      });
    }

    try {
      // Map tab to backend type filter
      final activeTab = _tabs[_tabController.index];
      String? typeFilter;
      if (activeTab == 'Deposits') {
        typeFilter = 'deposit';
      } else if (activeTab == 'Withdrawals') {
        typeFilter = 'withdraw';
      } else if (activeTab == 'Winnings') {
        typeFilter = 'winnings';
      } else if (activeTab == 'Refunds') {
        typeFilter = 'refund';
      }

      String? statusFilter;
      if (_filterStatus == 'Completed') {
        statusFilter = 'completed';
      } else if (_filterStatus == 'Pending') {
        statusFilter = 'pending';
      } else if (_filterStatus == 'Failed') {
        statusFilter = 'failed';
      }

      final data = await WalletService.getTransactions(
        type: typeFilter,
        status: statusFilter,
        page: _currentPage,
        perPage: 20,
      );

      final List<dynamic> rawTxns = data['transactions'] ?? [];
      final pagination = data['pagination'] as Map<String, dynamic>? ?? {};
      _lastPage = pagination['last_page'] ?? 1;

      final newTxns = rawTxns.map((json) {
        return TransactionRecord.fromJson(json as Map<String, dynamic>);
      }).toList();

      setState(() {
        if (loadMore) {
          _allTransactions.addAll(newTxns);
        } else {
          _allTransactions = newTxns;
        }
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = 'Failed to load transactions';
        if (loadMore) _currentPage--;
      });
    }
  }

  // Client-side filtering for date range and sorting
  List<TransactionRecord> _getFilteredTransactions() {
    List<TransactionRecord> list = _allTransactions;

    // Date Range filter
    if (_filterDateRange != 'All') {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      if (_filterDateRange == 'Today') {
        list = list.where((t) => t.dateTime.isAfter(todayStart)).toList();
      } else if (_filterDateRange == 'Last 3 Days') {
        final threeDaysAgo = todayStart.subtract(const Duration(days: 2));
        list = list.where((t) => t.dateTime.isAfter(threeDaysAgo)).toList();
      } else if (_filterDateRange == 'Last 7 Days') {
        final sevenDaysAgo = todayStart.subtract(const Duration(days: 6));
        list = list.where((t) => t.dateTime.isAfter(sevenDaysAgo)).toList();
      }
    }

    // Sort
    if (_filterSort == 'Newest First') {
      list.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    } else {
      list.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    }

    return list;
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(dt.year, dt.month, dt.day);

    int hour = dt.hour;
    String amPm = "AM";
    if (hour >= 12) {
      amPm = "PM";
      if (hour > 12) hour -= 12;
    } else if (hour == 0) {
      hour = 12;
    }
    String timeStr = "$hour:${dt.minute.toString().padLeft(2, '0')} $amPm";

    if (dateToCheck == today) {
      return "Today • $timeStr";
    } else if (dateToCheck == yesterday) {
      return "Yesterday • $timeStr";
    } else {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return "${dt.day} ${months[dt.month - 1]}, ${dt.year} • $timeStr";
    }
  }

  void _showFilterSheet(BuildContext context) {
    String tempStatus = _filterStatus;
    String tempDateRange = _filterDateRange;
    String tempSort = _filterSort;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
              padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3E4351),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Transactions',
                        style: GoogleFonts.poppins(color: context.battlyOnSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Color(0xFF1E222A),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, color: Color(0xFFA0A0A0), size: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Status Filter
                  _buildFilterSection('Status', ['All', 'Completed', 'Pending', 'Failed'],
                    tempStatus, (val) => setSheetState(() => tempStatus = val)),
                  const SizedBox(height: 16),

                  // Date Range Filter
                  _buildFilterSection('Date Range', ['All', 'Today', 'Last 3 Days', 'Last 7 Days'],
                    tempDateRange, (val) => setSheetState(() => tempDateRange = val)),
                  const SizedBox(height: 16),

                  // Sort Filter
                  _buildFilterSection('Sort Order', ['Newest First', 'Oldest First'],
                    tempSort, (val) => setSheetState(() => tempSort = val)),
                  const SizedBox(height: 24),

                  // Apply Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _filterStatus = tempStatus;
                          _filterDateRange = tempDateRange;
                          _filterSort = tempSort;
                        });
                        _loadTransactions();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B00),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Apply Filters',
                        style: GoogleFonts.poppins(color: context.battlyOnSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterSection(
    String title,
    List<String> options,
    String selected,
    ValueChanged<String> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            color: context.battlyMuted,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = option == selected;
            return GestureDetector(
              onTap: () => onChanged(option),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFFF6B00) : context.battlyCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFFF6B00) : context.battlyBorder,
                  ),
                ),
                child: Text(
                  option,
                  style: GoogleFonts.poppins(
                    color: isSelected ? Colors.white : context.battlyMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _getFilteredTransactions();

    return Scaffold(
      backgroundColor: context.battly.navBar,
      appBar: AppBar(
        backgroundColor: context.battly.navBar,
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
          'Transaction History',
          style: GoogleFonts.poppins(color: context.battlyOnSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _showFilterSheet(context),
            icon: const Icon(Icons.tune_rounded, color: Colors.white70, size: 20),
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab Bar
          Container(
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: context.battlyCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.battlyBorder, width: 1),
            ),
            child: TabBar(
              controller: _tabController,
              onTap: (_) => _loadTransactions(),
              indicator: BoxDecoration(
                color: const Color(0xFFFF6B00),
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: context.battlyMuted,
              labelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold),
              unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500),
              dividerColor: Colors.transparent,
              tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // Transaction List
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
                            const Icon(Icons.error_outline, color: Color(0xFFE53935), size: 40),
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadTransactions,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF6B00),
                              ),
                              child: Text('Retry',
                                style: GoogleFonts.poppins(color: context.battlyOnSurface, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      )
                    : filteredList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.receipt_long_outlined, color: Color(0xFFA0A0A0), size: 40),
                                const SizedBox(height: 12),
                                Text(
                                  'No transactions found',
                                  style: GoogleFonts.poppins(color: context.battlyMuted, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (notification is ScrollEndNotification &&
                                  notification.metrics.extentAfter < 100 &&
                                  !_isLoadingMore) {
                                _loadTransactions(loadMore: true);
                              }
                              return false;
                            },
                            child: RefreshIndicator(
                              onRefresh: () => _loadTransactions(),
                              color: const Color(0xFFFF6B00),
                              backgroundColor: context.battlyCard,
                              child: ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                itemCount: filteredList.length + (_currentPage < _lastPage ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == filteredList.length) {
                                    return const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B00)),
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  }
                                  return _buildTransactionItem(filteredList[index]);
                                },
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(TransactionRecord record) {
    IconData iconData;
    Color iconColor;

    switch (record.type) {
      case TransactionType.deposit:
        iconData = Icons.arrow_upward_rounded;
        iconColor = const Color(0xFF4CAF50);
        break;
      case TransactionType.withdraw:
        iconData = Icons.arrow_downward_rounded;
        iconColor = const Color(0xFFE53935);
        break;
      case TransactionType.winnings:
        iconData = Icons.emoji_events_outlined;
        iconColor = const Color(0xFFFFD700);
        break;
      case TransactionType.refund:
        iconData = Icons.settings_backup_restore_rounded;
        iconColor = const Color(0xFF2196F3);
        break;
      case TransactionType.spend:
        iconData = Icons.sports_esports_rounded;
        iconColor = const Color(0xFFFF6B00);
        break;
    }

    final String amountText = record.amount >= 0
        ? '+ NPR ${record.amount.abs().toStringAsFixed(0)}'
        : '- NPR ${record.amount.abs().toStringAsFixed(0)}';

    final Color amountColor = record.amount >= 0
        ? const Color(0xFF4CAF50)
        : const Color(0xFFE53935);

    return GestureDetector(
      onTap: () => showTransactionDetailsSheet(context, record, _formatDate(record.dateTime)),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(color: Colors.transparent),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.title,
                    style: GoogleFonts.poppins(color: context.battlyOnSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    record.subtitle,
                    style: GoogleFonts.poppins(
                      color: context.battlyMuted,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(record.dateTime),
                    style: GoogleFonts.poppins(
                      color: const Color(0x80A0A0A0),
                      fontSize: 8.5,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  amountText,
                  style: GoogleFonts.poppins(
                    color: amountColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                _buildStatusPill(record.status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(TransactionStatus status) {
    Color textColor;
    Color bgColor;
    String label;

    switch (status) {
      case TransactionStatus.completed:
        label = 'Completed';
        textColor = const Color(0xFF4CAF50);
        bgColor = const Color(0xFF4CAF50).withValues(alpha: 0.12);
        break;
      case TransactionStatus.pending:
        label = 'Pending';
        textColor = const Color(0xFFFF9800);
        bgColor = const Color(0xFFFF9800).withValues(alpha: 0.12);
        break;
      case TransactionStatus.failed:
        label = 'Failed';
        textColor = const Color(0xFFE53935);
        bgColor = const Color(0xFFE53935).withValues(alpha: 0.12);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: textColor,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ── Shared Data Models ──────────────────────────────────────────────────

enum TransactionType {
  deposit,
  withdraw,
  winnings,
  refund,
  spend,
}

enum TransactionStatus {
  completed,
  pending,
  failed,
}

class TransactionRecord {
  final String id;
  final TransactionType type;
  final String title;
  final String subtitle;
  final double amount;
  final DateTime dateTime;
  final TransactionStatus status;
  final String? referenceId;
  final String? transactionCode;
  final String? paymentMethod;
  final String? recipientName;

  TransactionRecord({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.dateTime,
    required this.status,
    this.referenceId,
    this.transactionCode,
    this.paymentMethod,
    this.recipientName,
  });

  /// Parse from backend JSON response.
  factory TransactionRecord.fromJson(Map<String, dynamic> json) {
    final rawType = json['transaction_type'] ?? json['type'] ?? 'spend';
    final rawStatus = json['status'] ?? 'completed';
    final rawAmount = json['amount_numeric'];
    double amountNumeric = 0.0;
    if (rawAmount != null) {
      if (rawAmount is num) {
        amountNumeric = rawAmount.toDouble();
      } else if (rawAmount is String) {
        amountNumeric = double.tryParse(rawAmount) ?? 0.0;
      }
    }
    final description = json['description'] ?? '';

    TransactionType type;
    String title;
    String subtitle = description;

    switch (rawType.toString().toLowerCase()) {
      case 'deposit':
        type = TransactionType.deposit;
        title = json['payment_method'] != null
            ? 'Added via ${_formatPaymentMethod(json['payment_method'])}'
            : 'Deposit';
        if (json['transaction_code'] != null) {
          subtitle = 'Txn ID: ${json['transaction_code']}';
        }
        break;
      case 'withdraw':
        type = TransactionType.withdraw;
        title = json['recipient_name'] != null
            ? 'Withdrawal to ${json['recipient_name']}'
            : 'Withdrawal';
        if (json['payment_method'] != null) {
          subtitle = 'Via ${_formatPaymentMethod(json['payment_method'])}';
        }
        break;
      case 'transfer':
        if (amountNumeric < 0) {
          type = TransactionType.spend;
          title = json['recipient_name'] != null
              ? 'Transfer to ${json['recipient_name']}'
              : 'Transfer Sent';
        } else {
          type = TransactionType.deposit;
          title = json['recipient_name'] != null
              ? 'Transfer from ${json['recipient_name']}'
              : 'Transfer Received';
        }
        subtitle = description;
        break;
      case 'winnings':
        type = TransactionType.winnings;
        title = 'Tournament Winnings';
        break;
      case 'refund':
        type = TransactionType.refund;
        title = 'Refund';
        break;
      default:
        if (amountNumeric < 0) {
          type = TransactionType.spend;
          title = 'Entry Fee';
        } else {
          type = TransactionType.deposit;
          title = description.isNotEmpty ? description : 'Credit';
        }
    }

    DateTime dateTime;
    try {
      dateTime = DateTime.parse(json['created_at'] ?? '');
    } catch (_) {
      dateTime = DateTime.now();
    }

    TransactionStatus status;
    switch (rawStatus.toString().toLowerCase()) {
      case 'completed':
        status = TransactionStatus.completed;
        break;
      case 'pending':
        status = TransactionStatus.pending;
        break;
      case 'failed':
        status = TransactionStatus.failed;
        break;
      default:
        status = TransactionStatus.completed;
    }

    return TransactionRecord(
      id: json['id'] ?? '',
      type: type,
      title: title,
      subtitle: subtitle,
      amount: amountNumeric,
      dateTime: dateTime,
      status: status,
      referenceId: json['reference_id'],
      transactionCode: json['transaction_code'],
      paymentMethod: json['payment_method'],
      recipientName: json['recipient_name'],
    );
  }

  static String _formatPaymentMethod(String method) {
    switch (method) {
      case 'esewa': return 'eSewa';
      case 'khalti': return 'Khalti';
      case 'ime_pay': return 'IME Pay';
      case 'connect_ips': return 'Connect IPS';
      case 'bank_transfer': return 'Bank Transfer';
      default: return method;
    }
  }
}
