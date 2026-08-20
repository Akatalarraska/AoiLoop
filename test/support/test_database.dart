import 'package:blauloop/core/database/app_database.dart';
import 'package:blauloop/core/database/id_generator.dart';
import 'package:blauloop/core/notifications/data/notification_schedule_repository.dart';
import 'package:blauloop/core/utils/clock.dart';
import 'package:blauloop/features/body_map/data/body_site_repository.dart';
import 'package:blauloop/features/body_map/data/site_usage_repository.dart';
import 'package:blauloop/features/changes/data/change_event_repository.dart';
import 'package:blauloop/features/consumables/data/consumable_instance_repository.dart';
import 'package:blauloop/features/consumables/data/consumable_type_repository.dart';
import 'package:blauloop/features/devices/data/device_repository.dart';
import 'package:blauloop/features/incidents/data/incident_repository.dart';
import 'package:blauloop/features/inventory/data/inventory_repository.dart';
import 'package:blauloop/features/settings/data/user_profile_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// A throwaway database with every repository wired to a pinned clock and
/// deterministic ids.
///
/// Data-layer tests are only worth writing if they can assert on exact
/// timestamps and readable ids, so nothing here is left to chance: the clock
/// does not move unless a test moves it, and ids come out as
/// `test-000…0001`.
class TestHarness {
  TestHarness._(this.db, this.clock, this.ids);

  /// Builds a harness and registers its teardown with the active test.
  factory TestHarness.create({DateTime? now}) {
    // Drift warns when several databases exist at once. Each harness gets its
    // own isolated in-memory store, so there is no shared executor to race
    // over and the warning would only bury real failures.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

    final FixedClock clock = FixedClock(now ?? DateTime.utc(2026, 8, 17, 9));
    final AppDatabase db = AppDatabase(executor: NativeDatabase.memory());
    final TestHarness harness = TestHarness._(
      db,
      clock,
      SequentialIdGenerator(),
    );
    addTearDown(db.close);
    return harness;
  }

  final AppDatabase db;
  final FixedClock clock;
  final IdGenerator ids;

  UserProfileRepository get profiles =>
      UserProfileRepository(db: db, clock: clock, ids: ids);
  DeviceRepository get devices =>
      DeviceRepository(db: db, clock: clock, ids: ids);
  ConsumableTypeRepository get types =>
      ConsumableTypeRepository(db: db, clock: clock, ids: ids);
  ConsumableInstanceRepository get instances =>
      ConsumableInstanceRepository(db: db, clock: clock, ids: ids);
  ChangeEventRepository get changes =>
      ChangeEventRepository(db: db, clock: clock, ids: ids);
  IncidentRepository get incidents =>
      IncidentRepository(db: db, clock: clock, ids: ids);
  BodySiteRepository get bodySites =>
      BodySiteRepository(db: db, clock: clock, ids: ids);
  SiteUsageRepository get siteUsages =>
      SiteUsageRepository(db: db, clock: clock, ids: ids);
  InventoryRepository get inventory =>
      InventoryRepository(db: db, clock: clock, ids: ids);
  NotificationScheduleRepository get notifications =>
      NotificationScheduleRepository(db: db, clock: clock, ids: ids);

  /// Every consumable type, as a plain future.
  ///
  /// Widget tests run on a fake clock, and listening to a Drift *stream*
  /// inside one leaves work scheduled that the test framework never gets to
  /// run — the test then hangs at teardown rather than failing usefully.
  /// Reading with a future sidesteps that entirely, and a test that only wants
  /// to know what was written has no use for a stream anyway.
  Future<List<ConsumableType>> allConsumableTypes() =>
      db.select(db.consumableTypes).get();

  Future<List<Device>> allDevices() => db.select(db.devices).get();

  /// A profile with sensible defaults, for tests that need one but do not care
  /// about its details.
  Future<UserProfile> seedProfile({
    String displayName = 'Test',
    String timezone = 'Europe/Madrid',
    String languageCode = 'es',
    TreatmentType treatmentType = TreatmentType.pumpAndCgm,
    int? preferredChangeMinuteOfDay,
  }) {
    return profiles.create(
      displayName: displayName,
      timezone: timezone,
      languageCode: languageCode,
      glucoseUnit: GlucoseUnit.mgPerDl,
      treatmentType: treatmentType,
      preferredChangeMinuteOfDay: preferredChangeMinuteOfDay,
    );
  }

  /// A cyclic consumable type. Defaults to a ten-day CGM sensor.
  Future<ConsumableType> seedType({
    String name = 'CGM sensor',
    ConsumableCategory category = ConsumableCategory.cgmSensor,
    Duration? defaultDuration = const Duration(days: 10),
    bool tracksCycle = true,
    bool tracksInventory = true,
  }) {
    return types.create(
      name: name,
      category: category,
      defaultDuration: defaultDuration,
      tracksCycle: tracksCycle,
      tracksInventory: tracksInventory,
    );
  }
}
