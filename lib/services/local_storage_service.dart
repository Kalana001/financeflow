import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const String _keyProfile = 'ff_profile';
  static const String _keyTransactions = 'ff_transactions';
  static const String _keyAccounts = 'ff_accounts';
  static const String _keyCategories = 'ff_categories';

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
    return prof != null && prof['name'] != null && prof['name'].toString().trim().isNotEmpty;
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
      final defaultAccounts = [
        {'id': 'acc-1', 'name': '💵 Cash Wallet', 'icon': '💵', 'type': 'Cash', 'current_balance': 0.0, 'opening_balance': 0.0},
        {'id': 'acc-2', 'name': '🏦 Bank Account', 'icon': '🏦', 'type': 'Bank', 'current_balance': 0.0, 'opening_balance': 0.0},
        {'id': 'acc-3', 'name': '💳 Credit Card', 'icon': '💳', 'type': 'Credit', 'current_balance': 0.0, 'opening_balance': 0.0},
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

  Future<void> updateAccount(String id, String newName, double newOpeningBalance, String icon) async {
    final accounts = await getAccounts();
    for (var acc in accounts) {
      if (acc['id'] == id) {
        final double oldOpening = (double.tryParse(acc['opening_balance'].toString()) ?? 0.0);
        final double oldCurrent = (double.tryParse(acc['current_balance'].toString()) ?? 0.0);
        
        acc['name'] = newName;
        acc['icon'] = icon;
        acc['opening_balance'] = newOpeningBalance;
        acc['current_balance'] = oldCurrent + (newOpeningBalance - oldOpening);
        break;
      }
    }
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
  // CUSTOM CATEGORIES MANAGEMENT
  // ----------------------------------------------------
  Future<List<Map<String, dynamic>>> getCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyCategories);
    if (str == null) {
      final defaultCategories = [
        {'name': 'Food & Dining', 'icon': '🍔'},
        {'name': 'Transport & Fuel', 'icon': '🚗'},
        {'name': 'Bills & Utilities', 'icon': '⚡'},
        {'name': 'Shopping & Store', 'icon': '🛒'},
        {'name': 'Salary & Income', 'icon': '💰'},
        {'name': 'Medical & Health', 'icon': '🏥'},
        {'name': 'Entertainment', 'icon': '🍿'},
      ];
      await prefs.setString(_keyCategories, jsonEncode(defaultCategories));
      return defaultCategories;
    }
    try {
      final List raw = jsonDecode(str);
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addCategory(Map<String, dynamic> cat) async {
    final cats = await getCategories();
    cats.add(cat);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCategories, jsonEncode(cats));
  }

  // ----------------------------------------------------
  // TRANSACTIONS CRUD
  // ----------------------------------------------------
  Future<List<Map<String, dynamic>>> getTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyTransactions);
    if (str == null) return [];
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

    final String accountId = tx['account_id'] ?? tx['account_name'] ?? 'acc-1';
    final double amount = (double.tryParse(tx['amount'].toString()) ?? 0.0);
    final isExpense = tx['type'] == 'expense';

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

      final reverseDelta = isExpense ? amount : -amount;
      await updateAccountBalance(accountId, reverseDelta);

      txs.removeAt(index);
      await saveTransactions(txs);
    }
  }

  // ----------------------------------------------------
  // EXPORT & RESTORE
  // ----------------------------------------------------
  Future<String> exportAllDataJson() async {
    final prof = await getProfile();
    final txs = await getTransactions();
    final accs = await getAccounts();
    final cats = await getCategories();
    final dump = {
      'exported_at': DateTime.now().toIso8601String(),
      'profile': prof,
      'accounts': accs,
      'categories': cats,
      'transactions': txs,
    };
    return jsonEncode(dump);
  }

  Future<String> exportCsvData() async {
    final txs = await getTransactions();
    final buffer = StringBuffer();
    buffer.writeln('ID,Date,Type,Category,Amount,Wallet,Notes,Location');
    for (var tx in txs) {
      buffer.writeln('"${tx['id']}","${tx['date']}","${tx['type']}","${tx['category']}",${tx['amount']},"${tx['account_id']}","${tx['notes']}","${tx['location']}"');
    }
    return buffer.toString();
  }

  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
