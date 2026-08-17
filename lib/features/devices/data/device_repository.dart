import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/database/id_generator.dart';
import '../../../core/database/repository.dart';
import '../../../core/utils/clock.dart';

/// Reads and writes the durable hardware a profile owns.
class DeviceRepository extends Repository {
  const DeviceRepository({
    required super.db,
    required super.clock,
    required super.ids,
  });

  /// Devices still in service, newest first.
  Stream<List<Device>> watchActive(String userProfileId) {
    return (db.select(db.devices)
          ..where(
            ($DevicesTable t) =>
                t.userProfileId.equals(userProfileId) & t.isActive.equals(true),
          )
          ..orderBy(<OrderClauseGenerator<$DevicesTable>>[
            ($DevicesTable t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch();
  }

  /// Every device, retired ones included, so history stays readable.
  Stream<List<Device>> watchAll(String userProfileId) {
    return (db.select(db.devices)
          ..where(($DevicesTable t) => t.userProfileId.equals(userProfileId))
          ..orderBy(<OrderClauseGenerator<$DevicesTable>>[
            ($DevicesTable t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch();
  }

  Future<List<Device>> findByType(String userProfileId, DeviceType type) {
    return (db.select(db.devices)..where(
          ($DevicesTable t) =>
              t.userProfileId.equals(userProfileId) &
              t.type.equalsValue(type) &
              t.isActive.equals(true),
        ))
        .get();
  }

  Future<Device?> findById(String id) {
    return (db.select(
      db.devices,
    )..where(($DevicesTable t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<Device> create({
    required String userProfileId,
    required DeviceType type,
    required String manufacturer,
    required String model,
    String? serialNumber,
    DateTime? startedAt,
    DateTime? warrantyUntil,
    String? notes,
  }) {
    final DateTime timestamp = now;
    return db
        .into(db.devices)
        .insertReturning(
          DevicesCompanion.insert(
            id: newId,
            userProfileId: userProfileId,
            type: type,
            manufacturer: manufacturer,
            model: model,
            serialNumber: Value<String?>(serialNumber),
            startedAt: Value<DateTime?>(startedAt?.toUtc()),
            warrantyUntil: Value<DateTime?>(warrantyUntil?.toUtc()),
            notes: Value<String?>(notes),
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
  }

  Future<void> update(String id, DevicesCompanion changes) async {
    await (db.update(db.devices)..where(($DevicesTable t) => t.id.equals(id)))
        .write(changes.copyWith(updatedAt: Value<DateTime>(now)));
  }

  /// Retires a device without deleting it.
  ///
  /// Deleting would orphan every consumable instance that referenced it, and
  /// the user would lose the record of which pump a set belonged to.
  Future<void> deactivate(String id) {
    return update(id, const DevicesCompanion(isActive: Value<bool>(false)));
  }

  /// Devices whose warranty ends on or before [cutoff].
  Future<List<Device>> findWarrantyExpiringBefore(
    String userProfileId,
    DateTime cutoff,
  ) {
    return (db.select(db.devices)
          ..where(
            ($DevicesTable t) =>
                t.userProfileId.equals(userProfileId) &
                t.isActive.equals(true) &
                t.warrantyUntil.isNotNull() &
                t.warrantyUntil.isSmallerOrEqualValue(cutoff.toUtc()),
          )
          ..orderBy(<OrderClauseGenerator<$DevicesTable>>[
            ($DevicesTable t) => OrderingTerm.asc(t.warrantyUntil),
          ]))
        .get();
  }
}

final Provider<DeviceRepository> deviceRepositoryProvider =
    Provider<DeviceRepository>((Ref ref) {
      return DeviceRepository(
        db: ref.watch(appDatabaseProvider),
        clock: ref.watch(clockProvider),
        ids: ref.watch(idGeneratorProvider),
      );
    });
