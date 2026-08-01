import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/auth/domain/auth_session.dart';
import 'package:mobile_flutter/features/auth/domain/authentication_repository.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    required this.authenticationRepository,
    required this.onAuthenticated,
    super.key,
  });

  final AuthenticationRepository authenticationRepository;
  final ValueChanged<AuthSession> onAuthenticated;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _isSubmitting = false;
  bool _isPasswordVisible = false;
  ApiFailure? _failure;
  int _retrySeconds = 0;
  DateTime? _retryEndsAt;
  Timer? _retryTimer;

  bool get _isBlocked => _isSubmitting || _retrySeconds > 0;

  String get _loginButtonSemanticLabel {
    if (_isSubmitting) {
      return 'Entrando';
    }
    if (_retrySeconds > 0) {
      return 'Tente novamente em $_retrySeconds segundos';
    }
    return 'Entrar';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _retryEndsAt != null) {
      _synchronizeRetryCountdown();
    }
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Informe seu e-mail.';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Informe um e-mail válido.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Informe sua senha.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isBlocked) {
      return;
    }

    final emailError = _validateEmail(_emailController.text);
    final passwordError = _validatePassword(_passwordController.text);
    if (!_formKey.currentState!.validate()) {
      if (emailError != null) {
        _emailFocusNode.requestFocus();
      } else if (passwordError != null) {
        _passwordFocusNode.requestFocus();
      }
      return;
    }

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });

    try {
      final session = await widget.authenticationRepository.login(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) {
        return;
      }
      setState(() => _isSubmitting = false);
      TextInput.finishAutofillContext();
      widget.onAuthenticated(session);
    } on ApiFailure catch (failure) {
      if (!mounted) {
        return;
      }
      setState(() {
        _failure = failure;
        _isSubmitting = false;
      });
      if (failure.kind == ApiFailureKind.rateLimited &&
          failure.retryAfter != null) {
        _startRetryCountdown(failure.retryAfter!);
      }
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _failure = const ApiFailure(ApiFailureKind.unknown);
        _isSubmitting = false;
      });
    }
  }

  void _startRetryCountdown(Duration duration) {
    _retryTimer?.cancel();
    final seconds = duration.inSeconds;
    if (seconds <= 0) {
      return;
    }
    _retryEndsAt = DateTime.now().add(duration);
    setState(() => _retrySeconds = seconds);
    _retryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _synchronizeRetryCountdown(decrementAtLeastOnce: true);
    });
  }

  void _synchronizeRetryCountdown({bool decrementAtLeastOnce = false}) {
    final retryEndsAt = _retryEndsAt;
    if (retryEndsAt == null || !mounted) {
      return;
    }

    final remainingMilliseconds = retryEndsAt
        .difference(DateTime.now())
        .inMilliseconds;
    final wallClockSeconds = remainingMilliseconds <= 0
        ? 0
        : (remainingMilliseconds / 1000).ceil();
    final timerSeconds = decrementAtLeastOnce
        ? (_retrySeconds - 1).clamp(0, _retrySeconds).toInt()
        : _retrySeconds;
    final remainingSeconds = wallClockSeconds < timerSeconds
        ? wallClockSeconds
        : timerSeconds;

    if (remainingSeconds == 0) {
      _retryTimer?.cancel();
      _retryEndsAt = null;
      setState(() {
        _retrySeconds = 0;
        _failure = null;
      });
      return;
    }
    setState(() => _retrySeconds = remainingSeconds);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE8F3F1), Color(0xFFF7F9F8)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              if (isWide) {
                return Row(
                  children: [
                    const Expanded(flex: 5, child: _BrandPanel()),
                    Expanded(
                      flex: 4,
                      child: _ScrollableForm(
                        minHeight: constraints.maxHeight,
                        child: _buildLoginCard(showBrandMark: false),
                      ),
                    ),
                  ],
                );
              }
              return _ScrollableForm(
                minHeight: constraints.maxHeight,
                child: _buildLoginCard(showBrandMark: true),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard({required bool showBrandMark}) {
    final theme = Theme.of(context);
    final failure = _failure;
    return Card(
      elevation: 0,
      color: Colors.white.withValues(alpha: 0.96),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: Color(0xFFDDE8E5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 30),
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showBrandMark) ...[
                  const _CompactBrand(),
                  const SizedBox(height: 32),
                ],
                Text(
                  'Bem-vindo',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: const Color(0xFF173B38),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Entre para organizar seus espaços e tarefas.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF5D716F),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  key: const Key('email-field'),
                  controller: _emailController,
                  focusNode: _emailFocusNode,
                  enabled: !_isSubmitting,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [
                    AutofillHints.username,
                    AutofillHints.email,
                  ],
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    hintText: 'voce@exemplo.com',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                  validator: _validateEmail,
                  onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  key: const Key('password-field'),
                  controller: _passwordController,
                  focusNode: _passwordFocusNode,
                  enabled: !_isSubmitting,
                  obscureText: !_isPasswordVisible,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              setState(
                                () => _isPasswordVisible = !_isPasswordVisible,
                              );
                            },
                      tooltip: _isPasswordVisible
                          ? 'Ocultar senha'
                          : 'Mostrar senha',
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                  validator: _validatePassword,
                  onFieldSubmitted: (_) => _submit(),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  child: failure == null
                      ? const SizedBox(height: 24)
                      : Padding(
                          padding: const EdgeInsets.only(top: 18, bottom: 6),
                          child: Semantics(
                            liveRegion: true,
                            child: Container(
                              key: const Key('login-error'),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      failure.userMessage(
                                        retrySeconds: _retrySeconds,
                                      ),
                                      style: TextStyle(
                                        color:
                                            theme.colorScheme.onErrorContainer,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 4),
                Semantics(
                  button: true,
                  enabled: !_isBlocked,
                  label: _loginButtonSemanticLabel,
                  child: FilledButton(
                    key: const Key('login-button'),
                    onPressed: _isBlocked ? null : _submit,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: _isSubmitting
                          ? const SizedBox.square(
                              key: ValueKey('login-progress'),
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _retrySeconds > 0
                                  ? 'Tente novamente em ${_retrySeconds}s'
                                  : 'Entrar',
                              key: ValueKey('login-label-$_retrySeconds'),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScrollableForm extends StatelessWidget {
  const _ScrollableForm({required this.minHeight, required this.child});

  final double minHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: minHeight > 48 ? minHeight - 48 : 0,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _CompactBrand extends StatelessWidget {
  const _CompactBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _BrandIcon(size: 42),
        const SizedBox(width: 12),
        Text(
          'Taskify Space',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: const Color(0xFF173B38),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(56),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _BrandIcon(size: 64),
            const SizedBox(height: 28),
            Text(
              'Taskify Space',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: const Color(0xFF173B38),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Organize o trabalho, acompanhe o progresso e mantenha todos no mesmo espaço.',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: const Color(0xFF4E6865),
                height: 1.4,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandIcon extends StatelessWidget {
  const _BrandIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x29006C67),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Icon(Icons.check_rounded, color: Colors.white, size: size * 0.66),
    );
  }
}
