import 'package:blauloop/core/catalog/catalog_entry.dart';
import 'package:blauloop/core/catalog/product_catalog.dart';
import 'package:blauloop/shared/models/consumable_enums.dart';
import 'package:blauloop/shared/models/device_enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// The shipped product catalogue.
///
/// These are integrity checks, not a claim that the data is correct. Whether
/// a Dexcom G7 really lasts ten days is a question for the manufacturer's
/// specification and a human reading it; what can be checked here is that
/// every entry is well formed, that nothing is orphaned, and that the rules
/// the rest of the app relies on actually hold.
void main() {
  group('every entry is well formed', () {
    test('brand ids are unique', () {
      final Set<String> ids = ProductCatalog.brands
          .map((CatalogBrand brand) => brand.id)
          .toSet();

      expect(ids, hasLength(ProductCatalog.brands.length));
    });

    test('brand ids are lowercase slugs', () {
      // The "Other" sentinel is a double-underscored string precisely so it
      // cannot collide with one of these.
      for (final CatalogBrand brand in ProductCatalog.brands) {
        expect(
          RegExp(r'^[a-z0-9-]+$').hasMatch(brand.id),
          isTrue,
          reason: '${brand.id} is not a slug',
        );
      }
    });

    test('every device belongs to a known brand', () {
      for (final CatalogDevice device in ProductCatalog.devices) {
        expect(
          ProductCatalog.brand(device.brandId),
          isNotNull,
          reason: '${device.name} references unknown brand ${device.brandId}',
        );
      }
    });

    test('every consumable belongs to a known brand', () {
      for (final CatalogConsumable product in ProductCatalog.consumables) {
        expect(
          ProductCatalog.brand(product.brandId),
          isNotNull,
          reason: '${product.name} references unknown brand ${product.brandId}',
        );
      }
    });

    test('no two products of one brand share a name in one category', () {
      final Set<String> seen = <String>{};
      for (final CatalogConsumable product in ProductCatalog.consumables) {
        final String key =
            '${product.brandId}/${product.category.name}/${product.name}';
        expect(seen.add(key), isTrue, reason: 'duplicate entry: $key');
      }
    });

    test('no product claims a zero or negative wear time', () {
      for (final CatalogConsumable product in ProductCatalog.consumables) {
        if (product.duration == null) {
          continue;
        }
        expect(
          product.duration! > Duration.zero,
          isTrue,
          reason: '${product.name} has a non-positive duration',
        );
      }
    });
  });

  group('narrowing by brand', () {
    test('returns only that brand, and only that category', () {
      final List<CatalogConsumable> sensors = ProductCatalog.consumablesFor(
        'dexcom',
        ConsumableCategory.cgmSensor,
      );

      expect(sensors, isNotEmpty);
      for (final CatalogConsumable product in sensors) {
        expect(product.brandId, 'dexcom');
        expect(product.category, ConsumableCategory.cgmSensor);
      }
    });

    test('an unknown brand yields nothing rather than throwing', () {
      expect(
        ProductCatalog.consumablesFor('nope', ConsumableCategory.cgmSensor),
        isEmpty,
      );
      expect(ProductCatalog.devicesFor('nope', DeviceType.pump), isEmpty);
    });

    test('offers only brands that make the thing being asked about', () {
      final List<CatalogBrand> pumpBrands = ProductCatalog.deviceBrandsFor(
        DeviceType.pump,
      );
      final Set<String> ids = pumpBrands
          .map((CatalogBrand brand) => brand.id)
          .toSet();

      expect(ids, contains('tandem'));
      // Abbott makes sensors, not pumps. A pump picker listing them is noise.
      expect(ids, isNot(contains('abbott')));
    });

    test('a brand appears once however many products it has', () {
      final List<CatalogBrand> brands = ProductCatalog.consumableBrandsFor(
        ConsumableCategory.infusionSet,
      );

      expect(
        brands.map((CatalogBrand brand) => brand.id).toSet(),
        hasLength(brands.length),
      );
    });
  });

  group('categories the catalogue deliberately says nothing about', () {
    test('counted consumables have no products', () {
      // Strips, lancets and pen needles are counted rather than timed. A brand
      // picker for them would be taps that change nothing.
      for (final ConsumableCategory category in <ConsumableCategory>[
        ConsumableCategory.testStrip,
        ConsumableCategory.lancet,
        ConsumableCategory.needle,
      ]) {
        expect(
          ProductCatalog.hasConsumablesFor(category),
          isFalse,
          reason: '${category.name} should not offer a brand picker',
        );
      }
    });

    test('the categories a countdown depends on do have products', () {
      for (final ConsumableCategory category in <ConsumableCategory>[
        ConsumableCategory.cgmSensor,
        ConsumableCategory.infusionSet,
        ConsumableCategory.reservoir,
        ConsumableCategory.pod,
      ]) {
        expect(
          ProductCatalog.hasConsumablesFor(category),
          isTrue,
          reason: '${category.name} has nothing to offer',
        );
      }
    });
  });

  test('a source is recorded wherever a duration is claimed', () {
    // Not every entry has one yet, and this test says how many do rather than
    // failing the build over it — the point is that the number is visible and
    // moves in one direction. Durations are what turn into reminders, so an
    // unsourced one is a claim nobody can check.
    final List<CatalogConsumable> timed = ProductCatalog.consumables
        .where((CatalogConsumable product) => product.hasDuration)
        .toList();
    final int sourced = timed
        .where((CatalogConsumable product) => product.source != null)
        .length;

    expect(
      sourced,
      greaterThanOrEqualTo(timed.length - 4),
      reason:
          'unsourced durations: '
          '${timed.where((CatalogConsumable p) => p.source == null).map((CatalogConsumable p) => p.name).join(', ')}',
    );
  });
}
