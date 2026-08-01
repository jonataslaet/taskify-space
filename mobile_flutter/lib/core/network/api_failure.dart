enum ApiFailureKind {
  validation,
  unauthorized,
  forbidden,
  rateLimited,
  timeout,
  network,
  server,
  malformedResponse,
  storage,
  unknown,
}

final class ApiFailure implements Exception {
  const ApiFailure(this.kind, {this.statusCode, this.retryAfter});

  final ApiFailureKind kind;
  final int? statusCode;
  final Duration? retryAfter;

  String userMessage({int? retrySeconds}) {
    return switch (kind) {
      ApiFailureKind.validation => 'Confira o e-mail e a senha informados.',
      ApiFailureKind.unauthorized =>
        'E-mail ou senha inválidos, ou cadastro ainda não liberado.',
      ApiFailureKind.forbidden =>
        'Seu acesso não permite concluir esta operação.',
      ApiFailureKind.rateLimited =>
        retrySeconds != null && retrySeconds > 0
            ? 'Muitas tentativas. Tente novamente em $retrySeconds segundos.'
            : 'Muitas tentativas. Aguarde um pouco e tente novamente.',
      ApiFailureKind.timeout =>
        'A conexão demorou mais que o esperado. Tente novamente.',
      ApiFailureKind.network =>
        'Não foi possível conectar à API. Confira sua conexão.',
      ApiFailureKind.server =>
        'O serviço está temporariamente indisponível. Tente novamente.',
      ApiFailureKind.malformedResponse =>
        'A API retornou uma resposta inesperada.',
      ApiFailureKind.storage =>
        'Não foi possível proteger sua sessão neste dispositivo.',
      ApiFailureKind.unknown =>
        'Não foi possível entrar agora. Tente novamente.',
    };
  }

  @override
  String toString() => 'ApiFailure(kind: $kind, statusCode: $statusCode)';
}
