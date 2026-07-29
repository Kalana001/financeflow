import 'dart:ui';
import 'package:flutter/material.dart';
import 'services/local_storage_service.dart';
import 'screens/setup_screen.dart';
import 'screens/dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storageService = LocalStorageService();

  runApp(FinanceFlowApp(storageService: storageService));
}

class FinanceFlowApp extends StatefulWidget {
  final LocalStorageService storageService;

  const FinanceFlowApp({super.key, required this.storageService});

  @override
  State<FinanceFlowApp> createState() => _FinanceFlowAppState();
}

class _FinanceFlowAppState extends State<FinanceFlowApp> with WidgetsBindingObserver {
  bool _isAppBlurred = false;
  bool _isSetup = false;
  bool _isCheckingSetup = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkSetupState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkSetupState() async {
    final setupDone = await widget.storageService.isSetupComplete();
    setState(() {
      _isSetup = setupDone;
      _isCheckingSetup = false;
    });
  }

  // ----------------------------------------------------
  // WINDOW FOCUS BLUR SHIELD (Protects data on window switch)
  // ----------------------------------------------------
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      setState(() => _isAppBlurred = true);
    } else if (state == AppLifecycleState.resumed) {
      setState(() => _isAppBlurred = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingSetup) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    Widget activeScreen;
    if (!_isSetup) {
      activeScreen = SetupScreen(
        storageService: widget.storageService,
        onSetupComplete: () {
          setState(() {
            _isSetup = true;
          });
        },
      );
    } else {
      activeScreen = DashboardScreen(
        storageService: widget.storageService,
        onLockRequested: () {
          // Refresh state
          _checkSetupState();
        },
        onResetRequested: () {
          setState(() {
            _isSetup = false;
          });
        },
      );
    }

    return MaterialApp(
      title: 'FinanceFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Plus Jakarta Sans',
        primaryColor: const Color(0xFF2563EB),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
        ),
      ),
      home: Stack(
        children: [
          activeScreen,
          if (_isAppBlurred)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                child: Container(
                  color: Colors.black.withOpacity(0.85),
                  alignment: Alignment.center,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield, color: Colors.blue, size: 64),
                      SizedBox(height: 16),
                      Text(
                        'FinanceFlow Privacy Shield',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, decoration: TextDecoration.none),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Financial numbers hidden while backgrounded.',
                        style: TextStyle(color: Colors.white70, fontSize: 12, decoration: TextDecoration.none),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
