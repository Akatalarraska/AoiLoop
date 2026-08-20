import 'package:flutter/foundation.dart';

/// A manufacturer and one of its models, as chosen or typed by the user.
///
/// Lives beside the catalogue rather than beside the picker that edits it,
/// because the onboarding draft holds one of these per consumable and a
/// domain model has no business importing a widget file.
///
/// Brand and model are kept as plain strings rather than as catalogue
/// references because that is what ends up in the database — and because the
/// user is always allowed to type something the catalogue has never heard of.
/// A product that exists only in this person's cupboard is still their product.
@immutable
class BrandModel {
  const BrandModel({
    this.brandId,
    this.brand = '',
    this.model = '',
    this.brandIsCustom = false,
  });

  /// The catalogue brand that was picked, or null when it was typed by hand.
  final String? brandId;

  /// Whether the user chose "Other" for the brand.
  ///
  /// Held explicitly rather than inferred from an empty [brandId], because the
  /// two differ at the only moment that matters: right after choosing "Other",
  /// when nothing has been typed yet and the field still has to be on screen.
  final bool brandIsCustom;

  final String brand;
  final String model;

  /// Whether the pair is complete enough to be worth saving.
  bool get isUsable => brand.trim().isNotEmpty && model.trim().isNotEmpty;

  bool get isEmpty => brand.trim().isEmpty && model.trim().isEmpty;

  BrandModel copyWith({String? brand, String? model}) {
    return BrandModel(
      brandId: brandId,
      brandIsCustom: brandIsCustom,
      brand: brand ?? this.brand,
      model: model ?? this.model,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BrandModel &&
      other.brandId == brandId &&
      other.brandIsCustom == brandIsCustom &&
      other.brand == brand &&
      other.model == model;

  @override
  int get hashCode => Object.hash(brandId, brandIsCustom, brand, model);
}
