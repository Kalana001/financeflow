import 'package:flutter/material.dart';
import '../services/local_storage_service.dart';

class PinLockScreen extends StatefulWidget {
  final LocalStorageService storageService;
  final VoidCallback onUnlocked;

  const PinLockScreen({
    super.key,
    required this.storageService,
    required this.onUnlocked,
  });

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _enteredPin = '';
  String _profileName = 'Member';
  String _correctPin = '1234';
  bool _biometricsEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadProfileInfo();
  }

  Future<void> _loadProfileInfo() async {
    final prof = await widget.storageService.getProfile();
    if (prof != null) {
      setState(() {
        _profileName = prof['name'] ?? 'Member';
        _correctPin = prof['pin'] ?? '1234';
        _biometricsEnabled = prof['biometrics_enabled'] == true;
      });
    }
  }

  void _pressKey(String digit) {
    if (_enteredPin.length >= 4) return;
    setState(() {
      _enteredPin += digit;
    });

    if (_enteredPin.length == 4) {
      if (_enteredPin == _correctPin) {
        Future.delayed(const Duration(milliseconds: 150), () {
          widget.onUnlocked();
        });
      } else {
        Future.delayed(const Duration(milliseconds: 200), () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid PIN! Please try again.')),
          );
          setState(() {
            _enteredPin = '';
          });
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 54, color: Color(0xFF2563EB)),
            const SizedBox(height: 16),
            Text(
              'Welcome Back, $_profileName!',
              style: const TextStyle(fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Enter your 4-digit PIN to unlock',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 32),

            // PIN Indicator Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isFilled = _enteredPin.length > index;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled ? const Color(0xFF2563EB) : Colors.grey[300],
                    border: Border.all(color: const Color(0xFF2563EB)),
                  ),
                );
              }),
            ),
            const SizedBox(height: 40),

            // Keypad Grid
            Container(
              maxWidth: 260,
              alignment: Alignment.center,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['1', '2', '3'].map((d) => _buildKeyBtn(d)).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['4', '5', '6'].map((d) => _buildKeyBtn(d)).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['7', '8', '9'].map((d) => _buildKeyBtn(d)).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.backspace_outlined),
                        onPressed: () {
                          if (_enteredPin.isNotEmpty) {
                            setState(() {
                              _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
                            });
                          }
                        },
                      ),
                      _buildKeyBtn('0'),
                      IconButton(
                        icon: Icon(
                          _biometricsEnabled ? Icons.fingerprint : Icons.check_circle_outline,
                          color: const Color(0xFF2563EB),
                        ),
                        onPressed: () {
                          // Quick unlock action
                          widget.onUnlocked();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyBtn(String digit) {
    return InkWell(
      onTap: () => _pressKey(digit),
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 60,
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Text(
          digit,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
