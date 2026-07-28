import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase endpoints with project credentials
  await Supabase.initialize(
    url: 'https://dwcdrqavdazsfjbfcgag.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR3Y2RycWF2ZGF6c2ZqYmZjZ2FnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUyMjgyMTYsImV4cCI6MjEwMDgwNDIxNn0.IPBq36gIfZFKJFklRDw-olZSXfoFtJpYxeC6QWXxQyE',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FinanceFlow',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MainSecurityController(),
    );
  }
}

class MainSecurityController extends StatefulWidget {
  const MainSecurityController({super.key});

  @override
  State<MainSecurityController> createState() => _MainSecurityControllerState();
}

class _MainSecurityControllerState extends State<MainSecurityController> with WidgetsBindingObserver {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isAuthenticated = false;
  bool _pinUnlocked = false;

  // Inactivity tracking variables
  Timer? _inactivityTimer;
  final Duration _inactivityTimeout = const Duration(seconds: 60);

  // App focus blur overlay state
  bool _isAppBlurred = false;

  final _pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Check initial authentication state
    if (_supabaseService.currentUser != null) {
      setState(() {
        _isAuthenticated = true;
      });
      _startInactivityTimer();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    super.dispose();
  }

  // Window Focus change listener (blur shield simulation)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _isAppBlurred = (state == AppLifecycleState.inactive || state == AppLifecycleState.paused);
    });

    if (state == AppLifecycleState.resumed) {
      _resetInactivityTimer();
    }
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_inactivityTimeout, () {
      if (_isAuthenticated && _pinUnlocked) {
        setState(() {
          _pinUnlocked = false;
          _pinController.clear();
        });
        showDialog(
          context: context,
          builder: (context) => const AlertDialog(
            title: Text('Session Locked'),
            content: Text('Session locked due to 60 seconds of inactivity.'),
          ),
        );
      }
    });
  }

  void _resetInactivityTimer() {
    if (_isAuthenticated && _pinUnlocked) {
      _startInactivityTimer();
    }
  }

  void _handleUserInteraction() {
    _resetInactivityTimer();
  }

  @override
  Widget build(BuildContext context) {
    // 1. If App focus blur shield is triggered (Minimized or backgrounded)
    if (_isAppBlurred) {
      return const Scaffold(
        backgroundColor: Color(0xFF090D16),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_outlined, size: 64, color: Colors.blue),
              SizedBox(height: 16),
              Text(
                'Secure Session Active',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Financial information is hidden.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Auth checking routes
    if (!_isAuthenticated) {
      return AuthScreen(
        supabaseService: _supabaseService,
        onAuthenticated: () {
          setState(() {
            _isAuthenticated = true;
          });
          _startInactivityTimer();
        },
      );
    }

    // 3. PIN Lock verification
    if (!_pinUnlocked) {
      return _buildPinLockScreen();
    }

    // 4. Authorized Main Area
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _handleUserInteraction,
      onPanDown: (_) => _handleUserInteraction(),
      child: DashboardScreen(supabaseService: _supabaseService),
    );
  }

  Widget _buildPinLockScreen() {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.blue),
              const SizedBox(height: 16),
              const Text(
                'Enter Security PIN',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Verify your security PIN to access budgets (Try 1234)',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 16),
                decoration: const InputDecoration(
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
                onChanged: (pin) {
                  if (pin == '1234') {
                    setState(() {
                      _pinUnlocked = true;
                    });
                    _startInactivityTimer();
                  } else if (pin.length == 4) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invalid code! Try 1234.')),
                    );
                    _pinController.clear();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
