import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../shared/extensions/build_context_x.dart';
import '../../../shared/extensions/date_time_format.dart';
import '../../../shared/extensions/history_l10n.dart';
import '../../../shared/widgets/responsive_page.dart';
import '../../body_map/presentation/body_map_providers.dart';
import '../domain/history_entry.dart';
import '../domain/history_view.dart';
import 'history_providers.dart';

/// Everything that has been logged, newest first.
///
/// Two sources in one list, because a timeline built on changes alone would be
/// missing entries rather than merely terse: a problem the user rode out wrote
/// no change at all.
///
/// It records and does not grade. A run of failures is a run of failures, and
/// the copy is careful never to let that read as a verdict on the person
/// having them.
///
/// The app bar belongs to `MainShell`; this screen supplies a body only.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<HistoryView> history = ref.watch(historyProvider);

    return SafeArea(
      child: history.when(
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
        data: (HistoryView view) => _HistoryBody(view: view),
      ),
    );
  }
}

class _HistoryBody extends ConsumerWidget {
  const _HistoryBody({required this.view});

  final HistoryView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<ConsumableType> types =
        ref.watch(allConsumableTypesProvider).value ?? const <ConsumableType>[];

    return ResponsivePage(
      children: <Widget>[
        Text(
          context.l10n.historyCount(view.totalEntries),
          style: context.textStyles.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          context.l10n.historyIntro,
          style: context.textStyles.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        _Filters(view: view, types: types),
        const SizedBox(height: AppSpacing.lg),

        if (view.isEmpty)
          _Empty(isFiltered: _isFiltered)
        else
          for (final HistoryDay day in view.days) _DaySection(day: day),
      ],
    );
  }

  /// Whether the user has narrowed anything, which decides whether an empty
  /// list means "nothing happened" or "nothing matches".
  bool get _isFiltered =>
      view.filter != HistoryFilter.everything || view.consumableTypeId != null;
}

/// What the list is narrowed to, and how to change it.
class _Filters extends ConsumerWidget {
  const _Filters({required this.view, required this.types});

  final HistoryView view;
  final List<ConsumableType> types;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // A wrap rather than a row: three chips plus a large text scale runs
        // out of width, and reflowing beats ellipsising the word that says
        // what is being shown.
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final HistoryFilter filter in HistoryFilter.values)
              ChoiceChip(
                label: Text(filter.label(context.l10n)),
                selected: view.filter == filter,
                onSelected: (bool _) =>
                    ref.read(historyFilterProvider.notifier).select(filter),
              ),
          ],
        ),
        if (types.length > 1) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String?>(
            initialValue: view.consumableTypeId,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: <DropdownMenuItem<String?>>[
              DropdownMenuItem<String?>(
                child: Text(context.l10n.historyAllConsumables),
              ),
              for (final ConsumableType type in types)
                DropdownMenuItem<String?>(
                  value: type.id,
                  child: Text(type.name),
                ),
            ],
            onChanged: (String? id) =>
                ref.read(historyScopeProvider.notifier).select(id),
          ),
        ],
      ],
    );
  }
}

/// One date, and everything logged under it.
class _DaySection extends StatelessWidget {
  const _DaySection({required this.day});

  final HistoryDay day;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.sm,
            bottom: AppSpacing.sm,
          ),
          child: Text(switch (day) {
            HistoryDay(isToday: true) => context.l10n.historyToday,
            HistoryDay(isYesterday: true) => context.l10n.historyYesterday,
            _ => context.formatDay(day.day),
          }, style: context.textStyles.titleSmall),
        ),
        for (final HistoryEntry entry in day.entries)
          _EntryTile(key: ValueKey<String>(entry.id), entry: entry),
      ],
    );
  }
}

/// One thing that happened.
///
/// A single semantics node, so a screen reader says "CGM sensor. Changed on
/// schedule. 08:15." rather than reading three unrelated fragments — the same
/// rule `CountdownCard` follows.
class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, super.key});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final String when = context.formatTimeOfDay(entry.occurredAt);
    final String what = entry.headline(context.l10n);
    final bool isProblem = entry is IncidentEntry;

    return Semantics(
      container: true,
      label: context.l10n.historySemanticLabel(entry.type.name, what, when),
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ExcludeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  isProblem ? Icons.report_problem_outlined : Icons.autorenew,
                  color: isProblem
                      ? context.colors.error
                      : context.colors.primary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        entry.type.name,
                        style: context.textStyles.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        what,
                        style: context.textStyles.bodyMedium?.copyWith(
                          color: isProblem
                              ? context.colors.error
                              : context.colors.onSurfaceVariant,
                        ),
                      ),
                      if (entry case ChangeEntry(isFirstEver: true))
                        Text(
                          context.l10n.historyFirstEver,
                          style: context.textStyles.bodySmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      if (entry.notes case final String note) ...<Widget>[
                        const SizedBox(height: AppSpacing.xs),
                        Text(note, style: context.textStyles.bodySmall),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  when,
                  style: context.textStyles.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Nothing to show, and an honest reason why.
class _Empty extends StatelessWidget {
  const _Empty({required this.isFiltered});

  /// Whether the user narrowed something. It decides whether this means
  /// "nothing has happened" or "nothing matches" — and telling somebody their
  /// history is empty when it is only hidden would be a small betrayal.
  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: <Widget>[
          ExcludeSemantics(
            child: Icon(
              Icons.history,
              size: 56,
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (isFiltered)
            Text(
              context.l10n.historyEmptyFiltered,
              style: context.textStyles.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            )
          else ...<Widget>[
            Text(
              context.l10n.historyEmptyTitle,
              style: context.textStyles.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.l10n.historyEmptyBody,
              style: context.textStyles.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
