import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../shared/extensions/build_context_x.dart';
import '../../../shared/extensions/date_time_format.dart';
import '../../../shared/widgets/responsive_page.dart';
import '../../body_map/presentation/body_map_providers.dart';
import '../data/user_profile_repository.dart';
import 'settings_controller.dart';

/// One consumable: whether it is tracked, how long it lasts, when it warns.
///
/// The duration is the setting that matters most on this screen, and the one
/// the app is least entitled to an opinion about. BlauLoop's catalogue carries
/// wear times that have never been checked against a manufacturer, so the copy
/// here points at the box rather than at the app: a wrong duration is a
/// reminder on the wrong day, and a reminder on the wrong day teaches somebody
/// to ignore the reminders.
///
/// Changing a duration does **not** re-date what is already on the body. A
/// duration describes the next cycle; silently moving a deadline for something
/// already in use would be the app changing a fact it never observed.
class ConsumableSettingsScreen extends ConsumerWidget {
  const ConsumableSettingsScreen({required this.initial, super.key});

  /// The consumable as the list that opened this screen knew it.
  ///
  /// Held so the screen always has something to draw. Watching the database
  /// and falling back to a spinner looks reasonable and behaves badly: the
  /// screen would flash a loading indicator in the middle of the user changing
  /// something. The live row is used when it is there and this when it is not,
  /// so the screen only ever moves forward.
  final ConsumableType initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Every type, not the active ones. Reading the active list here is what
    // made turning a consumable off a one-way door: the row vanished from the
    // very screen holding the switch that would put it back.
    final ConsumableType type =
        ref
            .watch(everyConsumableTypeProvider)
            .value
            ?.where((ConsumableType candidate) => candidate.id == initial.id)
            .firstOrNull ??
        initial;

    return Scaffold(
      appBar: AppBar(title: Text(type.name)),
      body: SafeArea(child: _Body(type: type)),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.type});

  final ConsumableType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SettingsController settings = ref.watch(settingsControllerProvider);
    final UserProfile? profile = ref.watch(primaryProfileProvider).value;

    return ResponsivePage(
      children: <Widget>[
        SwitchListTile(
          value: type.active,
          onChanged: (bool value) => settings.setTracked(type.id, value),
          title: Text(context.l10n.settingsTracked),
          subtitle: Text(context.l10n.settingsConsumablesNote),
        ),

        const Divider(height: AppSpacing.xl),
        ListTile(
          title: Text(context.l10n.settingsDuration),
          subtitle: Text(context.formatDuration(_duration)),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () async {
            final int? days = await _DurationPrompt.show(
              context,
              initialDays: _duration?.inDays,
            );
            if (days != null) {
              await settings.setDuration(
                type.id,
                days == 0 ? null : Duration(days: days),
              );
            }
          },
        ),
        // The app is not the authority here, and says so.
        _Note(context.l10n.settingsDurationUnverified),

        const Divider(height: AppSpacing.xl),
        ListTile(
          title: Text(context.l10n.settingsOwnChangeTime),
          subtitle: Text(
            type.preferredChangeMinuteOfDay == null
                ? context.l10n.settingsFollowsProfile
                : context.formatMinuteOfDay(type.preferredChangeMinuteOfDay!),
          ),
          trailing: type.preferredChangeMinuteOfDay == null
              ? const Icon(Icons.edit_outlined)
              : TextButton(
                  // Back to null, which means *inherit* rather than *none* —
                  // the distinction the nullable column exists for.
                  onPressed: () => settings.setTypeChangeTime(type.id, null),
                  child: Text(context.l10n.settingsClearPreferredTime),
                ),
          onTap: () async {
            final int fallback =
                type.preferredChangeMinuteOfDay ??
                profile?.preferredChangeMinuteOfDay ??
                9 * 60;
            final TimeOfDay? picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(
                hour: fallback ~/ 60,
                minute: fallback % 60,
              ),
            );
            if (picked != null) {
              await settings.setTypeChangeTime(
                type.id,
                picked.hour * 60 + picked.minute,
              );
            }
          },
        ),

        const Divider(height: AppSpacing.xl),
        _RemindersSection(type: type, settings: settings),
      ],
    );
  }

  Duration? get _duration {
    final int? minutes = type.defaultDurationMinutes;
    return minutes == null ? null : Duration(minutes: minutes);
  }
}

/// Which lead times this consumable warns at.
///
/// Offered as a fixed set of ticks rather than a free-form list. The engine
/// normalises and deduplicates whatever it is given, so an arbitrary list
/// would be accepted — but a screen that lets somebody enter forty-seven
/// offsets is a screen that lets them spend the entire notification budget on
/// one sensor.
class _RemindersSection extends StatelessWidget {
  const _RemindersSection({required this.type, required this.settings});

  /// The lead times offered, longest first — the same set onboarding used.
  static const List<Duration> offered = <Duration>[
    Duration(hours: 48),
    Duration(hours: 24),
    Duration(hours: 6),
    Duration(hours: 1),
    Duration.zero,
  ];

  final ConsumableType type;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final Set<Duration> chosen = type.defaultReminderOffsets.toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(
            context.l10n.settingsReminders,
            style: context.textStyles.titleSmall,
          ),
        ),
        if (chosen.isEmpty) _Note(context.l10n.settingsRemindersNone),
        for (final Duration offset in offered)
          CheckboxListTile(
            value: chosen.contains(offset),
            onChanged: (bool? ticked) {
              final Set<Duration> next = <Duration>{...chosen};
              (ticked ?? false) ? next.add(offset) : next.remove(offset);
              settings.setReminderOffsets(type.id, next.toList());
            },
            title: Text(context.formatReminderOffset(offset)),
          ),
      ],
    );
  }
}

/// Asks for a wear time in whole days.
///
/// Days, because that is the unit every box states. Zero means *counted, not
/// timed* — the consumable keeps its log and loses its countdown, which is a
/// real thing somebody wants for test strips.
class _DurationPrompt extends StatefulWidget {
  const _DurationPrompt({required this.initialDays});

  static Future<int?> show(BuildContext context, {int? initialDays}) {
    return showDialog<int>(
      context: context,
      builder: (BuildContext context) =>
          _DurationPrompt(initialDays: initialDays),
    );
  }

  final int? initialDays;

  @override
  State<_DurationPrompt> createState() => _DurationPromptState();
}

class _DurationPromptState extends State<_DurationPrompt> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialDays == null ? '' : '${widget.initialDays}',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.settingsDuration),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              labelText: context.l10n.settingsDurationField,
              errorText: _error,
            ),
            onSubmitted: (String _) => _submit(),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.l10n.settingsDurationUnverified,
            style: context.textStyles.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.actionCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(context.l10n.actionSave)),
      ],
    );
  }

  void _submit() {
    final int? days = int.tryParse(_controller.text.trim());
    if (days == null || days < 0) {
      setState(() => _error = context.l10n.inventoryInvalidQuantity);
      return;
    }
    Navigator.of(context).pop(days);
  }
}

/// The small print under a setting.
class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        text,
        style: context.textStyles.bodySmall?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
