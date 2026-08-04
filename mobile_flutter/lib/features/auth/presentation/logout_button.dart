import 'package:flutter/material.dart';

class LogoutButton extends StatefulWidget {
  const LogoutButton({required this.onLogout, super.key});

  final Future<void> Function() onLogout;

  @override
  State<LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<LogoutButton> {
  bool _isLoggingOut = false;

  Future<void> _logout() async {
    if (_isLoggingOut) {
      return;
    }

    setState(() => _isLoggingOut = true);
    try {
      await widget.onLogout();
    } on Object {
      // O encerramento local da sessão é garantido pelo aplicativo.
    } finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('logout-button'),
      tooltip: 'Sair',
      onPressed: _isLoggingOut ? null : _logout,
      icon: _isLoggingOut
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                key: ValueKey('logout-progress'),
                strokeWidth: 2,
              ),
            )
          : const Icon(Icons.logout_rounded),
    );
  }
}
