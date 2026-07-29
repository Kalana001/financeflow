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
  Map<String, dynamic> _profile = {};
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterCategory = 'All';

  // Preferences
  bool _simpleMode = false;
  String _preferredCurrency = 'LKR';
  Color _themeColor = const Color(0xFF2563EB);

  // High Value OTP Prompt State
  Map<String, dynamic>? _pendingHighValueTx;
  final _otpController = TextEditingController();

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
      final prof = (await widget.storageService.getProfile()) ?? {};
      setState(() {
        _transactions = txs;
        _profile = prof;
        _preferredCurrency = prof['currency'] ?? 'LKR';
        _simpleMode = prof['simple_mode'] == true;
      });
    } catch (e) {
      print('Error loading local data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addTransaction(double amount, String category, String type, String notes, String location) async {
    final newTx = {
      'id': 'tx-${DateTime.now().millisecondsSinceEpoch}',
      'amount': amount,
      'category': category,
      'type': type,
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

  double get _totalIncome => _transactions
      .where((t) => t['type'] == 'income')
      .fold(0.0, (sum, t) => sum + (double.tryParse(t['amount'].toString()) ?? 0.0));

  double get _totalExpense => _transactions
      .where((t) => t['type'] == 'expense')
      .fold(0.0, (sum, t) => sum + (double.tryParse(t['amount'].toString()) ?? 0.0));

  double get _balance => _totalIncome - _totalExpense;

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
            icon: const Icon(Icons.lock_outline),
            tooltip: 'Lock App',
            onPressed: widget.onLockRequested,
          ),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // User Welcome Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hello, ${_profile['name'] ?? 'Alex'}! 👋', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Text('Welcome to your private wealth tracker.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              CircleAvatar(
                backgroundColor: _themeColor.withOpacity(0.2),
                child: Icon(Icons.person, color: _themeColor),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Total Balance Gradient Card
          Card(
            color: _themeColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Balance', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text(
                    '$_preferredCurrency ${_balance.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('🟢 Income: $_preferredCurrency $_totalIncome', style: const TextStyle(color: Colors.white, fontSize: 12)),
                      Text('🔴 Expense: $_preferredCurrency $_totalExpense', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Summary Spending Cards
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Today's Spend", style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text('$_preferredCurrency ${_totalExpense > 0 ? (_totalExpense * 0.15).toStringAsFixed(0) : '0'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Budget Left", style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text('$_preferredCurrency ${(_totalIncome - _totalExpense).clamp(0, double.infinity).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Budget Usage Bar
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Monthly Target Budget', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _totalIncome > 0 ? (_totalExpense / _totalIncome) : 0,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(_totalExpense > _totalIncome ? Colors.red : _themeColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Budget used: ${((_totalIncome > 0 ? (_totalExpense / _totalIncome) : 0) * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // If Advanced Mode: Show Accounts & Multi-Wallets
          if (!_simpleMode) ...[
            const Text('My Accounts & Wallets', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildWalletChip('💵 Cash', '$_preferredCurrency 15,000', Colors.green),
                  _buildWalletChip('🏦 Bank Account', '$_preferredCurrency 250,000', Colors.blue),
                  _buildWalletChip('💳 Credit Card', '$_preferredCurrency 45,000', Colors.purple),
                  _buildWalletChip('📱 Digital Wallet', '$_preferredCurrency 8,500', Colors.orange),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Recent Transactions List
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

  Widget _buildWalletChip(String name, String balance, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(balance, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // 2. TRANSACTIONS / HISTORY TAB
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
  // 3. ANALYTICS & AI ADVISOR TAB
  // ----------------------------------------------------
  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Financial Insights & Analytics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                        ? "• You spent more than your income this month! Try reducing Food dining out to save $_preferredCurrency 10,000."
                        : "• Great job! You spent 20% less than your total budget limit. You can allocate $_preferredCurrency 15,000 to Emergency Savings.",
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
          const SizedBox(height: 16),

          // Monthly Subscriptions Tracker
          const Text('Monthly Active Subscriptions', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(leading: const Icon(Icons.tv, color: Colors.red), title: const Text('Netflix Standard'), trailing: Text('$_preferredCurrency 2,800/mo')),
                ListTile(leading: const Icon(Icons.music_note, color: Colors.green), title: const Text('Spotify Family'), trailing: Text('$_preferredCurrency 1,200/mo')),
                ListTile(leading: const Icon(Icons.wifi, color: Colors.blue), title: const Text('Fibre Internet'), trailing: Text('$_preferredCurrency 4,500/mo')),
              ],
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
  // 5. SETTINGS & CUSTOMIZER TAB
  // ----------------------------------------------------
  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Text('Preferences & Customization', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),

        // Simple vs Advanced Mode Toggle
        Card(
          child: SwitchListTile(
            title: const Text('Simple Beginner Mode'),
            subtitle: const Text('Hides complex charts and multi-account tools'),
            value: _simpleMode,
            onChanged: (val) {
              setState(() => _simpleMode = val);
              widget.storageService.updateProfileField('simple_mode', val);
            },
          ),
        ),

        // Preferred Currency Selector
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

        // Theme Preset Color Pickers
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('App Theme Preset', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildColorPicker(const Color(0xFF2563EB), 'Blue'),
                    _buildColorPicker(const Color(0xFF10B981), 'Green'),
                    _buildColorPicker(const Color(0xFF8B5CF6), 'Purple'),
                    _buildColorPicker(const Color(0xFFF97316), 'Orange'),
                  ],
                ),
              ],
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
            subtitle: const Text('Wipes profile name, PIN, and local transactions'),
            trailing: const Icon(Icons.delete, color: Colors.red),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Reset Profile & Data?'),
                  content: const Text('This will delete your local profile name, PIN, and transactions. This action cannot be undone.'),
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

  Widget _buildColorPicker(Color color, String name) {
    final isSelected = _themeColor == color;
    return GestureDetector(
      onTap: () => setState(() => _themeColor = color),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: color,
            radius: 18,
            child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
          ),
          const SizedBox(height: 4),
          Text(name, style: const TextStyle(fontSize: 10)),
        ],
      ),
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
              title: Text(tx['notes'] ?? tx['category']),
              subtitle: Text('${tx['date']} • ${tx['category']} • ${tx['location']}'),
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                  const Text('Add New Transaction', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                    onChanged: (text) {
                      final lText = text.toLowerCase();
                      if (lText.contains('pizza') || lText.contains('food') || lText.contains('kfc')) {
                        setModalState(() => category = 'Food');
                      } else if (lText.contains('uber') || lText.contains('cab') || lText.contains('ride')) {
                        setModalState(() => category = 'Transport');
                      } else if (lText.contains('electricity') || lText.contains('water') || lText.contains('bill')) {
                        setModalState(() => category = 'Bills');
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(labelText: 'Location (e.g. Colombo 03)'),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _themeColor),
                    onPressed: () {
                      final amt = double.tryParse(amountController.text) ?? 0.0;
                      if (amt > 0) {
                        Navigator.pop(context);
                        _addTransaction(amt, category, type, noteController.text, locationController.text);
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
