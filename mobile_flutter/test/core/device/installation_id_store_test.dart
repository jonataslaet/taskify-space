import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/device/installation_id_store.dart';

import '../../helpers/fakes.dart';

void main() {
  group('SecureInstallationIdStore', () {
    test('cria uma vez e reutiliza o UUID persistido', () async {
      final storage = FakeSecureStorageGateway();
      const generatedId = '123e4567-e89b-42d3-a456-426614174000';
      final store = SecureInstallationIdStore(
        storage,
        generator: () => generatedId,
      );

      expect(await store.getOrCreate(), generatedId);
      expect(await store.getOrCreate(), generatedId);
      expect(storage.writeCount, 1);

      final secondStore = SecureInstallationIdStore(
        storage,
        generator: () => '123e4567-e89b-42d3-a456-426614174999',
      );
      expect(await secondStore.getOrCreate(), generatedId);
      expect(storage.writeCount, 1);
    });

    test('o gerador padrão produz UUID v4', () {
      expect(
        generateInstallationId(),
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    });

    test('permite tentar novamente depois de uma falha transitória', () async {
      final storage = FakeSecureStorageGateway()..failNextWrite = true;
      const generatedId = '123e4567-e89b-42d3-a456-426614174000';
      final store = SecureInstallationIdStore(
        storage,
        generator: () => generatedId,
      );

      await expectLater(store.getOrCreate(), throwsStateError);
      expect(await store.getOrCreate(), generatedId);
      expect(storage.writeCount, 1);
    });
  });
}
