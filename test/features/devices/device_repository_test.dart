import 'package:aoiloop/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  late TestHarness h;
  late UserProfile profile;

  setUp(() async {
    h = TestHarness.create(now: DateTime.utc(2026, 8, 17, 9));
    profile = await h.seedProfile();
  });

  Future<Device> seedPump({String model = 'P1'}) {
    return h.devices.create(
      userProfileId: profile.id,
      type: DeviceType.pump,
      manufacturer: 'Acme',
      model: model,
    );
  }

  test('creates a device with only the required fields', () async {
    final Device device = await seedPump();

    expect(device.manufacturer, 'Acme');
    expect(device.isActive, isTrue);
    expect(device.serialNumber, isNull);
    expect(device.startedAt, isNull);
    expect(device.warrantyUntil, isNull);
  });

  test('never blocks tracking on a serial number nobody can find', () async {
    // Optional on purpose: a user who cannot find the sticker should still be
    // able to record the device.
    final Device device = await seedPump();

    expect(device.serialNumber, isNull);
  });

  test('normalises supplied dates to UTC', () async {
    final Device device = await h.devices.create(
      userProfileId: profile.id,
      type: DeviceType.transmitter,
      manufacturer: 'Acme',
      model: 'T1',
      startedAt: DateTime(2026, 6, 1, 10),
      warrantyUntil: DateTime(2027, 6, 1, 10),
    );

    expect(device.startedAt!.isUtc, isTrue);
    expect(device.warrantyUntil!.isUtc, isTrue);
  });

  test('watchActive excludes retired devices', () async {
    final Device old = await seedPump(model: 'Old');
    await seedPump(model: 'New');

    await h.devices.deactivate(old.id);

    final List<Device> active = await h.devices.watchActive(profile.id).first;
    expect(active.map((Device d) => d.model), <String>['New']);
  });

  test('deactivating keeps the row, so history stays readable', () async {
    final Device device = await seedPump();

    await h.devices.deactivate(device.id);

    final Device? reloaded = await h.devices.findById(device.id);
    expect(reloaded, isNotNull);
    expect(reloaded!.isActive, isFalse);
    expect(await h.devices.watchAll(profile.id).first, hasLength(1));
  });

  test('findByType returns only active devices of that type', () async {
    await seedPump();
    await h.devices.create(
      userProfileId: profile.id,
      type: DeviceType.cgm,
      manufacturer: 'Acme',
      model: 'C1',
    );
    final Device retired = await h.devices.create(
      userProfileId: profile.id,
      type: DeviceType.pump,
      manufacturer: 'Acme',
      model: 'Old pump',
    );
    await h.devices.deactivate(retired.id);

    final List<Device> pumps = await h.devices.findByType(
      profile.id,
      DeviceType.pump,
    );

    expect(pumps, hasLength(1));
    expect(pumps.single.model, 'P1');
  });

  test('devices belong to one profile only', () async {
    final UserProfile other = await h.seedProfile(displayName: 'Lucas');
    await seedPump();

    expect(await h.devices.watchActive(other.id).first, isEmpty);
  });

  group('warranty', () {
    test('finds devices whose warranty ends on or before the cutoff', () async {
      await h.devices.create(
        userProfileId: profile.id,
        type: DeviceType.pump,
        manufacturer: 'Acme',
        model: 'Expiring',
        warrantyUntil: DateTime.utc(2026, 9, 1),
      );
      await h.devices.create(
        userProfileId: profile.id,
        type: DeviceType.pump,
        manufacturer: 'Acme',
        model: 'Later',
        warrantyUntil: DateTime.utc(2028, 1, 1),
      );

      final List<Device> expiring = await h.devices.findWarrantyExpiringBefore(
        profile.id,
        DateTime.utc(2026, 10, 1),
      );

      expect(expiring.map((Device d) => d.model), <String>['Expiring']);
    });

    test('includes a warranty ending exactly on the cutoff', () async {
      // Inclusive boundary: a warranty that runs out at the cutoff has run out.
      await h.devices.create(
        userProfileId: profile.id,
        type: DeviceType.pump,
        manufacturer: 'Acme',
        model: 'Exactly',
        warrantyUntil: DateTime.utc(2026, 10, 1),
      );

      final List<Device> expiring = await h.devices.findWarrantyExpiringBefore(
        profile.id,
        DateTime.utc(2026, 10, 1),
      );

      expect(expiring, hasLength(1));
    });

    test('ignores devices with no warranty recorded', () async {
      await seedPump();

      final List<Device> expiring = await h.devices.findWarrantyExpiringBefore(
        profile.id,
        DateTime.utc(2030),
      );

      expect(expiring, isEmpty);
    });

    test('ignores retired devices', () async {
      final Device retired = await h.devices.create(
        userProfileId: profile.id,
        type: DeviceType.pump,
        manufacturer: 'Acme',
        model: 'Retired',
        warrantyUntil: DateTime.utc(2026, 9, 1),
      );
      await h.devices.deactivate(retired.id);

      final List<Device> expiring = await h.devices.findWarrantyExpiringBefore(
        profile.id,
        DateTime.utc(2030),
      );

      expect(expiring, isEmpty);
    });

    test('orders soonest first', () async {
      await h.devices.create(
        userProfileId: profile.id,
        type: DeviceType.pump,
        manufacturer: 'Acme',
        model: 'Second',
        warrantyUntil: DateTime.utc(2026, 12, 1),
      );
      await h.devices.create(
        userProfileId: profile.id,
        type: DeviceType.pump,
        manufacturer: 'Acme',
        model: 'First',
        warrantyUntil: DateTime.utc(2026, 9, 1),
      );

      final List<Device> expiring = await h.devices.findWarrantyExpiringBefore(
        profile.id,
        DateTime.utc(2030),
      );

      expect(expiring.map((Device d) => d.model), <String>['First', 'Second']);
    });
  });
}
