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
  final _pinController = TextEditingController();
  bool _enableBiometrics = false;
  String _selectedCurrency = 'LKR';
  String? _errorMessage;

  Future<void> _completeSetup() async {
    final name = _nameController.text.trim();
    final pin = _pinController.text.trim();

    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter your Profile Name.');
      return;
    }

    if (pin.length != 4 || int.tryParse(pin) == null) {
      setState(() => _errorMessage = 'Please enter a 4-digit numeric PIN.');
      return;
    }

    final profileData = {
      'name': name,
      'pin': pin,
      'currency': _selectedCurrency,
      'theme_preference': 'classic-blue',
      'simple_mode': false,
      'biometrics_enabled': _enableBiometrics,
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
              const SizedBox(height: 40),
              const Icon(Icons.account_balance_wallet, size: 64, color: Color(0xFF2563EB)),
              const SizedBox(height: 16),
              const Text(
                'Welcome to FinanceFlow',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Outfit', fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Set up your profile & PIN to secure your wealth tracker. No online passwords required.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 36),

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

              // Security PIN Input
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Set 4-Digit Security PIN',
                  hintText: 'e.g. 1234',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
              ),
              const SizedBox(height: 12),

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
              const SizedBox(height: 16),

              // Fingerprint Biometrics Switch
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: SwitchListTile(
                  title: const Text('Enable Fingerprint Lock'),
                  subtitle: const Text('Use biometrics to unlock quickly'),
                  value: _enableBiometrics,
                  activeColor: const Color(0xFF2563EB),
                  onChanged: (val) => setState(() => _enableBiometrics = val),
                ),
              ),
              const SizedBox(height: 32),

              // Create Button
              ElevatedButton(
                onPressed: _completeSetup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Create Profile & Get Started', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
