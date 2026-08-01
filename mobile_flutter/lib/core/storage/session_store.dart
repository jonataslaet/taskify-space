import 'package:mobile_flutter/features/auth/domain/auth_session.dart';

abstract interface class SessionStore {
  Future<void> save(AuthSession session);

  Future<AuthSession?> read();

  Future<void> clear();
}
