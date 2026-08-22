import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/auth/domain/authentication_repository.dart';
import 'package:mobile_flutter/features/auth/presentation/new_password_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({
    required this.authenticationRepository,
    this.initialEmail = '',
    super.key,
  });

  final AuthenticationRepository authenticationRepository;
  final String initialEmail;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _emailFocusNode = FocusNode();
  late final TextEditingController _emailController;
  ApiFailure? _failure;
  bool _isSubmitting = false;
  bool _requestSucceeded = false;
  DateTime? _retryEndsAt;
  Timer? _retryTimer;
  int _retrySeconds = 0;

  bool get _isBlocked => _isSubmitting || _retrySeconds > 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _emailController = TextEditingController(text: widget.initialEmail.trim());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _retryEndsAt != null) {
      _synchronizeRetryCountdown();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
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

  Future<void> _submit() async {
    if (_isBlocked) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      _emailFocusNode.requestFocus();
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _failure = null;
      _requestSucceeded = false;
    });

    try {
      await widget.authenticationRepository.requestPasswordRecovery(
        email: _emailController.text.trim(),
      );
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
      return;
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _failure = const ApiFailure(ApiFailureKind.unknown);
        _isSubmitting = false;
      });
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _isSubmitting = false;
      _requestSucceeded = true;
    });
    await _openCodePage();
  }

  Future<void> _openCodePage() async {
    final passwordReset = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (newPasswordContext) => NewPasswordPage.withCode(
          authenticationRepository: widget.authenticationRepository,
          onPasswordReset: () async {
            if (newPasswordContext.mounted) {
              Navigator.of(newPasswordContext).pop(true);
            }
          },
        ),
      ),
    );
    if (!mounted || passwordReset != true) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  void _startRetryCountdown(Duration duration) {
    _retryTimer?.cancel();
    if (duration.inSeconds <= 0) {
      return;
    }
    _retryEndsAt = DateTime.now().add(duration);
    setState(() => _retrySeconds = duration.inSeconds);
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
        if (_failure?.kind == ApiFailureKind.rateLimited) {
          _failure = null;
        }
      });
      return;
    }
    setState(() => _retrySeconds = remainingSeconds);
  }

  void _clearFeedback() {
    if (_failure == null && !_requestSucceeded) {
      return;
    }
    setState(() {
      _failure = null;
      _requestSucceeded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSubmitting,
      child: Scaffold(
        key: const ValueKey('forgot-password-page'),
        appBar: AppBar(
          title: const Text('Recuperar senha'),
          leading: IconButton(
            key: const ValueKey('forgot-password-back-button'),
            onPressed: _isSubmitting
                ? null
                : () => Navigator.of(context).maybePop(),
            tooltip: 'Voltar ao login',
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
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
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight > 48
                        ? constraints.maxHeight - 48
                        : 0,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: _buildCard(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
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
          onDisposeAction: AutofillContextAction.cancel,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.mark_email_read_outlined,
                  size: 52,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  'Esqueceu sua senha?',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF173B38),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Informe seu e-mail para receber um código de redefinição.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF5D716F),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  key: const ValueKey('forgot-password-email-field'),
                  controller: _emailController,
                  focusNode: _emailFocusNode,
                  enabled: !_isBlocked,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    hintText: 'voce@exemplo.com',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                  validator: _validateEmail,
                  onChanged: (_) => _clearFeedback(),
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (failure != null) ...[
                  const SizedBox(height: 18),
                  _FeedbackBanner(
                    key: const ValueKey('forgot-password-error'),
                    isError: true,
                    message: _failureMessage(failure),
                  ),
                ] else if (_requestSucceeded) ...[
                  const SizedBox(height: 18),
                  const _FeedbackBanner(
                    key: ValueKey('forgot-password-success'),
                    isError: false,
                    message:
                        'Caso esse email exista, será enviado a ele um código '
                        'para redefinir a senha.',
                  ),
                ],
                const SizedBox(height: 24),
                Semantics(
                  button: true,
                  enabled: !_isBlocked,
                  label: _isSubmitting
                      ? 'Enviando código de recuperação'
                      : _retrySeconds > 0
                      ? 'Tente novamente em $_retrySeconds segundos'
                      : 'Enviar código de recuperação',
                  child: FilledButton(
                    key: const ValueKey('forgot-password-submit-button'),
                    onPressed: _isBlocked ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox.square(
                            key: ValueKey('forgot-password-progress'),
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _retrySeconds > 0
                                ? 'Tente novamente em ${_retrySeconds}s'
                                : _requestSucceeded
                                ? 'Enviar novamente'
                                : 'Enviar código',
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

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({
    required this.isError,
    required this.message,
    super.key,
  });

  final bool isError;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isError
              ? colorScheme.errorContainer
              : colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: isError
                  ? colorScheme.onErrorContainer
                  : colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: isError
                      ? colorScheme.onErrorContainer
                      : colorScheme.onPrimaryContainer,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _failureMessage(ApiFailure failure) {
  if (failure.kind == ApiFailureKind.rateLimited) {
    return 'Muitas solicitações. Aguarde um pouco e tente novamente.';
  }
  return switch (failure.kind) {
    ApiFailureKind.validation => 'Confira o e-mail informado.',
    ApiFailureKind.timeout =>
      'A API não confirmou a solicitação a tempo. Confira seu e-mail antes de '
          'tentar novamente.',
    ApiFailureKind.network =>
      'Não foi possível conectar à API. Confira sua conexão.',
    ApiFailureKind.server =>
      'O serviço está temporariamente indisponível. Tente novamente.',
    ApiFailureKind.storage =>
      'Não foi possível identificar este dispositivo para concluir o pedido.',
    _ => 'Não foi possível solicitar o código agora. Tente novamente.',
  };
}
