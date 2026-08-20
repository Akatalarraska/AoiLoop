import 'package:blauloop/core/database/id_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UuidGenerator', () {
    test('produces ids of the length the schema expects', () {
      const UuidGenerator generator = UuidGenerator();

      // Every id column is `withLength(min: 36, max: 36)`. A generator that
      // drifted from that would fail at insert time, in production, on a
      // user's device.
      expect(generator.newId(), hasLength(36));
    });

    test('does not repeat', () {
      const UuidGenerator generator = UuidGenerator();

      final Set<String> ids = <String>{
        for (int i = 0; i < 1000; i++) generator.newId(),
      };

      expect(ids, hasLength(1000));
    });
  });

  group('SequentialIdGenerator', () {
    test('is deterministic, so tests can assert on relationships', () {
      final SequentialIdGenerator generator = SequentialIdGenerator();

      expect(generator.newId(), endsWith('0001'));
      expect(generator.newId(), endsWith('0002'));
    });

    test('matches the 36 character length the schema requires', () {
      final SequentialIdGenerator generator = SequentialIdGenerator();

      // Same constraint as production, so a test database exercises the same
      // column limits as a real one.
      expect(generator.newId(), hasLength(36));
    });

    test('respects a custom prefix and still fits', () {
      final SequentialIdGenerator generator = SequentialIdGenerator(
        prefix: 'profile',
      );

      final String id = generator.newId();
      expect(id, startsWith('profile-'));
      expect(id, hasLength(36));
    });

    test('independent instances do not share a counter', () {
      final SequentialIdGenerator a = SequentialIdGenerator();
      final SequentialIdGenerator b = SequentialIdGenerator();

      expect(a.newId(), b.newId());
    });
  });
}
