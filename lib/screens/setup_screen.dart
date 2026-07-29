import 'package:flutter/material.dart';
import '../services/local_storage_service.dart';

class SetupScreen extends StatefulWidget {
  final LocalStorageService storageService;
  final VoidCallback onSetupComplete;

  const SetupScreen({
    super.key,
    required this.storageService,
    required this.onSetupComplete,
  });

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _nameController = TextEditingController();
  final _budgetController = TextEditingController(text: '100000');
  String _selectedCurrency = 'LKR';
  String? _errorMessage;

  Future<void> _completeSetup() async {
    final name = _nameController.text.trim();
    final targetBudget = double.tryParse(_budgetController.text) ?? 100000.0;

    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter your Profile Name.');
      return;
    }

    final profileData = {
      'name': name,
      'currency': _selectedCurrency,
      'monthly_budget': targetBudget,
      'theme_preference': 'classic-blue',
      'simple_mode': false,
      'created_at': DateTime.now().toIso8601String(),
    };

    await widget.storageService.saveProfile(profileData);
    widget.onSetupComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 50),
              const Icon(Icons.account_balance_wallet_rounded, size: 72, color: Color(0xFF2563EB)),
              const SizedBox(height: 20),
              const Text(
                'Welcome to FinanceFlow',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Outfit', fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your profile name to start tracking your private finances.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 40),

              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),

              // Profile Name Input
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Profile Name',
                  hintText: 'e.g. Alex',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
              ),
              const SizedBox(height: 16),

              // Monthly Target Budget Input
              TextField(
                controller: _budgetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Monthly Target Budget',
                  hintText: '100000',
                  prefixIcon: Icon(Icons.track_changes),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
              ),
              const SizedBox(height: 16),

              // Preferred Currency Dropdown
              DropdownButtonFormField<String>(
                value: _selectedCurrency,
                decoration: const InputDecoration(
                  labelText: 'Preferred Currency',
                  prefixIcon: Icon(Icons.monetization_on),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
                items: ['LKR', 'USD', 'EUR', 'GBP', 'INR']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedCurrency = val ?? 'LKR'),
              ),
              const SizedBox(height: 36),

              // Create Button
              ElevatedButton(
                onPressed: _completeSetup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Start Tracking Wealth', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
