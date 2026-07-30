import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const String _keyProfile = 'ff_profile';
  static const String _keyTransactions = 'ff_transactions';
  static const String _keyAccounts = 'ff_accounts';
  static const String _keyCategories = 'ff_categories';
  static const String _keyCategoryBudgets = 'ff_cat_budgets';
  static const String _keyRecurring = 'ff_recurring';
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
    return prof != null && prof['name'] != null && prof['name'].toString().trim().isNotEmpty;
  }

  Future<void> updateProfileField(String key, dynamic value) async {
    final prof = (await getProfile()) ?? {};
    prof[key] = value;
    await saveProfile(prof);
  }

  // ----------------------------------------------------
  // GOALS MANAGEMENT & PERSISTENCE
  // ----------------------------------------------------
  Future<List<Map<String, dynamic>>> getGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyGoals);
    if (str == null) return [];
    try {
      final List rawList = jsonDecode(str);
      return rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveGoals(List<Map<String, dynamic>> goals) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGoals, jsonEncode(goals));
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
  // CUSTOM CATEGORIES & CATEGORY BUDGETS MANAGEMENT
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

  Future<Map<String, double>> getCategoryBudgets() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyCategoryBudgets);
    if (str == null) return {};
    try {
      final Map<String, dynamic> raw = jsonDecode(str);
      return raw.map((k, v) => MapEntry(k, (double.tryParse(v.toString()) ?? 0.0)));
    } catch (_) {
      return {};
    }
  }

  Future<void> saveCategoryBudget(String category, double limit) async {
    final budgets = await getCategoryBudgets();
    budgets[category] = limit;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCategoryBudgets, jsonEncode(budgets));
  }

  Future<void> saveAllCategoryBudgets(Map<String, double> budgets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCategoryBudgets, jsonEncode(budgets));
  }

  // ----------------------------------------------------
  // RECURRING TRANSACTIONS & SUBSCRIPTIONS
  // ----------------------------------------------------
  Future<List<Map<String, dynamic>>> getRecurringTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyRecurring);
    if (str == null) return [];
    try {
      final List rawList = jsonDecode(str);
      return rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveRecurringTransactions(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRecurring, jsonEncode(items));
  }

  Future<void> addRecurringTransaction(Map<String, dynamic> item) async {
    final list = await getRecurringTransactions();
    list.add(item);
    await saveRecurringTransactions(list);
  }

  Future<void> deleteRecurringTransaction(String id) async {
    final list = await getRecurringTransactions();
    list.removeWhere((element) => element['id'] == id);
    await saveRecurringTransactions(list);
  }

  // ----------------------------------------------------
  // TRANSACTIONS CRUD (WITH INTER-WALLET TRANSFERS)
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

    final double amount = (double.tryParse(tx['amount'].toString()) ?? 0.0);
    final type = tx['type'];

    if (type == 'transfer') {
      final fromAcc = tx['from_account_id'] ?? tx['account_id'];
      final toAcc = tx['to_account_id'];
      if (fromAcc != null) await updateAccountBalance(fromAcc, -amount);
      if (toAcc != null) await updateAccountBalance(toAcc, amount);
    } else {
      final String accountId = tx['account_id'] ?? tx['account_name'] ?? 'acc-1';
      final isExpense = type == 'expense';
      final delta = isExpense ? -amount : amount;
      await updateAccountBalance(accountId, delta);
    }
  }

  Future<void> deleteTransaction(String id) async {
    final txs = await getTransactions();
    final index = txs.indexWhere((element) => element['id'] == id);
    if (index != -1) {
      final tx = txs[index];
      final double amount = (double.tryParse(tx['amount'].toString()) ?? 0.0);
      final type = tx['type'];

      if (type == 'transfer') {
        final fromAcc = tx['from_account_id'] ?? tx['account_id'];
        final toAcc = tx['to_account_id'];
        if (fromAcc != null) await updateAccountBalance(fromAcc, amount);
        if (toAcc != null) await updateAccountBalance(toAcc, -amount);
      } else {
        final String accountId = tx['account_id'] ?? tx['account_name'] ?? 'acc-1';
        final isExpense = type == 'expense';
        final reverseDelta = isExpense ? amount : -amount;
        await updateAccountBalance(accountId, reverseDelta);
      }

      txs.removeAt(index);
      await saveTransactions(txs);
    }
  }

  // ----------------------------------------------------
  // EXPORT & RESTORE & REPORT GENERATOR
  // ----------------------------------------------------
  Future<String> exportAllDataJson() async {
    final prof = await getProfile();
    final txs = await getTransactions();
    final accs = await getAccounts();
    final cats = await getCategories();
    final recs = await getRecurringTransactions();
    final budgets = await getCategoryBudgets();
    final goals = await getGoals();
    final dump = {
      'exported_at': DateTime.now().toIso8601String(),
      'profile': prof,
      'accounts': accs,
      'categories': cats,
      'category_budgets': budgets,
      'recurring_subscriptions': recs,
      'goals': goals,
      'transactions': txs,
    };
    return jsonEncode(dump);
  }

  Future<String> exportCsvData() async {
    final txs = await getTransactions();
    final buffer = StringBuffer();
    buffer.writeln('ID,Date,Type,Category,Amount,Wallet,FromWallet,ToWallet,Notes,Location');
    for (var tx in txs) {
      buffer.writeln('"${tx['id']}","${tx['date']}","${tx['type']}","${tx['category']}",${tx['amount']},"${tx['account_id']}","${tx['from_account_id']}","${tx['to_account_id']}","${tx['notes']}","${tx['location']}"');
    }
    return buffer.toString();
  }

  Future<String> generatePdfStatementReport() async {
    final prof = (await getProfile()) ?? {};
    final txs = await getTransactions();
    final accs = await getAccounts();
    final currency = prof['currency'] ?? 'LKR';

    double totalIncome = 0;
    double totalExpense = 0;
    for (var t in txs) {
      final amt = (double.tryParse(t['amount'].toString()) ?? 0.0);
      if (t['type'] == 'income') totalIncome += amt;
      if (t['type'] == 'expense') totalExpense += amt;
    }

    final double netWorth = accs.fold(0.0, (s, a) => s + (double.tryParse(a['current_balance'].toString()) ?? 0.0));

    final buffer = StringBuffer();
    buffer.writeln('====================================================');
    buffer.writeln('          FINANCEFLOW EXECUTIVE STATEMENT           ');
    buffer.writeln('====================================================');
    buffer.writeln('Generated Date : ${DateTime.now().toIso8601String().substring(0, 10)}');
    buffer.writeln('User Name      : ${prof['name'] ?? 'Alex'}');
    buffer.writeln('Currency       : $currency');
    buffer.writeln('----------------------------------------------------');
    buffer.writeln('SUMMARY OF WEALTH & CASHFLOW');
    buffer.writeln('----------------------------------------------------');
    buffer.writeln('Total Net Worth (All Wallets) : $currency ${netWorth.toStringAsFixed(2)}');
    buffer.writeln('Total Income Outflow          : $currency ${totalIncome.toStringAsFixed(2)}');
    buffer.writeln('Total Expense Outflow         : $currency ${totalExpense.toStringAsFixed(2)}');
    buffer.writeln('Net Savings Cashflow          : $currency ${(totalIncome - totalExpense).toStringAsFixed(2)}');
    buffer.writeln('----------------------------------------------------');
    buffer.writeln('ACCOUNTS & WALLETS BREAKDOWN');
    buffer.writeln('----------------------------------------------------');
    for (var acc in accs) {
      buffer.writeln('• ${acc['name']} (${acc['type']}): $currency ${acc['current_balance']}');
    }
    buffer.writeln('----------------------------------------------------');
    buffer.writeln('RECENT TRANSACTIONS LOG (${txs.length} Total)');
    buffer.writeln('----------------------------------------------------');
    for (var tx in txs.take(20)) {
      final typeTag = tx['type'].toString().toUpperCase();
      buffer.writeln('${tx['date']} | [$typeTag] | ${tx['category']} | $currency ${tx['amount']} | ${tx['notes']}');
    }
    buffer.writeln('====================================================');
    buffer.writeln('        END OF EXECUTIVE STATEMENT REPORT           ');
    buffer.writeln('====================================================');
    return buffer.toString();
  }

  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
