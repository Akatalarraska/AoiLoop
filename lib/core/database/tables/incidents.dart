import 'package:drift/drift.dart';

import '../../../shared/models/change_enums.dart';
import 'consumable_instances.dart';
import 'table_mixins.dart';
import 'user_profiles.dart';

/// Something that went wrong with a specific consumable.
///
/// Recorded so the user can see patterns in their own history and so they have
/// the facts a manufacturer asks for. BlauLoop does not interpret incidents,
/// does not tell the user what caused one, and does not suggest what to do
/// about it.
@TableIndex(
  name: 'idx_incidents_profile_occurred_at',
  columns: {#userProfileId, #occurredAt},
)
@TableIndex(name: 'idx_incidents_instance', columns: {#consumableInstanceId})
class Incidents extends Table with UuidPrimaryKey {
  TextColumn get userProfileId =>
      text().references(UserProfiles, #id, onDelete: KeyAction.cascade)();

  TextColumn get consumableInstanceId => text().references(
    ConsumableInstances,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// When it happened. UTC. Often earlier than when it was logged.
  DateTimeColumn get occurredAt => dateTime()();

  TextColumn get type => textEnum<IncidentType>()();

  TextColumn get notes => text().nullable().withLength(max: 2000)();

  /// Relative path within the app's private storage — a photo of a lifted
  /// adhesive or a bent cannula, usually for a replacement claim.
  ///
  /// Relative rather than absolute because iOS changes the application
  /// container path between installs and updates, which would break every
  /// stored absolute path.
  TextColumn get photoPath => text().nullable().withLength(max: 500)();

  DateTimeColumn get createdAt => dateTime()();
}
