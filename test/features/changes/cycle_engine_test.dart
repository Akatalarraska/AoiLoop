import 'package:blauloop/core/database/app_database.dart';
import 'package:blauloop/core/errors/app_failure.dart';
import 'package:blauloop/features/changes/data/cycle_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  const Duration tenDays = Duration(days: 10);
  const int nineAm = 9 * 60;

  late TestHarness h;
  late CycleEngine engine;
  late UserProfile profile;
  late ConsumableType sensor;

  /// Local rather than UTC: the deadlines this engine produces are read off a
  /// phone in the user's own zone, and the preferred-time offer only means
  /// anything there.
  final DateTime installedAt = DateTime(2026, 8, 17, 12);

  setUp(() async {
    h = TestHarness.create(now: installedAt.toUtc());
    engine = CycleEngine(db: h.db, instances: h.instances, changes: h.changes);
    profile = await h.seedProfile();
    sensor = await h.seedType(name: 'Sensor', defaultDuration: tenDays);
  });

  Future<CycleTransition> register({
    DateTime? changedAt,
    bool usePreferredTime = false,
    int? preferredMinuteOfDay,
    ConsumableType? type,
  }) {
    return engine.registerChange(
      userProfileId: profile.id,
      type: type ?? sensor,
      changedAt: changedAt ?? installedAt,
      usePreferredTime: usePreferredTime,
      preferredMinuteOfDay: preferredMinuteOfDay,
    );
  }

  Future<List<ConsumableInstance>> allInstances() =>
      h.db.select(h.db.consumableInstances).get();

  group('the first change of a type', () {
    test('opens a cycle with nothing to close', () async {
      final CycleTransition transition = await register();

      expect(transition.closed, isNull);
      expect(transition.replacedSomething, isFalse);
      expect(transition.opened.status, ConsumableStatus.active);
      expect(transition.opened.installedAt, installedAt.toUtc());
    });

    test('dates the deadline from the type duration', () async {
      final CycleTransition transition = await register();

      expect(
        transition.opened.expectedChangeAt,
        installedAt.toUtc().add(tenDays),
      );
    });

    test('records the event with no predecessor', () async {
      final CycleTransition transition = await register();

      expect(transition.event.previousConsumableInstanceId, isNull);
      expect(transition.event.consumableInstanceId, transition.opened.id);
      // Nothing was missed, because there was no date to miss.
      expect(transition.event.type, ChangeType.scheduled);
    });
  });

  group('replacing what is in use', () {
    test('closes the old cycle at the moment of the change', () async {
      final CycleTransition first = await register();
      final DateTime changedAt = installedAt.add(tenDays);

      final CycleTransition second = await register(changedAt: changedAt);

      expect(second.closed!.id, first.opened.id);
      expect(
        second.closed!.removedAt,
        isNull,
        reason:
            'the returned row is '
            'the one read before the close, kept so callers can see what it '
            'looked like in use',
      );

      final ConsumableInstance reread = (await h.instances.findById(
        first.opened.id,
      ))!;
      expect(reread.removedAt, changedAt.toUtc());
      expect(reread.status, ConsumableStatus.completed);
    });

    test('links the new instance to the old one', () async {
      final CycleTransition first = await register();
      final CycleTransition second = await register(
        changedAt: installedAt.add(tenDays),
      );

      expect(second.event.previousConsumableInstanceId, first.opened.id);
      expect(second.event.consumableInstanceId, second.opened.id);
    });

    test('leaves exactly one active instance for the type', () async {
      await register();
      await register(changedAt: installedAt.add(tenDays));
      await register(changedAt: installedAt.add(const Duration(days: 20)));

      final List<ConsumableInstance> all = await allInstances();
      expect(all, hasLength(3));
      expect(
        all.where(
          (ConsumableInstance i) => i.status == ConsumableStatus.active,
        ),
        hasLength(1),
      );
    });
  });

  group('on time versus early', () {
    test('a change on the deadline ran its course', () async {
      await register();

      final CycleTransition second = await register(
        changedAt: installedAt.add(tenDays),
      );

      expect(second.closed, isNotNull);
      expect(second.event.type, ChangeType.scheduled);
      final ConsumableInstance closed = (await h.instances.findById(
        second.closed!.id,
      ))!;
      expect(closed.status, ConsumableStatus.completed);
    });

    test('a change once the card says due soon is still on time', () async {
      await register();

      // Twelve hours out, inside the 24 hour due-soon window Home uses.
      // Following the app's own prompt must not leave a mark in history.
      final CycleTransition second = await register(
        changedAt: installedAt.add(const Duration(days: 9, hours: 12)),
      );

      expect(second.event.type, ChangeType.scheduled);
      final ConsumableInstance closed = (await h.instances.findById(
        second.closed!.id,
      ))!;
      expect(closed.status, ConsumableStatus.completed);
    });

    test('a change well before the deadline is recorded as early', () async {
      await register();

      final CycleTransition second = await register(
        changedAt: installedAt.add(const Duration(days: 4)),
      );

      expect(second.event.type, ChangeType.early);
      final ConsumableInstance closed = (await h.instances.findById(
        second.closed!.id,
      ))!;
      expect(closed.status, ConsumableStatus.removedEarly);
    });

    test('an untracked predecessor is never early', () async {
      final ConsumableType strips = await h.seedType(
        name: 'Strips',
        defaultDuration: null,
        tracksCycle: false,
      );

      await register(type: strips);
      final CycleTransition second = await register(
        type: strips,
        changedAt: installedAt.add(const Duration(days: 1)),
      );

      expect(second.event.type, ChangeType.scheduled);
      final ConsumableInstance closed = (await h.instances.findById(
        second.closed!.id,
      ))!;
      expect(closed.status, ConsumableStatus.completed);
    });
  });

  group('the preferred change time', () {
    test('is only applied when the user accepts it', () async {
      final CycleTransition declined = await register(
        preferredMinuteOfDay: nineAm,
      );

      expect(declined.schedule.offersPreferredTime, isTrue);
      expect(
        declined.opened.expectedChangeAt,
        declined.schedule.naturalChangeAt,
      );
    });

    test('shortens the stored deadline when accepted', () async {
      final CycleTransition accepted = await register(
        preferredMinuteOfDay: nineAm,
        usePreferredTime: true,
      );

      expect(
        accepted.opened.expectedChangeAt,
        accepted.schedule.preferredChangeAt,
      );
      expect(
        accepted.opened.expectedChangeAt,
        DateTime(2026, 8, 27, 9).toUtc(),
      );
    });

    test(
      'accepting an offer that was never made keeps the real date',
      () async {
        // The deadline already lands at 12:00, so a 12:00 preference has
        // nothing to move. A stale checkbox must not invent a date.
        final CycleTransition transition = await register(
          preferredMinuteOfDay: 12 * 60,
          usePreferredTime: true,
        );

        expect(transition.schedule.offersPreferredTime, isFalse);
        expect(
          transition.opened.expectedChangeAt,
          installedAt.toUtc().add(tenDays),
        );
      },
    );
  });

  group('types that are counted rather than timed', () {
    test('open an instance with no deadline', () async {
      final ConsumableType strips = await h.seedType(
        name: 'Strips',
        defaultDuration: null,
        tracksCycle: false,
      );

      final CycleTransition transition = await register(type: strips);

      expect(transition.opened.expectedChangeAt, isNull);
      expect(transition.schedule.isTracked, isFalse);
    });

    test('are untracked when the countdown is off, duration or not', () async {
      final ConsumableType untimed = await h.seedType(
        name: 'Overpatch',
        defaultDuration: tenDays,
        tracksCycle: false,
      );

      final CycleTransition transition = await register(type: untimed);

      expect(transition.opened.expectedChangeAt, isNull);
    });
  });

  group('a change dated before the install it replaces', () {
    test('is rejected', () async {
      await register();

      expect(
        () =>
            register(changedAt: installedAt.subtract(const Duration(hours: 1))),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('leaves the database exactly as it was', () async {
      final CycleTransition first = await register();

      await expectLater(
        register(changedAt: installedAt.subtract(const Duration(hours: 1))),
        throwsA(isA<ValidationFailure>()),
      );

      // The whole point of the transaction: a rejected change must not close
      // the cycle the user is still wearing.
      final List<ConsumableInstance> all = await allInstances();
      expect(all, hasLength(1));
      expect(all.single.id, first.opened.id);
      expect(all.single.status, ConsumableStatus.active);
      expect(await h.db.select(h.db.changeEvents).get(), hasLength(1));
    });
  });

  test('carries the site and device forward across a routine change', () async {
    final BodySite site = await h.bodySites.create(
      userProfileId: profile.id,
      bodyRegion: BodyRegion.upperLeftAbdomen,
    );
    await h.instances.create(
      userProfileId: profile.id,
      consumableTypeId: sensor.id,
      installedAt: installedAt.toUtc(),
      bodySiteId: site.id,
    );

    final CycleTransition transition = await register(
      changedAt: installedAt.add(tenDays),
    );

    expect(transition.opened.bodySiteId, site.id);
    expect(transition.event.previousBodySiteId, site.id);
    expect(transition.event.newBodySiteId, site.id);
  });
}
