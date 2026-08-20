import 'package:aoiloop/shared/models/body_enums.dart';
import 'package:aoiloop/shared/models/change_enums.dart';
import 'package:aoiloop/shared/models/consumable_enums.dart';
import 'package:aoiloop/shared/models/notification_enums.dart';
import 'package:aoiloop/shared/models/profile_enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('enum stability', () {
    // Every domain enum is persisted **by name**. Renaming a value silently
    // orphans existing rows, so these tests pin the wire format. Adding a
    // value is fine; changing one of these strings is a migration.
    test('GlucoseUnit names are stable', () {
      expect(GlucoseUnit.values.map((GlucoseUnit v) => v.name), <String>[
        'mgPerDl',
        'mmolPerL',
      ]);
    });

    test('ConsumableStatus names are stable', () {
      expect(
        ConsumableStatus.values.map((ConsumableStatus v) => v.name),
        <String>['active', 'completed', 'removedEarly', 'discarded'],
      );
    });

    test('ChangeType names are stable', () {
      expect(ChangeType.values.map((ChangeType v) => v.name), <String>[
        'scheduled',
        'early',
        'incident',
        'manualCorrection',
      ]);
    });

    test('NotificationStatus names are stable', () {
      expect(
        NotificationStatus.values.map((NotificationStatus v) => v.name),
        <String>['pending', 'delivered', 'cancelled', 'failed'],
      );
    });

    test('BodySide names are stable', () {
      expect(BodySide.values.map((BodySide v) => v.name), <String>[
        'left',
        'right',
        'center',
        'notApplicable',
      ]);
    });
  });

  group('TreatmentType', () {
    test('pump and pod users track pump consumables', () {
      expect(TreatmentType.pumpAndCgm.usesPumpConsumables, isTrue);
      expect(TreatmentType.pumpOnly.usesPumpConsumables, isTrue);
      expect(TreatmentType.podAndCgm.usesPumpConsumables, isTrue);
      expect(TreatmentType.podOnly.usesPumpConsumables, isTrue);
    });

    test('injection users do not', () {
      // Onboarding must not offer infusion sets to someone on pens.
      expect(TreatmentType.injectionsOnly.usesPumpConsumables, isFalse);
      expect(TreatmentType.injectionsAndCgm.usesPumpConsumables, isFalse);
      expect(TreatmentType.other.usesPumpConsumables, isFalse);
    });

    test('usesCgm matches the treatments that include one', () {
      expect(TreatmentType.pumpAndCgm.usesCgm, isTrue);
      expect(TreatmentType.podAndCgm.usesCgm, isTrue);
      expect(TreatmentType.injectionsAndCgm.usesCgm, isTrue);

      expect(TreatmentType.pumpOnly.usesCgm, isFalse);
      expect(TreatmentType.podOnly.usesCgm, isFalse);
      expect(TreatmentType.injectionsOnly.usesCgm, isFalse);
      expect(TreatmentType.other.usesCgm, isFalse);
    });

    test('usesPod separates patch pumps from tubed pumps', () {
      // Pod users have no separate set or tubing to change.
      expect(TreatmentType.podOnly.usesPod, isTrue);
      expect(TreatmentType.podAndCgm.usesPod, isTrue);
      expect(TreatmentType.pumpAndCgm.usesPod, isFalse);
    });

    test('every treatment answers all three questions', () {
      for (final TreatmentType type in TreatmentType.values) {
        expect(() => type.usesPumpConsumables, returnsNormally);
        expect(() => type.usesCgm, returnsNormally);
        expect(() => type.usesPod, returnsNormally);
      }
    });
  });

  group('BodyRegion', () {
    test('derives the correct side for every default region', () {
      expect(BodyRegion.leftArm.side, BodySide.left);
      expect(BodyRegion.lowerLeftAbdomen.side, BodySide.left);
      expect(BodyRegion.leftThigh.side, BodySide.left);
      expect(BodyRegion.leftButtock.side, BodySide.left);

      expect(BodyRegion.rightArm.side, BodySide.right);
      expect(BodyRegion.upperRightAbdomen.side, BodySide.right);
      expect(BodyRegion.rightThigh.side, BodySide.right);
      expect(BodyRegion.rightButtock.side, BodySide.right);
    });

    test('a custom region has no derivable side', () {
      expect(BodyRegion.other.side, BodySide.notApplicable);
    });

    test('every region resolves a side', () {
      for (final BodyRegion region in BodyRegion.values) {
        expect(() => region.side, returnsNormally, reason: '$region');
      }
    });

    test('buttocks are the only rear regions', () {
      expect(BodyRegion.leftButtock.isFrontView, isFalse);
      expect(BodyRegion.rightButtock.isFrontView, isFalse);

      for (final BodyRegion region in BodyRegion.values) {
        if (region != BodyRegion.leftButtock &&
            region != BodyRegion.rightButtock) {
          expect(region.isFrontView, isTrue, reason: '$region');
        }
      }
    });

    test('the default set covers every region except the custom one', () {
      expect(BodyRegionX.defaults, hasLength(10));
      expect(BodyRegionX.defaults, isNot(contains(BodyRegion.other)));
    });

    test('the default set is balanced left and right', () {
      final int left = BodyRegionX.defaults
          .where((BodyRegion r) => r.side == BodySide.left)
          .length;
      final int right = BodyRegionX.defaults
          .where((BodyRegion r) => r.side == BodySide.right)
          .length;

      expect(left, right);
    });
  });

  group('IncidentType', () {
    test('hardware failures are commonly claimable', () {
      // A hint so the app can offer to capture the lot number while the user
      // still has the packaging. Not a promise about any manufacturer policy.
      expect(IncidentType.bentCannula.commonlyClaimable, isTrue);
      expect(IncidentType.occlusion.commonlyClaimable, isTrue);
      expect(IncidentType.signalLoss.commonlyClaimable, isTrue);
      expect(IncidentType.podFailure.commonlyClaimable, isTrue);
    });

    test('body reactions are not claims against the manufacturer', () {
      expect(IncidentType.pain.commonlyClaimable, isFalse);
      expect(IncidentType.bleeding.commonlyClaimable, isFalse);
      expect(IncidentType.irritation.commonlyClaimable, isFalse);
    });

    test('site reactions are exactly the three body outcomes', () {
      final Set<IncidentType> reactions = IncidentType.values
          .where((IncidentType t) => t.isSiteReaction)
          .toSet();

      expect(reactions, <IncidentType>{
        IncidentType.pain,
        IncidentType.bleeding,
        IncidentType.irritation,
      });
    });

    test('a site reaction is never also a claim', () {
      for (final IncidentType type in IncidentType.values) {
        if (type.isSiteReaction) {
          expect(type.commonlyClaimable, isFalse, reason: '$type');
        }
      }
    });

    test('every incident type answers both questions', () {
      for (final IncidentType type in IncidentType.values) {
        expect(() => type.commonlyClaimable, returnsNormally, reason: '$type');
        expect(() => type.isSiteReaction, returnsNormally, reason: '$type');
      }
    });
  });

  group('ConsumableStatus', () {
    test('only the active status is open', () {
      expect(ConsumableStatus.active.isOpen, isTrue);
      expect(ConsumableStatus.completed.isOpen, isFalse);
      expect(ConsumableStatus.removedEarly.isOpen, isFalse);
      expect(ConsumableStatus.discarded.isOpen, isFalse);
    });

    test('a discarded item still left the cupboard', () {
      // Dropped on the floor or failed on insertion, it is gone from stock all
      // the same.
      expect(ConsumableStatus.discarded.consumedStock, isTrue);
    });
  });

  group('NotificationStatus', () {
    test('only pending notifications hold a platform slot', () {
      expect(NotificationStatus.pending.isScheduled, isTrue);
      expect(NotificationStatus.delivered.isScheduled, isFalse);
      expect(NotificationStatus.cancelled.isScheduled, isFalse);
      expect(NotificationStatus.failed.isScheduled, isFalse);
    });
  });

  group('ConsumableCategory', () {
    test('covers every category the product spec names', () {
      expect(ConsumableCategory.values, hasLength(16));
      expect(ConsumableCategory.values, contains(ConsumableCategory.custom));
    });
  });
}
