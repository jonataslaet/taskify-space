import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/auth/domain/auth_session.dart';
import 'package:mobile_flutter/features/auth/domain/authentication_repository.dart';
import 'package:mobile_flutter/features/auth/presentation/forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    required this.authenticationRepository,
    required this.onAuthenticated,
    this.passwordResetSucceeded = false,
    super.key,
  });

  final AuthenticationRepository authenticationRepository;
  final ValueChanged<AuthSession> onAuthenticated;
  final bool passwordResetSucceeded;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _passwordConfirmationFocusNode = FocusNode();

  bool _isSubmitting = false;
  bool _isRegistering = false;
  bool _isPasswordVisible = false;
  late bool _showPasswordResetSuccess;
  ApiFailure? _failure;
  String? _successMessage;
  int _retrySeconds = 0;
  DateTime? _retryEndsAt;
  Timer? _retryTimer;

  bool get _isBlocked => _isSubmitting || _retrySeconds > 0;

  String get _loginButtonLabel {
    if (_retrySeconds > 0) {
      return 'Tente novamente em ${_retrySeconds}s';
    }
    return _isRegistering ? 'Criar conta' : 'Entrar';
  }

  String get _loginButtonSemanticLabel {
    if (_isSubmitting) {
      return _isRegistering ? 'Criando conta' : 'Entrando';
    }
    if (_retrySeconds > 0) {
      return 'Tente novamente em $_retrySeconds segundos';
    }
    return _isRegistering ? 'Criar conta' : 'Entrar';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _showPasswordResetSuccess = widget.passwordResetSucceeded;
  }

  @override
  void didUpdateWidget(covariant LoginPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.passwordResetSucceeded && widget.passwordResetSucceeded) {
      _showPasswordResetSuccess = true;
      _failure = null;
      _successMessage = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    _nameController.dispose();
    _nameFocusNode.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _passwordConfirmationFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _retryEndsAt != null) {
      _synchronizeRetryCountdown();
    }
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (_isRegistering && name.isEmpty) {
      return 'Informe seu nome.';
    }
    return null;
  }

  String? _validatePasswordConfirmation(String? value) {
    if (!_isRegistering) {
      return null;
    }
    final confirmation = value?.trim() ?? '';
    if (confirmation.isEmpty) {
      return 'Confirme sua senha.';
    }
    if (confirmation != _passwordController.text) {
      return 'As senhas não coincidem.';
    }
    return null;
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

    final nameError = _validateName(_nameController.text);
    final emailError = _validateEmail(_emailController.text);
    final passwordError = _validatePassword(_passwordController.text);
    final confirmationError = _validatePasswordConfirmation(
      _passwordConfirmationController.text,
    );
    if (!_formKey.currentState!.validate()) {
      if (_isRegistering && nameError != null) {
        _nameController.selection = TextSelection.fromPosition(
          TextPosition(offset: _nameController.text.length),
        );
        _nameFocusNode.requestFocus();
      } else if (emailError != null) {
        _emailFocusNode.requestFocus();
      } else if ((_isRegistering && confirmationError != null) ||
          (!_isRegistering && passwordError != null)) {
        if (_isRegistering) {
          _passwordConfirmationFocusNode.requestFocus();
        } else {
          _passwordFocusNode.requestFocus();
        }
      } else if (passwordError != null) {
        _passwordFocusNode.requestFocus();
      }
      return;
    }

    setState(() {
      _isSubmitting = true;
      _failure = null;
      _successMessage = null;
      _showPasswordResetSuccess = false;
    });

    try {
      if (_isRegistering) {
        final registeredEmail = _emailController.text.trim().toLowerCase();
        await widget.authenticationRepository.register(
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
          passwordConfirmation: _passwordConfirmationController.text,
        );
        if (!mounted) {
          return;
        }
        FocusManager.instance.primaryFocus?.unfocus();
        TextInput.finishAutofillContext();
        setState(() {
          _isSubmitting = false;
          _isRegistering = false;
          _isPasswordVisible = false;
          _nameController.clear();
          _passwordController.clear();
          _passwordConfirmationController.clear();
          _successMessage =
              'Cadastro realizado! Verifique $registeredEmail para confirmar '
              'o cadastro antes de entrar.';
        });
        return;
      }

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

  void _toggleAuthMode() {
    setState(() {
      _isRegistering = !_isRegistering;
      _failure = null;
      _successMessage = null;
      _showPasswordResetSuccess = false;
      _retryTimer?.cancel();
      _retryEndsAt = null;
      _retrySeconds = 0;
      if (!_isRegistering) {
        _passwordConfirmationController.clear();
      }
    });
  }

  Future<void> _openForgotPassword() async {
    if (_isBlocked || _isRegistering) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final passwordReset = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => ForgotPasswordPage(
          authenticationRepository: widget.authenticationRepository,
          initialEmail: _emailController.text,
        ),
      ),
    );
    if (!mounted || passwordReset != true) {
      return;
    }
    setState(() {
      _failure = null;
      _successMessage = null;
      _showPasswordResetSuccess = true;
      _isPasswordVisible = false;
      _passwordController.clear();
      _passwordConfirmationController.clear();
    });
  }

  Widget _buildLoginCard({required bool showBrandMark}) {
    final theme = Theme.of(context);
    final failure = _failure;
    final successMessage = _successMessage;
    final passwordResetSucceeded = _showPasswordResetSuccess;
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
                if (_isRegistering) ...[
                  TextFormField(
                    key: const Key('name-field'),
                    controller: _nameController,
                    focusNode: _nameFocusNode,
                    enabled: !_isSubmitting,
                    keyboardType: TextInputType.name,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Nome',
                      hintText: 'Seu nome completo',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: _validateName,
                    onFieldSubmitted: (_) => _emailFocusNode.requestFocus(),
                  ),
                  const SizedBox(height: 18),
                ],
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
                  onFieldSubmitted: (_) {
                    if (_isRegistering) {
                      _passwordConfirmationFocusNode.requestFocus();
                    } else {
                      _submit();
                    }
                  },
                ),
                if (!_isRegistering) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const Key('forgot-password-button'),
                      onPressed: _isBlocked ? null : _openForgotPassword,
                      child: const Text('Esqueci minha senha'),
                    ),
                  ),
                ],
                if (_isRegistering) ...[
                  const SizedBox(height: 18),
                  TextFormField(
                    key: const Key('password-confirmation-field'),
                    controller: _passwordConfirmationController,
                    focusNode: _passwordConfirmationFocusNode,
                    enabled: !_isSubmitting,
                    obscureText: !_isPasswordVisible,
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar senha',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                    validator: _validatePasswordConfirmation,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                ],
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  child:
                      failure == null &&
                          successMessage == null &&
                          !passwordResetSucceeded
                      ? const SizedBox(height: 24)
                      : Padding(
                          padding: const EdgeInsets.only(top: 18, bottom: 6),
                          child: Semantics(
                            liveRegion: true,
                            child: Container(
                              key: Key(
                                failure != null
                                    ? 'login-error'
                                    : passwordResetSucceeded
                                    ? 'password-reset-success'
                                    : 'registration-success',
                              ),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: failure == null
                                    ? theme.colorScheme.primaryContainer
                                    : theme.colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    failure == null
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.error_outline_rounded,
                                    color: failure == null
                                        ? theme.colorScheme.onPrimaryContainer
                                        : theme.colorScheme.onErrorContainer,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      failure?.userMessage() ??
                                          (passwordResetSucceeded
                                              ? 'Senha redefinida com sucesso. '
                                                    'Entre com sua nova senha.'
                                              : successMessage!),
                                      style: TextStyle(
                                        color: failure == null
                                            ? theme
                                                  .colorScheme
                                                  .onPrimaryContainer
                                            : theme
                                                  .colorScheme
                                                  .onErrorContainer,
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
                TextButton(
                  key: const Key('toggle-auth-mode-button'),
                  onPressed: _isBlocked ? null : _toggleAuthMode,
                  child: Text(
                    _isRegistering
                        ? 'Já tem conta? Entrar'
                        : 'Não tem conta? Criar conta',
                  ),
                ),
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
                              _loginButtonLabel,
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
