import 'package:blauloop/features/incidents/domain/incident_report.dart';
import 'package:blauloop/shared/models/change_enums.dart';
import 'package:blauloop/shared/models/consumable_enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pure Dart. No binding, no database, no clock — every instant here is
/// written out in full.
void main() {
  final DateTime occurredAt = DateTime.utc(2026, 8, 21, 14, 30);

  IncidentReport report({
    IncidentType type = IncidentType.occlusion,
    IncidentOutcome outcome = IncidentOutcome.replaced,
    String? notes,
  }) {
    return IncidentReport(
      type: type,
      occurredAt: occurredAt,
      outcome: outcome,
      notes: notes,
    );
  }

  group('IncidentOutcome', () {
    test('kept in use touches neither end of the cycle', () {
      expect(IncidentOutcome.keptInUse.closesCycle, isFalse);
      expect(IncidentOutcome.keptInUse.opensCycle, isFalse);
    });

    test('removed closes the cycle without opening one', () {
      expect(IncidentOutcome.removed.closesCycle, isTrue);
      expect(IncidentOutcome.removed.opensCycle, isFalse);
    });

    test('replaced closes one cycle and opens the next', () {
      expect(IncidentOutcome.replaced.closesCycle, isTrue);
      expect(IncidentOutcome.replaced.opensCycle, isTrue);
    });
  });

  group('IncidentReport', () {
    test('trimming turns a blank note into nothing at all', () {
      // Storing '' would leave a row claiming a note that reads as blank
      // forever after.
      expect(report(notes: '   ').trimmed().notes, isNull);
      expect(report(notes: '  lifted  ').trimmed().notes, 'lifted');
    });

    test('trimming leaves everything else alone', () {
      final IncidentReport trimmed = report(notes: 'lifted in the shower')
          .trimmed();

      expect(trimmed.type, IncidentType.occlusion);
      expect(trimmed.occurredAt, occurredAt);
      expect(trimmed.outcome, IncidentOutcome.replaced);
      expect(trimmed.notes, 'lifted in the shower');
    });

    test('is a value', () {
      expect(report(), report());
      expect(report().hashCode, report().hashCode);
      expect(report(), isNot(report(type: IncidentType.leak)));
      expect(report(), isNot(report(outcome: IncidentOutcome.removed)));
    });
  });

  group('incidentTypesFor', () {
    test('offers every failure, whatever the consumable is', () {
      // Ordered, never filtered. A list that hides the answer someone needs
      // fails the person whose product did something unexpected.
      for (final ConsumableCategory category in ConsumableCategory.values) {
        expect(
          incidentTypesFor(category).toSet(),
          IncidentType.values.toSet(),
          reason: 'every type should be reachable for $category',
        );
        expect(
          incidentTypesFor(category),
          hasLength(IncidentType.values.length),
          reason: 'no duplicates for $category',
        );
      }
    });

    test('leads a sensor with what happens to sensors', () {
      final List<IncidentType> types = incidentTypesFor(
        ConsumableCategory.cgmSensor,
      );

      expect(
        types.take(8),
        containsAll(<IncidentType>[
          IncidentType.detached,
          IncidentType.adhesiveFailure,
          IncidentType.inaccurateReadings,
          IncidentType.signalLoss,
        ]),
      );
    });

    test('leads an infusion set with delivery failures', () {
      final List<IncidentType> types = incidentTypesFor(
        ConsumableCategory.infusionSet,
      );

      expect(
        types.take(9),
        containsAll(<IncidentType>[
          IncidentType.bentCannula,
          IncidentType.occlusion,
          IncidentType.noFlow,
          IncidentType.leak,
        ]),
      );
    });

    test('a sensor does not lead with a bent cannula', () {
      final List<IncidentType> sensor = incidentTypesFor(
        ConsumableCategory.cgmSensor,
      );
      final List<IncidentType> set = incidentTypesFor(
        ConsumableCategory.infusionSet,
      );

      expect(
        sensor.indexOf(IncidentType.bentCannula),
        greaterThan(set.indexOf(IncidentType.bentCannula)),
      );
    });

    test('"something else" is always last', () {
      // The escape hatch offered before the real options is the one people
      // take by mistake.
      for (final ConsumableCategory category in ConsumableCategory.values) {
        expect(
          incidentTypesFor(category).last,
          IncidentType.other,
          reason: '$category should end with the catch-all',
        );
      }
    });

    test('a category with nothing specific to say keeps declaration order', () {
      expect(incidentTypesFor(ConsumableCategory.lancet), <IncidentType>[
        ...IncidentType.values.where(
          (IncidentType type) => type != IncidentType.other,
        ),
        IncidentType.other,
      ]);
    });

    test('the returned list cannot be edited by a caller', () {
      expect(
        () => incidentTypesFor(ConsumableCategory.pod).add(IncidentType.leak),
        throwsUnsupportedError,
      );
    });
  });
}
