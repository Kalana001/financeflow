import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // 1. AUTHENTICATION SERVICES
  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;

  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUpWithEmail(String email, String password, String name) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name},
    );
  }

  Future<void> resetPasswordForEmail(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // 2. USER PROFILE & PREFERENCES
  Future<Map<String, dynamic>> getProfile() async {
    final userId = currentUser?.id;
    if (userId == null) return {};

    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    return data;
  }

  Future<void> updateProfile(Map<String, dynamic> updates) async {
    final userId = currentUser?.id;
    if (userId == null) return;

    await _client.from('profiles').update(updates).eq('id', userId);
  }

  Future<void> updateFcmToken(String token) async {
    await updateProfile({'fcm_token': token});
  }

  // 3. TRANSACTIONS CRUD (Isolate read/writes by active uid via Supabase RLS)
  Future<List<Map<String, dynamic>>> getTransactions() async {
    final userId = currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('transactions')
        .select()
        .eq('user_id', userId)
        .order('date', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> insertTransaction(Map<String, dynamic> tx) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('Unauthorized session');

    final txData = {
      ...tx,
      'user_id': userId,
    };

    final response = await _client
        .from('transactions')
        .insert(txData)
        .select()
        .single();
    return response;
  }

  Future<void> deleteTransaction(String id) async {
    await _client.from('transactions').delete().eq('id', id);
  }

  // 4. BUDGETS & GOALS MANAGEMENT
  Future<List<Map<String, dynamic>>> getBudgets() async {
    final userId = currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('budgets')
        .select()
        .eq('user_id', userId);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> saveBudget(Map<String, dynamic> budget) async {
    final userId = currentUser?.id;
    if (userId == null) return;

    await _client.from('budgets').upsert({
      ...budget,
      'user_id': userId,
    });
  }

  Future<List<Map<String, dynamic>>> getGoals() async {
    final userId = currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('goals')
        .select()
        .eq('user_id', userId);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> saveGoal(Map<String, dynamic> goal) async {
    final userId = currentUser?.id;
    if (userId == null) return;

    await _client.from('goals').upsert({
      ...goal,
      'user_id': userId,
    });
  }

  // 5. SECURITY & DATA PRIVACY (GDPR Compliance)
  Future<String> exportUserData() async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('Unauthorized session');

    final profile = await getProfile();
    final transactions = await getTransactions();
    final budgets = await getBudgets();
    final goals = await getGoals();

    final backupPayload = {
      'exported_at': DateTime.now().toIso8601String(),
      'profile': profile,
      'transactions': transactions,
      'budgets': budgets,
      'goals': goals,
    };

    return jsonEncode(backupPayload);
  }

  Future<void> deleteUserAccount() async {
    final userId = currentUser?.id;
    if (userId == null) return;

    // Supabase Cascade rules delete profiles, transactions, budgets and goals upon User record purge.
    // RPC or backend functions process the authentication record wipe.
    await _client.from('profiles').delete().eq('id', userId);
    await signOut();
  }
}
