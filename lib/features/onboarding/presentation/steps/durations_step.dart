import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/catalog/brand_model.dart';
import '../../../../core/catalog/catalog_entry.dart';
import '../../../../core/catalog/product_catalog.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/widgets/brand_model_picker.dart';
import '../../domain/consumable_preset.dart';
import '../../domain/onboarding_draft.dart';
import '../onboarding_controller.dart';
import '../onboarding_l10n.dart';
import '../widgets/onboarding_step_layout.dart';

/// Which product each consumable is, and how long it lasts.
///
/// Naming the product is optional and comes first, because when it is answered
/// the duration answers itself: the catalogue fills in the manufacturer's
/// stated wear time and the row below updates in front of the user. Anyone who
/// does not know their infusion set by name — which is most people — skips
/// straight to the number.
///
/// The number stays editable either way. What the box says and what a
/// particular person actually gets are different figures, and this screen
/// exists so the second one wins before a single countdown starts.
class DurationsStep extends ConsumerWidget {
  const DurationsStep({super.key});

  static const int _minDays = 1;
  static const int _maxDays = 400;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingDraft draft = ref.watch(onboardingControllerProvider).draft;
    final OnboardingController controller = ref.read(
      onboardingControllerProvider.notifier,
    );

    return OnboardingStepLayout(
      title: context.l10n.onboardingDurationsTitle,
      body: context.l10n.onboardingDurationsBody,
      children: <Widget>[
        for (final ConsumablePreset preset in draft.selectedCyclicPresets)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: _ConsumableCard(
              preset: preset,
              product: draft.productFor(preset.key),
              days: draft.durationFor(preset.key)!.inDays,
              onProductChanged: (BrandModel picked) => controller.setProduct(
                preset.key,
                picked,
                catalogDuration: _durationOf(picked, preset),
              ),
              onDaysChanged: (int days) => controller.setDuration(
                preset.key,
                Duration(days: days.clamp(_minDays, _maxDays)),
              ),
            ),
          ),
      ],
    );
  }

  /// The manufacturer's stated wear time for a chosen product, or null.
  ///
  /// Null covers both "typed by hand" and "in the catalogue but with no
  /// duration recorded". Neither is a reason to overwrite what the user has;
  /// see `ProductCatalog` for why unknown durations stay unknown.
  static Duration? _durationOf(BrandModel picked, ConsumablePreset preset) {
    if (picked.brandId == null || picked.model.isEmpty) {
      return null;
    }
    for (final CatalogConsumable product in ProductCatalog.consumablesFor(
      picked.brandId!,
      preset.category,
    )) {
      if (product.name == picked.model) {
        return product.duration;
      }
    }
    return null;
  }
}

/// One consumable: what it is, and how long it lasts.
class _ConsumableCard extends StatelessWidget {
  const _ConsumableCard({
    required this.preset,
    required this.product,
    required this.days,
    required this.onProductChanged,
    required this.onDaysChanged,
  });

  final ConsumablePreset preset;
  final BrandModel product;
  final int days;
  final ValueChanged<BrandModel> onProductChanged;
  final ValueChanged<int> onDaysChanged;

  @override
  Widget build(BuildContext context) {
    final List<CatalogBrand> brands = ProductCatalog.consumableBrandsFor(
      preset.category,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            preset.key.label(context.l10n),
            style: context.textStyles.titleMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // No pickers where the catalogue knows nothing: three taps that
        // change nothing are worse than no control at all.
        if (brands.isNotEmpty) ...<Widget>[
          BrandModelPicker(
            key: Key('${preset.key.name}-brand-model'),
            value: product,
            brands: brands,
            modelsFor: (String brandId) =>
                ProductCatalog.consumablesFor(brandId, preset.category)
                    .map((CatalogConsumable product) => product.name)
                    .toList(growable: false),
            onChanged: onProductChanged,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],

        _DurationRow(
          label: context.l10n.onboardingDurationsLasts,
          days: days,
          onChanged: onDaysChanged,
          canDecrease: days > DurationsStep._minDays,
          canIncrease: days < DurationsStep._maxDays,
        ),
      ],
    );
  }
}

class _DurationRow extends StatelessWidget {
  const _DurationRow({
    required this.label,
    required this.days,
    required this.onChanged,
    required this.canDecrease,
    required this.canIncrease,
  });

  final String label;
  final int days;
  final ValueChanged<int> onChanged;
  final bool canDecrease;
  final bool canIncrease;

  @override
  Widget build(BuildContext context) {
    final String value = context.l10n.durationDays(days);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: context.textStyles.bodyLarge)),
          IconButton(
            onPressed: canDecrease ? () => onChanged(days - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
            tooltip: context.l10n.durationShorter,
          ),
          // One live region per consumable: the value is announced when it
          // changes, without repeating the label each time.
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 72),
            child: Semantics(
              liveRegion: true,
              label: '$label, $value',
              excludeSemantics: true,
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: context.textStyles.bodyLarge,
              ),
            ),
          ),
          IconButton(
            onPressed: canIncrease ? () => onChanged(days + 1) : null,
            icon: const Icon(Icons.add_circle_outline),
            tooltip: context.l10n.durationLonger,
          ),
        ],
      ),
    );
  }
}
