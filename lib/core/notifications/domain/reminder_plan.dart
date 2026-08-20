import 'package:flutter/foundation.dart';

import '../../../shared/models/notification_enums.dart';
import '../../database/converters/reminder_offsets_converter.dart';

/// One reminder AoiLoop intends the operating system to deliver.
@immutable
class ReminderMoment {
  const ReminderMoment({
    required this.kind,
    required this.at,
    required this.leadTime,
  });

  final NotificationKind kind;

  /// When it should fire. UTC.
  final DateTime at;

  /// How far ahead of the deadline this one lands. Zero for the reminder on
  /// the due date itself.
  final Duration leadTime;

  @override
  bool operator ==(Object other) =>
      other is ReminderMoment &&
      other.kind == kind &&
      other.at == at &&
      other.leadTime == leadTime;

  @override
  int get hashCode => Object.hash(kind, at, leadTime);

  @override
  String toString() => 'ReminderMoment($kind at $at, lead $leadTime)';
}

/// What should be scheduled for one cycle, worked out from its deadline.
///
/// Plain Dart, like the rest of AoiLoop's date arithmetic: no plugin, no
/// database, no clock of its own. The half of notifications that can actually
/// go wrong is *which moments* get chosen, and this is the half that can be
/// tested without a device.
///
/// It decides nothing about delivery. Whether the OS accepts a moment, and
/// what happens when it refuses, belongs to the gateway and the scheduler.
@immutable
class ReminderPlan {
  const ReminderPlan(this.moments);

  /// The reminders for a cycle due at [expectedChangeAt], evaluated at [now].
  ///
  /// Moments already in the past are dropped rather than scheduled. A
  /// notification dated behind the clock either never fires or fires the
  /// instant it is registered, and a reminder that arrives immediately after
  /// the user logs something is how an app teaches people to silence it.
  ///
  /// A null [expectedChangeAt] yields an empty plan: an item that is counted
  /// rather than timed has no deadline to warn about.
  factory ReminderPlan.forCycle({
    required DateTime? expectedChangeAt,
    required List<Duration> offsets,
    required DateTime now,
  }) {
    if (expectedChangeAt == null || offsets.isEmpty) {
      return const ReminderPlan(<ReminderMoment>[]);
    }

    final DateTime due = expectedChangeAt.toUtc();
    final DateTime cutoff = now.toUtc();

    // Normalised again rather than trusted. These arrive from a type's stored
    // column, which the converter already sorts and deduplicates — but the
    // plan is also built from offsets a caller assembled by hand, and two
    // reminders at the same instant are indistinguishable to the user and
    // spend two slots of a budget of 64.
    final List<Duration> leads = ReminderOffsetsConverter.normalize(offsets);

    final List<ReminderMoment> moments = <ReminderMoment>[];
    for (final Duration lead in leads) {
      final DateTime at = due.subtract(lead);
      if (!at.isAfter(cutoff)) {
        continue;
      }
      moments.add(
        ReminderMoment(
          kind: lead == Duration.zero
              ? NotificationKind.cycleDue
              : NotificationKind.cycleReminder,
          at: at,
          leadTime: lead,
        ),
      );
    }

    // Chronological, because that is the order the budget is spent in: when
    // there are more reminders than slots, the near future is what matters.
    moments.sort((ReminderMoment a, ReminderMoment b) => a.at.compareTo(b.at));
    return ReminderPlan(List<ReminderMoment>.unmodifiable(moments));
  }

  /// Every reminder to schedule, soonest first.
  final List<ReminderMoment> moments;

  bool get isEmpty => moments.isEmpty;

  int get length => moments.length;

  @override
  bool operator ==(Object other) =>
      other is ReminderPlan && listEquals(other.moments, moments);

  @override
  int get hashCode => Object.hashAll(moments);

  @override
  String toString() => 'ReminderPlan(${moments.length} moments)';
}
