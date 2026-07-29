import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const String _keyProfile = 'ff_profile';
  static const String _keyTransactions = 'ff_transactions';
  static const String _keyGoals = 'ff_goals';
  static const String _keyBudgets = 'ff_budgets';

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
  // TRANSACTIONS CRUD
  // ----------------------------------------------------
  Future<List<Map<String, dynamic>>> getTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyTransactions);
    if (str == null) {
      // Seed default transactions for new installation
      final initialData = [
        {
          'id': 'tx-1',
          'amount': 2500.0,
          'type': 'expense',
          'category': 'Food',
          'date': DateTime.now().toIso8601String().substring(0, 10),
          'notes': 'Pizza Hut dinner',
          'payment_method': 'Cash',
          'location': 'Colombo 03'
        },
        {
          'id': 'tx-2',
          'amount': 150000.0,
          'type': 'income',
          'category': 'Salary',
          'date': DateTime.now().toIso8601String().substring(0, 10),
          'notes': 'Monthly Paycheck',
          'payment_method': 'Bank Account',
          'location': 'Office'
        },
      ];
      await prefs.setString(_keyTransactions, jsonEncode(initialData));
      return initialData;
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
  }

  Future<void> deleteTransaction(String id) async {
    final txs = await getTransactions();
    txs.removeWhere((element) => element['id'] == id);
    await saveTransactions(txs);
  }

  // ----------------------------------------------------
  // DATA EXPORT & PURGE (GDPR)
  // ----------------------------------------------------
  Future<String> exportAllDataJson() async {
    final prof = await getProfile();
    final txs = await getTransactions();
    final dump = {
      'exported_at': DateTime.now().toIso8601String(),
      'profile': prof,
      'transactions': txs,
    };
    return jsonEncode(dump);
  }

  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyProfile);
    await prefs.remove(_keyTransactions);
    await prefs.remove(_keyGoals);
    await prefs.remove(_keyBudgets);
  }
}
