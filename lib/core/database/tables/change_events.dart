import 'package:drift/drift.dart';

import '../../../shared/models/change_enums.dart';
import 'body_sites.dart';
import 'consumable_instances.dart';
import 'table_mixins.dart';
import 'user_profiles.dart';

/// The record that a change happened.
///
/// A change is a transition, so this table links the instance that ended to
/// the one that began, and the site that was vacated to the one now in use.
/// The dashboard reads `ConsumableInstances`; the history timeline reads this.
///
/// Rows here are append-only in spirit. A user who logged something wrongly
/// records a [ChangeType.manualCorrection] rather than editing the past, so
/// the history stays an honest account of what was known when.
@TableIndex(
  name: 'idx_change_events_profile_changed_at',
  columns: {#userProfileId, #changedAt},
)
@TableIndex(
  name: 'idx_change_events_instance',
  columns: {#consumableInstanceId},
)
class ChangeEvents extends Table with UuidPrimaryKey {
  TextColumn get userProfileId =>
      text().references(UserProfiles, #id, onDelete: KeyAction.cascade)();

  /// The instance that was put on.
  ///
  /// This table points at `ConsumableInstances` and `BodySites` twice each, so
  /// every one of those columns carries an explicit `@ReferenceName`. Without
  /// them Drift cannot tell the two links apart and silently drops the
  /// generated filters for both.
  @ReferenceName('changesInstalling')
  TextColumn get consumableInstanceId => text().references(
    ConsumableInstances,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// The instance that came off, when there was one. Null for the first ever
  /// change of a consumable type.
  @ReferenceName('changesRemoving')
  TextColumn get previousConsumableInstanceId => text().nullable().references(
    ConsumableInstances,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// When the change happened. UTC. May differ from `createdAt` when the user
  /// logs it after the fact — a 3 a.m. sensor swap entered at breakfast.
  DateTimeColumn get changedAt => dateTime()();

  TextColumn get type => textEnum<ChangeType>()();

  @ReferenceName('changesLeavingSite')
  TextColumn get previousBodySiteId => text().nullable().references(
    BodySites,
    #id,
    onDelete: KeyAction.setNull,
  )();

  @ReferenceName('changesArrivingAtSite')
  TextColumn get newBodySiteId => text().nullable().references(
    BodySites,
    #id,
    onDelete: KeyAction.setNull,
  )();

  TextColumn get notes => text().nullable().withLength(max: 2000)();

  /// When the row was written, as opposed to when the change happened.
  DateTimeColumn get createdAt => dateTime()();
}
