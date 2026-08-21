import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';

/// One thing that happened, as the history reads it.
///
/// Two sources, one list. A timeline built on `ChangeEvents` alone would be
/// missing entries rather than merely terse: an incident the user rode out —
/// an irritated site they kept the sensor on for — writes an `Incidents` row
/// and no change event at all, because nothing was installed. Reading only
/// changes would drop it silently, which is the worst way for a history to be
/// wrong.
///
/// Sealed, so every surface that renders an entry has to handle both kinds and
/// the analyzer says so.
@immutable
sealed class HistoryEntry {
  const HistoryEntry({required this.type});

  /// The consumable this is about. Resolved before the entry is built, because
  /// a timeline row that says "something was changed" is not a history.
  final ConsumableType type;

  /// When it happened, as opposed to when it was written down. UTC.
  ///
  /// A getter rather than a field: each kind already carries the timestamp on
  /// its own row, and copying it into the base would give an entry two records
  /// of one fact — which is how two copies of anything start to disagree.
  DateTime get occurredAt;

  /// Stable across rebuilds, so list state survives a reorder.
  String get id;

  /// The user's own words, if they left any.
  String? get notes;

  /// The calendar day this belongs to, in local time.
  ///
  /// Local because a day is a human unit: a change logged at 23:30 on Tuesday
  /// belongs to Tuesday for the person who made it, whatever UTC calls it.
  DateTime get localDay {
    final DateTime local = occurredAt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}

/// A consumable was replaced.
final class ChangeEntry extends HistoryEntry {
  const ChangeEntry({required this.event, required super.type});

  final ChangeEvent event;

  @override
  DateTime get occurredAt => event.changedAt;

  @override
  String get id => event.id;

  @override
  String? get notes => event.notes;

  ChangeType get reason => event.type;

  /// Whether this was the first of its kind, with nothing to replace.
  bool get isFirstEver => event.previousConsumableInstanceId == null;

  @override
  bool operator ==(Object other) =>
      other is ChangeEntry && other.event == event && other.type == type;

  @override
  int get hashCode => Object.hash(event, type);
}

/// Something went wrong.
final class IncidentEntry extends HistoryEntry {
  const IncidentEntry({required this.incident, required super.type});

  final Incident incident;

  @override
  DateTime get occurredAt => incident.occurredAt;

  @override
  String get id => incident.id;

  @override
  String? get notes => incident.notes;

  IncidentType get reason => incident.type;

  @override
  bool operator ==(Object other) =>
      other is IncidentEntry &&
      other.incident == incident &&
      other.type == type;

  @override
  int get hashCode => Object.hash(incident, type);
}
