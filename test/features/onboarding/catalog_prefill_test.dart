import 'package:blauloop/core/catalog/brand_model.dart';
import 'package:blauloop/features/onboarding/domain/consumable_preset.dart';
import 'package:blauloop/features/onboarding/domain/onboarding_draft.dart';
import 'package:flutter_test/flutter_test.dart';

/// Naming a product, and what that does to the duration and the label.
void main() {
  const OnboardingDraft empty = OnboardingDraft();
  const BrandModel g7 = BrandModel(
    brandId: 'dexcom',
    brand: 'Dexcom',
    model: 'G7',
  );

  group('picking a product from the catalogue', () {
    test('adopts the manufacturer duration', () {
      final OnboardingDraft draft = empty.withProduct(
        ConsumablePresetKey.cgmSensor,
        g7,
        catalogDuration: const Duration(days: 10),
      );

      expect(
        draft.durationFor(ConsumablePresetKey.cgmSensor),
        const Duration(days: 10),
      );
    });

    test('leaves the duration editable afterwards', () {
      // The number on the box is a starting point. What a particular person
      // actually gets out of a sensor is their own figure, and it has to win.
      final OnboardingDraft draft = empty
          .withProduct(
            ConsumablePresetKey.cgmSensor,
            g7,
            catalogDuration: const Duration(days: 10),
          )
          .withDuration(ConsumablePresetKey.cgmSensor, const Duration(days: 7));

      expect(
        draft.durationFor(ConsumablePresetKey.cgmSensor),
        const Duration(days: 7),
      );
    });

    test('names the consumable after the product', () {
      final OnboardingDraft draft = empty.withProduct(
        ConsumablePresetKey.cgmSensor,
        g7,
      );

      expect(
        draft.nameFor(ConsumablePresetKey.cgmSensor, 'Glucose sensor (CGM)'),
        'Dexcom G7',
      );
    });
  });

  group('when no product is named', () {
    test('the generic label is kept', () {
      expect(
        empty.nameFor(ConsumablePresetKey.cgmSensor, 'Glucose sensor (CGM)'),
        'Glucose sensor (CGM)',
      );
    });

    test('a half-filled choice is not a name', () {
      final OnboardingDraft draft = empty.withProduct(
        ConsumablePresetKey.cgmSensor,
        const BrandModel(brandId: 'dexcom', brand: 'Dexcom'),
      );

      expect(
        draft.nameFor(ConsumablePresetKey.cgmSensor, 'Glucose sensor (CGM)'),
        'Glucose sensor (CGM)',
      );
    });

    test('the preset default duration stands', () {
      expect(
        empty.durationFor(ConsumablePresetKey.cgmSensor),
        ConsumablePresets.cgmSensor.defaultDuration,
      );
    });
  });

  group('a product the catalogue does not know', () {
    test('is accepted, and names the consumable', () {
      const BrandModel typed = BrandModel(
        brandIsCustom: true,
        brand: 'Some New Brand',
        model: 'Model Z',
      );

      final OnboardingDraft draft = empty.withProduct(
        ConsumablePresetKey.cgmSensor,
        typed,
      );

      expect(
        draft.nameFor(ConsumablePresetKey.cgmSensor, 'Glucose sensor (CGM)'),
        'Some New Brand Model Z',
      );
    });

    test('does not disturb the duration', () {
      // A null catalogue duration means "not known", never "reset to the
      // default". Someone who set 7 days and then named their product must
      // not silently get 10 back.
      final OnboardingDraft draft = empty
          .withDuration(ConsumablePresetKey.cgmSensor, const Duration(days: 7))
          .withProduct(ConsumablePresetKey.cgmSensor, g7);

      expect(
        draft.durationFor(ConsumablePresetKey.cgmSensor),
        const Duration(days: 7),
      );
    });
  });

  test('choosing a product for one consumable leaves the others alone', () {
    final OnboardingDraft draft = empty
        .withProduct(
          ConsumablePresetKey.cgmSensor,
          g7,
          catalogDuration: const Duration(days: 10),
        )
        .withProduct(
          ConsumablePresetKey.infusionSet,
          const BrandModel(
            brandId: 'ypsomed',
            brand: 'Ypsomed',
            model: 'mylife Orbit soft',
          ),
          catalogDuration: const Duration(days: 3),
        );

    expect(
      draft.durationFor(ConsumablePresetKey.cgmSensor),
      const Duration(days: 10),
    );
    expect(
      draft.durationFor(ConsumablePresetKey.infusionSet),
      const Duration(days: 3),
    );
    expect(draft.productFor(ConsumablePresetKey.reservoir).isEmpty, isTrue);
  });
}
