import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mobile_flutter/app/password_recovery_route.dart';
import 'package:mobile_flutter/core/storage/session_store.dart';
import 'package:mobile_flutter/features/auth/domain/auth_session.dart';
import 'package:mobile_flutter/features/auth/domain/authentication_repository.dart';
import 'package:mobile_flutter/features/auth/presentation/login_page.dart';
import 'package:mobile_flutter/features/auth/presentation/new_password_page.dart';
import 'package:mobile_flutter/features/spaces/domain/spaces_repository.dart';
import 'package:mobile_flutter/features/spaces/presentation/spaces_page.dart';
import 'package:mobile_flutter/features/tasks/domain/tasks_repository.dart';

class TaskifyApp extends StatefulWidget {
  const TaskifyApp({
    required this.authenticationRepository,
    required this.spacesRepository,
    required this.tasksRepository,
    this.sessionStore,
    this.initialRoute,
    super.key,
  });

  final AuthenticationRepository authenticationRepository;
  final SpacesRepository spacesRepository;
  final TasksRepository tasksRepository;
  final SessionStore? sessionStore;
  final String? initialRoute;

  @override
  State<TaskifyApp> createState() => _TaskifyAppState();
}

class _TaskifyAppState extends State<TaskifyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final String _initialRoute;
  AuthSession? _session;
  bool _isLoggingOut = false;
  bool _isCompletingPasswordReset = false;
  bool _passwordResetSucceeded = false;

  @override
  void initState() {
    super.initState();
    final requestedInitialRoute =
        widget.initialRoute ??
        WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    final recoveryRoute = PasswordRecoveryRoute.tryParse(requestedInitialRoute);
    _initialRoute = recoveryRoute == null
        ? '/'
        : '/new-password/${Uri.encodeComponent(recoveryRoute.token)}';
  }

  void _handleSessionExpired() {
    _returnToLogin();
    final sessionStore = widget.sessionStore;
    if (sessionStore != null) {
      unawaited(sessionStore.clear());
    }
  }

  Future<void> _handleLogout() async {
    final session = _session;
    if (session == null || _isLoggingOut) {
      return;
    }

    _isLoggingOut = true;
    try {
      try {
        await widget.authenticationRepository.logout(
          refreshToken: session.refreshToken,
        );
      } on Object {
        // A sessão local precisa terminar mesmo sem conexão com a API.
      }

      try {
        await widget.sessionStore?.clear();
      } on Object {
        // O estado em memória ainda precisa ser descartado e a tela protegida fechada.
      }
    } finally {
      if (mounted) {
        _returnToLogin();
        _isLoggingOut = false;
      }
    }
  }

  void _returnToLogin() {
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    if (mounted) {
      setState(() {
        _session = null;
        _passwordResetSucceeded = false;
      });
    }
  }

  Future<void> _handlePasswordReset() async {
    if (_isCompletingPasswordReset) {
      return;
    }
    _isCompletingPasswordReset = true;

    if (mounted) {
      setState(() {
        _session = null;
        _passwordResetSucceeded = true;
      });
    }

    try {
      await widget.sessionStore?.clear();
    } on Object {
      // A sessão em memória e as telas protegidas ainda precisam ser removidas.
    }

    if (!mounted) {
      return;
    }
    _navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (_) => false);
    _isCompletingPasswordReset = false;
  }

  Route<dynamic>? _generateRoute(RouteSettings settings) {
    final recoveryRoute = PasswordRecoveryRoute.tryParse(settings.name);
    if (recoveryRoute == null) {
      return null;
    }

    return MaterialPageRoute<void>(
      settings: settings,
      builder: (context) => NewPasswordPage(
        authenticationRepository: widget.authenticationRepository,
        token: recoveryRoute.token,
        onPasswordReset: _handlePasswordReset,
      ),
    );
  }

  Route<dynamic> _generateSafeFallbackRoute(RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (context) => _UnknownRoutePage(
        isPasswordRecoveryLink: _looksLikePasswordRecoveryLink(settings.name),
      ),
    );
  }

  Widget _buildHome() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: _session == null
          ? LoginPage(
              key: const ValueKey('login-page'),
              authenticationRepository: widget.authenticationRepository,
              onPasswordReset: _handlePasswordReset,
              passwordResetSucceeded: _passwordResetSucceeded,
              onAuthenticated: (session) {
                setState(() {
                  _session = session;
                  _passwordResetSucceeded = false;
                });
              },
            )
          : SpacesPage(
              key: const ValueKey('spaces-page'),
              session: _session!,
              spacesRepository: widget.spacesRepository,
              tasksRepository: widget.tasksRepository,
              onSessionExpired: _handleSessionExpired,
              onLogout: _handleLogout,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      initialRoute: _initialRoute,
      onGenerateRoute: _generateRoute,
      onUnknownRoute: _generateSafeFallbackRoute,
      debugShowCheckedModeBanner: false,
      title: 'Taskify Space',
      locale: const Locale('pt', 'BR'),
      supportedLocales: const <Locale>[Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006C67),
          brightness: Brightness.light,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF6F8F7),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD8E1DF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD8E1DF)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        scaffoldBackgroundColor: const Color(0xFFF2F6F5),
        useMaterial3: true,
      ),
      home: _buildHome(),
    );
  }
}

bool _looksLikePasswordRecoveryLink(String? location) {
  return location?.toLowerCase().contains('new-password') ?? false;
}

class _UnknownRoutePage extends StatelessWidget {
  const _UnknownRoutePage({required this.isPasswordRecoveryLink});

  final bool isPasswordRecoveryLink;

  @override
  Widget build(BuildContext context) {
    final title = isPasswordRecoveryLink
        ? 'Link inválido'
        : 'Página não encontrada';
    final message = isPasswordRecoveryLink
        ? 'O link de recuperação está incompleto ou em um formato inválido.'
        : 'Não foi possível abrir o endereço solicitado.';

    return Scaffold(
      key: const ValueKey('unknown-route-page'),
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPasswordRecoveryLink
                        ? Icons.link_off_rounded
                        : Icons.search_off_rounded,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  FilledButton.tonalIcon(
                    key: const ValueKey('unknown-route-back-button'),
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Voltar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
