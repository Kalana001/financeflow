import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class DashboardScreen extends StatefulWidget {
  final SupabaseService supabaseService;

  const DashboardScreen({super.key, required this.supabaseService});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentTab = 0;
  List<Map<String, dynamic>> _transactions = [];
  Map<String, dynamic> _profile = {};
  bool _isLoading = true;

  // Local state to simulate high value OTP prompt
  Map<String, dynamic>? _pendingHighValueTx;
  final _otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final txs = await widget.supabaseService.getTransactions();
      final prof = await widget.supabaseService.getProfile();
      setState(() {
        _transactions = txs;
        _profile = prof;
      });
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addTransaction(double amount, String category, String type, String notes) async {
    final newTx = {
      'amount': amount,
      'category': category,
      'type': type,
      'payment_method': 'Cash',
      'date': DateTime.now().toIso8601String().substring(0, 10),
      'notes': notes,
      'tags': ['manual'],
      'location': 'Colombo',
    };

    // Transaction OTP verification for high-value operations (> LKR 50,000)
    if (type == 'expense' && amount > 50000) {
      setState(() {
        _pendingHighValueTx = newTx;
      });
      _showOtpVerificationDialog();
      return;
    }

    await widget.supabaseService.insertTransaction(newTx);
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
                'This transaction of ${_profile['currency'] ?? 'LKR'} ${_pendingHighValueTx!['amount']} exceeds the high-value security limit. Enter OTP to authorize (Try 123456).',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Verification OTP Code'),
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
                  await widget.supabaseService.insertTransaction(_pendingHighValueTx!);
                  setState(() => _pendingHighValueTx = null);
                  _otpController.clear();
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Transaction successfully verified and authorized.')),
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

    final currency = _profile['currency'] ?? 'LKR';
    final simpleMode = _profile['simple_mode'] == true;

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
      body: _currentTab == 0 ? _buildHomeTab(currency, simpleMode) : _buildSettingsTab(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (idx) => setState(() => _currentTab = idx),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTransactionBottomSheet(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHomeTab(String currency, bool simpleMode) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Balance Header Card
          Card(
            color: Theme.of(context).primaryColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Balance', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text(
                    '$currency ${_balance.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.between,
                    children: [
                      Text('🟢 Income: $currency $_totalIncome', style: const TextStyle(color: Colors.white, fontSize: 12)),
                      Text('🔴 Expense: $currency $_totalExpense', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 2. Spend Limit Progress Indicator
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
                    valueColor: AlwaysStoppedAnimation<Color>(_totalExpense > _totalIncome ? Colors.red : Colors.green),
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
          const SizedBox(height: 20),

          // 3. Transactions List
          const Text('Recent Transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _transactions.length,
            itemBuilder: (context, index) {
              final tx = _transactions[index];
              final isExpense = tx['type'] == 'expense';
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isExpense ? Colors.red[50] : Colors.green[50],
                  child: Icon(isExpense ? Icons.arrow_downward : Icons.arrow_upward, color: isExpense ? Colors.red : Colors.green),
                ),
                title: Text(tx['notes'] ?? tx['category']),
                subtitle: Text('${tx['date']} • ${tx['payment_method']}'),
                trailing: Text(
                  '${isExpense ? '-' : '+'} $currency ${tx['amount']}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: isExpense ? Colors.red : Colors.green),
                ),
              );
            },
          )
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Card(
          child: ListTile(
            title: const Text('Download My Financial Data (GDPR)'),
            subtitle: const Text('Export a copy of your records in JSON format'),
            trailing: const Icon(Icons.download),
            onTap: () async {
              final jsonStr = await widget.supabaseService.exportUserData();
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Data Decrypted & Exported'),
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
            title: const Text('Delete Account Permanently'),
            subtitle: const Text('Wipes your transactions and logs completely'),
            trailing: const Icon(Icons.delete, color: Colors.red),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Confirm Deletion?'),
                  content: const Text('This will delete all your data and profiles. This cannot be undone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                  ],
                ),
              );

              if (confirm == true) {
                await widget.supabaseService.deleteUserAccount();
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
          ),
        ),
      ],
    );
  }

  void _showAddTransactionBottomSheet() {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String category = 'Food';
    String type = 'expense';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
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
                onChanged: (val) => type = val ?? 'expense',
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
                ],
                onChanged: (val) => category = val ?? 'Food',
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  final amt = double.tryParse(amountController.text) ?? 0.0;
                  if (amt > 0) {
                    Navigator.pop(context);
                    _addTransaction(amt, category, type, noteController.text);
                  }
                },
                child: const Text('Add Transaction'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
