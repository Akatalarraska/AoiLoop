import '../../shared/models/consumable_enums.dart';
import '../../shared/models/device_enums.dart';
import 'catalog_entry.dart';

/// The products BlauLoop ships knowing about.
///
/// Its whole job is to save typing and to start a countdown from the number on
/// the box rather than from a guess. Nothing depends on it: every picker that
/// reads this catalogue also accepts a name typed by hand, because a catalogue
/// that blocks someone whose pump is not listed is worse than no catalogue.
///
/// ## What belongs here
///
/// Publicly documented manufacturer specifications, and nothing else. No
/// prescription details, no clinic practice, no "what most people do". Each
/// entry carries a [CatalogConsumable.source] so it can be re-checked instead
/// of trusted.
///
/// ## What is deliberately missing
///
/// **Durations this file is not sure of are null, not guessed.** A wrong
/// duration is a wrong reminder, and a reminder that fires on the wrong day
/// teaches someone to ignore the app — which is the one failure a tracker
/// cannot recover from. An unknown duration costs the user one number typed
/// during onboarding. That is the better trade, every time.
///
/// **Compatibility is not modelled.** The catalogue narrows models by brand
/// and nothing more. Which sets fit which pump is a matrix that changes with
/// every product revision, and getting it wrong would hide the item a user
/// actually has.
///
/// ## Keeping it current
///
/// Entries arrive through the `device_request.yml` issue template, which asks
/// for the manufacturer's specification link. Verification is a human step and
/// there is no automation behind it yet.
abstract final class ProductCatalog {
  // ---------------------------------------------------------------- brands

  static const List<CatalogBrand> brands = <CatalogBrand>[
    CatalogBrand(id: 'abbott', name: 'Abbott'),
    CatalogBrand(id: 'dexcom', name: 'Dexcom'),
    CatalogBrand(id: 'insulet', name: 'Insulet'),
    CatalogBrand(id: 'medtronic', name: 'Medtronic'),
    CatalogBrand(id: 'roche', name: 'Roche'),
    CatalogBrand(id: 'senseonics', name: 'Senseonics'),
    CatalogBrand(id: 'sooil', name: 'SOOIL'),
    CatalogBrand(id: 'tandem', name: 'Tandem'),
    CatalogBrand(id: 'unomedical', name: 'Unomedical'),
    CatalogBrand(id: 'ypsomed', name: 'Ypsomed'),
  ];

  static CatalogBrand? brand(String id) {
    for (final CatalogBrand candidate in brands) {
      if (candidate.id == id) {
        return candidate;
      }
    }
    return null;
  }

  // --------------------------------------------------------------- devices

  static const List<CatalogDevice> devices = <CatalogDevice>[
    // Pumps with tubing.
    CatalogDevice(
      brandId: 'medtronic',
      name: 'MiniMed 780G',
      type: DeviceType.pump,
    ),
    CatalogDevice(
      brandId: 'medtronic',
      name: 'MiniMed 770G',
      type: DeviceType.pump,
    ),
    CatalogDevice(
      brandId: 'medtronic',
      name: 'MiniMed 640G',
      type: DeviceType.pump,
    ),
    CatalogDevice(brandId: 'tandem', name: 't:slim X2', type: DeviceType.pump),
    CatalogDevice(brandId: 'tandem', name: 'Mobi', type: DeviceType.pump),
    CatalogDevice(
      brandId: 'ypsomed',
      name: 'mylife YpsoPump',
      type: DeviceType.pump,
    ),
    CatalogDevice(
      brandId: 'roche',
      name: 'Accu-Chek Insight',
      type: DeviceType.pump,
    ),
    CatalogDevice(brandId: 'sooil', name: 'DANA-i', type: DeviceType.pump),
    CatalogDevice(brandId: 'sooil', name: 'DANA RS', type: DeviceType.pump),

    // Patch pump controllers.
    CatalogDevice(
      brandId: 'insulet',
      name: 'Omnipod 5 Controller',
      type: DeviceType.podController,
    ),
    CatalogDevice(
      brandId: 'insulet',
      name: 'Omnipod DASH PDM',
      type: DeviceType.podController,
    ),
    CatalogDevice(
      brandId: 'roche',
      name: 'Accu-Chek Solo',
      type: DeviceType.podController,
    ),

    // Sensor readers and receivers.
    CatalogDevice(brandId: 'dexcom', name: 'G7 Receiver', type: DeviceType.cgm),
    CatalogDevice(brandId: 'dexcom', name: 'G6 Receiver', type: DeviceType.cgm),
    CatalogDevice(
      brandId: 'abbott',
      name: 'FreeStyle Libre 3 Reader',
      type: DeviceType.cgm,
    ),
    CatalogDevice(
      brandId: 'abbott',
      name: 'FreeStyle Libre 2 Reader',
      type: DeviceType.cgm,
    ),
    CatalogDevice(
      brandId: 'senseonics',
      name: 'Eversense Smart Transmitter',
      type: DeviceType.transmitter,
    ),
  ];

  /// Models of one brand for one kind of device, in catalogue order.
  static List<CatalogDevice> devicesFor(String brandId, DeviceType type) {
    return devices
        .where(
          (CatalogDevice device) =>
              device.brandId == brandId && device.type == type,
        )
        .toList(growable: false);
  }

  /// Brands that make this kind of device.
  ///
  /// Filtered rather than listing every brand, so the pump picker does not
  /// offer companies that have never made a pump.
  static List<CatalogBrand> deviceBrandsFor(DeviceType type) {
    final Set<String> ids = <String>{
      for (final CatalogDevice device in devices)
        if (device.type == type) device.brandId,
    };
    return brands
        .where((CatalogBrand brand) => ids.contains(brand.id))
        .toList(growable: false);
  }

  // ----------------------------------------------------------- consumables

  /// Wear times are the manufacturer's stated figures. Where this file is not
  /// confident, `duration` is null and the user is asked instead.
  static const List<CatalogConsumable> consumables = <CatalogConsumable>[
    // --- Glucose sensors ---
    CatalogConsumable(
      brandId: 'dexcom',
      name: 'G7',
      category: ConsumableCategory.cgmSensor,
      duration: Duration(days: 10),
      source: 'https://www.dexcom.com/en-us/g7-cgm-system',
      note: 'A 12 hour grace period follows the 10 day session.',
    ),
    CatalogConsumable(
      brandId: 'dexcom',
      name: 'G6',
      category: ConsumableCategory.cgmSensor,
      duration: Duration(days: 10),
      source: 'https://www.dexcom.com/en-us/g6-cgm-system',
    ),
    CatalogConsumable(
      brandId: 'dexcom',
      name: 'ONE+',
      category: ConsumableCategory.cgmSensor,
      duration: Duration(days: 10),
      source: 'https://www.dexcom.com/en-gb/dexcom-one-plus',
    ),
    CatalogConsumable(
      brandId: 'abbott',
      name: 'FreeStyle Libre 3',
      category: ConsumableCategory.cgmSensor,
      duration: Duration(days: 14),
      source: 'https://www.freestyle.abbott/',
    ),
    CatalogConsumable(
      brandId: 'abbott',
      name: 'FreeStyle Libre 2',
      category: ConsumableCategory.cgmSensor,
      duration: Duration(days: 14),
      source: 'https://www.freestyle.abbott/',
    ),
    CatalogConsumable(
      brandId: 'medtronic',
      name: 'Guardian 4',
      category: ConsumableCategory.cgmSensor,
      duration: Duration(days: 7),
      source: 'https://www.medtronicdiabetes.com/',
    ),
    CatalogConsumable(
      brandId: 'senseonics',
      name: 'Eversense E3',
      category: ConsumableCategory.cgmSensor,
      duration: Duration(days: 180),
      source: 'https://www.eversensediabetes.com/',
      note: 'Implanted and replaced by a clinician.',
    ),

    // --- Sensor transmitters ---
    CatalogConsumable(
      brandId: 'dexcom',
      name: 'G6 Transmitter',
      category: ConsumableCategory.transmitter,
      duration: Duration(days: 90),
      source: 'https://www.dexcom.com/en-us/g6-cgm-system',
    ),

    // --- Pods ---
    CatalogConsumable(
      brandId: 'insulet',
      name: 'Omnipod 5 Pod',
      category: ConsumableCategory.pod,
      duration: Duration(days: 3),
      source: 'https://www.omnipod.com/',
      note: 'An 8 hour grace period follows the 72 hour life.',
    ),
    CatalogConsumable(
      brandId: 'insulet',
      name: 'Omnipod DASH Pod',
      category: ConsumableCategory.pod,
      duration: Duration(days: 3),
      source: 'https://www.omnipod.com/',
      note: 'An 8 hour grace period follows the 72 hour life.',
    ),

    // --- Infusion sets ---
    CatalogConsumable(
      brandId: 'medtronic',
      name: 'Quick-set',
      category: ConsumableCategory.infusionSet,
      duration: Duration(days: 3),
      source: 'https://www.medtronicdiabetes.com/',
    ),
    CatalogConsumable(
      brandId: 'medtronic',
      name: 'Mio Advance',
      category: ConsumableCategory.infusionSet,
      duration: Duration(days: 3),
      source: 'https://www.medtronicdiabetes.com/',
    ),
    CatalogConsumable(
      brandId: 'medtronic',
      name: 'Silhouette',
      category: ConsumableCategory.infusionSet,
      duration: Duration(days: 3),
      source: 'https://www.medtronicdiabetes.com/',
    ),
    CatalogConsumable(
      brandId: 'medtronic',
      name: 'Sure-T',
      category: ConsumableCategory.infusionSet,
      duration: Duration(days: 2),
      source: 'https://www.medtronicdiabetes.com/',
      note: 'Steel cannula, changed more often than a soft one.',
    ),
    CatalogConsumable(
      brandId: 'unomedical',
      name: 'AutoSoft 90',
      category: ConsumableCategory.infusionSet,
      duration: Duration(days: 3),
    ),
    CatalogConsumable(
      brandId: 'unomedical',
      name: 'AutoSoft XC',
      category: ConsumableCategory.infusionSet,
      duration: Duration(days: 3),
    ),
    CatalogConsumable(
      brandId: 'unomedical',
      name: 'VariSoft',
      category: ConsumableCategory.infusionSet,
      duration: Duration(days: 3),
    ),
    CatalogConsumable(
      brandId: 'unomedical',
      name: 'TruSteel',
      category: ConsumableCategory.infusionSet,
      duration: Duration(days: 2),
      note: 'Steel cannula, changed more often than a soft one.',
    ),
    CatalogConsumable(
      brandId: 'ypsomed',
      name: 'mylife Orbit soft',
      category: ConsumableCategory.infusionSet,
      duration: Duration(days: 3),
      source: 'https://www.mylife-diabetescare.com/',
    ),
    CatalogConsumable(
      brandId: 'ypsomed',
      name: 'mylife Orbit micro',
      category: ConsumableCategory.infusionSet,
      duration: Duration(days: 3),
      source: 'https://www.mylife-diabetescare.com/',
    ),

    // --- Reservoirs and cartridges ---
    CatalogConsumable(
      brandId: 'medtronic',
      name: 'MiniMed reservoir 3.0 mL',
      category: ConsumableCategory.reservoir,
      duration: Duration(days: 3),
      source: 'https://www.medtronicdiabetes.com/',
    ),
    CatalogConsumable(
      brandId: 'tandem',
      name: 't:slim cartridge 3 mL',
      category: ConsumableCategory.reservoir,
      duration: Duration(days: 3),
      source: 'https://www.tandemdiabetes.com/',
    ),
    CatalogConsumable(
      brandId: 'ypsomed',
      name: 'mylife YpsoPump reservoir 1.6 mL',
      category: ConsumableCategory.reservoir,
      duration: Duration(days: 3),
      source: 'https://www.mylife-diabetescare.com/',
    ),
  ];

  /// Products of one brand in one category, in catalogue order.
  static List<CatalogConsumable> consumablesFor(
    String brandId,
    ConsumableCategory category,
  ) {
    return consumables
        .where(
          (CatalogConsumable product) =>
              product.brandId == brandId && product.category == category,
        )
        .toList(growable: false);
  }

  /// Brands that make something in this category.
  static List<CatalogBrand> consumableBrandsFor(ConsumableCategory category) {
    final Set<String> ids = <String>{
      for (final CatalogConsumable product in consumables)
        if (product.category == category) product.brandId,
    };
    return brands
        .where((CatalogBrand brand) => ids.contains(brand.id))
        .toList(growable: false);
  }

  /// Whether BlauLoop knows any product in this category at all.
  ///
  /// Test strips, lancets and pen needles are deliberately absent: they are
  /// counted rather than timed, and a brand picker for them would be three
  /// taps that change nothing.
  static bool hasConsumablesFor(ConsumableCategory category) => consumables.any(
    (CatalogConsumable product) => product.category == category,
  );
}
