import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/clock.dart';
import '../../../shared/extensions/build_context_x.dart';
import '../../../shared/extensions/date_time_format.dart';
import '../../../shared/extensions/incident_enums_l10n.dart';
import '../../changes/data/cycle_engine.dart';
import '../../changes/domain/cycle_schedule.dart';
import '../../dashboard/domain/dashboard_view.dart';
import '../domain/incident_report.dart';

/// Records that something went wrong, and what the user did about it.
///
/// Longer than the register-change sheet on purpose. A routine change is one
/// fact — *when* — and everything else can be inferred; a failure is an
/// account of something, and the parts of it worth keeping are exactly the
/// parts BlauLoop cannot work out for itself. So this asks, and it asks
/// nothing it can answer.
///
/// Two of the answers have no default at all. Neither *what happened* nor
/// *and now?* is pre-selected, and the save button stays disabled until both
/// are given. A pre-ticked failure reason would write someone else's account
/// of their day into their history, and a pre-ticked outcome would move a
/// deadline they never agreed to move.
///
/// Nothing here interprets the report. It does not say what caused a failure,
/// whether it will happen again, or what to do about it — and the subtitle
/// says so out loud, at the one moment a user is most likely to expect
/// otherwise.
class ReportIncidentSheet extends ConsumerStatefulWidget {
  const ReportIncidentSheet({
    required this.card,
    required this.profile,
    super.key,
  });

  /// Opens the sheet for [card] and returns once it closes.
  ///
  /// The caller is responsible for only offering this where something is
  /// actually in use — see [DashboardCard.hasStarted]. The engine rejects the
  /// write as well, because a card can go stale between the tap and the save.
  static Future<void> show(
    BuildContext context, {
    required DashboardCard card,
    required UserProfile profile,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) =>
          ReportIncidentSheet(card: card, profile: profile),
    );
  }

  final DashboardCard card;
  final UserProfile profile;

  @override
  ConsumerState<ReportIncidentSheet> createState() =>
      _ReportIncidentSheetState();
}

class _ReportIncidentSheetState extends ConsumerState<ReportIncidentSheet> {
  final TextEditingController _notes = TextEditingController();

  /// The instant the sheet opened. Both the default answer and the latest one
  /// the pickers accept — a failure that has not happened yet is not a
  /// failure.
  late final DateTime _openedAt;

  late DateTime _occurredAt;

  /// When the replacement went on, if the user said it was not the same
  /// moment. Null means *the same moment*, which is what it is whenever a
  /// failure is dealt with as it happens.
  DateTime? _replacedAt;

  IncidentType? _type;
  IncidentOutcome? _outcome;
  bool _usePreferredTime = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _openedAt = ref.read(clockProvider).now();
    _occurredAt = _openedAt;
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  /// True while the report still holds the moment the sheet opened.
  bool get _isNow => _occurredAt == _openedAt;

  /// When the replacement went on.
  DateTime get _replacementAt => _replacedAt ?? _occurredAt;

  /// Whether to ask separately when the new one went on.
  ///
  /// Only once the failure has been moved into the past. Logged as it happens
  /// the two moments are the same, and asking twice for one answer is how a
  /// form teaches people to stop reading it. Moved into the past they can
  /// differ by hours, and hours are what the next deadline is made of.
  bool get _asksReplacementTime =>
      _outcome == IncidentOutcome.replaced && !_isNow;

  List<IncidentType> get _options =>
      incidentTypesFor(widget.card.type.category);

  CycleSchedule get _schedule => ref
      .read(cycleEngineProvider)
      .preview(
        type: widget.card.type,
        changedAt: _replacementAt,
        profileMinuteOfDay: widget.profile.preferredChangeMinuteOfDay,
      );

  @override
  Widget build(BuildContext context) {
    final bool replacing = _outcome == IncidentOutcome.replaced;
    final CycleSchedule schedule = _schedule;

    return SafeArea(
      child: ConstrainedBox(
        // A sheet that grows past the screen swallows its own save button.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        context.l10n.reportIncidentTitle,
                        style: context.textStyles.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        widget.card.type.name,
                        style: context.textStyles.titleMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        context.l10n.reportIncidentSubtitle,
                        style: context.textStyles.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      _FieldLabel(context.l10n.reportIncidentWhat),
                      const SizedBox(height: AppSpacing.sm),
                      _IncidentTypePicker(
                        options: _options,
                        selected: _type,
                        onChanged: _saving
                            ? null
                            : (IncidentType type) =>
                                  setState(() => _type = type),
                      ),
                      const Divider(height: AppSpacing.xl),

                      _MomentRow(
                        label: context.l10n.reportIncidentWhen,
                        moment: _occurredAt,
                        isNow: _isNow,
                        onEdit: _saving ? null : _pickOccurredAt,
                      ),
                      const Divider(height: AppSpacing.xl),

                      _FieldLabel(context.l10n.reportIncidentOutcome),
                      const SizedBox(height: AppSpacing.xs),
                      RadioGroup<IncidentOutcome>(
                        groupValue: _outcome,
                        onChanged: _selectOutcome,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            for (final IncidentOutcome outcome
                                in IncidentOutcome.values)
                              RadioListTile<IncidentOutcome>(
                                value: outcome,
                                enabled: !_saving,
                                contentPadding: EdgeInsets.zero,
                                title: Text(outcome.label(context.l10n)),
                              ),
                          ],
                        ),
                      ),

                      if (_asksReplacementTime) ...<Widget>[
                        const SizedBox(height: AppSpacing.sm),
                        _MomentRow(
                          label: context.l10n.reportIncidentReplacedWhen,
                          moment: _replacementAt,
                          isNow: false,
                          onEdit: _saving ? null : _pickReplacedAt,
                        ),
                      ],

                      if (replacing) ...<Widget>[
                        const Divider(height: AppSpacing.xl),
                        _NextChangeRow(
                          changeAt: schedule.changeAt(
                            usePreferredTime: _usePreferredTime,
                          ),
                        ),
                        if (schedule.offersPreferredTime)
                          CheckboxListTile(
                            value: _usePreferredTime,
                            onChanged: _saving
                                ? null
                                : (bool? checked) => setState(
                                    () => _usePreferredTime = checked ?? false,
                                  ),
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              context.l10n.registerChangePreferredOffer(
                                context.formatMinuteOfDay(
                                  schedule.preferredMinuteOfDay!,
                                ),
                              ),
                            ),
                          ),
                      ],

                      const Divider(height: AppSpacing.xl),
                      TextField(
                        controller: _notes,
                        enabled: !_saving,
                        maxLines: 3,
                        maxLength: 2000,
                        decoration: InputDecoration(
                          labelText: context.l10n.reportIncidentNotes,
                          hintText: context.l10n.reportIncidentNotesHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.sm),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: AppSpacing.sm,
                overflowAlignment: OverflowBarAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(context.l10n.actionCancel),
                  ),
                  FilledButton(
                    // Disabled rather than validated on submit: the two
                    // missing answers are visible on screen, and an error
                    // message telling someone to look up is worse than a
                    // button that waits for them.
                    onPressed: _saving || _type == null || _outcome == null
                        ? null
                        : _submit,
                    child: Text(context.l10n.reportIncidentSubmit),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectOutcome(IncidentOutcome? outcome) {
    setState(() {
      _outcome = outcome;
      if (outcome != IncidentOutcome.replaced) {
        // Nothing went on, so a time for it is a stale answer to a question
        // that is no longer being asked.
        _replacedAt = null;
        _usePreferredTime = false;
      }
    });
  }

  /// Asks for a date, then a time, bounded so a wrong answer cannot be
  /// produced: no earlier than the install this is about, no later than now.
  Future<DateTime?> _pickMoment({
    required DateTime initial,
    required DateTime earliest,
  }) async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(earliest.year, earliest.month, earliest.day),
      lastDate: _openedAt,
    );
    if (date == null || !mounted) {
      return null;
    }

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) {
      return null;
    }

    final DateTime picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    // Clamped rather than refused. Picking today and a time an hour from now
    // is a slip, not an intention, and losing the rest of the form over it
    // would be a poor trade.
    if (picked.isAfter(_openedAt)) {
      return _openedAt;
    }
    return picked.isBefore(earliest) ? earliest : picked;
  }

  Future<void> _pickOccurredAt() async {
    final DateTime earliest =
        widget.card.instance?.installedAt.toLocal() ??
        _openedAt.subtract(const Duration(days: 365));

    final DateTime? picked = await _pickMoment(
      initial: _occurredAt,
      earliest: earliest,
    );
    if (picked == null) {
      return;
    }

    setState(() {
      _occurredAt = picked;
      // A replacement time the user chose is kept, unless moving the failure
      // has left it in front of the thing it replaced.
      if (_replacedAt != null && _replacedAt!.isBefore(picked)) {
        _replacedAt = null;
      }
    });
  }

  Future<void> _pickReplacedAt() async {
    final DateTime? picked = await _pickMoment(
      initial: _replacementAt,
      earliest: _occurredAt,
    );
    if (picked != null) {
      setState(() => _replacedAt = picked);
    }
  }

  Future<void> _submit() async {
    setState(() => _saving = true);

    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String name = widget.card.type.name;
    final String saved = context.l10n.reportIncidentSaved(name);
    final String savedAndReplaced = context.l10n.reportIncidentSavedAndReplaced(
      name,
    );
    final String tooEarly = context.l10n.reportIncidentTooEarly;
    final String replacedTooEarly = context.l10n.reportIncidentReplacedTooEarly;
    final String nothingInUse = context.l10n.reportIncidentNothingInUse;
    final String failed = context.l10n.reportIncidentFailed;

    final IncidentReport report = IncidentReport(
      type: _type!,
      occurredAt: _occurredAt,
      outcome: _outcome!,
      notes: _notes.text,
    );

    String? error;
    IncidentRecord? record;
    try {
      record = await ref
          .read(cycleEngineProvider)
          .reportIncident(
            userProfileId: widget.profile.id,
            type: widget.card.type,
            report: report,
            replacedAt: _outcome == IncidentOutcome.replaced
                ? _replacementAt
                : null,
            profileMinuteOfDay: widget.profile.preferredChangeMinuteOfDay,
            usePreferredTime: _usePreferredTime,
          );
    } on ValidationFailure catch (failure) {
      error = switch (failure.field) {
        'occurredAt' => tooEarly,
        'replacedAt' => replacedTooEarly,
        'instance' => nothingInUse,
        _ => failed,
      };
    } on Object {
      error = failed;
    }

    if (!mounted) {
      return;
    }
    if (error != null) {
      setState(() => _saving = false);
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    navigator.pop();
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(record!.wasReplaced ? savedAndReplaced : saved)),
      );
  }
}

/// The failure reasons, most plausible for this consumable first.
///
/// A wrap of chips rather than a dropdown: fifteen options behind a menu is
/// fifteen options nobody reads, and a wrap is the one layout that reflows
/// rather than clips when the text is scaled up.
class _IncidentTypePicker extends StatelessWidget {
  const _IncidentTypePicker({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<IncidentType> options;
  final IncidentType? selected;
  final ValueChanged<IncidentType>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final IncidentType type in options)
          ChoiceChip(
            label: Text(type.label(context.l10n)),
            selected: selected == type,
            onSelected: onChanged == null ? null : (bool _) => onChanged!(type),
          ),
      ],
    );
  }
}

/// A moment, with the way to say it was a different one.
class _MomentRow extends StatelessWidget {
  const _MomentRow({
    required this.label,
    required this.moment,
    required this.isNow,
    required this.onEdit,
  });

  final String label;
  final DateTime moment;
  final bool isNow;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final String when = context.formatDayAndTime(moment);

    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _FieldLabel(label),
              const SizedBox(height: AppSpacing.xs),
              Text(
                isNow ? '${context.l10n.reportIncidentNow} · $when' : when,
                style: context.textStyles.titleMedium,
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onEdit,
          child: Text(context.l10n.reportIncidentEditTime),
        ),
      ],
    );
  }
}

/// The deadline the replacement cycle will be stored with.
class _NextChangeRow extends StatelessWidget {
  const _NextChangeRow({required this.changeAt});

  final DateTime? changeAt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _FieldLabel(context.l10n.reportIncidentNextTitle),
        const SizedBox(height: AppSpacing.xs),
        Text(
          changeAt == null
              ? context.l10n.registerChangeNoCountdown
              : context.formatDayAndTime(changeAt!),
          style: changeAt == null
              ? context.textStyles.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                )
              : context.textStyles.titleMedium,
        ),
      ],
    );
  }
}

/// The small heading above each answer, styled once so the sheet reads as one
/// form rather than a stack of unrelated controls.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.textStyles.labelMedium?.copyWith(
        color: context.colors.onSurfaceVariant,
      ),
    );
  }
}
