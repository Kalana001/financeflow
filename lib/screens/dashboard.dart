import 'dart:convert';
import 'package:flutter/material.dart';
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
  Map<String, dynamic> _profile = {};
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterCategory = 'All';

  // Preferences
  bool _simpleMode = false;
  String _preferredCurrency = 'LKR';
  double _targetMonthlyBudget = 100000.0;
  Color _themeColor = const Color(0xFF2563EB);

  // High Value OTP Prompt State
  Map<String, dynamic>? _pendingHighValueTx;
  final _otpController = TextEditingController();

  // Icon Choices for Custom Wallets
  final List<String> _walletIcons = ['💵', '🏦', '💳', '📱', '🐖', '💎', '🛒', '⚡'];

  // Goals List
  final List<Map<String, dynamic>> _goals = [
    {'title': 'New Phone', 'target': 150000.0, 'current': 90000.0, 'icon': Icons.phone_iphone, 'color': Colors.blue},
    {'title': 'Emergency Fund', 'target': 300000.0, 'current': 210000.0, 'icon': Icons.shield, 'color': Colors.green},
    {'title': 'Vacation Trip', 'target': 100000.0, 'current': 45000.0, 'icon': Icons.flight_takeoff, 'color': Colors.orange},
  ];

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
      final prof = (await widget.storageService.getProfile()) ?? {};
      setState(() {
        _transactions = txs;
        _accounts = accs;
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

  // Dynamic Net Worth calculation: Sum of all wallet balances
  double get _totalNetWorth => _accounts.fold(
      0.0, (sum, acc) => sum + (double.tryParse(acc['current_balance'].toString()) ?? 0.0));

  double get _totalIncome => _transactions
      .where((t) => t['type'] == 'income')
      .fold(0.0, (sum, t) => sum + (double.tryParse(t['amount'].toString()) ?? 0.0));

  double get _totalExpense => _transactions
      .where((t) => t['type'] == 'expense')
      .fold(0.0, (sum, t) => sum + (double.tryParse(t['amount'].toString()) ?? 0.0));

  Future<void> _addTransaction(double amount, String category, String type, String notes, String location, String accountId) async {
    final newTx = {
      'id': 'tx-${DateTime.now().millisecondsSinceEpoch}',
      'amount': amount,
      'category': category,
      'type': type,
      'account_id': accountId,
      'payment_method': 'Cash',
      'date': DateTime.now().toIso8601String().substring(0, 10),
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
  // 1. HOME TAB (Redesigned Net Worth & Edit Budget)
  // ----------------------------------------------------
  Widget _buildHomeTab() {
    final budgetPct = _targetMonthlyBudget > 0 ? (_totalExpense / _targetMonthlyBudget).clamp(0.0, 1.0) : 0.0;
    final remainingBudget = (_targetMonthlyBudget - _totalExpense).clamp(0.0, double.infinity);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // User Greeting Header
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

          // Redesigned Modern Total Net Worth Card
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

          // Monthly Target Budget Progress Card with Edit Button
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

          // Recent Transactions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              TextButton(onPressed: () => setState(() => _currentTab = 1), child: const Text('See All')),
            ],
          ),
          _buildTransactionList(_transactions.take(4).toList()),
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
            keyboardType: TextInputType.number,
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

  // Account Detail Modal (Transactions by Wallet + Edit Name/Opening Balance)
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
                  TextField(controller: openingController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Opening Balance')),
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
                  TextField(controller: balanceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Opening Balance')),
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
    final filtered = _transactions.where((tx) {
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
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search expenses, categories, or notes...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'Food', 'Transport', 'Salary', 'Bills'].map((cat) {
                    final selected = _filterCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: selected,
                        onSelected: (_) => setState(() => _filterCategory = cat),
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
  // 3. ENHANCED ANALYTICS & AI ADVISOR TAB
  // ----------------------------------------------------
  Widget _buildAnalyticsTab() {
    final dailyAvg = _totalExpense > 0 ? (_totalExpense / 30.0) : 0.0;
    final healthScore = _totalIncome > 0 ? (((_totalIncome - _totalExpense) / _totalIncome) * 100).clamp(0, 100).toStringAsFixed(0) : '85';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Financial Insights & Analytics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // Health Score & Daily Burn Rate Badges
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
                        Text('$healthScore / 100 (Excellent)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Daily Burn Rate', style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('$_preferredCurrency ${dailyAvg.toStringAsFixed(0)} / day', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // AI Advisor Card
          Card(
            color: Colors.amber[50],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.amber[300]!)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.psychology, color: Colors.amber),
                      SizedBox(width: 8),
                      Text('🤖 AI Financial Assistant Advice', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _totalExpense > _totalIncome
                        ? "• Your monthly spend exceeds income! Try reducing Food dining out to save $_preferredCurrency 10,000."
                        : "• Excellent savings ratio! You spent 20% less than your monthly target budget. Allocate $_preferredCurrency 15,000 to Emergency Savings.",
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Spending Category Breakdown
          const Text('Expense Categories Breakdown', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildCategoryProgressRow('🍔 Food', 0.45, Colors.orange),
                  const SizedBox(height: 12),
                  _buildCategoryProgressRow('🚗 Transport', 0.25, Colors.blue),
                  const SizedBox(height: 12),
                  _buildCategoryProgressRow('⚡ Bills', 0.20, Colors.red),
                  const SizedBox(height: 12),
                  _buildCategoryProgressRow('🛒 Shopping', 0.10, Colors.purple),
                ],
              ),
            ),
          ),
        ],
      ),
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
                onPressed: () {},
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Goal'),
              )
            ],
          ),
          const SizedBox(height: 12),
          ..._goals.map((g) {
            final pct = (g['current'] / g['target']).clamp(0.0, 1.0);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
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
                              Text('Target: $_preferredCurrency ${g['target']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Text('${(pct * 100).toStringAsFixed(0)}%', style: TextStyle(fontWeight: FontWeight.bold, color: g['color'])),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(value: pct, backgroundColor: Colors.grey[200], valueColor: AlwaysStoppedAnimation<Color>(g['color'])),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
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
    String category = 'Food';
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
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
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
                  // Wallet Destination / Source Selector
                  DropdownButtonFormField<String>(
                    value: selectedAccount,
                    items: _accounts.map((a) => DropdownMenuItem(value: a['name'].toString(), child: Text(a['name'].toString()))).toList(),
                    onChanged: (val) => setModalState(() => selectedAccount = val ?? selectedAccount),
                    decoration: InputDecoration(labelText: isExpense ? 'Pay From Wallet / Account' : 'Deposit To Wallet / Account'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: category,
                    items: const [
                      DropdownMenuItem(value: 'Food', child: Text('Food')),
                      DropdownMenuItem(value: 'Transport', child: Text('Transport')),
                      DropdownMenuItem(value: 'Salary', child: Text('Salary')),
                      DropdownMenuItem(value: 'Bills', child: Text('Bills')),
                      DropdownMenuItem(value: 'Shopping', child: Text('Shopping')),
                    ],
                    onChanged: (val) => setModalState(() => category = val ?? 'Food'),
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
                        _addTransaction(amt, category, type, noteController.text, locationController.text, selectedAccount);
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
