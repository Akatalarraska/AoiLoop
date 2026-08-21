import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/clock.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/extensions/body_enums_l10n.dart';
import '../../../shared/extensions/build_context_x.dart';
import '../../../shared/extensions/cycle_countdown_l10n.dart';
import '../../../shared/extensions/date_time_format.dart';
import '../../body_map/domain/body_map_view.dart';
import '../../body_map/domain/body_site_choice.dart';
import '../../body_map/presentation/body_map_providers.dart';
import '../../body_map/presentation/body_site_picker.dart';
import '../../dashboard/domain/dashboard_view.dart';
import '../../inventory/presentation/stock_note.dart';
import '../data/cycle_engine.dart';
import '../domain/cycle_schedule.dart';

/// Registers that a consumable was replaced.
///
/// Deliberately small. Everything it asks for is something the engine cannot
/// work out on its own — *when* it happened, and whether to accept the shift
/// to the user's preferred time — and everything it shows is a consequence of
/// those two answers. Body site belongs to a later phase, and a failure
/// belongs to `ReportIncidentSheet`, which the same menu offers one row down;
/// putting either here would make the common case, a routine change logged as
/// it happens, several taps longer than it needs to be.
///
/// The one thing that appears conditionally is the reason for an early
/// change, and only when the chosen moment actually makes it one. This is the
/// sheet a deliberate early swap goes through — a trip, a shower, a planned
/// change — and a history that records those with no explanation is a history
/// nobody can read a month later.
///
/// The dashboard is not told to refresh. `watchActive` is a Drift stream, so
/// closing one instance and opening another redraws Home on its own.
class RegisterChangeSheet extends ConsumerStatefulWidget {
  const RegisterChangeSheet({
    required this.card,
    required this.profile,
    super.key,
  });

  /// Opens the sheet for [card] and returns once it closes.
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
          RegisterChangeSheet(card: card, profile: profile),
    );
  }

  /// Opens the sheet for whatever [view] says is next, asking first when
  /// there is no single answer.
  ///
  /// Home's summary button has to work in the state every user starts in:
  /// several consumables set up and none of them counting down, where "the
  /// next change" does not exist yet. Guessing one and being wrong is worse
  /// than one extra tap, so that case gets a chooser. Once anything is
  /// counting down there *is* an answer, and the button goes straight to it.
  static Future<void> showForView(
    BuildContext context, {
    required DashboardView view,
  }) async {
    final DashboardCard? unambiguous =
        view.nextChange ?? (view.cards.length == 1 ? view.cards.single : null);

    final DashboardCard? card =
        unambiguous ?? await _ChooseConsumableSheet.show(context, view: view);
    if (card == null || !context.mounted) {
      return;
    }
    return show(context, card: card, profile: view.profile);
  }

  final DashboardCard card;
  final UserProfile profile;

  @override
  ConsumerState<RegisterChangeSheet> createState() =>
      _RegisterChangeSheetState();
}

class _RegisterChangeSheetState extends ConsumerState<RegisterChangeSheet> {
  /// Why the change is early. Only ever asked for when it is.
  final TextEditingController _reason = TextEditingController();

  /// The moment the change happened, in local time because that is how it was
  /// picked. Converted on the way to the engine, never before.
  late DateTime _changedAt;

  /// The instant the sheet opened, which is both the default answer and the
  /// latest one the pickers will accept.
  late final DateTime _openedAt;

  bool _usePreferredTime = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _openedAt = ref.read(clockProvider).now();
    _changedAt = _openedAt;
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  /// Where the new one is going.
  ///
  /// Null until the user says otherwise, which means *wherever the last one
  /// was*. Holding "unset" rather than eagerly copying the previous site is
  /// what lets the engine tell a deliberate move from a routine change.
  BodySiteChoice? _site;

  /// The site id that will actually be written.
  String? get _effectiveSiteId =>
      _site != null ? _site!.siteId : widget.card.instance?.bodySiteId;

  bool get _siteIsCarriedOver => _site == null;

  /// The chosen site's own name, read from the body map so the sheet and the
  /// picker cannot disagree about what a site is called.
  String? get _siteLabel {
    final String? id = _effectiveSiteId;
    if (id == null) {
      return null;
    }
    final BodySiteCard? card = ref.watch(bodyMapProvider).value?.cardFor(id);
    return card?.region.label(context.l10n);
  }

  Future<void> _pickSite() async {
    final BodySiteChoice? choice = await BodySitePicker.show(
      context,
      selectedSiteId: _effectiveSiteId,
    );
    if (choice != null && mounted) {
      setState(() => _site = choice);
    }
  }

  /// True while the sheet still holds the moment it opened with, which is the

  /// overwhelmingly common case: someone logging a change as they make it.
  bool get _isNow => _changedAt == _openedAt;

  /// Whether this change will go into the history as an early removal.
  ///
  /// Asked of the engine rather than worked out here, so the sheet and the
  /// row it writes agree about where "early" starts.
  bool get _isEarly => ref
      .read(cycleEngineProvider)
      .wouldBeEarly(widget.card.instance, _changedAt);

  CycleSchedule get _schedule => ref
      .read(cycleEngineProvider)
      .preview(
        type: widget.card.type,
        changedAt: _changedAt,
        profileMinuteOfDay: widget.profile.preferredChangeMinuteOfDay,
      );

  @override
  Widget build(BuildContext context) {
    final CycleSchedule schedule = _schedule;

    return SafeArea(
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
            Text(
              context.l10n.registerChangeTitle(widget.card.type.name),
              style: context.textStyles.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.lg),

            _WhenRow(
              changedAt: _changedAt,
              isNow: _isNow,
              onEdit: _saving ? null : _pickMoment,
            ),
            const Divider(height: AppSpacing.xl),

            _SiteRow(
              siteLabel: _siteLabel,
              isCarriedOver: _siteIsCarriedOver,
              onEdit: _saving ? null : _pickSite,
            ),
            const Divider(height: AppSpacing.xl),

            _NextChangeRow(
              changeAt: schedule.changeAt(usePreferredTime: _usePreferredTime),
            ),

            if (schedule.offersPreferredTime) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              _PreferredTimeOffer(
                // From the schedule, not from the profile. Since v3 a type can
                // carry its own change time, and the label has to name the
                // hour the date was actually computed at — otherwise the offer
                // reads "move to 20:00" above a deadline of 08:00.
                minuteOfDay: schedule.preferredMinuteOfDay!,
                value: _usePreferredTime,
                onChanged: _saving
                    ? null
                    : (bool value) => setState(() => _usePreferredTime = value),
              ),
            ],

            if (_isEarly) ...<Widget>[
              const Divider(height: AppSpacing.xl),
              _EarlyChangeReason(controller: _reason, enabled: !_saving),
            ],

            const SizedBox(height: AppSpacing.lg),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: AppSpacing.sm,
              overflowAlignment: OverflowBarAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: Text(context.l10n.actionCancel),
                ),
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: Text(context.l10n.actionRegisterChange),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Asks for a date, then a time.
  ///
  /// Bounded at both ends rather than validated afterwards: the earliest
  /// acceptable moment is when the thing being replaced went on, and the
  /// latest is now, because a change that has not happened yet is not a
  /// change. Two pickers that cannot produce a wrong answer beat one error
  /// message.
  Future<void> _pickMoment() async {
    final DateTime earliest =
        widget.card.instance?.installedAt.toLocal() ??
        _openedAt.subtract(const Duration(days: 365));

    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _changedAt,
      firstDate: DateTime(earliest.year, earliest.month, earliest.day),
      lastDate: _openedAt,
    );
    if (date == null || !mounted) {
      return;
    }

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_changedAt),
    );
    if (time == null || !mounted) {
      return;
    }

    final DateTime picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      // Clamped rather than refused: picking today's date and a time an hour
      // from now is a slip, not an intention, and the sheet should not lose
      // the rest of what was entered over it.
      _changedAt = picked.isAfter(_openedAt) ? _openedAt : picked;
      if (picked.isBefore(earliest)) {
        _changedAt = earliest;
      }
    });
  }

  Future<void> _submit() async {
    setState(() => _saving = true);

    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String saved = context.l10n.registerChangeSaved(
      widget.card.type.name,
    );
    final String tooEarly = context.l10n.registerChangeTooEarly;
    final String failed = context.l10n.registerChangeFailed;

    // Read before the await, and normalised: a field someone tapped into and
    // left is an empty string, and storing '' would leave a change claiming a
    // reason that reads as blank.
    final String trimmed = _reason.text.trim();
    final String? reason = trimmed.isEmpty ? null : trimmed;

    final AppLocalizations l10n = context.l10n;

    String? error;
    CycleTransition? transition;
    try {
      transition = await ref
          .read(cycleEngineProvider)
          .registerChange(
            userProfileId: widget.profile.id,
            type: widget.card.type,
            changedAt: _changedAt,
            profileMinuteOfDay: widget.profile.preferredChangeMinuteOfDay,
            usePreferredTime: _usePreferredTime,
            placement: _site,
            notes: reason,
          );
    } on ValidationFailure {
      error = tooEarly;
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
    final String? note = stockNote(
      l10n,
      transition!.stock,
      widget.card.type.name,
    );
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(note == null ? saved : '$saved $note')),
      );
  }
}

/// What the history will say, and the chance to add why.
///
/// Shown only when the change lands before the deadline, so a routine on-time
/// swap stays the two-tap job it should be. The notice comes first because the
/// user is entitled to know what is being written down about them before they
/// are asked to explain it — and it is phrased as a record, not a reproach.
/// Changing something early is a thing people do for good reasons, and an app
/// that tuts at them is one they stop telling the truth to.
class _EarlyChangeReason extends StatelessWidget {
  const _EarlyChangeReason({required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.registerChangeEarlyNotice,
          style: context.textStyles.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: controller,
          enabled: enabled,
          maxLines: 2,
          maxLength: 2000,
          decoration: InputDecoration(
            labelText: context.l10n.registerChangeReason,
            hintText: context.l10n.registerChangeReasonHint,
          ),
        ),
      ],
    );
  }
}

/// Where the consumable is going, and the way to say somewhere else.
///
/// Shows the site that will actually be stored — the one carried over from
/// the last change unless the user names another — for the same reason the
/// deadline row shows the date that will be stored. A preview that disagreed
/// with what was saved would be worse than no preview.
class _SiteRow extends StatelessWidget {
  const _SiteRow({
    required this.siteLabel,
    required this.isCarriedOver,
    required this.onEdit,
  });

  /// The site's own name, or null when none is recorded.
  final String? siteLabel;

  /// Whether this is simply where the last one was.
  final bool isCarriedOver;

  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.l10n.sitePickerWhere,
                style: context.textStyles.labelMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                siteLabel ?? context.l10n.sitePickerNone,
                style: context.textStyles.titleMedium,
              ),
              if (siteLabel != null && isCarriedOver)
                Text(
                  context.l10n.sitePickerSame,
                  style: context.textStyles.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        TextButton(
          onPressed: onEdit,
          child: Text(
            siteLabel == null
                ? context.l10n.sitePickerChoose
                : context.l10n.sitePickerChange,
          ),
        ),
      ],
    );
  }
}

/// Asks which of the tracked consumables was replaced.
///
/// Returns the chosen card, or null if the sheet was dismissed.
class _ChooseConsumableSheet extends StatelessWidget {
  const _ChooseConsumableSheet({required this.view});

  static Future<DashboardCard?> show(
    BuildContext context, {
    required DashboardView view,
  }) {
    return showModalBottomSheet<DashboardCard>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) => _ChooseConsumableSheet(view: view),
    );
  }

  final DashboardView view;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              context.l10n.registerChangeChooseTitle,
              style: context.textStyles.headlineSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: <Widget>[
                for (final DashboardCard card in view.cards)
                  ListTile(
                    title: Text(card.type.name),
                    subtitle: Text(card.countdown.label(context.l10n)),
                    onTap: () => Navigator.of(context).pop(card),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

/// When the change happened, and the way to say otherwise.
class _WhenRow extends StatelessWidget {
  const _WhenRow({
    required this.changedAt,
    required this.isNow,
    required this.onEdit,
  });

  final DateTime changedAt;
  final bool isNow;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final String when = context.formatDayAndTime(changedAt);

    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.l10n.registerChangeWhen,
                style: context.textStyles.labelMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                isNow ? '${context.l10n.registerChangeNow} · $when' : when,
                style: context.textStyles.titleMedium,
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onEdit,
          child: Text(context.l10n.registerChangeEditTime),
        ),
      ],
    );
  }
}

/// The deadline this change will actually store.
///
/// Shows the selected date rather than the natural one, so the number on
/// screen is the number in the database. A preview that disagreed with what
/// was saved would be worse than no preview.
class _NextChangeRow extends StatelessWidget {
  const _NextChangeRow({required this.changeAt});

  final DateTime? changeAt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.registerChangeNextTitle,
          style: context.textStyles.labelMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
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

/// The offer to end the new cycle at the user's preferred time of day.
class _PreferredTimeOffer extends StatelessWidget {
  const _PreferredTimeOffer({
    required this.minuteOfDay,
    required this.value,
    required this.onChanged,
  });

  final int minuteOfDay;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged == null
          ? null
          : (bool? checked) => onChanged!(checked ?? false),
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(
        context.l10n.registerChangePreferredOffer(
          context.formatMinuteOfDay(minuteOfDay),
        ),
      ),
    );
  }
}
