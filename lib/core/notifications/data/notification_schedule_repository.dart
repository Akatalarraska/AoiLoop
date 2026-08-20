import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/app_database.dart';
import '../../database/database_providers.dart';
import '../../database/id_generator.dart';
import '../../database/repository.dart';
import '../../utils/clock.dart';

/// AoiLoop's own ledger of the local notifications it asked the OS to deliver.
///
/// The app does not trust the platform to remember. iOS caps a single app at
/// 64 pending notifications and silently discards the rest; Android may defer
/// exact alarms; both lose everything when notification permission is revoked
/// or the app is reinstalled. Keeping the intended schedule here means it can
/// be reconciled and rebuilt, and that a user whose reminders quietly stopped
/// can be told rather than left guessing.
///
/// This is the data layer only. Talking to the platform is Phase 5.
class NotificationScheduleRepository extends Repository {
  const NotificationScheduleRepository({
    required super.db,
    required super.clock,
    required super.ids,
  });

  /// The platform's own pending-notification budget.
  ///
  /// iOS is the binding constraint at 64. AoiLoop applies the same cap on both
  /// platforms so behaviour does not diverge, and so the scheduler always has
  /// to decide what matters most rather than discovering the limit at run time
  /// on one platform only.
  static const int platformPendingLimit = 64;

  Future<NotificationSchedule> create({
    required String userProfileId,
    required NotificationKind type,
    required DateTime scheduledAt,
    required int platformNotificationId,
    String? consumableInstanceId,
    NotificationStatus status = NotificationStatus.pending,
  }) {
    return db
        .into(db.notificationSchedules)
        .insertReturning(
          NotificationSchedulesCompanion.insert(
            id: newId,
            userProfileId: userProfileId,
            type: type,
            scheduledAt: scheduledAt.toUtc(),
            status: status,
            platformNotificationId: platformNotificationId,
            consumableInstanceId: Value<String?>(consumableInstanceId),
            createdAt: now,
          ),
        );
  }

  /// Everything still expected to fire, soonest first.
  Future<List<NotificationSchedule>> findPending(String userProfileId) {
    return (db.select(db.notificationSchedules)
          ..where(
            ($NotificationSchedulesTable t) =>
                t.userProfileId.equals(userProfileId) &
                t.status.equalsValue(NotificationStatus.pending),
          )
          ..orderBy(<OrderClauseGenerator<$NotificationSchedulesTable>>[
            ($NotificationSchedulesTable t) => OrderingTerm.asc(t.scheduledAt),
          ]))
        .get();
  }

  Future<List<NotificationSchedule>> findPendingForInstance(
    String consumableInstanceId,
  ) {
    return (db.select(db.notificationSchedules)..where(
          ($NotificationSchedulesTable t) =>
              t.consumableInstanceId.equals(consumableInstanceId) &
              t.status.equalsValue(NotificationStatus.pending),
        ))
        .get();
  }

  /// Withdraws every pending reminder for one instance and reports the
  /// platform ids that now need cancelling with the OS.
  ///
  /// Called whenever a change is logged: the reminders for the instance that
  /// just came off are no longer true, and firing them would tell the user to
  /// do something they have already done.
  Future<List<int>> cancelForInstance(String consumableInstanceId) async {
    return db.transaction(() async {
      final List<NotificationSchedule> pending = await findPendingForInstance(
        consumableInstanceId,
      );
      if (pending.isEmpty) {
        return const <int>[];
      }
      await (db.update(db.notificationSchedules)..where(
            ($NotificationSchedulesTable t) =>
                t.consumableInstanceId.equals(consumableInstanceId) &
                t.status.equalsValue(NotificationStatus.pending),
          ))
          .write(
            const NotificationSchedulesCompanion(
              status: Value<NotificationStatus>(NotificationStatus.cancelled),
            ),
          );
      return pending
          .map((NotificationSchedule s) => s.platformNotificationId)
          .toList(growable: false);
    });
  }

  Future<void> markStatus(String id, NotificationStatus status) async {
    await (db.update(
      db.notificationSchedules,
    )..where(($NotificationSchedulesTable t) => t.id.equals(id))).write(
      NotificationSchedulesCompanion(status: Value<NotificationStatus>(status)),
    );
  }

  /// Marks everything that was due before [cutoff] as delivered.
  ///
  /// The OS gives no reliable delivery callback, so this is a best-effort
  /// reconciliation run at startup: anything pending whose moment has passed
  /// either fired or was dropped, and either way it is no longer pending.
  Future<int> reconcilePastDue(String userProfileId, DateTime cutoff) {
    return (db.update(db.notificationSchedules)..where(
          ($NotificationSchedulesTable t) =>
              t.userProfileId.equals(userProfileId) &
              t.status.equalsValue(NotificationStatus.pending) &
              t.scheduledAt.isSmallerThanValue(cutoff.toUtc()),
        ))
        .write(
          const NotificationSchedulesCompanion(
            status: Value<NotificationStatus>(NotificationStatus.delivered),
          ),
        );
  }

  /// How many notifications are currently claiming a slot in the platform's
  /// budget. Compare against [platformPendingLimit] before scheduling more.
  Future<int> countPending(String userProfileId) async {
    final Expression<int> total = db.notificationSchedules.id.count();
    final TypedResult row =
        await (db.selectOnly(db.notificationSchedules)
              ..addColumns(<Expression<Object>>[total])
              ..where(
                db.notificationSchedules.userProfileId.equals(userProfileId) &
                    db.notificationSchedules.status.equalsValue(
                      NotificationStatus.pending,
                    ),
              ))
            .getSingle();
    return row.read(total) ?? 0;
  }

  /// Removes resolved rows older than [before], so the ledger does not grow
  /// without bound. Pending rows are never touched.
  Future<int> purgeResolvedBefore(DateTime before) {
    return (db.delete(db.notificationSchedules)..where(
          ($NotificationSchedulesTable t) =>
              t.status.equalsValue(NotificationStatus.pending).not() &
              t.scheduledAt.isSmallerThanValue(before.toUtc()),
        ))
        .go();
  }
}

final Provider<NotificationScheduleRepository>
notificationScheduleRepositoryProvider =
    Provider<NotificationScheduleRepository>((Ref ref) {
      return NotificationScheduleRepository(
        db: ref.watch(appDatabaseProvider),
        clock: ref.watch(clockProvider),
        ids: ref.watch(idGeneratorProvider),
      );
    });
