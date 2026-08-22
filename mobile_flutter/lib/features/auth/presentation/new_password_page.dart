import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_flutter/core/network/api_failure.dart';
import 'package:mobile_flutter/features/auth/domain/authentication_repository.dart';

class NewPasswordPage extends StatefulWidget {
  const factory NewPasswordPage({
    required AuthenticationRepository authenticationRepository,
    required String token,
    required Future<void> Function() onPasswordReset,
    Key? key,
  }) = NewPasswordPage._withToken;

  const NewPasswordPage._withToken({
    required this.authenticationRepository,
    required this.token,
    required this.onPasswordReset,
    super.key,
  }) : _acceptsCode = false;

  const NewPasswordPage.withCode({
    required this.authenticationRepository,
    required this.onPasswordReset,
    super.key,
  }) : token = null,
       _acceptsCode = true;

  final AuthenticationRepository authenticationRepository;
  final Future<void> Function() onPasswordReset;
  final String? token;
  final bool _acceptsCode;

  @override
  State<NewPasswordPage> createState() => _NewPasswordPageState();
}

class _NewPasswordPageState extends State<NewPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  final _codeFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmationFocusNode = FocusNode();
  ApiFailure? _failure;
  bool _isSubmitting = false;
  bool _isPasswordVisible = false;
  bool _tokenRejected = false;
  bool _codeRejected = false;
  bool _resetSucceeded = false;

  bool get _acceptsCode => widget._acceptsCode;

  bool get _hasUsableLinkToken {
    final token = widget.token;
    return token != null && RegExp(r'^[0-9]{6}$').hasMatch(token);
  }

  String get _submittedToken =>
      _acceptsCode ? _codeController.text : widget.token!;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    _codeFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmationFocusNode.dispose();
    super.dispose();
  }

  String? _validateCode(String? value) {
    if (!_acceptsCode) {
      return null;
    }
    final code = value ?? '';
    if (code.isEmpty) {
      return 'Informe o código de validação.';
    }
    if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      return 'Informe os 6 dígitos do código de validação.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Informe a nova senha.';
    }
    final hasRequiredLength = password.length >= 8 && password.length <= 32;
    final hasDigit = RegExp(r'[0-9]').hasMatch(password);
    final hasLowercase = RegExp(r'[a-z]').hasMatch(password);
    final hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
    final hasAllowedSpecial = RegExp(
      r"[!@#&()\[\]{}:;',?/*~$^+=<>._-]",
    ).hasMatch(password);
    final hasWhitespace = RegExp(r'\s').hasMatch(password);
    if (!hasRequiredLength ||
        !hasDigit ||
        !hasLowercase ||
        !hasUppercase ||
        !hasAllowedSpecial ||
        hasWhitespace) {
      return 'Use de 8 a 32 caracteres, sem espaços, com letra maiúscula, '
          'letra minúscula, número e caractere especial como !, @, #, \$, - '
          'ou _.';
    }
    return null;
  }

  String? _validateConfirmation(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirme a nova senha.';
    }
    if (value != _passwordController.text) {
      return 'As senhas não coincidem.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting ||
        _resetSucceeded ||
        (!_acceptsCode && (_tokenRejected || !_hasUsableLinkToken))) {
      return;
    }

    final codeError = _validateCode(_codeController.text);
    final passwordError = _validatePassword(_passwordController.text);
    final confirmationError = _validateConfirmation(
      _confirmationController.text,
    );
    if (!_formKey.currentState!.validate()) {
      if (codeError != null) {
        _codeFocusNode.requestFocus();
      } else if (passwordError != null) {
        _passwordFocusNode.requestFocus();
      } else if (confirmationError != null) {
        _confirmationFocusNode.requestFocus();
      }
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _failure = null;
      _codeRejected = false;
    });

    try {
      await widget.authenticationRepository.resetPassword(
        token: _submittedToken,
        newPassword: _passwordController.text,
        newPasswordConfirmation: _confirmationController.text,
      );
      if (!mounted) {
        return;
      }
      TextInput.finishAutofillContext(shouldSave: true);
      setState(() {
        _isSubmitting = false;
        _resetSucceeded = true;
      });
      try {
        await widget.onPasswordReset();
      } on Object {
        // A senha já foi alterada. A confirmação permanece visível caso a
        // navegação ou a limpeza local não possa ser concluída imediatamente.
      }
    } on ApiFailure catch (failure) {
      if (!mounted) {
        return;
      }
      final tokenRejected =
          failure.statusCode == 404 ||
          failure.kind == ApiFailureKind.unauthorized;
      setState(() {
        _isSubmitting = false;
        _tokenRejected = tokenRejected && !_acceptsCode;
        _codeRejected = tokenRejected && _acceptsCode;
        _failure = tokenRejected ? null : failure;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _failure = const ApiFailure(ApiFailureKind.unknown);
      });
    }
  }

  void _clearFailure() {
    if (_failure != null) {
      setState(() => _failure = null);
    }
  }

  void _clearCodeFailure(String _) {
    if (_failure == null && !_codeRejected) {
      return;
    }
    setState(() {
      _failure = null;
      _codeRejected = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSubmitting,
      child: Scaffold(
        key: const ValueKey('new-password-page'),
        appBar: AppBar(
          title: const Text('Nova senha'),
          leading: IconButton(
            key: const ValueKey('new-password-back-button'),
            onPressed: _isSubmitting
                ? null
                : () => Navigator.of(context).maybePop(),
            tooltip: 'Voltar à tela anterior',
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
    return Card(
      elevation: 0,
      color: Colors.white.withValues(alpha: 0.96),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: Color(0xFFDDE8E5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 30),
        child: !_acceptsCode && (!_hasUsableLinkToken || _tokenRejected)
            ? _buildInvalidToken(theme)
            : _resetSucceeded
            ? _buildSuccess(theme)
            : _buildForm(theme),
      ),
    );
  }

  Widget _buildInvalidToken(ThemeData theme) {
    return Semantics(
      liveRegion: true,
      child: Column(
        key: const ValueKey('new-password-invalid-token'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.link_off_rounded,
            size: 58,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 20),
          Text(
            'Link inválido ou expirado',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: const Color(0xFF173B38),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Solicite um novo link de recuperação para redefinir sua senha.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF5D716F),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(ThemeData theme) {
    return Semantics(
      liveRegion: true,
      child: Column(
        key: const ValueKey('new-password-success'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 58,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 20),
          Text(
            'Senha redefinida',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: const Color(0xFF173B38),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Sua senha foi alterada. Você já pode entrar com a nova senha.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF5D716F),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(ThemeData theme) {
    final failure = _failure;
    final submitLabel = _acceptsCode ? 'Confirmar' : 'Redefinir senha';
    final submittingLabel = _acceptsCode
        ? 'Confirmando nova senha'
        : 'Redefinindo senha';
    return AutofillGroup(
      onDisposeAction: AutofillContextAction.cancel,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.lock_reset_rounded,
              size: 52,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              'Crie uma nova senha',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: const Color(0xFF173B38),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (_acceptsCode) ...[
              Text(
                'Caso o email informado exista, receberá nele um código de '
                'validação, o qual colocará no campo de validação desta tela',
                key: const ValueKey('new-password-code-instructions'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF5D716F),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                key: const ValueKey('new-password-code-field'),
                controller: _codeController,
                focusNode: _codeFocusNode,
                enabled: !_isSubmitting,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.oneTimeCode],
                autocorrect: false,
                enableSuggestions: false,
                maxLength: 6,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  labelText: 'Código de validação',
                  hintText: '000000',
                  counterText: '',
                  prefixIcon: Icon(Icons.pin_outlined),
                ),
                forceErrorText: _codeRejected
                    ? 'Código inválido ou expirado'
                    : null,
                validator: _validateCode,
                onChanged: _clearCodeFailure,
                onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
              ),
              const SizedBox(height: 24),
            ],
            Text(
              'Use de 8 a 32 caracteres com letras maiúscula e minúscula, '
              'número e caractere especial como !, @, #, \$, - ou _.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF5D716F),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            TextFormField(
              key: const ValueKey('new-password-field'),
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              enabled: !_isSubmitting,
              obscureText: !_isPasswordVisible,
              keyboardType: TextInputType.visiblePassword,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'Nova senha',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  key: const ValueKey('new-password-visibility-button'),
                  onPressed: _isSubmitting
                      ? null
                      : () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible,
                        ),
                  tooltip: _isPasswordVisible
                      ? 'Ocultar senhas'
                      : 'Mostrar senhas',
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
              validator: _validatePassword,
              onChanged: (_) => _clearFailure(),
              onFieldSubmitted: (_) => _confirmationFocusNode.requestFocus(),
            ),
            const SizedBox(height: 18),
            TextFormField(
              key: const ValueKey('new-password-confirmation-field'),
              controller: _confirmationController,
              focusNode: _confirmationFocusNode,
              enabled: !_isSubmitting,
              obscureText: !_isPasswordVisible,
              keyboardType: TextInputType.visiblePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Confirmar nova senha',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
              validator: _validateConfirmation,
              onChanged: (_) => _clearFailure(),
              onFieldSubmitted: (_) => _submit(),
            ),
            if (failure != null) ...[
              const SizedBox(height: 18),
              Semantics(
                liveRegion: true,
                child: Container(
                  key: const ValueKey('new-password-error'),
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
                          _failureMessage(failure),
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Semantics(
              button: true,
              enabled: !_isSubmitting,
              label: _isSubmitting ? submittingLabel : submitLabel,
              child: FilledButton(
                key: const ValueKey('new-password-submit-button'),
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox.square(
                        key: ValueKey('new-password-progress'),
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(submitLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _failureMessage(ApiFailure failure) {
  return switch (failure.kind) {
    ApiFailureKind.validation =>
      'A nova senha não foi aceita. Confira os requisitos informados.',
    ApiFailureKind.rateLimited =>
      'Muitas tentativas. Aguarde um pouco e tente novamente.',
    ApiFailureKind.timeout =>
      'A API não confirmou a redefinição a tempo. Tente entrar com a nova '
          'senha antes de solicitar outro link.',
    ApiFailureKind.network =>
      'Não foi possível conectar à API. Confira sua conexão.',
    ApiFailureKind.server =>
      'O serviço está temporariamente indisponível. Tente novamente.',
    _ => 'Não foi possível redefinir a senha agora. Tente novamente.',
  };
}
