import 'package:drift/drift.dart';

import '../../../shared/models/device_enums.dart';
import 'table_mixins.dart';
import 'user_profiles.dart';

/// Durable hardware the user owns: pumps, receivers, transmitters, meters.
///
/// Distinct from a consumable, which is used up and replaced on a cycle. The
/// line is not always obvious — a CGM transmitter with a fixed 90-day life is
/// modelled as both, a `Device` for its identity and warranty and a
/// `ConsumableType` for its countdown. That is deliberate: they answer
/// different questions.
@TableIndex(name: 'idx_devices_profile', columns: {#userProfileId})
class Devices extends Table with UuidPrimaryKey, RowTimestamps {
  /// Deleting a profile removes its devices. There is nothing meaningful left
  /// to keep once the person is gone from the app.
  TextColumn get userProfileId =>
      text().references(UserProfiles, #id, onDelete: KeyAction.cascade)();

  TextColumn get type => textEnum<DeviceType>()();

  TextColumn get manufacturer => text().withLength(min: 1, max: 80)();

  TextColumn get model => text().withLength(min: 1, max: 80)();

  /// Needed for warranty and replacement claims. Optional, because a user
  /// should never be blocked from tracking a device they cannot find the
  /// serial for.
  TextColumn get serialNumber => text().nullable().withLength(max: 80)();

  /// When this device entered service. Drives the warranty countdown.
  DateTimeColumn get startedAt => dateTime().nullable()();

  DateTimeColumn get warrantyUntil => dateTime().nullable()();

  TextColumn get notes => text().nullable().withLength(max: 2000)();

  /// Retired devices are kept, not deleted, so history that references them
  /// stays readable.
  BoolColumn get isActive =>
      boolean().withDefault(const Constant<bool>(true))();
}
