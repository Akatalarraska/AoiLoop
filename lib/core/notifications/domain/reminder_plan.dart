import 'package:flutter/foundation.dart';

import '../../../shared/models/notification_enums.dart';
import '../../database/converters/reminder_offsets_converter.dart';

/// One reminder BlauLoop intends the operating system to deliver.
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
/// Plain Dart, like the rest of BlauLoop's date arithmetic: no plugin, no
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

  /// The reminders for stock expiring on [expiresOn], evaluated at [now].
  ///
  /// Two kinds, because they are two different sentences rather than the same
  /// one said twice. The warnings ahead of the date are something to plan a
  /// pharmacy trip around; the one on the date itself is something to act on —
  /// take it out of the drawer before it gets used by mistake.
  ///
  /// [expiresOn] is a calendar date, so every moment is placed at
  /// [reminderHourUtc] rather than at midnight. A notification that lands at
  /// 00:00 either wakes someone up or is buried under everything that arrived
  /// overnight, and neither reads as a warning.
  ///
  /// Moments already behind [now] are dropped, for the same reason
  /// [ReminderPlan.forCycle] drops them: a notification dated in the past
  /// either never fires or fires immediately.
  factory ReminderPlan.forExpiry({
    required DateTime? expiresOn,
    required List<Duration> leadTimes,
    required DateTime now,
  }) {
    if (expiresOn == null) {
      return const ReminderPlan(<ReminderMoment>[]);
    }

    final DateTime expiry = expiresOn.toUtc();
    final DateTime dueMoment = DateTime.utc(
      expiry.year,
      expiry.month,
      expiry.day,
      reminderHourUtc,
    );
    final DateTime cutoff = now.toUtc();

    final List<ReminderMoment> moments = <ReminderMoment>[];

    for (final Duration lead in ReminderOffsetsConverter.normalize(leadTimes)) {
      if (lead == Duration.zero) {
        continue;
      }
      final DateTime at = dueMoment.subtract(lead);
      if (!at.isAfter(cutoff)) {
        continue;
      }
      moments.add(
        ReminderMoment(
          kind: NotificationKind.expiringSoon,
          at: at,
          leadTime: lead,
        ),
      );
    }

    if (dueMoment.isAfter(cutoff)) {
      moments.add(
        ReminderMoment(
          kind: NotificationKind.expired,
          at: dueMoment,
          leadTime: Duration.zero,
        ),
      );
    }

    moments.sort((ReminderMoment a, ReminderMoment b) => a.at.compareTo(b.at));
    return ReminderPlan(List<ReminderMoment>.unmodifiable(moments));
  }

  /// The hour of the UTC day an expiry reminder lands on.
  ///
  /// Expiry is a calendar date rather than an instant, so something has to
  /// choose a time. Late morning UTC covers waking hours across the zones
  /// BlauLoop currently ships to without landing in the middle of anyone's
  /// night, and it is a constant rather than a preference because Phase 10 is
  /// where the settings screen decides which of these become adjustable.
  static const int reminderHourUtc = 9;

  /// How far ahead of an expiry date to warn, by default.
  ///
  /// Weeks rather than hours, because the action is a pharmacy trip and not a
  /// two-minute change. Thirty days is roughly a prescription cycle — long
  /// enough to do something about it — and seven is the reminder for anyone
  /// who read the first one and forgot.
  static const List<Duration> defaultExpiryLeadTimes = <Duration>[
    Duration(days: 30),
    Duration(days: 7),
  ];

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
