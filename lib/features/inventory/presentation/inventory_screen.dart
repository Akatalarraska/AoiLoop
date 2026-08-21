import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../shared/extensions/build_context_x.dart';
import '../../../shared/extensions/date_time_format.dart';
import '../domain/inventory_view.dart';
import 'inventory_locations_screen.dart';
import 'inventory_providers.dart';
import 'stock_sheets.dart';

/// What is left in the cupboard.
///
/// BlauLoop subtracts one each time a change is registered, and says so at the
/// top. It also puts *correct the count* right beside *add stock*, because an
/// automatic count the user cannot override is a trap: boxes get borrowed,
/// someone else restocks, a change gets logged twice. The person holding the
/// supplies is the authority.
///
/// Nothing here is a recommendation about how much to keep. The warning level
/// is a number the user chose and the app repeats back.
///
/// Pushed over `MainShell`, so it owns its app bar and back button.
class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<InventoryView> inventory = ref.watch(inventoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.sectionInventory),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.place_outlined),
            tooltip: context.l10n.inventoryLocations,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) =>
                    const InventoryLocationsScreen(),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: inventory.when(
          loading: () => Center(
            child: Semantics(
              label: context.l10n.loading,
              child: const CircularProgressIndicator.adaptive(),
            ),
          ),
          error: (Object error, StackTrace stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                context.l10n.genericErrorBody,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (InventoryView view) => _InventoryBody(view: view),
        ),
      ),
    );
  }
}

class _InventoryBody extends StatelessWidget {
  const _InventoryBody({required this.view});

  final InventoryView view;

  @override
  Widget build(BuildContext context) {
    if (view.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            context.l10n.inventoryNothingToCount,
            style: context.textStyles.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: AppSpacing.pagePadding,
      children: <Widget>[
        if (view.hasAnyStock) ...<Widget>[
          Text(
            context.l10n.inventoryLowCount(view.lowCount),
            style: context.textStyles.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
        ] else ...<Widget>[
          Text(
            context.l10n.inventoryEmptyTitle,
            style: context.textStyles.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            context.l10n.inventoryEmptyBody,
            style: context.textStyles.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        Text(
          context.l10n.inventoryIntro,
          style: context.textStyles.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        for (final InventoryCard card in view.cards)
          _StockCard(key: ValueKey<String>(card.id), card: card, view: view),
      ],
    );
  }
}

/// One consumable: how many are left, when the app will warn, and the three
/// things that can be done about it.
///
/// A single semantics node, so a screen reader says "CGM sensor. Running low.
/// 2 left." rather than reading a name, a badge and a number as three
/// unrelated fragments.
class _StockCard extends StatelessWidget {
  const _StockCard({required this.card, required this.view, super.key});

  final InventoryCard card;
  final InventoryView view;

  @override
  Widget build(BuildContext context) {
    final String count = card.isTracked
        ? context.l10n.inventoryUnits(card.total)
        : context.l10n.inventoryNotCounted;
    final String state = _stateLabel(context);

    return Semantics(
      container: true,
      label: context.l10n.inventorySemanticLabel(card.type.name, state, count),
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _Header(card: card, state: state),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  count,
                  style: context.textStyles.headlineSmall?.copyWith(
                    color: card.level.needsAttention
                        ? context.colors.error
                        : context.colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  card.minimum > 0
                      ? context.l10n.inventoryMinimum(card.minimum)
                      : context.l10n.inventoryNoMinimum,
                  style: context.textStyles.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),

                if (card.batches.length > 1 ||
                    card.hasDatedBatches) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  _Batches(card: card, view: view),
                ],

                const SizedBox(height: AppSpacing.sm),
                OverflowBar(
                  spacing: AppSpacing.sm,
                  overflowAlignment: OverflowBarAlignment.start,
                  children: <Widget>[
                    TextButton.icon(
                      onPressed: () => StockSheet.show(
                        context,
                        card: card,
                        action: StockAction.add,
                      ),
                      icon: const Icon(Icons.add),
                      label: Text(context.l10n.inventoryAddStock),
                    ),
                    TextButton(
                      onPressed: () => StockSheet.show(
                        context,
                        card: card,
                        action: StockAction.correct,
                      ),
                      child: Text(context.l10n.inventoryCorrectCount),
                    ),
                    TextButton(
                      onPressed: () => StockSheet.show(
                        context,
                        card: card,
                        action: StockAction.minimum,
                      ),
                      child: Text(context.l10n.inventorySetMinimum),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _stateLabel(BuildContext context) => switch (card.level) {
    StockLevel.ok => context.l10n.inventoryOkBadge,
    StockLevel.low => context.l10n.inventoryLowBadge,
    StockLevel.out => context.l10n.inventoryOutBadge,
    StockLevel.untracked => context.l10n.inventoryNotCounted,
  };
}

/// Name and level, side by side until the text gets big enough that they stop
/// fitting.
class _Header extends StatelessWidget {
  const _Header({required this.card, required this.state});

  final InventoryCard card;
  final String state;

  @override
  Widget build(BuildContext context) {
    final Widget name = Text(
      card.type.name,
      style: context.textStyles.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
    final Widget badge = _LevelBadge(level: card.level, label: state);

    if (context.prefersLargeText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          name,
          const SizedBox(height: AppSpacing.sm),
          badge,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: name),
        const SizedBox(width: AppSpacing.sm),
        badge,
      ],
    );
  }
}

/// The stock level, on colour, shape and text together — the same rule every
/// status surface in the app follows.
class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level, required this.label});

  final StockLevel level;
  final String label;

  @override
  Widget build(BuildContext context) {
    final (Color fill, Color ink, IconData icon) = switch (level) {
      StockLevel.ok => (
        context.colors.secondaryContainer,
        context.colors.onSecondaryContainer,
        Icons.check_circle_outline,
      ),
      StockLevel.low => (
        context.colors.errorContainer,
        context.colors.onErrorContainer,
        Icons.trending_down,
      ),
      StockLevel.out => (
        context.colors.errorContainer,
        context.colors.onErrorContainer,
        Icons.remove_shopping_cart_outlined,
      ),
      StockLevel.untracked => (
        context.colors.surfaceContainerHighest,
        context.colors.onSurfaceVariant,
        Icons.help_outline,
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        border: Border.all(color: ink, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: ink),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: context.textStyles.labelMedium?.copyWith(
                color: ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The individual batches, shown only once there is more than one or one of
/// them carries a date. A single undated box needs no breakdown.
class _Batches extends StatelessWidget {
  const _Batches({required this.card, required this.view});

  final InventoryCard card;
  final InventoryView view;

  @override
  Widget build(BuildContext context) {
    final Map<String, String> places = <String, String>{
      for (final InventoryLocation location in view.locations)
        location.id: location.name,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.inventoryBatchesTitle,
          style: context.textStyles.labelMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final InventoryItem batch in card.batches)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
            child: Text(
              <String>[
                context.l10n.inventoryBatchLine(
                  context.l10n.inventoryUnits(batch.quantity),
                  places[batch.locationId] ??
                      context.l10n.inventoryLocationNone,
                ),
                if (batch.expirationDate case final DateTime expires)
                  context.l10n.inventoryBatchExpires(
                    context.formatDay(expires),
                  ),
              ].join(' · '),
              style: context.textStyles.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
