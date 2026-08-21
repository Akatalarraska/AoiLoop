import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../shared/extensions/body_enums_l10n.dart';
import '../../../shared/extensions/body_site_card_l10n.dart';
import '../../../shared/extensions/build_context_x.dart';
import '../../../shared/extensions/date_time_format.dart';
import '../../../shared/widgets/responsive_page.dart';
import '../domain/body_map_view.dart';
import 'body_map_providers.dart';

/// Where things have been put, and when.
///
/// It reports usage and never prescribes a site. The strongest statement it
/// makes is which site has gone longest without being used, which is
/// arithmetic over the user's own history — and the copy is careful to phrase
/// it as a fact rather than as a suggestion, because a tracker that starts
/// recommending placements has quietly become something else.
///
/// Sites are listed and grouped rather than drawn on a silhouette. With
/// placement recorded to a region and no finer, a picture buys nothing a
/// heading does not: nobody reproduces a real position on a phone diagram
/// accurately enough for the extra precision to mean anything, and a list is
/// the layout that a screen reader and a 200% text scale both handle without
/// help.
///
/// The app bar belongs to `MainShell`; this screen supplies a body only.
class BodyMapScreen extends ConsumerWidget {
  const BodyMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<BodyMapView> map = ref.watch(bodyMapProvider);

    return SafeArea(
      child: map.when(
        loading: () => Center(
          child: Semantics(
            label: context.l10n.loading,
            child: const CircularProgressIndicator.adaptive(),
          ),
        ),
        error: (Object error, StackTrace stackTrace) =>
            _BodyMapError(onRetry: () => ref.invalidate(bodySitesProvider)),
        data: (BodyMapView view) => _BodyMapBody(view: view),
      ),
    );
  }
}

class _BodyMapBody extends StatelessWidget {
  const _BodyMapBody({required this.view});

  final BodyMapView view;

  @override
  Widget build(BuildContext context) {
    return ResponsivePage(
      children: <Widget>[
        Text(
          context.l10n.bodyMapOccupiedCount(view.occupiedCount),
          style: context.textStyles.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          context.l10n.bodyMapIntro,
          style: context.textStyles.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        for (final BodyAreaGroup group in view.groups) ...<Widget>[
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.md,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              group.area.label(context.l10n),
              style: context.textStyles.titleSmall,
            ),
          ),
          for (final BodySiteCard card in group.cards)
            _SiteTile(
              key: ValueKey<String>(card.id),
              card: card,
              isLongestRested: card.id == view.longestRested?.id,
            ),
        ],

        const SizedBox(height: AppSpacing.xl),
        Text(
          context.l10n.medicalDisclaimerShort,
          style: context.textStyles.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// One site: where it is, what is on it, and how long it has been free.
///
/// A single semantics node, so a screen reader says "Left arm. Free for 12
/// days." rather than reading a place and a duration as two unrelated
/// fragments — the same rule `CountdownCard` follows.
class _SiteTile extends StatelessWidget {
  const _SiteTile({
    required this.card,
    required this.isLongestRested,
    super.key,
  });

  final BodySiteCard card;
  final bool isLongestRested;

  @override
  Widget build(BuildContext context) {
    final String region = card.region.label(context.l10n);

    return Semantics(
      container: true,
      button: true,
      label: card.semanticLabel(context.l10n, region),
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: InkWell(
          onTap: () => _SiteHistorySheet.show(context, card: card),
          borderRadius: AppSpacing.cardBorderRadius,
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: <Widget>[
                  Icon(
                    card.isOccupied
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    color: card.isOccupied
                        ? context.colors.primary
                        : context.colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          region,
                          style: context.textStyles.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          card.stateLabel(context.l10n),
                          style: context.textStyles.bodySmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                        if (isLongestRested) ...<Widget>[
                          const SizedBox(height: AppSpacing.xs),
                          // Stated, never suggested. "Longest without use" is
                          // a fact about what the user did; "try this one"
                          // would be advice, and advice is not this app's.
                          Text(
                            context.l10n.bodyMapLongestRested,
                            style: context.textStyles.labelSmall?.copyWith(
                              color: context.colors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Everything that has been put on one site.
class _SiteHistorySheet extends ConsumerWidget {
  const _SiteHistorySheet({required this.card});

  static Future<void> show(BuildContext context, {required BodySiteCard card}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) => _SiteHistorySheet(card: card),
    );
  }

  final BodySiteCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ConsumableType>> types = ref.watch(
      allConsumableTypesProvider,
    );
    final AsyncValue<List<ConsumableInstance>> history = ref.watch(
      siteHistoryProvider(card.id),
    );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    context.l10n.bodyMapHistoryTitle(
                      card.region.label(context.l10n),
                    ),
                    style: context.textStyles.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    card.stateLabel(context.l10n),
                    style: context.textStyles.bodyMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: _History(history: history, types: types),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.history, required this.types});

  final AsyncValue<List<ConsumableInstance>> history;
  final AsyncValue<List<ConsumableType>> types;

  @override
  Widget build(BuildContext context) {
    final List<ConsumableInstance>? rows = history.value;
    if (rows == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: CircularProgressIndicator.adaptive(),
        ),
      );
    }
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Text(
          context.l10n.bodyMapHistoryEmpty,
          style: context.textStyles.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      );
    }

    final Map<String, String> namesById = <String, String>{
      for (final ConsumableType type in types.value ?? <ConsumableType>[])
        type.id: type.name,
    };

    return ListView.builder(
      shrinkWrap: true,
      itemCount: rows.length,
      itemBuilder: (BuildContext context, int index) {
        final ConsumableInstance instance = rows[index];
        return ListTile(
          dense: true,
          title: Text(
            context.l10n.bodyMapHistoryEntry(
              namesById[instance.consumableTypeId] ?? '',
              context.formatDayAndTime(instance.installedAt),
            ),
          ),
        );
      },
    );
  }
}

/// The read failed. The tab is reachable from the bar, so it offers a way out
/// rather than leaving the user on a blank screen.
class _BodyMapError extends StatelessWidget {
  const _BodyMapError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ExcludeSemantics(
              child: Icon(
                Icons.error_outline,
                size: 56,
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              context.l10n.genericErrorTitle,
              style: context.textStyles.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.l10n.genericErrorBody,
              style: context.textStyles.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}
