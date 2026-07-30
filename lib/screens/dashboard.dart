import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/local_storage_service.dart';

class DashboardScreen extends StatefulWidget {
  final LocalStorageService storageService;
  final VoidCallback onLockRequested;
  final VoidCallback onResetRequested;

  const DashboardScreen({
    super.key,
    required this.storageService,
    required this.onLockRequested,
    required this.onResetRequested,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentTab = 0;
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _recurringItems = [];
  Map<String, double> _categoryBudgets = {};
  Map<String, dynamic> _profile = {};
  List<Map<String, dynamic>> _goals = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterCategory = 'All';
  String _selectedMonthFilter = 'All';

  // Settings & Preferences
  String _preferredCurrency = 'LKR';
  double _targetMonthlyBudget = 100000.0;
  double _whatIfCutPct = 20.0;
  String _whatIfCategory = 'Food & Dining';
  
  // Customization & Security States
  String _avatarEmoji = '👨‍💼';
  int _paydayResetDate = 1;
  bool _stealthMode = false;
  bool _privacyBlurEnabled = true;
  bool _pinLockEnabled = false;
  String _pinCode = '1234';
  bool _isDarkMode = false;
  Color _themeColor = const Color(0xFF2563EB);

  // Daily Reminder States
  bool _dailyReminderEnabled = true;
  int _dailyReminderHour = 20; // 8:00 PM default

  // Avatar Palette Choices
  final List<String> _avatars = [
    '👨‍💼', '👩‍💼', '🚀', '💎', '🦁', '👑', '🦊', '🤖',
    '🦄', '🐯', '🦅', '🎯', '⚡', '🔥', '🌟', '🏆',
    '🎩', '💼', '🧘', '🕶️', '🎨', '🔮', '💸', '🐖'
  ];

  // High Value OTP Prompt State
  Map<String, dynamic>? _pendingHighValueTx;
  final _otpController = TextEditingController();

  // Icon Choices for Custom Wallets
  final List<String> _walletIcons = ['💵', '🏦', '💳', '📱', '🐖', '💎', '🛒', '⚡'];

  // Category Icon Palette
  final List<String> _categoryIcons = ['🍔', '🚗', '⚡', '🛒', '💰', '🏥', '🍿', '🏋️', '🐶', '🎁', '✈️', '🎓', '🎮', '☕'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final txs = await widget.storageService.getTransactions();
      final accs = await widget.storageService.getAccounts();
      final cats = await widget.storageService.getCategories();
      final recs = await widget.storageService.getRecurringTransactions();
      final budgets = await widget.storageService.getCategoryBudgets();
      final savedGoals = await widget.storageService.getGoals();
      final prof = (await widget.storageService.getProfile()) ?? {};

      setState(() {
        _transactions = txs;
        _accounts = accs;
        _categories = cats;
        _recurringItems = recs;
        _categoryBudgets = budgets;
        _goals = savedGoals;
        _profile = prof;
        _preferredCurrency = prof['currency'] ?? 'LKR';
        _targetMonthlyBudget = (double.tryParse(prof['monthly_budget'].toString()) ?? 100000.0);
        _avatarEmoji = prof['avatar_emoji'] ?? '👨‍💼';
        _paydayResetDate = prof['payday_reset_date'] ?? 1;
        _stealthMode = prof['stealth_mode'] == true;
        _privacyBlurEnabled = prof['privacy_blur'] ?? true;
        _pinLockEnabled = prof['pin_lock'] == true;
        _pinCode = prof['pin_code'] ?? '1234';
        _isDarkMode = prof['dark_mode'] == true;
        _dailyReminderEnabled = prof['daily_reminder_enabled'] ?? true;
        _dailyReminderHour = prof['daily_reminder_hour'] ?? 20;

        if (prof['theme_color_val'] != null) {
          _themeColor = Color(prof['theme_color_val'] as int);
        }
      });
    } catch (e) {
      print('Error loading local data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _isCategoryMatch(String txCategory, String targetCategory) {
    final a = txCategory.trim().toLowerCase();
    final b = targetCategory.trim().toLowerCase();
    if (a == b) return true;
    if (a.contains(b) || b.contains(a)) return true;

    final cleanA = a.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    final cleanB = b.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    if (cleanA.isEmpty || cleanB.isEmpty) return false;
    return cleanA.contains(cleanB) || cleanB.contains(cleanA);
  }

  String _formatReminderHour(int hour) {
    if (hour == 0) return '12:00 AM (Midnight)';
    if (hour == 12) return '12:00 PM (Noon)';
    if (hour > 12) return '${hour - 12}:00 PM';
    return '$hour:00 AM';
  }

  DateTime _calculateNextDueDate(String startDateStr, String frequency) {
    DateTime start = DateTime.tryParse(startDateStr) ?? DateTime.now();
    DateTime now = DateTime.now();
    DateTime next = start;

    while (next.isBefore(DateTime(now.year, now.month, now.day))) {
      if (frequency == 'Weekly') {
        next = next.add(const Duration(days: 7));
      } else if (frequency == 'Yearly') {
        next = DateTime(next.year + 1, next.month, next.day);
      } else {
        // Monthly default
        int nextMonth = next.month + 1;
        int nextYear = next.year;
        if (nextMonth > 12) {
          nextMonth = 1;
          nextYear += 1;
        }
        next = DateTime(nextYear, nextMonth, next.day);
      }
    }
    return next;
  }

  // Available months for filter dropdown
  List<String> get _availableMonths {
    final Set<String> months = {'All'};
    for (var tx in _transactions) {
      final d = tx['date'].toString();
      if (d.length >= 7) {
        months.add(d.substring(0, 7));
      }
    }
    return months.toList();
  }

  // Filtered transactions by selected month
  List<Map<String, dynamic>> get _filteredByMonthTransactions {
    if (_selectedMonthFilter == 'All') return _transactions;
    return _transactions.where((t) => t['date'].toString().startsWith(_selectedMonthFilter)).toList();
  }

  double get _totalNetWorth => _accounts.fold(
      0.0, (sum, acc) => sum + (double.tryParse(acc['current_balance'].toString()) ?? 0.0));

  double get _totalIncome => _filteredByMonthTransactions
      .where((t) => t['type'] == 'income')
      .fold(0.0, (sum, t) => sum + (double.tryParse(t['amount'].toString()) ?? 0.0));

  double get _totalExpense => _filteredByMonthTransactions
      .where((t) => t['type'] == 'expense')
      .fold(0.0, (sum, t) => sum + (double.tryParse(t['amount'].toString()) ?? 0.0));

  bool get _hasLoggedToday {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return _transactions.any((t) => t['date'] == today);
  }

  Future<void> _addTransaction(double amount, String category, String type, String notes, String location, String accountId, DateTime selectedDate, {String? fromAccountId, String? toAccountId, bool isRecurring = false, String frequency = 'Monthly', bool autoLog = false}) async {
    final newTx = {
      'id': 'tx-${DateTime.now().millisecondsSinceEpoch}',
      'amount': amount,
      'category': category,
      'type': type,
      'account_id': accountId,
      'from_account_id': fromAccountId,
      'to_account_id': toAccountId,
      'payment_method': 'Cash',
      'date': selectedDate.toIso8601String().substring(0, 10),
      'notes': notes.isEmpty ? (type == 'transfer' ? 'Wallet Transfer' : category) : notes,
      'location': location.isEmpty ? 'Colombo' : location,
    };

    if (type == 'expense' && amount > 50000) {
      setState(() {
        _pendingHighValueTx = newTx;
      });
      _showOtpVerificationDialog();
      return;
    }

    await widget.storageService.addTransaction(newTx);

    if (isRecurring) {
      await widget.storageService.addRecurringTransaction({
        'id': 'rec-${DateTime.now().millisecondsSinceEpoch}',
        'title': notes.isEmpty ? category : notes,
        'amount': amount,
        'category': category,
        'type': type,
        'account_id': accountId,
        'frequency': frequency,
        'start_date': selectedDate.toIso8601String().substring(0, 10),
        'auto_log': autoLog,
      });
    }

    _loadData();
  }

  void _showOtpVerificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('⚠️ OTP Verification Required'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This expense of $_preferredCurrency ${_pendingHighValueTx!['amount']} exceeds the LKR 50,000 security threshold. Enter OTP code to authorize (Try 123456).',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: '6-Digit Verification OTP'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _pendingHighValueTx = null);
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_otpController.text == '123456' || _otpController.text == '123') {
                  Navigator.pop(context);
                  await widget.storageService.addTransaction(_pendingHighValueTx!);
                  setState(() => _pendingHighValueTx = null);
                  _otpController.clear();
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Transaction authorized and saved.')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid code! Try 123456.')),
                  );
                }
              },
              child: const Text('Verify'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final themeData = ThemeData(
      brightness: _isDarkMode ? Brightness.dark : Brightness.light,
      primaryColor: _themeColor,
      scaffoldBackgroundColor: _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      cardColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _themeColor,
        brightness: _isDarkMode ? Brightness.dark : Brightness.light,
      ),
      useMaterial3: true,
    );

    Widget currentBody;
    switch (_currentTab) {
      case 0:
        currentBody = _buildHomeTab();
        break;
      case 1:
        currentBody = _buildTransactionsTab();
        break;
      case 2:
        currentBody = _buildAnalyticsTab();
        break;
      case 3:
        currentBody = _buildGoalsTab();
        break;
      case 4:
        currentBody = _buildSettingsTab();
        break;
      default:
        currentBody = _buildHomeTab();
    }

    return Theme(
      data: themeData,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('FinanceFlow', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
              onPressed: () async {
                setState(() => _isDarkMode = !_isDarkMode);
                await widget.storageService.updateProfileField('dark_mode', _isDarkMode);
              },
            ),
          ],
        ),
        body: currentBody,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentTab,
          onTap: (idx) => setState(() => _currentTab = idx),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: _themeColor,
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'History'),
            BottomNavigationBarItem(icon: Icon(Icons.insights), label: 'Analytics'),
            BottomNavigationBarItem(icon: Icon(Icons.track_changes), label: 'Goals'),
            BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: _themeColor,
          onPressed: () => _showAddTransactionBottomSheet(),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // 1. HOME TAB
  // ----------------------------------------------------
  Widget _buildHomeTab() {
    final budgetPct = _targetMonthlyBudget > 0 ? (_totalExpense / _targetMonthlyBudget).clamp(0.0, 1.0) : 0.0;
    final remainingBudget = (_targetMonthlyBudget - _totalExpense).clamp(0.0, double.infinity);

    final netWorthStr = _stealthMode ? '••••••' : '${_totalNetWorth.toStringAsFixed(2)}';
    final incomeStr = _stealthMode ? '••••' : _totalIncome.toStringAsFixed(0);
    final expenseStr = _stealthMode ? '••••' : _totalExpense.toStringAsFixed(0);

    final currentHour = DateTime.now().hour;
    final isReminderTimeReached = currentHour >= _dailyReminderHour;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hello, ${_profile['name'] ?? 'Alex'}! 👋', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Text('Your private wealth dashboard.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              CircleAvatar(
                backgroundColor: _themeColor.withOpacity(0.15),
                child: Text(_avatarEmoji, style: const TextStyle(fontSize: 20)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Daily Expense Reminder Banner
          if (_dailyReminderEnabled && !_hasLoggedToday && isReminderTimeReached) ...[
            Container(
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber[300]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active, color: Colors.amber),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('🔔 Daily Reminder (${_formatReminderHour(_dailyReminderHour)})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                        const Text('You haven\'t logged any transactions today yet!', style: TextStyle(fontSize: 11, color: Colors.black54)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800], padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                    onPressed: () => _showAddTransactionBottomSheet(),
                    child: const Text('Log Now', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Total Net Worth Card (With Stealth Peek Eye Button 👁️)
          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_themeColor, _themeColor.withOpacity(0.85)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: _themeColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL NET WORTH (ALL WALLETS)', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(_stealthMode ? Icons.visibility_off : Icons.visibility, color: Colors.white70, size: 18),
                      onPressed: () async {
                        setState(() => _stealthMode = !_stealthMode);
                        await widget.storageService.updateProfileField('stealth_mode', _stealthMode);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$_preferredCurrency $netWorthStr',
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text('🟢 Income: $_preferredCurrency $incomeStr', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      Expanded(child: Text('🔴 Expense: $_preferredCurrency $expenseStr', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Accounts & Wallets Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('My Accounts & Wallets', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: _showAddAccountModal,
                icon: const Icon(Icons.add_card, size: 16),
                label: const Text('Add Wallet'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _accounts.map((acc) {
                final balance = (double.tryParse(acc['current_balance'].toString()) ?? 0.0);
                final icon = acc['icon'] ?? '💵';
                return _buildAccountCard(acc['id'], acc['name'], icon, balance, acc);
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Upgraded Recurring Subscriptions Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('🔁 Subscriptions & Recurring Bills', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: _showAddSubscriptionModal,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Sub'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_recurringItems.isEmpty) ...[
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: const Padding(
                padding: EdgeInsets.all(14.0),
                child: Text('No recurring subscriptions added yet (e.g. Netflix, Wi-Fi, Rent). Tap "Add Sub" above.', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ),
            ),
          ] else ...[
            Column(
              children: _recurringItems.map((rec) {
                final startDate = rec['start_date'] ?? DateTime.now().toIso8601String().substring(0, 10);
                final frequency = rec['frequency'] ?? 'Monthly';
                final nextDue = _calculateNextDueDate(startDate, frequency);
                final nextDueStr = nextDue.toIso8601String().substring(0, 10);
                final daysLeft = nextDue.difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)).inDays;
                final isAutoLog = rec['auto_log'] == true;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: isAutoLog ? Colors.green : Colors.purple, child: Icon(isAutoLog ? Icons.flash_on : Icons.autorenew, color: Colors.white, size: 18)),
                    title: Text(rec['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('⏱️ Next Due: $nextDueStr (${daysLeft == 0 ? "Due Today!" : "In $daysLeft days"}) • ${isAutoLog ? "Auto-Pilot ⚡" : "Confirm Mode 💬"}', style: const TextStyle(fontSize: 11)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$_preferredCurrency ${rec['amount']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                        IconButton(
                          icon: const Icon(Icons.play_arrow, color: Colors.green, size: 20),
                          tooltip: 'Confirm & Log transaction now',
                          onPressed: () async {
                            await _addTransaction(
                              (double.tryParse(rec['amount'].toString()) ?? 0.0),
                              rec['category'],
                              rec['type'] ?? 'expense',
                              'Recurring: ${rec['title']}',
                              'Subscription',
                              rec['account_id'] ?? 'acc-1',
                              DateTime.now(),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Logged ${rec['title']} transaction!')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),

          // Target Budget Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Monthly Target Budget', style: TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 16, color: Colors.blue),
                        onPressed: _showEditBudgetDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Used: $_preferredCurrency ${_totalExpense.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      Text('Target: $_preferredCurrency ${_targetMonthlyBudget.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: budgetPct,
                      minHeight: 8,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(_totalExpense > _targetMonthlyBudget ? Colors.red : _themeColor),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Remaining: $_preferredCurrency ${remainingBudget.toStringAsFixed(0)} (${(budgetPct * 100).toStringAsFixed(0)}% used)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _totalExpense > _targetMonthlyBudget ? Colors.red : Colors.green),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showAddSubscriptionModal() {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    DateTime startDate = DateTime.now();
    String frequency = 'Monthly';
    bool autoLog = false;
    String category = _categories.isNotEmpty ? _categories[0]['name'] : 'Food & Dining';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Add Recurring Subscription'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Subscription Title (e.g. Netflix)')),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                      decoration: const InputDecoration(labelText: 'Amount'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('📅 Start Date: ${startDate.toIso8601String().substring(0, 10)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: startDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) setModalState(() => startDate = picked);
                          },
                          child: const Text('Pick Date'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: frequency,
                      items: const [
                        DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
                        DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                        DropdownMenuItem(value: 'Yearly', child: Text('Yearly')),
                      ],
                      onChanged: (val) => setModalState(() => frequency = val ?? 'Monthly'),
                      decoration: const InputDecoration(labelText: 'Frequency'),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('⚡ Auto-Log without asking'),
                      subtitle: const Text('If off, asks you to confirm when due'),
                      value: autoLog,
                      onChanged: (val) => setModalState(() => autoLog = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    final t = titleController.text.trim();
                    final amt = double.tryParse(amountController.text) ?? 0.0;
                    if (t.isNotEmpty && amt > 0) {
                      Navigator.pop(context);
                      await widget.storageService.addRecurringTransaction({
                        'id': 'rec-${DateTime.now().millisecondsSinceEpoch}',
                        'title': t,
                        'amount': amt,
                        'category': category,
                        'type': 'expense',
                        'frequency': frequency,
                        'start_date': startDate.toIso8601String().substring(0, 10),
                        'auto_log': autoLog,
                        'account_id': _accounts.isNotEmpty ? _accounts[0]['name'] : 'acc-1',
                      });
                      _loadData();
                    }
                  },
                  child: const Text('Save Subscription'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAccountCard(String id, String name, String iconStr, double balance, Map<String, dynamic> rawAcc) {
    final balStr = _stealthMode ? '••••••' : balance.toStringAsFixed(2);
    return GestureDetector(
      onTap: () => _showAccountDetailModal(id, name, balance, rawAcc),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _isDarkMode ? Colors.grey[800]! : Colors.grey[300]!),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(iconStr, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            Text('$_preferredCurrency $balStr', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: balance < 0 ? Colors.red : (_isDarkMode ? Colors.white : Colors.black87))),
          ],
        ),
      ),
    );
  }

  void _showEditBudgetDialog() {
    final controller = TextEditingController(text: _targetMonthlyBudget.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Monthly Target Budget'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            decoration: const InputDecoration(labelText: 'Target Amount (e.g. 100000)'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(controller.text) ?? 100000.0;
                Navigator.pop(context);
                setState(() => _targetMonthlyBudget = amt);
                await widget.storageService.updateProfileField('monthly_budget', amt);
              },
              child: const Text('Save Budget'),
            ),
          ],
        );
      },
    );
  }

  void _showAccountDetailModal(String id, String name, double balance, Map<String, dynamic> rawAcc) {
    final walletTxs = _transactions.where((t) => t['account_id'] == id || t['account_id'] == name || t['from_account_id'] == name || t['to_account_id'] == name).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () {
                      Navigator.pop(context);
                      _showEditAccountModal(rawAcc);
                    },
                  ),
                ],
              ),
              Text('Available Balance: $_preferredCurrency ${balance.toStringAsFixed(2)}', style: TextStyle(fontSize: 14, color: balance < 0 ? Colors.red : Colors.green, fontWeight: FontWeight.w600)),
              const Divider(height: 24),
              const Text('Transactions for this Wallet:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 10),
              Expanded(child: _buildTransactionList(walletTxs)),
            ],
          ),
        );
      },
    );
  }

  void _showEditAccountModal(Map<String, dynamic> acc) {
    final nameController = TextEditingController(text: acc['name']);
    final openingController = TextEditingController(text: (acc['opening_balance'] ?? 0.0).toString());
    String selectedIcon = acc['icon'] ?? '💵';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Edit Wallet Details'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Wallet Name')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: openingController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    decoration: const InputDecoration(labelText: 'Opening Balance'),
                  ),
                  const SizedBox(height: 12),
                  const Text('Select Wallet Icon:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: _walletIcons.map((ic) {
                      return ChoiceChip(
                        label: Text(ic, style: const TextStyle(fontSize: 16)),
                        selected: selectedIcon == ic,
                        onSelected: (_) => setModalState(() => selectedIcon = ic),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    final n = nameController.text.trim();
                    final bal = double.tryParse(openingController.text) ?? 0.0;
                    if (n.isNotEmpty) {
                      Navigator.pop(context);
                      await widget.storageService.updateAccount(acc['id'], n, bal, selectedIcon);
                      _loadData();
                    }
                  },
                  child: const Text('Update Wallet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddAccountModal() {
    final nameController = TextEditingController();
    final balanceController = TextEditingController();
    String selectedIcon = '💵';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Add Custom Account / Wallet'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Wallet Name (e.g. Sampath Bank)')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: balanceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    decoration: const InputDecoration(labelText: 'Opening Balance'),
                  ),
                  const SizedBox(height: 12),
                  const Text('Select Icon:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: _walletIcons.map((ic) {
                      return ChoiceChip(
                        label: Text(ic, style: const TextStyle(fontSize: 16)),
                        selected: selectedIcon == ic,
                        onSelected: (_) => setModalState(() => selectedIcon = ic),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final bal = double.tryParse(balanceController.text) ?? 0.0;
                    if (name.isNotEmpty) {
                      Navigator.pop(context);
                      await widget.storageService.addAccount({
                        'id': 'acc-${DateTime.now().millisecondsSinceEpoch}',
                        'name': name,
                        'icon': selectedIcon,
                        'type': 'Custom',
                        'opening_balance': bal,
                        'current_balance': bal,
                      });
                      _loadData();
                    }
                  },
                  child: const Text('Create Wallet'),
                )
              ],
            );
          },
        );
      },
    );
  }

  // ----------------------------------------------------
  // 2. TRANSACTIONS TAB
  // ----------------------------------------------------
  Widget _buildTransactionsTab() {
    final filtered = _filteredByMonthTransactions.where((tx) {
      final matchesSearch = (tx['notes'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (tx['category'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase());
      
      bool matchesCat = _filterCategory == 'All';
      if (!matchesCat) {
        final txCat = (tx['category'] ?? '').toString();
        matchesCat = _isCategoryMatch(txCat, _filterCategory);
      }

      return matchesSearch && matchesCat;
    }).toList();

    final filteredIncome = filtered.where((t) => t['type'] == 'income').fold(0.0, (s, t) => s + (double.tryParse(t['amount'].toString()) ?? 0.0));
    final filteredExpense = filtered.where((t) => t['type'] == 'expense').fold(0.0, (s, t) => s + (double.tryParse(t['amount'].toString()) ?? 0.0));

    return Column(
      children: [
        // Top Search & Month Filter Header
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search notes or categories...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _selectedMonthFilter,
                    items: _availableMonths.map((m) {
                      return DropdownMenuItem(value: m, child: Text(m == 'All' ? '🗓️ All Months' : '📅 $m'));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedMonthFilter = val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // High-Contrast Filter Summary Metrics Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _isDarkMode ? Colors.blue[900]! : Colors.blue[200]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Count: ${filtered.length} txs', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : Colors.blue[900])),
                    Text('🟢 In: $_preferredCurrency ${filteredIncome.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: _isDarkMode ? const Color(0xFF4ADE80) : const Color(0xFF15803D), fontWeight: FontWeight.bold)),
                    Text('🔴 Out: $_preferredCurrency ${filteredExpense.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: _isDarkMode ? const Color(0xFFF87171) : const Color(0xFFB91C1C), fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Modern Filter Chips Bar
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    {'name': 'All', 'icon': '✨'},
                    ..._categories,
                  ].map((cat) {
                    final catName = cat['name'].toString();
                    final catIcon = cat['icon'].toString();
                    final isSelected = _filterCategory == catName;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        avatar: Text(catIcon, style: const TextStyle(fontSize: 14)),
                        label: Text(catName, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
                        selected: isSelected,
                        selectedColor: _themeColor.withOpacity(0.2),
                        onSelected: (_) => setState(() => _filterCategory = catName),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildTransactionList(filtered))),
      ],
    );
  }

  // ----------------------------------------------------
  // 3. ANALYTICS TAB
  // ----------------------------------------------------
  Widget _buildAnalyticsTab() {
    final monthTxs = _filteredByMonthTransactions;
    final monthIncome = monthTxs.where((t) => t['type'] == 'income').fold(0.0, (s, t) => s + (double.tryParse(t['amount'].toString()) ?? 0.0));
    final monthExpense = monthTxs.where((t) => t['type'] == 'expense').fold(0.0, (s, t) => s + (double.tryParse(t['amount'].toString()) ?? 0.0));

    final healthScore = monthIncome > 0 ? (((monthIncome - monthExpense) / monthIncome) * 100).clamp(0, 100).toStringAsFixed(0) : '85';
    final runwayMonths = (_totalNetWorth / (monthExpense > 0 ? monthExpense : 25000.0)).clamp(0.0, 99.0);

    // DYNAMIC AI WHAT-IF SIMULATOR CATEGORIES
    final expenseCategoriesWithTx = _categories.where((cat) {
      final cName = cat['name'].toString();
      return monthTxs.any((t) => (t['type'] == 'expense' || t['type'] == null) && _isCategoryMatch(t['category'].toString(), cName));
    }).toList();

    final activeSimCategories = expenseCategoriesWithTx.isNotEmpty ? expenseCategoriesWithTx : _categories;

    final currentSimCat = activeSimCategories.any((c) => c['name'] == _whatIfCategory)
        ? _whatIfCategory
        : (activeSimCategories.isNotEmpty ? activeSimCategories[0]['name'].toString() : 'Food & Dining');

    final selectedCatExpenses = monthTxs
        .where((t) => _isCategoryMatch(t['category'].toString(), currentSimCat) && (t['type'] == 'expense' || t['type'] == null))
        .fold(0.0, (s, t) => s + (double.tryParse(t['amount'].toString()) ?? 0.0));

    final monthlySavings = selectedCatExpenses * (_whatIfCutPct / 100.0);
    final sixMonthSavings = monthlySavings * 6;

    final maxCashflow = [monthIncome, monthExpense].reduce((a, b) => a > b ? a : b);
    final maxCashflowBase = maxCashflow > 0 ? maxCashflow : 1.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Financial Insights & AI Analytics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: _selectedMonthFilter,
                items: _availableMonths.map((m) {
                  return DropdownMenuItem(value: m, child: Text(m == 'All' ? '🗓️ All Months' : '📅 $m'));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedMonthFilter = val);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Card(
                  color: _isDarkMode ? Colors.green[900]!.withOpacity(0.3) : Colors.green[50],
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Health Score', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('$healthScore / 100 (Healthy)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  color: _isDarkMode ? Colors.purple[900]!.withOpacity(0.3) : Colors.purple[50],
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Emergency Runway', style: TextStyle(fontSize: 11, color: Colors.purple, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('${runwayMonths.toStringAsFixed(1)} Months', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.purple)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // DYNAMIC AI WHAT-IF PREDICTIVE SIMULATOR CARD
          Card(
            color: _isDarkMode ? Colors.blue[900]!.withOpacity(0.3) : Colors.blue[50],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.blue[200]!)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('🔮 AI "What-If" Predictive Simulator', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('Select Category: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 6),
                          DropdownButton<String>(
                            value: currentSimCat,
                            items: activeSimCategories.map((c) => DropdownMenuItem(value: c['name'].toString(), child: Text('${c['icon']} ${c['name']}'))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _whatIfCategory = val);
                            },
                          ),
                        ],
                      ),
                      Text('Spent: $_preferredCurrency ${selectedCatExpenses.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('What if I reduce $currentSimCat expenses by ${_whatIfCutPct.toStringAsFixed(0)}%?', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  Slider(
                    value: _whatIfCutPct,
                    min: 0,
                    max: 50,
                    divisions: 10,
                    label: '${_whatIfCutPct.toStringAsFixed(0)}%',
                    onChanged: (val) => setState(() => _whatIfCutPct = val),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('💵 Monthly Savings: +$_preferredCurrency ${monthlySavings.toStringAsFixed(0)} / mo', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
                      Text('🚀 6-Month Savings: +$_preferredCurrency ${sixMonthSavings.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // VERTICAL BAR CHART: INCOME VS EXPENSE CASHFLOW
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📊 Cashflow Comparison (Vertical Bar Chart)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 160,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Vertical Bar 1: Income
                        Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('$_preferredCurrency ${monthIncome.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                            const SizedBox(height: 6),
                            Container(
                              width: 48,
                              height: (120 * (monthIncome / maxCashflowBase)).clamp(10.0, 120.0),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text('🟢 Income', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        // Vertical Bar 2: Expense
                        Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('$_preferredCurrency ${monthExpense.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red)),
                            const SizedBox(height: 6),
                            Container(
                              width: 48,
                              height: (120 * (monthExpense / maxCashflowBase)).clamp(10.0, 120.0),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text('🔴 Expense', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // PER-CATEGORY SPENDING & BUDGET LIMITS (ALL Categories Shown)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('🎯 Category Spending & Budget Caps', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Row(
                        children: [
                          TextButton(
                            onPressed: _showSetSingleCategoryBudgetModal,
                            child: const Text('Set Single', style: TextStyle(fontSize: 11)),
                          ),
                          TextButton(
                            onPressed: _showSetBulkCategoryBudgetModal,
                            child: const Text('Set All (Bulk)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ..._categories.map((cat) {
                    final catName = cat['name'].toString();
                    final catIcon = cat['icon'].toString();
                    final limit = _categoryBudgets[catName] ?? 0.0;

                    final spent = monthTxs
                        .where((t) => _isCategoryMatch(t['category'].toString(), catName) && (t['type'] == 'expense' || t['type'] == null))
                        .fold(0.0, (s, t) => s + (double.tryParse(t['amount'].toString()) ?? 0.0));

                    final pct = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;

                    Color barColor = Colors.blue;
                    String statusBadge = 'No limit set';
                    if (limit > 0) {
                      if (spent >= limit) {
                        barColor = Colors.red;
                        statusBadge = '🔴 OVERBUDGET!';
                      } else if (pct >= 0.8) {
                        barColor = Colors.orange;
                        statusBadge = '🟡 Warning (80%+)';
                      } else {
                        barColor = Colors.green;
                        statusBadge = '🟢 Normal';
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('$catIcon $catName', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              Text(
                                limit > 0
                                    ? 'Spent: $_preferredCurrency ${spent.toStringAsFixed(0)} / ${limit.toStringAsFixed(0)} ($statusBadge)'
                                    : 'Spent: $_preferredCurrency ${spent.toStringAsFixed(0)} (No Limit)',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: barColor),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: limit > 0 ? pct : (spent > 0 ? 0.3 : 0.0),
                              minHeight: 8,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(barColor),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showSetSingleCategoryBudgetModal() {
    String selectedCat = _categories.isNotEmpty ? _categories[0]['name'] : 'Food & Dining';
    final controller = TextEditingController(text: (_categoryBudgets[selectedCat] ?? 0.0).toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Set Single Category Budget'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedCat,
                    items: _categories.map((c) => DropdownMenuItem(value: c['name'].toString(), child: Text('${c['icon']} ${c['name']}'))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          selectedCat = val;
                          controller.text = (_categoryBudgets[val] ?? 0.0).toStringAsFixed(0);
                        });
                      }
                    },
                    decoration: const InputDecoration(labelText: 'Select Category'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    decoration: const InputDecoration(labelText: 'Monthly Limit (e.g. 30000)'),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    final amt = double.tryParse(controller.text) ?? 0.0;
                    Navigator.pop(context);
                    await widget.storageService.saveCategoryBudget(selectedCat, amt);
                    _loadData();
                  },
                  child: const Text('Save Limit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSetBulkCategoryBudgetModal() {
    final Map<String, TextEditingController> controllers = {};
    for (var cat in _categories) {
      final name = cat['name'].toString();
      final currentLimit = _categoryBudgets[name] ?? 0.0;
      controllers[name] = TextEditingController(text: currentLimit > 0 ? currentLimit.toStringAsFixed(0) : '');
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Bulk Budget Limits for All'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final name = cat['name'].toString();
                final icon = cat['icon'].toString();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: TextField(
                    controller: controllers[name],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    decoration: InputDecoration(labelText: '$icon $name Limit'),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final Map<String, double> newBudgets = {};
                controllers.forEach((key, ctrl) {
                  final amt = double.tryParse(ctrl.text) ?? 0.0;
                  if (amt > 0) newBudgets[key] = amt;
                });
                await widget.storageService.saveAllCategoryBudgets(newBudgets);
                _loadData();
              },
              child: const Text('Save All Limits'),
            ),
          ],
        );
      },
    );
  }

  // ----------------------------------------------------
  // 4. GOALS TAB (With Interactive Deposit Money & Persistence Fix)
  // ----------------------------------------------------
  Widget _buildGoalsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Financial Goals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: _showAddGoalModal,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Goal'),
              )
            ],
          ),
          const SizedBox(height: 12),
          if (_goals.isEmpty) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 16.0),
                child: Column(
                  children: [
                    Icon(Icons.track_changes, size: 64, color: Colors.blue[300]),
                    const SizedBox(height: 16),
                    const Text('No Savings Goals Added Yet!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap "Add Goal" above to create your first financial target (e.g. New Phone, Car Deposit, Emergency Fund).',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            ..._goals.map((g) {
              final target = (double.tryParse(g['target'].toString()) ?? 50000.0);
              final current = (double.tryParse(g['current'].toString()) ?? 0.0);
              final pct = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;

              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(backgroundColor: Color(0xFFF3E8FF), child: Icon(Icons.stars, color: Colors.purple)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(g['title'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('Saved: $_preferredCurrency ${current.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} (${(pct * 100).toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            tooltip: 'Delete Goal',
                            onPressed: () async {
                              setState(() {
                                _goals.removeWhere((item) => item['id'] == g['id']);
                              });
                              await widget.storageService.saveGoals(_goals);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 8,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(pct >= 1.0 ? Colors.green : Colors.purple),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.add, size: 16, color: Colors.white),
                            label: const Text('Add Money / Deposit', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: () => _showDepositToGoalModal(g),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  void _showDepositToGoalModal(Map<String, dynamic> goal) {
    final depositController = TextEditingController();
    String fromWallet = _accounts.isNotEmpty ? _accounts[0]['name'] : '💵 Cash Wallet';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text('Deposit to ${goal['title']}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: fromWallet,
                    items: _accounts.map((a) => DropdownMenuItem(value: a['name'].toString(), child: Text(a['name'].toString()))).toList(),
                    onChanged: (val) => setModalState(() => fromWallet = val ?? fromWallet),
                    decoration: const InputDecoration(labelText: 'Pay From Wallet'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: depositController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    decoration: const InputDecoration(labelText: 'Deposit Amount (e.g. 5000)'),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    final amt = double.tryParse(depositController.text) ?? 0.0;
                    if (amt > 0) {
                      Navigator.pop(context);
                      final currentSaved = (double.tryParse(goal['current'].toString()) ?? 0.0);
                      
                      setState(() {
                        goal['current'] = currentSaved + amt;
                      });

                      await widget.storageService.saveGoals(_goals);

                      await _addTransaction(
                        amt,
                        'Savings',
                        'expense',
                        'Goal Savings: ${goal['title']}',
                        'Deposit',
                        fromWallet,
                        DateTime.now(),
                      );
                    }
                  },
                  child: const Text('Deposit Money'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddGoalModal() {
    final titleController = TextEditingController();
    final targetController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Add Savings Goal'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Goal Title (e.g. Car Deposit)')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: targetController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    decoration: const InputDecoration(labelText: 'Target Amount'),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    final t = titleController.text.trim();
                    final target = double.tryParse(targetController.text) ?? 50000.0;
                    if (t.isNotEmpty) {
                      Navigator.pop(context);
                      final newGoal = {
                        'id': 'g-${DateTime.now().millisecondsSinceEpoch}',
                        'title': t,
                        'target': target,
                        'current': 0.0,
                      };
                      setState(() {
                        _goals.add(newGoal);
                      });
                      await widget.storageService.saveGoals(_goals);
                    }
                  },
                  child: const Text('Create Goal'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ----------------------------------------------------
  // 5. SETTINGS TAB
  // ----------------------------------------------------
  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // SECTION 1: Profile & Financial Preferences
        _buildSettingsHeader('1. 👤 Profile & Financial Preferences'),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              ListTile(
                leading: Text(_avatarEmoji, style: const TextStyle(fontSize: 22)),
                title: const Text('Edit Profile Name & Avatar'),
                subtitle: Text(_profile['name'] ?? 'Alex'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showEditProfileDialog,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.monetization_on, color: Colors.green),
                title: const Text('Default Currency Selector'),
                subtitle: Text('Currently set to $_preferredCurrency'),
                trailing: DropdownButton<String>(
                  value: _preferredCurrency,
                  items: ['LKR', 'USD', 'EUR', 'GBP', 'INR', 'AUD', 'CAD'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) async {
                    if (val != null) {
                      setState(() => _preferredCurrency = val);
                      await widget.storageService.updateProfileField('currency', val);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // SECTION 2: Privacy & Security Controls
        _buildSettingsHeader('2. 🔐 Privacy & Security Controls'),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.notifications_active, color: Colors.amber),
                title: const Text('🔔 Daily Expense Reminder'),
                subtitle: Text(_dailyReminderEnabled ? 'Remind at ${_formatReminderHour(_dailyReminderHour)}' : 'Disabled'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_dailyReminderEnabled)
                      DropdownButton<int>(
                        value: _dailyReminderHour,
                        items: List.generate(24, (h) => DropdownMenuItem(value: h, child: Text(_formatReminderHour(h)))),
                        onChanged: (val) async {
                          if (val != null) {
                            setState(() => _dailyReminderHour = val);
                            await widget.storageService.updateProfileField('daily_reminder_hour', val);
                          }
                        },
                      ),
                    Switch(
                      value: _dailyReminderEnabled,
                      onChanged: (val) async {
                        setState(() => _dailyReminderEnabled = val);
                        await widget.storageService.updateProfileField('daily_reminder_enabled', val);
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.visibility_off, color: Colors.purple),
                title: const Text('Stealth Mode (Mask Balances ••••••)'),
                subtitle: const Text('Hides net worth & wallet balances in public'),
                value: _stealthMode,
                onChanged: (val) async {
                  setState(() => _stealthMode = val);
                  await widget.storageService.updateProfileField('stealth_mode', val);
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.lock, color: Colors.orange),
                title: const Text('Optional 4-Digit PIN Lock'),
                subtitle: Text(_pinLockEnabled ? 'Active PIN: $_pinCode' : 'Disabled (Tap to set PIN)'),
                value: _pinLockEnabled,
                onChanged: (val) async {
                  if (val) {
                    _showSetPinDialog();
                  } else {
                    setState(() => _pinLockEnabled = false);
                    await widget.storageService.updateProfileField('pin_lock', false);
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // SECTION 3: Data Backup & Report Exporter
        _buildSettingsHeader('3. 💾 Data Backup & Report Exporter'),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: const Text('📄 Export Executive PDF Statement'),
                subtitle: const Text('Download / Copy printable financial report'),
                trailing: const Icon(Icons.download),
                onTap: () async {
                  final reportStr = await widget.storageService.generatePdfStatementReport();
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Executive Financial Statement Report'),
                      content: SingleChildScrollView(child: SelectableText(reportStr, style: const TextStyle(fontFamily: 'monospace', fontSize: 11))),
                      actions: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copy Report'),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: reportStr));
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('📋 Executive PDF Statement copied to clipboard! You can save as a document file.')),
                            );
                          },
                        ),
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                      ],
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.table_chart, color: Colors.green),
                title: const Text('Export Data to CSV / Excel'),
                subtitle: const Text('Download / Copy transactions spreadsheet'),
                trailing: const Icon(Icons.download),
                onTap: () async {
                  final csvStr = await widget.storageService.exportCsvData();
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Exported CSV Spreadsheet'),
                      content: SingleChildScrollView(child: SelectableText(csvStr, style: const TextStyle(fontSize: 11))),
                      actions: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copy CSV Data'),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: csvStr));
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('📋 CSV Spreadsheet data copied to clipboard! You can paste and save as a .csv file.')),
                            );
                          },
                        ),
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                      ],
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Reset & Wipe Data'),
                subtitle: const Text('Factory reset all local records'),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Reset Profile & Data?'),
                      content: const Text('This will wipe all local wallets and transactions. Cannot be undone!'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Wipe All Data', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await widget.storageService.clearAllData();
                    widget.onResetRequested();
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // SECTION 4: Themes & Accent Color Palette
        _buildSettingsHeader('4. 🎨 Themes & Accent Color Palette'),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(_isDarkMode ? Icons.dark_mode : Icons.light_mode, color: Colors.amber),
                  title: const Text('Dark Mode / Light Mode'),
                  subtitle: Text(_isDarkMode ? 'Dark Theme Active' : 'Light Theme Active'),
                  value: _isDarkMode,
                  onChanged: (val) async {
                    setState(() => _isDarkMode = val);
                    await widget.storageService.updateProfileField('dark_mode', val);
                  },
                ),
                const Divider(height: 20),
                const Text('Select Accent Color Theme:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildThemeColorOption('Royal Blue 💙', const Color(0xFF2563EB)),
                    _buildThemeColorOption('Emerald 💚', const Color(0xFF10B981)),
                    _buildThemeColorOption('Purple 💜', const Color(0xFF8B5CF6)),
                    _buildThemeColorOption('Midnight 🌙', const Color(0xFF1E293B)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  void _showSetPinDialog() {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set 4-Digit Security PIN'),
          content: TextField(
            controller: pinController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Enter 4-Digit PIN (e.g. 1234)'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final p = pinController.text.trim();
                if (p.length == 4) {
                  Navigator.pop(context);
                  setState(() {
                    _pinLockEnabled = true;
                    _pinCode = p;
                  });
                  await widget.storageService.updateProfileField('pin_lock', true);
                  await widget.storageService.updateProfileField('pin_code', p);
                }
              },
              child: const Text('Save PIN'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSettingsHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildThemeColorOption(String label, Color color) {
    final isSelected = _themeColor.value == color.value;
    return GestureDetector(
      onTap: () async {
        setState(() => _themeColor = color);
        await widget.storageService.updateProfileField('theme_color_val', color.value);
      },
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: color,
            radius: 20,
            child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _profile['name'] ?? 'Alex');
    String selectedAvatar = _avatarEmoji;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Edit Profile & Avatar'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Profile Display Name')),
                    const SizedBox(height: 12),
                    const Text('Select Avatar Emoji:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _avatars.map((av) {
                        return ChoiceChip(
                          label: Text(av, style: const TextStyle(fontSize: 20)),
                          selected: selectedAvatar == av,
                          onSelected: (_) => setModalState(() => selectedAvatar = av),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    final n = nameController.text.trim();
                    if (n.isNotEmpty) {
                      Navigator.pop(context);
                      setState(() {
                        _profile['name'] = n;
                        _avatarEmoji = selectedAvatar;
                      });
                      await widget.storageService.updateProfileField('name', n);
                      await widget.storageService.updateProfileField('avatar_emoji', selectedAvatar);
                    }
                  },
                  child: const Text('Save Profile'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTransactionList(List<Map<String, dynamic>> txList) {
    if (txList.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(child: Text('No transactions recorded yet.', style: TextStyle(color: Colors.grey))),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: txList.length,
      itemBuilder: (context, index) {
        final tx = txList[index];
        final type = tx['type'];
        final isExpense = type == 'expense';
        final isTransfer = type == 'transfer';
        final amtStr = _stealthMode ? '••••' : tx['amount'].toString();

        IconData leadingIcon = isExpense ? Icons.arrow_downward : Icons.arrow_upward;
        Color leadingColor = isExpense ? Colors.red : Colors.green;
        if (isTransfer) {
          leadingIcon = Icons.swap_horiz;
          leadingColor = Colors.blue;
        }

        String subtitleText = '${tx['date']} • ${tx['category']}';
        if (isTransfer) {
          subtitleText = '${tx['date']} • ${tx['from_account_id']} ➡️ ${tx['to_account_id']}';
        }

        return Dismissible(
          key: Key(tx['id'] ?? index.toString()),
          background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16), child: const Icon(Icons.delete, color: Colors.white)),
          onDismissed: (_) async {
            await widget.storageService.deleteTransaction(tx['id']);
            _loadData();
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: leadingColor.withOpacity(0.1),
                child: Icon(leadingIcon, color: leadingColor),
              ),
              title: Text(tx['notes'] ?? tx['category'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
              subtitle: Text(subtitleText, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
              trailing: Text(
                isTransfer ? '🔄 $_preferredCurrency $amtStr' : '${isExpense ? '-' : '+'} $_preferredCurrency $amtStr',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isTransfer ? Colors.blue : (isExpense ? Colors.red : Colors.green)),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAddTransactionBottomSheet() {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final locationController = TextEditingController();
    DateTime selectedTxDate = DateTime.now();

    String category = _categories.isNotEmpty ? _categories[0]['name'] : 'Food & Dining';
    String type = 'expense';
    String fromAccount = _accounts.isNotEmpty ? _accounts[0]['name'] : '💵 Cash Wallet';
    String toAccount = _accounts.length > 1 ? _accounts[1]['name'] : (_accounts.isNotEmpty ? _accounts[0]['name'] : '🏦 Bank Account');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isExpense = type == 'expense';
            final isTransfer = type == 'transfer';
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 24,
                left: 24,
                right: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(isTransfer ? 'Transfer Money (Wallet ➡️ Wallet)' : (isExpense ? 'Add Expense' : 'Add Income'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('📅 Date: ${selectedTxDate.toIso8601String().substring(0, 10)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        TextButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedTxDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setModalState(() => selectedTxDate = picked);
                            }
                          },
                          icon: const Icon(Icons.edit_calendar, size: 16),
                          label: const Text('Change Date'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                      decoration: const InputDecoration(labelText: 'Amount'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: type,
                      items: const [
                        DropdownMenuItem(value: 'expense', child: Text('Expense 🔴')),
                        DropdownMenuItem(value: 'income', child: Text('Income 🟢')),
                        DropdownMenuItem(value: 'transfer', child: Text('Inter-Wallet Transfer 🔄')),
                      ],
                      onChanged: (val) => setModalState(() => type = val ?? 'expense'),
                      decoration: const InputDecoration(labelText: 'Transaction Type'),
                    ),
                    const SizedBox(height: 12),

                    if (isTransfer) ...[
                      DropdownButtonFormField<String>(
                        value: fromAccount,
                        items: _accounts.map((a) => DropdownMenuItem(value: a['name'].toString(), child: Text(a['name'].toString()))).toList(),
                        onChanged: (val) => setModalState(() => fromAccount = val ?? fromAccount),
                        decoration: const InputDecoration(labelText: 'From Source Wallet'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: toAccount,
                        items: _accounts.map((a) => DropdownMenuItem(value: a['name'].toString(), child: Text(a['name'].toString()))).toList(),
                        onChanged: (val) => setModalState(() => toAccount = val ?? toAccount),
                        decoration: const InputDecoration(labelText: 'To Destination Wallet'),
                      ),
                    ] else ...[
                      DropdownButtonFormField<String>(
                        value: fromAccount,
                        items: _accounts.map((a) => DropdownMenuItem(value: a['name'].toString(), child: Text(a['name'].toString()))).toList(),
                        onChanged: (val) => setModalState(() => fromAccount = val ?? fromAccount),
                        decoration: InputDecoration(labelText: isExpense ? 'Pay From Wallet / Account' : 'Deposit To Wallet / Account'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: category,
                        items: [
                          ..._categories.map((c) => DropdownMenuItem(value: c['name'].toString(), child: Text('${c['icon']} ${c['name']}'))),
                        ],
                        onChanged: (val) => setModalState(() => category = val ?? category),
                        decoration: const InputDecoration(labelText: 'Category'),
                      ),
                    ],

                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(labelText: 'Notes (e.g. Pizza Hut, Rent, ATM Cash Withdrawal)'),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _themeColor),
                      onPressed: () {
                        final amt = double.tryParse(amountController.text) ?? 0.0;
                        if (amt > 0) {
                          Navigator.pop(context);
                          _addTransaction(
                            amt,
                            isTransfer ? 'Transfer' : category,
                            type,
                            noteController.text,
                            locationController.text,
                            fromAccount,
                            selectedTxDate,
                            fromAccountId: fromAccount,
                            toAccountId: isTransfer ? toAccount : null,
                          );
                        }
                      },
                      child: const Text('Save Transaction', style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
