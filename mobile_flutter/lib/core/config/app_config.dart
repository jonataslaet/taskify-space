import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig({
    required String apiBaseUrl,
    bool allowInsecureHttp = !kReleaseMode,
  }) : apiBaseUri = _parseApiBaseUri(
         apiBaseUrl,
         allowInsecureHttp: allowInsecureHttp,
       );

  factory AppConfig.fromEnvironment() {
    const configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
    final apiBaseUrl = configuredBaseUrl.trim().isNotEmpty
        ? configuredBaseUrl
        : _defaultApiBaseUrl;

    return AppConfig(apiBaseUrl: apiBaseUrl);
  }

  final Uri apiBaseUri;

  static String get _defaultApiBaseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Alias do loopback do computador host no Android Emulator.
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  Uri endpoint(String path) {
    final endpointPath = path.replaceFirst(RegExp(r'^/+'), '');
    if (endpointPath.isEmpty) {
      return apiBaseUri;
    }

    final basePath = apiBaseUri.path == '/' ? '/' : '${apiBaseUri.path}/';
    return apiBaseUri.replace(path: '$basePath$endpointPath');
  }

  static Uri _parseApiBaseUri(
    String rawValue, {
    required bool allowInsecureHttp,
  }) {
    final value = rawValue.trim();
    final uri = Uri.tryParse(value);
    if (value.isEmpty ||
        uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException(
        'API_BASE_URL deve ser uma URL HTTP(S) absoluta e sem query ou fragmento.',
      );
    }
    if (uri.scheme == 'http' && !allowInsecureHttp) {
      throw const FormatException(
        'API_BASE_URL deve usar HTTPS em builds de release.',
      );
    }

    var normalizedPath = uri.path;
    while (normalizedPath.length > 1 && normalizedPath.endsWith('/')) {
      normalizedPath = normalizedPath.substring(0, normalizedPath.length - 1);
    }
    return uri.replace(path: normalizedPath.isEmpty ? '/' : normalizedPath);
  }
}
