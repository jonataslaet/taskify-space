final class PasswordRecoveryRoute {
  const PasswordRecoveryRoute({required this.token});

  final String token;

  static final RegExp _recoveryCodePattern = RegExp(r'^[0-9]{6}$');

  static PasswordRecoveryRoute? tryParse(String? location) {
    if (location == null || location.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(location);
    if (uri == null) {
      return null;
    }

    final segments = _recoveryPathSegments(uri);
    if (segments == null ||
        segments.length != 2 ||
        segments.first != 'new-password') {
      return null;
    }

    final token = segments.last;
    if (!_recoveryCodePattern.hasMatch(token)) {
      return null;
    }
    return PasswordRecoveryRoute(token: token);
  }

  static List<String>? _recoveryPathSegments(Uri uri) {
    switch (uri.scheme.toLowerCase()) {
      case '':
        if (uri.hasAuthority) {
          return null;
        }
        return uri.pathSegments;
      case 'http':
      case 'https':
        if (!uri.hasAuthority || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
          return null;
        }
        return uri.pathSegments;
      case 'taskifyspace':
        if (uri.hasAuthority && uri.host.isNotEmpty) {
          if (uri.userInfo.isNotEmpty || uri.host != 'new-password') {
            return null;
          }
          return <String>['new-password', ...uri.pathSegments];
        }
        if (uri.userInfo.isNotEmpty) {
          return null;
        }
        return uri.pathSegments;
      default:
        return null;
    }
  }
}
