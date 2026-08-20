import 'package:blauloop/features/onboarding/domain/consumable_preset.dart';
import 'package:blauloop/shared/models/consumable_enums.dart';
import 'package:blauloop/shared/models/profile_enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// The presets decide what a new user's dashboard looks like on day one, and
/// they are derived entirely from a single answer. These tests pin that
/// derivation: someone on injections must never be asked about reservoirs,
/// and a pod user must never be given an infusion set to change.
void main() {
  group('catalogue', () {
    test('every key has exactly one preset', () {
      for (final ConsumablePresetKey key in ConsumablePresetKey.values) {
        expect(
          ConsumablePresets.all.where(
            (ConsumablePreset preset) => preset.key == key,
          ),
          hasLength(1),
          reason: 'missing or duplicated preset for $key',
        );
      }
    });

    test('a preset has a countdown exactly when it has a lifetime', () {
      for (final ConsumablePreset preset in ConsumablePresets.all) {
        expect(
          preset.tracksCycle,
          preset.defaultDuration != null,
          reason: '${preset.key} disagrees with itself about its cycle',
        );
      }
    });

    test('worn items last a plausible number of days', () {
      expect(
        ConsumablePresets.cgmSensor.defaultDuration,
        const Duration(days: 10),
      );
      expect(
        ConsumablePresets.infusionSet.defaultDuration,
        const Duration(days: 3),
      );
      expect(ConsumablePresets.pod.defaultDuration, const Duration(days: 3));
      expect(
        ConsumablePresets.cgmTransmitter.defaultDuration,
        const Duration(days: 90),
      );
    });

    test('counted items have no lifetime', () {
      for (final ConsumablePreset preset in <ConsumablePreset>[
        ConsumablePresets.testStrip,
        ConsumablePresets.lancet,
        ConsumablePresets.ketoneStrip,
        ConsumablePresets.penNeedle,
        ConsumablePresets.glucagon,
      ]) {
        expect(preset.defaultDuration, isNull, reason: '${preset.key}');
        expect(preset.tracksInventory, isTrue, reason: '${preset.key}');
      }
    });
  });

  group('suggestions', () {
    test('a pump user is offered sets and reservoirs, never a pod', () {
      final List<ConsumablePresetKey> keys = _keysFor(TreatmentType.pumpAndCgm);

      expect(keys, contains(ConsumablePresetKey.infusionSet));
      expect(keys, contains(ConsumablePresetKey.reservoir));
      expect(keys, isNot(contains(ConsumablePresetKey.pod)));
      expect(keys, isNot(contains(ConsumablePresetKey.penNeedle)));
    });

    test('a pod user is offered a pod, never a set or a reservoir', () {
      final List<ConsumablePresetKey> keys = _keysFor(TreatmentType.podAndCgm);

      expect(keys, contains(ConsumablePresetKey.pod));
      expect(keys, isNot(contains(ConsumablePresetKey.infusionSet)));
      expect(keys, isNot(contains(ConsumablePresetKey.reservoir)));
    });

    test('someone without a CGM is not offered sensors', () {
      final List<ConsumablePresetKey> keys = _keysFor(
        TreatmentType.injectionsOnly,
      );

      expect(keys, isNot(contains(ConsumablePresetKey.cgmSensor)));
      expect(keys, isNot(contains(ConsumablePresetKey.cgmTransmitter)));
      expect(keys, contains(ConsumablePresetKey.penNeedle));
    });

    test('"something else" offers the whole catalogue', () {
      expect(
        _keysFor(TreatmentType.other),
        ConsumablePresets.all.map((ConsumablePreset p) => p.key),
      );
    });

    test('suggestions keep catalogue order, so the UI is stable', () {
      for (final TreatmentType treatment in TreatmentType.values) {
        final List<ConsumablePresetKey> keys = _keysFor(treatment);
        final List<ConsumablePresetKey> catalogueOrder = ConsumablePresets.all
            .map((ConsumablePreset preset) => preset.key)
            .where(keys.contains)
            .toList();
        expect(keys, catalogueOrder, reason: '$treatment');
      }
    });
  });

  group('default selection', () {
    test('only ticks what the treatment certainly involves', () {
      expect(
        ConsumablePresets.defaultSelectionFor(TreatmentType.pumpAndCgm),
        <ConsumablePresetKey>{
          ConsumablePresetKey.cgmSensor,
          ConsumablePresetKey.infusionSet,
          ConsumablePresetKey.reservoir,
          ConsumablePresetKey.testStrip,
          ConsumablePresetKey.lancet,
        },
      );
    });

    test('never ticks something that was not even offered', () {
      for (final TreatmentType treatment in TreatmentType.values) {
        expect(
          ConsumablePresets.defaultSelectionFor(treatment),
          everyElement(isIn(_keysFor(treatment))),
          reason: '$treatment ticks a preset it does not show',
        );
      }
    });

    test('leaves the optional extras unticked', () {
      for (final TreatmentType treatment in TreatmentType.values) {
        final Set<ConsumablePresetKey> selected =
            ConsumablePresets.defaultSelectionFor(treatment);

        expect(selected, isNot(contains(ConsumablePresetKey.cgmTransmitter)));
        expect(selected, isNot(contains(ConsumablePresetKey.insulin)));
        expect(selected, isNot(contains(ConsumablePresetKey.glucagon)));
        expect(selected, isNot(contains(ConsumablePresetKey.ketoneStrip)));
      }
    });

    test('a pod user starts with a pod countdown', () {
      expect(
        ConsumablePresets.defaultSelectionFor(TreatmentType.podOnly),
        contains(ConsumablePresetKey.pod),
      );
    });

    test('every treatment ends up tracking at least one thing', () {
      for (final TreatmentType treatment in TreatmentType.values) {
        expect(
          ConsumablePresets.defaultSelectionFor(treatment),
          isNotEmpty,
          reason: '$treatment would land on an empty dashboard',
        );
      }
    });
  });

  test('categories map onto the domain vocabulary', () {
    expect(ConsumablePresets.pod.category, ConsumableCategory.pod);
    expect(
      ConsumablePresets.cgmTransmitter.category,
      ConsumableCategory.transmitter,
    );
    expect(ConsumablePresets.penNeedle.category, ConsumableCategory.needle);
  });
}

List<ConsumablePresetKey> _keysFor(TreatmentType treatment) {
  return ConsumablePresets.suggestedFor(treatment)
      .map((ConsumablePreset preset) => preset.key)
      .toList();
}
