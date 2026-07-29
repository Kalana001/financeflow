import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const String _keyProfile = 'ff_profile';
  static const String _keyTransactions = 'ff_transactions';
  static const String _keyAccounts = 'ff_accounts';
  static const String _keyCategories = 'ff_categories';
  static const String _keyGoals = 'ff_goals';

  // ----------------------------------------------------
  // PROFILE & SETUP MANAGEMENT
  // ----------------------------------------------------
  Future<Map<String, dynamic>?> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyProfile);
    if (str == null) return null;
    try {
      return jsonDecode(str) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProfile(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProfile, jsonEncode(profile));
  }

  Future<bool> isSetupComplete() async {
    final prof = await getProfile();
    return prof != null && prof['name'] != null && prof['pin'] != null;
  }

  Future<void> updateProfileField(String key, dynamic value) async {
    final prof = (await getProfile()) ?? {};
    prof[key] = value;
    await saveProfile(prof);
  }

  // ----------------------------------------------------
  // ACCOUNTS & WALLETS MANAGEMENT
  // ----------------------------------------------------
  Future<List<Map<String, dynamic>>> getAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyAccounts);
    if (str == null) {
      // Default initial accounts with 0 balance for clean start
      final defaultAccounts = [
        {'id': 'acc-1', 'name': '💵 Cash Wallet', 'type': 'Cash', 'current_balance': 0.0, 'color': 'green'},
        {'id': 'acc-2', 'name': '🏦 Bank Account', 'type': 'Bank', 'current_balance': 0.0, 'color': 'blue'},
        {'id': 'acc-3', 'name': '💳 Credit Card', 'type': 'Credit', 'current_balance': 0.0, 'color': 'purple'},
      ];
      await prefs.setString(_keyAccounts, jsonEncode(defaultAccounts));
      return defaultAccounts;
    }
    try {
      final List raw = jsonDecode(str);
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAccounts(List<Map<String, dynamic>> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccounts, jsonEncode(accounts));
  }

  Future<void> addAccount(Map<String, dynamic> acc) async {
    final accounts = await getAccounts();
    accounts.add(acc);
    await saveAccounts(accounts);
  }

  Future<void> updateAccountBalance(String accountId, double deltaAmount) async {
    final accounts = await getAccounts();
    for (var acc in accounts) {
      if (acc['id'] == accountId || acc['name'] == accountId) {
        final current = (double.tryParse(acc['current_balance'].toString()) ?? 0.0);
        acc['current_balance'] = current + deltaAmount;
        break;
      }
    }
    await saveAccounts(accounts);
  }

  // ----------------------------------------------------
  // TRANSACTIONS CRUD (Linked to Accounts with Refund Logic)
  // ----------------------------------------------------
  Future<List<Map<String, dynamic>>> getTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyTransactions);
    if (str == null) {
      // Clean slate: 0 transactions for new installations
      return [];
    }
    try {
      final List rawList = jsonDecode(str);
      return rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveTransactions(List<Map<String, dynamic>> txs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTransactions, jsonEncode(txs));
  }

  Future<void> addTransaction(Map<String, dynamic> tx) async {
    final txs = await getTransactions();
    txs.insert(0, tx);
    await saveTransactions(txs);

    // Automatically update linked wallet balance
    final String accountId = tx['account_id'] ?? tx['account_name'] ?? 'acc-1';
    final double amount = (double.tryParse(tx['amount'].toString()) ?? 0.0);
    final isExpense = tx['type'] == 'expense';

    // Expense reduces wallet balance; Income increases wallet balance
    final delta = isExpense ? -amount : amount;
    await updateAccountBalance(accountId, delta);
  }

  Future<void> deleteTransaction(String id) async {
    final txs = await getTransactions();
    final index = txs.indexWhere((element) => element['id'] == id);
    if (index != -1) {
      final tx = txs[index];
      final String accountId = tx['account_id'] ?? tx['account_name'] ?? 'acc-1';
      final double amount = (double.tryParse(tx['amount'].toString()) ?? 0.0);
      final isExpense = tx['type'] == 'expense';

      // Automatic Refund / Reversal on Account Balance
      // Deleting an expense refunds the money back (+); deleting income reverses the deposit (-)
      final reverseDelta = isExpense ? amount : -amount;
      await updateAccountBalance(accountId, reverseDelta);

      txs.removeAt(index);
      await saveTransactions(txs);
    }
  }

  // ----------------------------------------------------
  // DATA EXPORT & PURGE
  // ----------------------------------------------------
  Future<String> exportAllDataJson() async {
    final prof = await getProfile();
    final txs = await getTransactions();
    final accs = await getAccounts();
    final dump = {
      'exported_at': DateTime.now().toIso8601String(),
      'profile': prof,
      'accounts': accs,
      'transactions': txs,
    };
    return jsonEncode(dump);
  }

  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyProfile);
    await prefs.remove(_keyTransactions);
    await prefs.remove(_keyAccounts);
    await prefs.remove(_keyCategories);
    await prefs.remove(_keyGoals);
  }
}
