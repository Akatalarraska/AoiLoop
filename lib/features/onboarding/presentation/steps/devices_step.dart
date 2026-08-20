import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/catalog/brand_model.dart';
import '../../../../core/catalog/catalog_entry.dart';
import '../../../../core/catalog/product_catalog.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/models/device_enums.dart';
import '../../../../shared/models/profile_enums.dart';
import '../../../../shared/widgets/brand_model_picker.dart';
import '../../domain/onboarding_draft.dart';
import '../onboarding_controller.dart';
import '../widgets/onboarding_step_layout.dart';

/// Optional hardware: the pump (or pod controller) and the CGM.
///
/// Entirely skippable. Its value shows up later — a warranty claim needs a
/// serial number, and nobody can find one at the moment the pump fails — but
/// none of that is worth blocking a first launch for.
class DevicesStep extends ConsumerWidget {
  const DevicesStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingDraft draft = ref.watch(onboardingControllerProvider).draft;
    final OnboardingController controller = ref.read(
      onboardingControllerProvider.notifier,
    );
    final TreatmentType? treatment = draft.treatmentType;

    return OnboardingStepLayout(
      title: context.l10n.onboardingDevicesTitle,
      body: context.l10n.onboardingDevicesBody,
      children: <Widget>[
        if (treatment != null && treatment.usesPumpConsumables) ...<Widget>[
          _DeviceFields(
            title: treatment.usesPod
                ? context.l10n.deviceSectionPod
                : context.l10n.deviceSectionPump,
            type: treatment.usesPod
                ? DeviceType.podController
                : DeviceType.pump,
            device: draft.pump,
            onChanged: controller.setPump,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        if (treatment != null && treatment.usesCgm)
          _DeviceFields(
            title: context.l10n.deviceSectionCgm,
            type: DeviceType.cgm,
            device: draft.cgm,
            onChanged: controller.setCgm,
          ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          context.l10n.deviceIncompleteHint,
          style: context.textStyles.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _DeviceFields extends StatelessWidget {
  const _DeviceFields({
    required this.title,
    required this.type,
    required this.device,
    required this.onChanged,
  });

  final String title;

  /// Which kind of device this section is for, so the brand list offers only
  /// companies that make one. A pump picker listing Abbott would be noise.
  final DeviceType type;

  final DraftDevice device;
  final ValueChanged<DraftDevice> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(title, style: context.textStyles.titleMedium),
        ),
        const SizedBox(height: AppSpacing.md),
        BrandModelPicker(
          key: Key('$title-brand-model'),
          value: BrandModel(
            brandId: device.brandId,
            brandIsCustom: device.brandIsCustom,
            brand: device.manufacturer,
            model: device.model,
          ),
          brands: ProductCatalog.deviceBrandsFor(type),
          modelsFor: (String brandId) => ProductCatalog.devicesFor(
            brandId,
            type,
          ).map((CatalogDevice device) => device.name).toList(growable: false),
          onChanged: (BrandModel picked) => onChanged(
            device.withBrandModel(
              brandId: picked.brandId,
              brandIsCustom: picked.brandIsCustom,
              manufacturer: picked.brand,
              model: picked.model,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          key: Key('$title-serial'),
          initialValue: device.serialNumber ?? '',
          decoration: InputDecoration(
            labelText: context.l10n.fieldSerialNumber,
            border: const OutlineInputBorder(),
          ),
          onChanged: (String value) =>
              onChanged(device.copyWith(serialNumber: value)),
        ),
      ],
    );
  }
}
