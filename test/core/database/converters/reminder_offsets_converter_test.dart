import 'package:blauloop/core/database/converters/reminder_offsets_converter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ReminderOffsetsConverter converter = ReminderOffsetsConverter();

  group('normalize', () {
    test('sorts longest lead time first', () {
      final List<Duration> result = ReminderOffsetsConverter.normalize(
        const <Duration>[
          Duration(hours: 1),
          Duration(hours: 48),
          Duration(hours: 6),
          Duration(hours: 24),
        ],
      );

      expect(result, const <Duration>[
        Duration(hours: 48),
        Duration(hours: 24),
        Duration(hours: 6),
        Duration(hours: 1),
      ]);
    });

    test('removes duplicates so one moment gets one notification', () {
      final List<Duration> result = ReminderOffsetsConverter.normalize(
        const <Duration>[
          Duration(hours: 24),
          Duration(hours: 1),
          Duration(hours: 24),
          Duration(minutes: 60),
        ],
      );

      expect(result, const <Duration>[Duration(hours: 24), Duration(hours: 1)]);
    });

    test('drops negative offsets', () {
      // A reminder cannot lead a deadline by a negative amount. Scheduling one
      // would either never fire or fire the instant it was created.
      final List<Duration> result = ReminderOffsetsConverter.normalize(
        const <Duration>[Duration(hours: 24), Duration(hours: -1)],
      );

      expect(result, const <Duration>[Duration(hours: 24)]);
    });

    test('keeps zero, which means "at the moment it is due"', () {
      final List<Duration> result = ReminderOffsetsConverter.normalize(
        const <Duration>[Duration.zero, Duration(hours: 1)],
      );

      expect(result, const <Duration>[Duration(hours: 1), Duration.zero]);
    });

    test('handles an empty list', () {
      expect(ReminderOffsetsConverter.normalize(const <Duration>[]), isEmpty);
    });

    test('is idempotent', () {
      const List<Duration> input = <Duration>[
        Duration(hours: 1),
        Duration(hours: 24),
      ];
      final List<Duration> once = ReminderOffsetsConverter.normalize(input);
      final List<Duration> twice = ReminderOffsetsConverter.normalize(once);

      expect(twice, once);
    });
  });

  group('round trip', () {
    test('survives storage and retrieval unchanged', () {
      const List<Duration> offsets = <Duration>[
        Duration(hours: 48),
        Duration(hours: 24),
        Duration(hours: 6),
        Duration(hours: 1),
        Duration.zero,
      ];

      expect(converter.fromSql(converter.toSql(offsets)), offsets);
    });

    test('normalises on write, so equal sets store identically', () {
      const List<Duration> a = <Duration>[
        Duration(hours: 1),
        Duration(hours: 24),
      ];
      const List<Duration> b = <Duration>[
        Duration(hours: 24),
        Duration(hours: 1),
        Duration(hours: 24),
      ];

      expect(converter.toSql(a), converter.toSql(b));
    });

    test('stores minutes as plain readable text', () {
      expect(
        converter.toSql(const <Duration>[
          Duration(hours: 24),
          Duration(hours: 1),
        ]),
        '1440,60',
      );
    });

    test('reads an empty column as an empty list', () {
      expect(converter.fromSql(''), isEmpty);
    });

    test('keeps sub-hour offsets', () {
      const List<Duration> offsets = <Duration>[Duration(minutes: 30)];

      expect(converter.fromSql(converter.toSql(offsets)), offsets);
    });

    test('truncates sub-minute precision, which reminders do not need', () {
      // Documenting the resolution rather than pretending it is finer than it
      // is: the OS will not fire a notification to the second anyway.
      expect(
        converter.fromSql(
          converter.toSql(const <Duration>[Duration(minutes: 5, seconds: 30)]),
        ),
        const <Duration>[Duration(minutes: 5)],
      );
    });
  });
}
