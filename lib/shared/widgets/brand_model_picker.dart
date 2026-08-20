import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../../core/catalog/brand_model.dart';
import '../../core/catalog/catalog_entry.dart';
import '../extensions/build_context_x.dart';

/// Two dropdowns: a brand, then only that brand's models.
///
/// Cascading rather than one long list, because "Dexcom" narrows forty
/// products to four and the second choice becomes obvious. The alternative —
/// every model from every manufacturer in one menu — is the version people
/// scroll past their own device in.
///
/// **Both dropdowns end in "Other", which reveals a text field.** That escape
/// hatch is not a fallback, it is the point: the catalogue will always be
/// behind reality, and someone whose pump came out last month must be able to
/// finish onboarding today. Nothing downstream distinguishes a product that
/// was picked from one that was typed.
class BrandModelPicker extends StatelessWidget {
  const BrandModelPicker({
    required this.value,
    required this.brands,
    required this.modelsFor,
    required this.onChanged,
    this.brandLabel,
    this.modelLabel,
    super.key,
  });

  final BrandModel value;

  /// Brands that make this kind of thing.
  final List<CatalogBrand> brands;

  /// The models one brand offers. Called with a catalogue brand id.
  final List<String> Function(String brandId) modelsFor;

  final ValueChanged<BrandModel> onChanged;

  final String? brandLabel;
  final String? modelLabel;

  /// Sentinel for the "Other" row. Not a brand id, and cannot collide with one
  /// because catalogue ids are lowercase slugs.
  static const String otherValue = '__other__';

  @override
  Widget build(BuildContext context) {
    final String other = context.l10n.catalogOther;
    final List<String> models = value.brandId == null
        ? const <String>[]
        : modelsFor(value.brandId!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DropdownButtonFormField<String>(
          initialValue: value.brandIsCustom ? otherValue : value.brandId,
          decoration: InputDecoration(
            labelText: brandLabel ?? context.l10n.fieldManufacturer,
          ),
          items: <DropdownMenuItem<String>>[
            for (final CatalogBrand brand in brands)
              DropdownMenuItem<String>(
                value: brand.id,
                child: Text(brand.name),
              ),
            DropdownMenuItem<String>(value: otherValue, child: Text(other)),
          ],
          onChanged: (String? picked) => _pickBrand(picked, context),
        ),

        if (value.brandIsCustom) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            initialValue: value.brand,
            decoration: InputDecoration(
              labelText: brandLabel ?? context.l10n.fieldManufacturer,
            ),
            textCapitalization: TextCapitalization.words,
            onChanged: (String text) => onChanged(value.copyWith(brand: text)),
          ),
        ],

        const SizedBox(height: AppSpacing.md),

        // A model list is only meaningful once a brand narrows it. Before
        // that, and for a hand-typed brand, the field is free text.
        if (value.brandId != null && models.isNotEmpty)
          DropdownButtonFormField<String>(
            initialValue: models.contains(value.model)
                ? value.model
                : (value.model.isEmpty ? null : otherValue),
            decoration: InputDecoration(
              labelText: modelLabel ?? context.l10n.fieldModel,
            ),
            items: <DropdownMenuItem<String>>[
              for (final String model in models)
                DropdownMenuItem<String>(value: model, child: Text(model)),
              DropdownMenuItem<String>(value: otherValue, child: Text(other)),
            ],
            onChanged: (String? picked) => onChanged(
              value.copyWith(model: picked == otherValue ? '' : (picked ?? '')),
            ),
          )
        else
          TextFormField(
            initialValue: value.model,
            decoration: InputDecoration(
              labelText: modelLabel ?? context.l10n.fieldModel,
            ),
            onChanged: (String text) => onChanged(value.copyWith(model: text)),
          ),

        // Picking "Other" in the model dropdown leaves the model empty, which
        // is the signal to offer a field for it.
        if (value.brandId != null && models.isNotEmpty && value.model.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: TextFormField(
              decoration: InputDecoration(
                labelText: modelLabel ?? context.l10n.fieldModel,
              ),
              onChanged: (String text) =>
                  onChanged(value.copyWith(model: text)),
            ),
          ),
      ],
    );
  }

  void _pickBrand(String? picked, BuildContext context) {
    if (picked == null) {
      return;
    }
    if (picked == otherValue) {
      // Clearing the model too: a model chosen for one brand means nothing
      // under another, and leaving it behind is how a form ends up claiming a
      // Dexcom t:slim.
      onChanged(const BrandModel(brandIsCustom: true));
      return;
    }
    final CatalogBrand brand = brands.firstWhere(
      (CatalogBrand candidate) => candidate.id == picked,
    );
    onChanged(BrandModel(brandId: brand.id, brand: brand.name));
  }
}
