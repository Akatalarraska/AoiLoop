import 'package:dt1flow/app/theme/app_theme.dart';
import 'package:dt1flow/app/theme/status_palette.dart';
import 'package:dt1flow/shared/models/cycle_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/contrast.dart';

void main() {
  group('theme wiring', () {
    test('both themes carry a StatusPalette extension', () {
      expect(AppTheme.light().extension<StatusPalette>(), isNotNull);
      expect(AppTheme.dark().extension<StatusPalette>(), isNotNull);
    });

    test('light and dark palettes are actually different', () {
      expect(
        StatusPalette.light.overdue.color,
        isNot(StatusPalette.dark.overdue.color),
      );
    });

    test('themes use Material 3', () {
      expect(AppTheme.light().useMaterial3, isTrue);
      expect(AppTheme.dark().useMaterial3, isTrue);
    });

    test('tap targets are padded to the accessible minimum', () {
      expect(
        AppTheme.light().materialTapTargetSize,
        MaterialTapTargetSize.padded,
      );
    });

    test('navigation labels are always visible, never icon-only', () {
      expect(
        AppTheme.light().navigationBarTheme.labelBehavior,
        NavigationDestinationLabelBehavior.alwaysShow,
      );
    });
  });

  for (final (String name, StatusPalette palette, Brightness brightness)
      in <(String, StatusPalette, Brightness)>[
        ('light', StatusPalette.light, Brightness.light),
        ('dark', StatusPalette.dark, Brightness.dark),
      ]) {
    group('StatusPalette.$name', () {
      test('resolves every CycleStatus', () {
        for (final CycleStatus status in CycleStatus.values) {
          expect(
            palette.of(status),
            isNotNull,
            reason: 'no visuals for $status',
          );
        }
      });

      test('gives every status a distinct icon', () {
        // The shape channel is what keeps statuses distinguishable without
        // colour. Two statuses sharing an icon silently breaks that.
        final Set<IconData> icons = CycleStatus.values
            .map((CycleStatus s) => palette.of(s).icon)
            .toSet();

        expect(icons, hasLength(CycleStatus.values.length));
      });

      test('gives every status a distinct accent colour', () {
        final Set<int> colors = CycleStatus.values
            .map((CycleStatus s) => palette.of(s).color.toARGB32())
            .toSet();

        expect(colors, hasLength(CycleStatus.values.length));
      });

      test('meets WCAG AA for text on its container', () {
        for (final CycleStatus status in CycleStatus.values) {
          final StatusVisuals visuals = palette.of(status);
          final double ratio = contrastRatio(
            visuals.onContainer,
            visuals.container,
          );

          expect(
            ratio,
            greaterThanOrEqualTo(wcagAaNormalText),
            reason: '$status text contrast is ${ratio.toStringAsFixed(2)}:1',
          );
        }
      });

      test('meets WCAG AA for the accent against the page surface', () {
        // The accent is used for icons and borders — graphical objects, so the
        // 3:1 threshold applies rather than 4.5:1.
        final Color surface = ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F7A8C),
          brightness: brightness,
        ).surface;

        for (final CycleStatus status in CycleStatus.values) {
          final double ratio = contrastRatio(palette.of(status).color, surface);

          expect(
            ratio,
            greaterThanOrEqualTo(wcagAaLargeText),
            reason: '$status accent contrast is ${ratio.toStringAsFixed(2)}:1',
          );
        }
      });
    });
  }

  group('StatusVisuals.lerp', () {
    test('interpolates colours and snaps the icon at the midpoint', () {
      final StatusVisuals a = StatusPalette.light.healthy;
      final StatusVisuals b = StatusPalette.light.overdue;

      expect(StatusVisuals.lerp(a, b, 0).icon, a.icon);
      expect(StatusVisuals.lerp(a, b, 0.49).icon, a.icon);
      expect(StatusVisuals.lerp(a, b, 0.5).icon, b.icon);
      expect(StatusVisuals.lerp(a, b, 1).color, b.color);
    });
  });

  group('StatusPalette.lerp', () {
    test('returns itself when handed a foreign extension', () {
      const StatusPalette palette = StatusPalette.light;

      expect(palette.lerp(null, 0.5), same(palette));
    });

    test('interpolates towards the other palette', () {
      final StatusPalette blended = StatusPalette.light.lerp(
        StatusPalette.dark,
        1,
      );

      expect(blended.healthy.color, StatusPalette.dark.healthy.color);
    });
  });

  group('CycleStatus', () {
    test('every status has a copyWith that preserves untouched fields', () {
      final StatusVisuals original = StatusPalette.light.healthy;
      final StatusVisuals recoloured = original.copyWith(
        color: const Color(0xFF000000),
      );

      expect(recoloured.color, const Color(0xFF000000));
      expect(recoloured.icon, original.icon);
      expect(recoloured.container, original.container);
      expect(recoloured.onContainer, original.onContainer);
    });
  });
}
