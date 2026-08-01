import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_flutter/app/taskify_app.dart';
import 'package:mobile_flutter/core/config/app_config.dart';
import 'package:mobile_flutter/core/device/installation_id_store.dart';
import 'package:mobile_flutter/core/storage/secure_session_store.dart';
import 'package:mobile_flutter/core/storage/secure_storage_gateway.dart';
import 'package:mobile_flutter/features/auth/data/http_authentication_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  const secureStorage = FlutterSecureStorage();
  final storageGateway = FlutterSecureStorageGateway(secureStorage);
  final authenticationRepository = HttpAuthenticationRepository(
    client: http.Client(),
    config: AppConfig.fromEnvironment(),
    installationIdStore: SecureInstallationIdStore(storageGateway),
    sessionStore: SecureSessionStore(storageGateway),
  );

  runApp(TaskifyApp(authenticationRepository: authenticationRepository));
}
