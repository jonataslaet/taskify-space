final class AuthSession {
  const AuthSession({
    required this.id,
    required this.username,
    required this.name,
    required this.accessToken,
    required this.refreshToken,
    required this.role,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! int) {
      throw const FormatException('Campo id ausente ou inválido.');
    }

    final rawName = json['name'];
    if (rawName != null && rawName is! String) {
      throw const FormatException('Campo name inválido.');
    }

    final username = _requiredString(
      json,
      ['username', 'email', 'userName', 'user_name'],
    );
    final accessToken = _requiredString(
      json,
      ['accessToken', 'token', 'access_token'],
    );
    final refreshToken = _requiredString(
      json,
      ['refreshToken', 'refresh_token', 'refreshTokenValue'],
    );
    final role = _requiredString(json, ['role', 'roles']);

    return AuthSession(
      id: id,
      username: username,
      name: rawName is String && rawName.trim().isNotEmpty
          ? rawName.trim()
          : null,
      accessToken: accessToken,
      refreshToken: refreshToken,
      role: role,
    );
  }

  final int id;
  final String username;
  final String? name;
  final String accessToken;
  final String refreshToken;
  final String role;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'username': username,
    'name': name,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'role': role,
  };

  static String _requiredString(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    throw FormatException('Campos ${keys.join(', ')} ausentes ou inválidos.');
  }
}
