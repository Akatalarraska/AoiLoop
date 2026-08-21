import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../shared/extensions/build_context_x.dart';
import '../../../shared/extensions/date_time_format.dart';
import '../../../shared/extensions/history_l10n.dart';
import '../../history/domain/history_entry.dart';
import '../domain/calendar_month.dart';
import 'calendar_providers.dart';

/// A month at a time: what was logged on each day, and what is coming.
///
/// The two are kept visually apart because they are different claims. What was
/// logged is a record; what is expected is a date the app worked out, and it
/// moves the moment the user does anything. A calendar that drew them the same
/// way would let a plan read as a fact.
///
/// The app bar belongs to `MainShell`; this screen supplies a body only.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<CalendarMonth> calendar = ref.watch(calendarProvider);

    return SafeArea(
      child: calendar.when(
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
        data: (CalendarMonth month) => _CalendarBody(month: month),
      ),
    );
  }
}

class _CalendarBody extends ConsumerWidget {
  const _CalendarBody({required this.month});

  final CalendarMonth month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime? selected = ref.watch(selectedDayProvider);
    final CalendarDay? openDay = selected == null
        ? null
        : month.dayOn(selected);

    return ListView(
      padding: AppSpacing.pagePadding,
      children: <Widget>[
        _MonthHeader(month: month),
        const SizedBox(height: AppSpacing.xs),
        Text(
          context.l10n.calendarIntro,
          style: context.textStyles.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        _WeekdayHeadings(firstWeekday: ref.watch(firstWeekdayProvider)),
        const SizedBox(height: AppSpacing.xs),
        _Grid(month: month, selected: selected),

        const SizedBox(height: AppSpacing.md),
        Text(
          context.l10n.calendarMonthCount(month.entryCount),
          style: context.textStyles.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),

        if (openDay != null) ...<Widget>[
          const Divider(height: AppSpacing.xl),
          _DayDetail(day: openDay),
        ],
      ],
    );
  }
}

/// The month being shown, and the way to move between them.
class _MonthHeader extends ConsumerWidget {
  const _MonthHeader({required this.month});

  final CalendarMonth month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String title = DateFormat.yMMMM(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(month.month);

    void go(DateTime to) {
      ref.read(visibleMonthProvider.notifier).show(to);
      // The open day belonged to the month being left. Keeping it would show
      // a detail panel for a square no longer on screen.
      ref.read(selectedDayProvider.notifier).select(null);
    }

    return Row(
      children: <Widget>[
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: context.l10n.calendarPreviousMonth,
          onPressed: () => go(month.previousMonth),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: context.textStyles.titleMedium,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: context.l10n.calendarNextMonth,
          onPressed: () => go(month.nextMonth),
        ),
      ],
    );
  }
}

/// Mon, Tue, Wed… starting on whichever day the locale starts on.
class _WeekdayHeadings extends StatelessWidget {
  const _WeekdayHeadings({required this.firstWeekday});

  final int firstWeekday;

  @override
  Widget build(BuildContext context) {
    final DateFormat format = DateFormat.E(
      Localizations.localeOf(context).toLanguageTag(),
    );
    // Any week will do; 5 January 2026 is a Monday, so adding gives each
    // weekday in turn without any date arithmetic worth testing.
    final DateTime monday = DateTime(2026, 1, 5);

    return ExcludeSemantics(
      child: Row(
        children: <Widget>[
          for (int i = 0; i < 7; i++)
            Expanded(
              child: Text(
                format.format(
                  monday.add(Duration(days: (firstWeekday - 1 + i) % 7)),
                ),
                textAlign: TextAlign.center,
                style: context.textStyles.labelSmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Six rows of seven squares.
class _Grid extends ConsumerWidget {
  const _Grid({required this.month, required this.selected});

  final CalendarMonth month;
  final DateTime? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: <Widget>[
        for (int row = 0; row < 6; row++)
          Row(
            children: <Widget>[
              for (int column = 0; column < 7; column++)
                Expanded(
                  child: _DaySquare(
                    day: month.days[row * 7 + column],
                    isToday: month.days[row * 7 + column].day == month.today,
                    isSelected: month.days[row * 7 + column].day == selected,
                    onTap: () => ref
                        .read(selectedDayProvider.notifier)
                        .select(
                          month.days[row * 7 + column].day == selected
                              ? null
                              : month.days[row * 7 + column].day,
                        ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// One square: the date, and dots for what is on it.
///
/// The dots are a summary and never the whole answer — tapping opens the day,
/// and the screen reader label says in words what the dots say in colour.
class _DaySquare extends StatelessWidget {
  const _DaySquare({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final CalendarDay day;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color ink = day.isInMonth
        ? context.colors.onSurface
        : context.colors.onSurfaceVariant.withValues(alpha: 0.5);

    return Semantics(
      button: true,
      selected: isSelected,
      label: context.l10n.calendarDaySemanticLabel(
        context.formatDay(day.day),
        _summary(context),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        child: ExcludeSemantics(
          child: Container(
            constraints: const BoxConstraints(minHeight: AppSpacing.xxxl),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              color: isSelected
                  ? context.colors.secondaryContainer
                  : Colors.transparent,
              border: isToday
                  ? Border.all(color: context.colors.primary, width: 2)
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '${day.day.day}',
                  style: context.textStyles.bodyMedium?.copyWith(
                    color: ink,
                    fontWeight: isToday ? FontWeight.w700 : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                _Dots(day: day),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// What the square says, in words, for anyone not reading the dots.
  String _summary(BuildContext context) {
    if (!day.hasAnything) {
      return context.l10n.calendarDayEmpty;
    }
    return <String>[
      if (day.entries.isNotEmpty) context.l10n.historyCount(day.entries.length),
      if (day.expectations.isNotEmpty) context.l10n.calendarExpectedTitle,
    ].join('. ');
  }
}

/// A filled dot for something logged, a hollow one for something expected.
///
/// Two shapes rather than two colours, so the difference between a record and
/// a plan survives a greyscale screenshot — the same reasoning as the status
/// palette carrying an icon per status.
class _Dots extends StatelessWidget {
  const _Dots({required this.day});

  final CalendarDay day;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (day.entries.isNotEmpty)
            _Dot(
              filled: true,
              color: day.hasProblem
                  ? context.colors.error
                  : context.colors.primary,
            ),
          if (day.expectations.isNotEmpty)
            _Dot(filled: false, color: context.colors.outline),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.filled, required this.color});

  final bool filled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? color : Colors.transparent,
          border: filled ? null : Border.all(color: color),
        ),
      ),
    );
  }
}

/// Everything on the day the user opened.
class _DayDetail extends StatelessWidget {
  const _DayDetail({required this.day});

  final CalendarDay day;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(context.formatDay(day.day), style: context.textStyles.titleMedium),
        const SizedBox(height: AppSpacing.md),

        if (!day.hasAnything)
          Text(
            context.l10n.calendarDayEmpty,
            style: context.textStyles.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),

        if (day.entries.isNotEmpty) ...<Widget>[
          Text(
            context.l10n.calendarHappenedTitle,
            style: context.textStyles.labelMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final HistoryEntry entry in day.entries)
            ListTile(
              key: ValueKey<String>(entry.id),
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                entry is IncidentEntry
                    ? Icons.report_problem_outlined
                    : Icons.autorenew,
                color: entry is IncidentEntry
                    ? context.colors.error
                    : context.colors.primary,
              ),
              title: Text(entry.type.name),
              subtitle: Text(entry.headline(context.l10n)),
              trailing: Text(context.formatTimeOfDay(entry.occurredAt)),
            ),
        ],

        if (day.expectations.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Text(
            context.l10n.calendarExpectedTitle,
            style: context.textStyles.labelMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final CalendarExpectation expectation in day.expectations)
            ListTile(
              key: ValueKey<String>(expectation.id),
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_outlined),
              title: Text(switch (expectation) {
                ChangeDue() => context.l10n.calendarChangeDue(
                  expectation.type.name,
                ),
                StockExpires() => context.l10n.calendarStockExpires(
                  expectation.type.name,
                ),
              }),
            ),
        ],
      ],
    );
  }
}
