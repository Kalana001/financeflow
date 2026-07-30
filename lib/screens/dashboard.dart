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
  Map<String, dynamic> _profile = {};
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterCategory = 'All';
  String _selectedMonthFilter = 'All';

  // Preferences
  bool _simpleMode = false;
  String _preferredCurrency = 'LKR';
  double _targetMonthlyBudget = 100000.0;
  double _whatIfCutPct = 20.0;
  String _whatIfCategory = 'Food';
  Color _themeColor = const Color(0xFF2563EB);

  // High Value OTP Prompt State
  Map<String, dynamic>? _pendingHighValueTx;
  final _otpController = TextEditingController();

  // Icon Choices for Custom Wallets
  final List<String> _walletIcons = ['💵', '🏦', '💳', '📱', '🐖', '💎', '🛒', '⚡'];

  // Category Icon Palette
  final List<String> _categoryIcons = ['🍔', '🚗', '⚡', '🛒', '💰', '🏥', '🍿', '🏋️', '🐶', '🎁', '✈️', '🎓', '🎮', '☕'];

  // Dynamic Goals List starts EMPTY for new users
  final List<Map<String, dynamic>> _goals = [];

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
      final prof = (await widget.storageService.getProfile()) ?? {};
      setState(() {
        _transactions = txs;
        _accounts = accs;
        _categories = cats;
        _profile = prof;
        _preferredCurrency = prof['currency'] ?? 'LKR';
        _simpleMode = prof['simple_mode'] == true;
        _targetMonthlyBudget = (double.tryParse(prof['monthly_budget'].toString()) ?? 100000.0);
      });
    } catch (e) {
      print('Error loading local data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // List of available months for filter dropdown
  List<String> get _availableMonths {
    final Set<String> months = {'All'};
    for (var tx in _transactions) {
      final d = tx['date'].toString();
      if (d.length >= 7) {
        months.add(d.substring(0, 7)); // e.g. "2026-07"
      }
    }
    return months.toList();
  }

  // Filtered transactions by selected month
  List<Map<String, dynamic>> get _filteredByMonthTransactions {
    if (_selectedMonthFilter == 'All') return _transactions;
    return _transactions.where((t) => t['date'].toString().startsWith(_selectedMonthFilter)).toList();
  }

  // Dynamic Net Worth calculation: Sum of all wallet balances
  double get _totalNetWorth => _accounts.fold(
      0.0, (sum, acc) => sum + (double.tryParse(acc['current_balance'].toString()) ?? 0.0));

  double get _totalIncome => _filteredByMonthTransactions
      .where((t) => t['type'] == 'income')
      .fold(0.0, (sum, t) => sum + (double.tryParse(t['amount'].toString()) ?? 0.0));

  double get _totalExpense => _filteredByMonthTransactions
      .where((t) => t['type'] == 'expense')
      .fold(0.0, (sum, t) => sum + (double.tryParse(t['amount'].toString()) ?? 0.0));

  Future<void> _addTransaction(double amount, String category, String type, String notes, String location, String accountId, DateTime selectedDate) async {
    final newTx = {
      'id': 'tx-${DateTime.now().millisecondsSinceEpoch}',
      'amount': amount,
      'category': category,
      'type': type,
      'account_id': accountId,
      'payment_method': 'Cash',
      'date': selectedDate.toIso8601String().substring(0, 10),
      'notes': notes.isEmpty ? category : notes,
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('FinanceFlow', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          )
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
    );
  }

  // ----------------------------------------------------
  // 1. HOME TAB
  // ----------------------------------------------------
  Widget _buildHomeTab() {
    final budgetPct = _targetMonthlyBudget > 0 ? (_totalExpense / _targetMonthlyBudget).clamp(0.0, 1.0) : 0.0;
    final remainingBudget = (_targetMonthlyBudget - _totalExpense).clamp(0.0, double.infinity);

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
                child: Icon(Icons.person, color: _themeColor),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Total Net Worth Card
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
                const Text('TOTAL NET WORTH (ALL WALLETS)', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$_preferredCurrency ${_totalNetWorth.toStringAsFixed(2)}',
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
                      Expanded(child: Text('🟢 Income: $_preferredCurrency ${_totalIncome.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      Expanded(child: Text('🔴 Expense: $_preferredCurrency ${_totalExpense.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
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

          // Top Savings Goals Overview
          if (_goals.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Top Savings Goals', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                TextButton(onPressed: () => setState(() => _currentTab = 3), child: const Text('View All')),
              ],
            ),
            const SizedBox(height: 6),
            Column(
              children: _goals.take(2).map((g) {
                final pct = (g['current'] / g['target']).clamp(0.0, 1.0);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: (g['color'] as Color).withOpacity(0.1), child: Icon(g['icon'], color: g['color'])),
                    title: Text(g['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('Saved: $_preferredCurrency ${g['current']} / ${g['target']}', style: const TextStyle(fontSize: 11)),
                    trailing: Text('${(pct * 100).toStringAsFixed(0)}%', style: TextStyle(fontWeight: FontWeight.bold, color: g['color'])),
                  ),
                );
              }).toList(),
            ),
          ] else ...[
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(backgroundColor: Colors.blue[50], child: const Icon(Icons.track_changes, color: Colors.blue)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Set a Savings Goal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('Create target goals to track savings velocity.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _currentTab = 3),
                      child: const Text('Add Goal'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountCard(String id, String name, String iconStr, double balance, Map<String, dynamic> rawAcc) {
    return GestureDetector(
      onTap: () => _showAccountDetailModal(id, name, balance, rawAcc),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[300]!),
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
            Text('$_preferredCurrency ${balance.toStringAsFixed(2)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: balance < 0 ? Colors.red : Colors.black87)),
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
    final walletTxs = _transactions.where((t) => t['account_id'] == id || t['account_id'] == name).toList();

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
  // 2. TRANSACTIONS TAB (With Monthly Filter)
  // ----------------------------------------------------
  Widget _buildTransactionsTab() {
    final filtered = _filteredByMonthTransactions.where((tx) {
      final matchesSearch = (tx['notes'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (tx['category'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCat = _filterCategory == 'All' || tx['category'] == _filterCategory;
      return matchesSearch && matchesCat;
    }).toList();

    return Column(
      children: [
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
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    'All',
                    ..._categories.map((c) => '${c['icon']} ${c['name']}'),
                  ].map((cat) {
                    final selected = _filterCategory == cat || (_filterCategory == 'Food' && cat.contains('Food'));
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: selected,
                        onSelected: (_) => setState(() => _filterCategory = cat.replaceAll(RegExp(r'[^\w\s]'), '').trim()),
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
  // 3. ANALYTICS TAB (With Monthly Filter & Weekly Breakdown Bar Chart)
  // ----------------------------------------------------
  Widget _buildAnalyticsTab() {
    if (_transactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.insights, size: 64, color: Colors.blue[300]),
              const SizedBox(height: 16),
              const Text('No Transactions Recorded Yet!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Log your first income or expense transaction to unlock live Financial Health Scores, Category Breakdown, and AI Advisor tips.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: _themeColor),
                onPressed: () => _showAddTransactionBottomSheet(),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Add First Transaction', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final monthTxs = _filteredByMonthTransactions;
    final monthIncome = monthTxs.where((t) => t['type'] == 'income').fold(0.0, (s, t) => s + (double.tryParse(t['amount'].toString()) ?? 0.0));
    final monthExpense = monthTxs.where((t) => t['type'] == 'expense').fold(0.0, (s, t) => s + (double.tryParse(t['amount'].toString()) ?? 0.0));

    final healthScore = monthIncome > 0 ? (((monthIncome - monthExpense) / monthIncome) * 100).clamp(0, 100).toStringAsFixed(0) : '85';
    final runwayMonths = (_totalNetWorth / (monthExpense > 0 ? monthExpense : 25000.0)).clamp(0.0, 99.0);

    final selectedCatExpenses = monthTxs
        .where((t) => t['category'] == _whatIfCategory && t['type'] == 'expense')
        .fold(0.0, (s, t) => s + (double.tryParse(t['amount'].toString()) ?? 0.0));

    final sixMonthSavings = (selectedCatExpenses * (_whatIfCutPct / 100.0)) * 6;

    final totalCashflow = (monthIncome + monthExpense) > 0 ? (monthIncome + monthExpense) : 1.0;
    final incomePct = (monthIncome / totalCashflow).clamp(0.0, 1.0);
    final expensePct = (monthExpense / totalCashflow).clamp(0.0, 1.0);

    // Week-by-Week Spending Breakdown Calculation
    double week1 = 0, week2 = 0, week3 = 0, week4 = 0;
    for (var tx in monthTxs) {
      if (tx['type'] == 'expense' && tx['date'] != null) {
        final day = int.tryParse(tx['date'].toString().split('-').last) ?? 1;
        final amt = double.tryParse(tx['amount'].toString()) ?? 0.0;
        if (day <= 7) week1 += amt;
        else if (day <= 14) week2 += amt;
        else if (day <= 21) week3 += amt;
        else week4 += amt;
      }
    }
    final maxWeekSpend = [week1, week2, week3, week4].reduce((a, b) => a > b ? a : b);
    final maxWeekBase = maxWeekSpend > 0 ? maxWeekSpend : 1.0;

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
                  color: Colors.green[50],
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
                  color: Colors.purple[50],
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
          const SizedBox(height: 12),

          // 📅 Week-by-Week Spending Breakdown Chart
          const Text('📅 Week-by-Week Spending Breakdown', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildBarChartRow('Week 1 (Days 1 - 7)', (week1 / maxWeekBase).clamp(0.0, 1.0), Colors.blue, '$_preferredCurrency ${week1.toStringAsFixed(0)}'),
                  const SizedBox(height: 10),
                  _buildBarChartRow('Week 2 (Days 8 - 14)', (week2 / maxWeekBase).clamp(0.0, 1.0), Colors.indigo, '$_preferredCurrency ${week2.toStringAsFixed(0)}'),
                  const SizedBox(height: 10),
                  _buildBarChartRow('Week 3 (Days 15 - 21)', (week3 / maxWeekBase).clamp(0.0, 1.0), Colors.orange, '$_preferredCurrency ${week3.toStringAsFixed(0)}'),
                  const SizedBox(height: 10),
                  _buildBarChartRow('Week 4 (Days 22 - End)', (week4 / maxWeekBase).clamp(0.0, 1.0), Colors.teal, '$_preferredCurrency ${week4.toStringAsFixed(0)}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 🔮 AI What-If Simulator
          Card(
            color: Colors.blue[50],
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
                    children: [
                      const Text('Select Category: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _whatIfCategory,
                        items: ['Food', 'Transport', 'Bills', 'Shopping'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _whatIfCategory = val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('What if I reduce $_whatIfCategory expenses by ${_whatIfCutPct.toStringAsFixed(0)}%?', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Slider(
                    value: _whatIfCutPct,
                    min: 0,
                    max: 50,
                    divisions: 10,
                    label: '${_whatIfCutPct.toStringAsFixed(0)}%',
                    onChanged: (val) => setState(() => _whatIfCutPct = val),
                  ),
                  Text(
                    '👉 Projected 6-Month Savings: +$_preferredCurrency ${sixMonthSavings.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Cashflow Ratio Bar Chart
          const Text('Income vs Expense Cashflow Ratio', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildBarChartRow('🟢 Income Cashflow', incomePct, Colors.green, '$_preferredCurrency ${monthIncome.toStringAsFixed(0)}'),
                  const SizedBox(height: 12),
                  _buildBarChartRow('🔴 Expense Outflow', expensePct, Colors.red, '$_preferredCurrency ${monthExpense.toStringAsFixed(0)}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Category Spending Donut Chart
          const Text('Category Spending Distribution', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _themeColor, width: 14),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Total Spend', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text('$_preferredCurrency ${monthExpense.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._categories.map((cat) {
                    final catName = cat['name'].toString().split(' ').first;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: _buildCategoryProgressRow('${cat['icon']} ${cat['name']}', _getCategoryPct(catName, monthExpense), Colors.orange),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _getCategoryPct(String cat, double totalExp) {
    if (totalExp == 0) return 0.0;
    final catExp = _filteredByMonthTransactions.where((t) => t['category'].toString().toLowerCase().contains(cat.toLowerCase()) && t['type'] == 'expense').fold(0.0, (s, t) => s + (double.tryParse(t['amount'].toString()) ?? 0.0));
    return (catExp / totalExp).clamp(0.0, 1.0);
  }

  Widget _buildBarChartRow(String label, double pct, Color color, String amountStr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            Text(amountStr, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 10,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryProgressRow(String label, double pct, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            Text('${(pct * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: pct, backgroundColor: Colors.grey[200], valueColor: AlwaysStoppedAnimation<Color>(color)),
      ],
    );
  }

  // Modal to Add Custom Expense Category
  Future<String?> _showAddCategoryModal() async {
    final nameController = TextEditingController();
    String selectedIcon = '🍔';

    return showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Add Custom Category'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Category Name (e.g. Gym)')),
                  const SizedBox(height: 12),
                  const Text('Select Category Icon:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categoryIcons.map((ic) {
                      return ChoiceChip(
                        label: Text(ic, style: const TextStyle(fontSize: 18)),
                        selected: selectedIcon == ic,
                        onSelected: (_) => setModalState(() => selectedIcon = ic),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    final n = nameController.text.trim();
                    if (n.isNotEmpty) {
                      final newCat = {'name': n, 'icon': selectedIcon};
                      await widget.storageService.addCategory(newCat);
                      await _loadData();
                      Navigator.pop(context, n);
                    }
                  },
                  child: const Text('Create Category'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ----------------------------------------------------
  // 4. GOALS TAB
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
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: _themeColor),
                      onPressed: _showAddGoalModal,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('Create First Goal', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            ..._goals.map((g) {
              final target = (g['target'] as double);
              final current = (g['current'] as double);
              final pct = (current / target).clamp(0.0, 1.0);
              final remaining = (target - current).clamp(0.0, double.infinity);

              final depositsCount = (g['deposits_count'] as int? ?? 1);
              final lastAmount = (g['last_deposit_amount'] as double? ?? 15000.0);

              String velocityStr;
              if (depositsCount >= 5) {
                final estDays = (remaining / (lastAmount / 5.0)).ceil().clamp(1, 999);
                velocityStr = '🚀 High Regularity: Completed in ~$estDays days!';
              } else {
                final months = (remaining / lastAmount).ceil().clamp(1, 48);
                velocityStr = '⏱️ Regularity: Est. completion in ~$months months';
              }

              return GestureDetector(
                onTap: () => _showGoalDetailModal(g),
                child: Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(backgroundColor: (g['color'] as Color).withOpacity(0.1), child: Icon(g['icon'], color: g['color'])),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(g['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text('Saved: $_preferredCurrency ${current.toStringAsFixed(0)} / ${target.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 16, color: Colors.blue),
                              onPressed: () => _showEditGoalModal(g),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 8,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(g['color']),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(velocityStr, style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                              onPressed: () => _showDepositToGoalModal(g),
                              icon: const Icon(Icons.add, size: 14),
                              label: const Text('Deposit', style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  void _showGoalDetailModal(Map<String, dynamic> goal) {
    final historyList = (goal['history'] as List? ?? []);
    final target = (goal['target'] as double);
    final current = (goal['current'] as double);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${goal['title']} - Activity History', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Target: $_preferredCurrency ${target.toStringAsFixed(0)} • Saved: $_preferredCurrency ${current.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const Divider(height: 24),
              const Text('Goal History Log:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 10),
              historyList.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No deposit or target history logged yet.', style: TextStyle(color: Colors.grey)),
                    )
                  : Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: historyList.length,
                        itemBuilder: (context, index) {
                          final h = historyList[index];
                          final isDeposit = h['type'] == 'deposit';
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(isDeposit ? Icons.arrow_upward : Icons.edit, color: isDeposit ? Colors.green : Colors.blue),
                            title: Text(isDeposit ? 'Deposit: +$_preferredCurrency ${h['amount']}' : 'Target Updated: $_preferredCurrency ${h['amount']}'),
                            subtitle: Text('${h['date']} • ${h['notes']}'),
                          );
                        },
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  void _showDepositToGoalModal(Map<String, dynamic> goal) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Deposit to "${goal['title']}"'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            decoration: const InputDecoration(labelText: 'Deposit Amount (e.g. 5000)'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final amt = double.tryParse(controller.text) ?? 0.0;
                if (amt > 0) {
                  Navigator.pop(context);
                  setState(() {
                    goal['current'] = (goal['current'] as double) + amt;
                    goal['deposits_count'] = (goal['deposits_count'] as int? ?? 1) + 1;
                    goal['last_deposit_amount'] = amt;

                    final history = (goal['history'] as List? ?? []);
                    history.insert(0, {
                      'type': 'deposit',
                      'amount': amt,
                      'date': DateTime.now().toIso8601String().substring(0, 16).replaceAll('T', ' '),
                      'notes': 'Manual goal deposit'
                    });
                    goal['history'] = history;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('🎉 Deposited $_preferredCurrency $amt into ${goal['title']}!')),
                  );
                }
              },
              child: const Text('Save Deposit'),
            ),
          ],
        );
      },
    );
  }

  void _showEditGoalModal(Map<String, dynamic> goal) {
    final titleController = TextEditingController(text: goal['title']);
    final targetController = TextEditingController(text: (goal['target'] as double).toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Goal Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Goal Title')),
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
              onPressed: () {
                final t = titleController.text.trim();
                final target = double.tryParse(targetController.text) ?? 50000.0;
                if (t.isNotEmpty) {
                  Navigator.pop(context);
                  setState(() {
                    goal['title'] = t;
                    goal['target'] = target;

                    final history = (goal['history'] as List? ?? []);
                    history.insert(0, {
                      'type': 'target_change',
                      'amount': target,
                      'date': DateTime.now().toIso8601String().substring(0, 16).replaceAll('T', ' '),
                      'notes': 'Target amount updated to $target'
                    });
                    goal['history'] = history;
                  });
                }
              },
              child: const Text('Update Goal'),
            ),
          ],
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
              onPressed: () {
                final t = titleController.text.trim();
                final target = double.tryParse(targetController.text) ?? 50000.0;
                if (t.isNotEmpty) {
                  Navigator.pop(context);
                  setState(() {
                    _goals.add({
                      'id': 'g-${DateTime.now().millisecondsSinceEpoch}',
                      'title': t,
                      'target': target,
                      'current': 0.0,
                      'deposits_count': 1,
                      'last_deposit_amount': 10000.0,
                      'icon': Icons.stars,
                      'color': Colors.purple,
                      'history': [
                        {
                          'type': 'target_change',
                          'amount': target,
                          'date': DateTime.now().toIso8601String().substring(0, 16).replaceAll('T', ' '),
                          'notes': 'Goal created with target $target'
                        }
                      ],
                    });
                  });
                }
              },
              child: const Text('Create Goal'),
            ),
          ],
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
        const Text('Preferences & Customization', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),

        Card(
          child: SwitchListTile(
            title: const Text('Simple Beginner Mode'),
            subtitle: const Text('Hides complex tools'),
            value: _simpleMode,
            onChanged: (val) {
              setState(() => _simpleMode = val);
              widget.storageService.updateProfileField('simple_mode', val);
            },
          ),
        ),

        Card(
          child: ListTile(
            title: const Text('Preferred Currency'),
            subtitle: Text('Currently set to $_preferredCurrency'),
            trailing: DropdownButton<String>(
              value: _preferredCurrency,
              items: ['LKR', 'USD', 'EUR', 'GBP', 'INR'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _preferredCurrency = val);
                  widget.storageService.updateProfileField('currency', val);
                }
              },
            ),
          ),
        ),

        const SizedBox(height: 16),
        const Text('Data Privacy & Reset', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),

        Card(
          child: ListTile(
            title: const Text('Export Local Data (JSON)'),
            subtitle: const Text('Export a copy of your records in JSON format'),
            trailing: const Icon(Icons.download),
            onTap: () async {
              final jsonStr = await widget.storageService.exportAllDataJson();
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Data Exported'),
                  content: SingleChildScrollView(child: Text(jsonStr)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    )
                  ],
                ),
              );
            },
          ),
        ),

        Card(
          child: ListTile(
            title: const Text('Reset Profile & Clear Data'),
            subtitle: const Text('Wipes profile name and local transactions'),
            trailing: const Icon(Icons.delete, color: Colors.red),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Reset Profile & Data?'),
                  content: const Text('This action cannot be undone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset', style: TextStyle(color: Colors.red))),
                  ],
                ),
              );

              if (confirm == true) {
                await widget.storageService.clearAllData();
                widget.onResetRequested();
              }
            },
          ),
        ),
      ],
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
        final isExpense = tx['type'] == 'expense';
        return Dismissible(
          key: Key(tx['id'] ?? index.toString()),
          background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16), child: const Icon(Icons.delete, color: Colors.white)),
          onDismissed: (_) async {
            await widget.storageService.deleteTransaction(tx['id']);
            _loadData();
          },
          child: Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isExpense ? Colors.red[50] : Colors.green[50],
                child: Icon(isExpense ? Icons.arrow_downward : Icons.arrow_upward, color: isExpense ? Colors.red : Colors.green),
              ),
              title: Text(tx['notes'] ?? tx['category'], overflow: TextOverflow.ellipsis),
              subtitle: Text('${tx['date']} • ${tx['category']} • ${tx['location'] ?? ''}', overflow: TextOverflow.ellipsis),
              trailing: Text(
                '${isExpense ? '-' : '+'} $_preferredCurrency ${tx['amount']}',
                style: TextStyle(fontWeight: FontWeight.bold, color: isExpense ? Colors.red : Colors.green),
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
    String selectedAccount = _accounts.isNotEmpty ? _accounts[0]['name'] : '💵 Cash Wallet';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isExpense = type == 'expense';
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 24,
                left: 24,
                right: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(isExpense ? 'Add Expense' : 'Add Income', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  // Date Picker Row
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
                      DropdownMenuItem(value: 'expense', child: Text('Expense')),
                      DropdownMenuItem(value: 'income', child: Text('Income')),
                    ],
                    onChanged: (val) => setModalState(() => type = val ?? 'expense'),
                    decoration: const InputDecoration(labelText: 'Transaction Type'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedAccount,
                    items: _accounts.map((a) => DropdownMenuItem(value: a['name'].toString(), child: Text(a['name'].toString()))).toList(),
                    onChanged: (val) => setModalState(() => selectedAccount = val ?? selectedAccount),
                    decoration: InputDecoration(labelText: isExpense ? 'Pay From Wallet / Account' : 'Deposit To Wallet / Account'),
                  ),
                  const SizedBox(height: 12),

                  // Category Selector with "+ Add New Category" Option
                  DropdownButtonFormField<String>(
                    value: category,
                    items: [
                      ..._categories.map((c) => DropdownMenuItem(value: c['name'].toString(), child: Text('${c['icon']} ${c['name']}'))),
                      const DropdownMenuItem(value: '__ADD_NEW__', child: Text('➕ + Add New Category', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
                    ],
                    onChanged: (val) async {
                      if (val == '__ADD_NEW__') {
                        final createdName = await _showAddCategoryModal();
                        if (createdName != null && createdName.isNotEmpty) {
                          setModalState(() {
                            category = createdName;
                          });
                        }
                      } else if (val != null) {
                        setModalState(() => category = val);
                      }
                    },
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: 'Notes (e.g. Pizza Hut or Uber)'),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _themeColor),
                    onPressed: () {
                      final amt = double.tryParse(amountController.text) ?? 0.0;
                      if (amt > 0) {
                        Navigator.pop(context);
                        _addTransaction(amt, category, type, noteController.text, locationController.text, selectedAccount, selectedTxDate);
                      }
                    },
                    child: const Text('Save Transaction', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
