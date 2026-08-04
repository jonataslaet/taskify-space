import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_flutter/core/storage/session_store.dart';
import 'package:mobile_flutter/features/auth/domain/auth_session.dart';
import 'package:mobile_flutter/features/auth/domain/authentication_repository.dart';
import 'package:mobile_flutter/features/auth/presentation/login_page.dart';
import 'package:mobile_flutter/features/spaces/domain/spaces_repository.dart';
import 'package:mobile_flutter/features/spaces/presentation/spaces_page.dart';
import 'package:mobile_flutter/features/tasks/domain/tasks_repository.dart';

class TaskifyApp extends StatefulWidget {
  const TaskifyApp({
    required this.authenticationRepository,
    required this.spacesRepository,
    required this.tasksRepository,
    this.sessionStore,
    super.key,
  });

  final AuthenticationRepository authenticationRepository;
  final SpacesRepository spacesRepository;
  final TasksRepository tasksRepository;
  final SessionStore? sessionStore;

  @override
  State<TaskifyApp> createState() => _TaskifyAppState();
}

class _TaskifyAppState extends State<TaskifyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  AuthSession? _session;
  bool _isLoggingOut = false;

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
      setState(() => _session = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Taskify Space',
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
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _session == null
            ? LoginPage(
                key: const ValueKey('login-page'),
                authenticationRepository: widget.authenticationRepository,
                onAuthenticated: (session) {
                  setState(() => _session = session);
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
      ),
    );
  }
}
