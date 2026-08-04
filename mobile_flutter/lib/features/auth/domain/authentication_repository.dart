import 'package:mobile_flutter/features/auth/domain/auth_session.dart';

abstract interface class AuthenticationRepository {
  Future<AuthSession> login({required String email, required String password});

  Future<void> logout({required String refreshToken});

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  });
}
