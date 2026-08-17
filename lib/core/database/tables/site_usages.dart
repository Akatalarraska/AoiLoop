import 'package:drift/drift.dart';

import 'body_sites.dart';
import 'consumable_instances.dart';
import 'table_mixins.dart';

/// A period during which a body site was occupied.
///
/// Redundant with `ConsumableInstances.bodySiteId` at first glance, but it
/// answers a different question cheaply: "how long has this spot been resting"
/// is a scan of this table, without joining every instance ever recorded. It
/// also survives an instance being reassigned to a different site after a
/// correction.
@TableIndex(
  name: 'idx_site_usages_site_started',
  columns: {#bodySiteId, #startedAt},
)
@TableIndex(name: 'idx_site_usages_instance', columns: {#consumableInstanceId})
// A site can only be occupied by one thing at a time. An open usage is one
// with no end. Partial index, so it is declared as validated SQL.
@TableIndex.sql('''
  CREATE UNIQUE INDEX idx_one_open_usage_per_site
  ON site_usages (body_site_id)
  WHERE ended_at IS NULL;
''')
class SiteUsages extends Table with UuidPrimaryKey {
  TextColumn get bodySiteId =>
      text().references(BodySites, #id, onDelete: KeyAction.cascade)();

  TextColumn get consumableInstanceId => text().references(
    ConsumableInstances,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// UTC.
  DateTimeColumn get startedAt => dateTime()();

  /// UTC. Null while the site is still occupied.
  DateTimeColumn get endedAt => dateTime().nullable()();
}
