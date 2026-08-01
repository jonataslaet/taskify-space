import 'package:flutter/material.dart';
import 'package:mobile_flutter/features/auth/domain/auth_session.dart';
import 'package:mobile_flutter/features/auth/domain/authentication_repository.dart';
import 'package:mobile_flutter/features/auth/presentation/authenticated_page.dart';
import 'package:mobile_flutter/features/auth/presentation/login_page.dart';

class TaskifyApp extends StatefulWidget {
  const TaskifyApp({required this.authenticationRepository, super.key});

  final AuthenticationRepository authenticationRepository;

  @override
  State<TaskifyApp> createState() => _TaskifyAppState();
}

class _TaskifyAppState extends State<TaskifyApp> {
  AuthSession? _session;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
            : AuthenticatedPage(
                key: const ValueKey('authenticated-page'),
                session: _session!,
              ),
      ),
    );
  }
}
