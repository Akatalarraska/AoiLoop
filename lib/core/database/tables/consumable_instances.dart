import 'package:drift/drift.dart';

import '../../../shared/models/consumable_enums.dart';
import 'body_sites.dart';
import 'consumable_types.dart';
import 'devices.dart';
import 'table_mixins.dart';
import 'user_profiles.dart';

/// One specific consumable that was actually used.
///
/// This is the central table of the app. Every countdown on the dashboard is
/// a row here with `status = active`, and every entry in history is one that
/// has been closed.
///
/// The invariant that matters: **at most one active instance per consumable
/// type per profile**. It is enforced by a partial unique index below rather
/// than by application code, because it must hold even if two writes race —
/// a caregiver logging a change while a reminder-driven flow is open.
@TableIndex(
  name: 'idx_consumable_instances_profile_status',
  columns: {#userProfileId, #status},
)
@TableIndex(
  name: 'idx_consumable_instances_expected_change',
  columns: {#expectedChangeAt},
)
@TableIndex(name: 'idx_consumable_instances_type', columns: {#consumableTypeId})
// Declared as SQL because it is a *partial* index, which the column-list form
// cannot express. drift_dev parses and validates this statement at build time,
// and it becomes part of the schema, so it is created by migrations like any
// other index rather than being applied by hand afterwards.
@TableIndex.sql('''
  CREATE UNIQUE INDEX idx_one_active_instance_per_type
  ON consumable_instances (user_profile_id, consumable_type_id)
  WHERE status = 'active';
''')
class ConsumableInstances extends Table with UuidPrimaryKey, RowTimestamps {
  TextColumn get userProfileId =>
      text().references(UserProfiles, #id, onDelete: KeyAction.cascade)();

  /// Restricted rather than cascading: deleting a type that has history would
  /// silently erase changes the user made. Types are deactivated instead.
  TextColumn get consumableTypeId =>
      text().references(ConsumableTypes, #id, onDelete: KeyAction.restrict)();

  /// The device this belongs to, when that is meaningful — a reservoir
  /// belongs to a pump, a sensor to a transmitter. Null for standalone items.
  TextColumn get deviceId =>
      text().nullable().references(Devices, #id, onDelete: KeyAction.setNull)();

  /// When it went on or in. UTC.
  DateTimeColumn get installedAt => dateTime()();

  /// When it is expected to be changed. UTC. Null for items with no cycle.
  ///
  /// Computed by the cycle engine from [installedAt], the type's duration and
  /// the profile's preferred change time — then **stored**, not recomputed on
  /// read. If the user later edits the duration, past instances must keep the
  /// deadline they actually had.
  DateTimeColumn get expectedChangeAt => dateTime().nullable()();

  /// When it came off. UTC. Null while active.
  DateTimeColumn get removedAt => dateTime().nullable()();

  TextColumn get status => textEnum<ConsumableStatus>()();

  /// Needed for manufacturer replacement claims, and worth capturing at
  /// install time because the packaging is gone by the time it fails.
  TextColumn get lotNumber => text().nullable().withLength(max: 60)();
  TextColumn get serialNumber => text().nullable().withLength(max: 80)();

  /// Printed expiry of this unit, distinct from its wear cycle.
  DateTimeColumn get expirationDate => dateTime().nullable()();

  /// Where on the body it went. Null for items that are not worn.
  TextColumn get bodySiteId => text().nullable().references(
    BodySites,
    #id,
    onDelete: KeyAction.setNull,
  )();

  TextColumn get notes => text().nullable().withLength(max: 2000)();
}
