import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'models/auth_session.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/greenhouse_api_service.dart';

void main() {
  runApp(const GreenHouseApp());
}

class GreenHouseApp extends StatelessWidget {
  const GreenHouseApp({
    super.key,
    this.authService,
    this.httpClient,
    this.initialSession,
    this.startInDemoMode = false,
  });

  final AuthService? authService;
  final http.Client? httpClient;
  final AuthSession? initialSession;
  final bool startInDemoMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GreenHouse',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        scaffoldBackgroundColor: const Color(0xFFF5F7F2),
      ),
      home: _AppSessionGate(
        authService: authService ?? AuthService(client: httpClient),
        httpClient: httpClient,
        initialSession: initialSession,
        startInDemoMode: startInDemoMode,
      ),
    );
  }
}

class _AppSessionGate extends StatefulWidget {
  const _AppSessionGate({
    required this.authService,
    this.httpClient,
    this.initialSession,
    this.startInDemoMode = false,
  });

  final AuthService authService;
  final http.Client? httpClient;
  final AuthSession? initialSession;
  final bool startInDemoMode;

  @override
  State<_AppSessionGate> createState() => _AppSessionGateState();
}

class _AppSessionGateState extends State<_AppSessionGate> {
  AuthSession? _session;
  bool _demoMode = false;
  bool _isCheckingSession = true;
  String? _loginMessage;

  @override
  void initState() {
    super.initState();
    _session = widget.initialSession;
    _demoMode = widget.startInDemoMode;
    if (_session != null || _demoMode) {
      _isCheckingSession = false;
    } else {
      _restoreSession();
    }
  }

  Future<void> _restoreSession() async {
    final saved = await widget.authService.loadSession();
    if (!mounted) return;
    setState(() {
      _session = saved;
      _isCheckingSession = false;
    });
  }

  void _onAuthenticated(AuthSession session) {
    setState(() {
      _session = session;
      _demoMode = false;
      _loginMessage = null;
    });
  }

  void _onEnterDemoMode() {
    setState(() {
      _session = null;
      _demoMode = true;
      _loginMessage = null;
    });
  }

  Future<void> _onLogout(String? message) async {
    await widget.authService.logout();
    if (!mounted) return;
    setState(() {
      _session = null;
      _demoMode = false;
      _loginMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingSession) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
        ),
      );
    }

    if (_session != null) {
      return DashboardScreen(
        key: ValueKey(_session!.userId),
        session: _session,
        apiService: GreenhouseApiService(
          session: _session!,
          client: widget.httpClient,
        ),
        onLogout: _onLogout,
      );
    }

    if (_demoMode) {
      return DashboardScreen(
        key: const ValueKey('demo-mode'),
        onLogout: _onLogout,
      );
    }

    return LoginScreen(
      authService: widget.authService,
      onAuthenticated: _onAuthenticated,
      onDemoMode: _onEnterDemoMode,
      initialMessage: _loginMessage,
    );
  }
}
