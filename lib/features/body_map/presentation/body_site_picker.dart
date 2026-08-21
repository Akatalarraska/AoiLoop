import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../shared/extensions/body_enums_l10n.dart';
import '../../../shared/extensions/body_site_card_l10n.dart';
import '../../../shared/extensions/build_context_x.dart';
import '../domain/body_map_view.dart';
import '../domain/body_site_choice.dart';
import 'body_map_providers.dart';

/// Asks where a consumable went.
///
/// Every active site, grouped by area, each showing what the user's own
/// history says about it: what is on it now, and how long it has been free.
/// Nothing is recommended and nothing is disabled. A region is coarse enough
/// to hold a sensor and an infusion set at the same time, so a site that is
/// already occupied is *marked*, not blocked — refusing it would be the app
/// telling someone their own body is arranged wrongly.
class BodySitePicker extends ConsumerWidget {
  const BodySitePicker({required this.selectedSiteId, super.key});

  /// Opens the picker and returns the choice, or null if it was dismissed.
  static Future<BodySiteChoice?> show(
    BuildContext context, {
    String? selectedSiteId,
  }) {
    return showModalBottomSheet<BodySiteChoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) =>
          BodySitePicker(selectedSiteId: selectedSiteId),
    );
  }

  final String? selectedSiteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<BodyMapView> map = ref.watch(bodyMapProvider);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                context.l10n.sitePickerTitle,
                style: context.textStyles.headlineSmall,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: map.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: CircularProgressIndicator.adaptive(),
                  ),
                ),
                error: (Object error, StackTrace stack) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(context.l10n.genericErrorBody),
                ),
                data: (BodyMapView view) =>
                    _SiteList(view: view, selectedSiteId: selectedSiteId),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SiteList extends StatelessWidget {
  const _SiteList({required this.view, required this.selectedSiteId});

  final BodyMapView view;
  final String? selectedSiteId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: <Widget>[
        for (final BodyAreaGroup group in view.groups) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Text(
              group.area.label(context.l10n),
              style: context.textStyles.titleSmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          for (final BodySiteCard card in group.cards)
            _SiteRow(card: card, selected: card.id == selectedSiteId),
        ],

        const Divider(height: AppSpacing.xl),
        // For anyone who does not want to track placement at all. Tracking a
        // site is a courtesy the app offers, not a toll it charges for
        // logging a change.
        ListTile(
          leading: const Icon(Icons.not_interested),
          title: Text(context.l10n.sitePickerClear),
          onTap: () => Navigator.of(context).pop(const BodySiteChoice.none()),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

/// One selectable site, with what is known about it underneath.
class _SiteRow extends StatelessWidget {
  const _SiteRow({required this.card, required this.selected});

  final BodySiteCard card;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final String state = card.stateLabel(context.l10n);

    return ListTile(
      selected: selected,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      ),
      title: Text(card.region.label(context.l10n)),
      subtitle: Text(state),
      onTap: () => Navigator.of(context).pop(BodySiteChoice(card.id)),
    );
  }
}
