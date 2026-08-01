import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/storage/secure_session_store.dart';

import '../../helpers/fakes.dart';

void main() {
  test('salva os dois tokens atomicamente em um único registro', () async {
    final storage = FakeSecureStorageGateway();
    final store = SecureSessionStore(storage);

    await store.save(testSession);

    expect(storage.writeCount, 1);
    expect(storage.values, hasLength(1));
    final storedJson = jsonDecode(storage.values.values.single);
    expect(storedJson['accessToken'], 'access-token-test-only');
    expect(storedJson['refreshToken'], 'refresh-token-test-only');
    expect((await store.read())?.username, testSession.username);

    await store.clear();
    expect(await store.read(), isNull);
  });
}
