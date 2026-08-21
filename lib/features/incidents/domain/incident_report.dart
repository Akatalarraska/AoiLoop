import 'package:flutter/foundation.dart';

import '../../../shared/models/change_enums.dart';
import '../../../shared/models/consumable_enums.dart';

/// What the user did about a consumable that went wrong.
///
/// Not stored. It is the shape of the question the report sheet asks — *is it
/// still on you?* — and the instruction the engine acts on. What ends up in
/// the database is a closed instance, an open one, or neither, and those are
/// already readable without a column repeating them.
///
/// The three cases exist because all three happen. A sensor that reads badly
/// is often left on until the evening; a set that occluded comes off
/// immediately whether or not there is a spare in the house.
enum IncidentOutcome {
  /// Logged, but still in use. Nothing about the cycle changes.
  keptInUse,

  /// Taken off, with nothing put on in its place. The countdown stops and the
  /// consumable reads as inactive until something replaces it.
  removed,

  /// Taken off and replaced there and then. The common case.
  replaced,
}

extension IncidentOutcomeX on IncidentOutcome {
  /// Whether the instance the incident is about stops being in use.
  bool get closesCycle => this != IncidentOutcome.keptInUse;

  /// Whether a fresh instance is opened.
  bool get opensCycle => this == IncidentOutcome.replaced;
}

/// Every [IncidentType], with the ones that plausibly happen to [category]
/// first.
///
/// Ordered, never filtered. A CGM user has no use for *bent cannula* at the
/// top of their list, but a list that hides it is a list that fails the person
/// whose product does something the app did not anticipate — the same reason
/// every catalogue picker in BlauLoop also accepts a name typed by hand. So
/// the likely answers come first and the rest stay reachable underneath.
///
/// [IncidentType.other] is pinned last in both halves. It is the answer for
/// when nothing else fits, and an escape hatch offered before the real options
/// is one people take by mistake.
List<IncidentType> incidentTypesFor(ConsumableCategory category) {
  final Set<IncidentType> likely = _likelyFor(category);

  final List<IncidentType> ordered = <IncidentType>[
    for (final IncidentType type in IncidentType.values)
      if (type != IncidentType.other && likely.contains(type)) type,
    for (final IncidentType type in IncidentType.values)
      if (type != IncidentType.other && !likely.contains(type)) type,
    IncidentType.other,
  ];

  return List<IncidentType>.unmodifiable(ordered);
}

/// The failures that belong to a category's own hardware.
///
/// Site reactions — pain, bleeding, irritation — are in every set that touches
/// the body, because the skin does not care which product is on it.
Set<IncidentType> _likelyFor(ConsumableCategory category) {
  const Set<IncidentType> worn = <IncidentType>{
    IncidentType.detached,
    IncidentType.adhesiveFailure,
    IncidentType.pain,
    IncidentType.bleeding,
    IncidentType.irritation,
  };
  const Set<IncidentType> delivery = <IncidentType>{
    IncidentType.bentCannula,
    IncidentType.occlusion,
    IncidentType.noFlow,
    IncidentType.leak,
  };

  return switch (category) {
    ConsumableCategory.cgmSensor => <IncidentType>{
      ...worn,
      IncidentType.inaccurateReadings,
      IncidentType.signalLoss,
      IncidentType.deviceError,
    },
    ConsumableCategory.transmitter => <IncidentType>{
      IncidentType.signalLoss,
      IncidentType.deviceError,
      IncidentType.detached,
    },
    ConsumableCategory.infusionSet ||
    ConsumableCategory.cannula => <IncidentType>{...worn, ...delivery},
    ConsumableCategory.tubing => <IncidentType>{
      IncidentType.occlusion,
      IncidentType.noFlow,
      IncidentType.leak,
    },
    ConsumableCategory.pod => <IncidentType>{
      ...worn,
      ...delivery,
      IncidentType.podFailure,
      IncidentType.deviceError,
    },
    ConsumableCategory.reservoir => <IncidentType>{
      IncidentType.occlusion,
      IncidentType.noFlow,
      IncidentType.leak,
      IncidentType.pumpFailure,
    },
    ConsumableCategory.insulin => <IncidentType>{
      IncidentType.noFlow,
      IncidentType.leak,
    },
    ConsumableCategory.adhesive => worn,
    ConsumableCategory.needle => <IncidentType>{
      IncidentType.bentCannula,
      IncidentType.leak,
      IncidentType.pain,
      IncidentType.bleeding,
    },
    ConsumableCategory.battery => <IncidentType>{
      IncidentType.deviceError,
      IncidentType.pumpFailure,
    },
    // Nothing specific to say. The full list in declaration order is a better
    // answer than a guess dressed up as one.
    ConsumableCategory.testStrip ||
    ConsumableCategory.ketoneStrip ||
    ConsumableCategory.lancet ||
    ConsumableCategory.glucagon ||
    ConsumableCategory.custom => const <IncidentType>{},
  };
}

/// One report of something going wrong, as the user described it.
///
/// A value rather than a pile of parameters, so the rules about what a report
/// needs are testable without a database — and so the sheet and the engine
/// cannot disagree about what was entered.
///
/// BlauLoop records this and draws no conclusions from it. Nothing here is
/// interpreted, scored, or turned into advice.
@immutable
class IncidentReport {
  const IncidentReport({
    required this.type,
    required this.occurredAt,
    required this.outcome,
    this.notes,
  });

  final IncidentType type;

  /// When it went wrong, which is often earlier than when it is being logged.
  final DateTime occurredAt;

  final IncidentOutcome outcome;

  final String? notes;

  /// The report with a blank note normalised away.
  ///
  /// A text field the user tapped into and left is an empty string, not null,
  /// and storing `''` would leave a row claiming a note that reads as blank
  /// forever after.
  IncidentReport trimmed() {
    return IncidentReport(
      type: type,
      occurredAt: occurredAt,
      outcome: outcome,
      notes: _clean(notes),
    );
  }

  IncidentReport copyWith({
    IncidentType? type,
    DateTime? occurredAt,
    IncidentOutcome? outcome,
    String? notes,
  }) {
    return IncidentReport(
      type: type ?? this.type,
      occurredAt: occurredAt ?? this.occurredAt,
      outcome: outcome ?? this.outcome,
      notes: notes ?? this.notes,
    );
  }

  static String? _clean(String? value) {
    if (value == null) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  bool operator ==(Object other) =>
      other is IncidentReport &&
      other.type == type &&
      other.occurredAt == occurredAt &&
      other.outcome == outcome &&
      other.notes == notes;

  @override
  int get hashCode => Object.hash(type, occurredAt, outcome, notes);

  @override
  String toString() =>
      'IncidentReport(type: $type, occurredAt: $occurredAt, '
      'outcome: $outcome)';
}
