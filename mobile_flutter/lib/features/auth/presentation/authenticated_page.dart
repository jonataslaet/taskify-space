import 'package:flutter/material.dart';
import 'package:mobile_flutter/features/auth/domain/auth_session.dart';

class AuthenticatedPage extends StatelessWidget {
  const AuthenticatedPage({required this.session, super.key});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final displayName = session.name ?? session.username;
    return Scaffold(
      appBar: AppBar(title: const Text('Taskify Space')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.verified_user_rounded,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Olá, $displayName!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Login concluído e sessão armazenada com segurança.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    session.role,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
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
