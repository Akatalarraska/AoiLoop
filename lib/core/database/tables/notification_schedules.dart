import 'package:drift/drift.dart';

import '../../../shared/models/notification_enums.dart';
import 'consumable_instances.dart';
import 'table_mixins.dart';
import 'user_profiles.dart';

/// A local notification DT1FLOW asked the operating system to deliver.
///
/// The app keeps its own ledger rather than trusting the OS, because the two
/// diverge in practice. iOS caps an app at 64 pending notifications and
/// silently drops the rest — with five offsets per consumable that limit is
/// closer than it looks. Android may defer exact alarms, and both platforms
/// lose everything on reinstall or when notification permission is revoked.
///
/// Having the intended schedule in the database means it can be reconciled and
/// rebuilt. Without it, a user whose reminders quietly stopped would have no
/// way to know.
@TableIndex(
  name: 'idx_notification_schedules_status_time',
  columns: {#status, #scheduledAt},
)
@TableIndex(
  name: 'idx_notification_schedules_instance',
  columns: {#consumableInstanceId},
)
class NotificationSchedules extends Table with UuidPrimaryKey {
  TextColumn get userProfileId =>
      text().references(UserProfiles, #id, onDelete: KeyAction.cascade)();

  /// The instance this reminder is about. Null for notifications that are not
  /// tied to one — a low-stock warning, for example.
  TextColumn get consumableInstanceId => text().nullable().references(
    ConsumableInstances,
    #id,
    onDelete: KeyAction.cascade,
  )();

  TextColumn get type => textEnum<NotificationKind>()();

  /// When it should fire. UTC.
  DateTimeColumn get scheduledAt => dateTime()();

  TextColumn get status => textEnum<NotificationStatus>()();

  /// The integer id the platform plugin needs in order to cancel this later.
  ///
  /// Not the primary key: the app's identity for a notification is a UUID, and
  /// this is the handle the OS understands. Keeping them separate means an id
  /// space collision on the platform side cannot corrupt the ledger.
  IntColumn get platformNotificationId => integer()();

  DateTimeColumn get createdAt => dateTime()();
}
