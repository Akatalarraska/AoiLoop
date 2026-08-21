import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/locale/locale_providers.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/constants/app_info.dart';
import '../../../core/database/app_database.dart';
import '../../../shared/extensions/build_context_x.dart';
import '../../../shared/extensions/date_time_format.dart';
import '../../../shared/extensions/profile_enums_l10n.dart';
import '../../../shared/widgets/responsive_page.dart';
import '../../body_map/presentation/body_map_providers.dart';
import '../data/user_profile_repository.dart';
import 'consumable_settings_screen.dart';
import 'settings_controller.dart';

/// Everything onboarding asked, and the way to change your mind about it.
///
/// Onboarding has collected these answers since Phase 2 and offered no way
/// back to them for eight phases. Every screen that said "arrives with the
/// settings screen" was pointing here.
///
/// Two rules shape it. Nothing is destructive: turning a consumable off hides
/// it and keeps its history, because the first mistap must not cost a record.
/// And no setting quietly changes a date — the preferred change time is still
/// only an offer, and the screen says so where it is set rather than leaving
/// the user to discover it.
///
/// Pushed over `MainShell`, so it owns its app bar and back button.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UserProfile? profile = ref.watch(primaryProfileProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.sectionSettings)),
      body: SafeArea(
        child: profile == null
            ? Center(
                child: Semantics(
                  label: context.l10n.loading,
                  child: const CircularProgressIndicator.adaptive(),
                ),
              )
            : _SettingsBody(profile: profile),
      ),
    );
  }
}

class _SettingsBody extends ConsumerWidget {
  const _SettingsBody({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<ConsumableType> types =
        ref.watch(everyConsumableTypeProvider).value ??
        const <ConsumableType>[];

    return ResponsivePage(
      children: <Widget>[
        _SectionHeading(context.l10n.settingsYouTitle),
        _NameTile(profile: profile),
        _LanguageTile(profile: profile),
        _UnitsTile(profile: profile),

        const Divider(height: AppSpacing.xl),
        _SectionHeading(context.l10n.settingsChangesTitle),
        _PreferredTimeTile(profile: profile),

        const Divider(height: AppSpacing.xl),
        _SectionHeading(context.l10n.settingsConsumablesTitle),
        _Note(context.l10n.settingsConsumablesNote),
        for (final ConsumableType type in types)
          ListTile(
            key: ValueKey<String>(type.id),
            title: Text(type.name),
            subtitle: Text(_summarise(context, type)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) =>
                    ConsumableSettingsScreen(initial: type),
              ),
            ),
          ),

        const Divider(height: AppSpacing.xl),
        _SectionHeading(context.l10n.settingsAboutTitle),
        ListTile(
          title: Text(context.l10n.settingsVersion(AppInfo.version)),
          subtitle: Text(context.l10n.medicalDisclaimerShort),
        ),
      ],
    );
  }

  /// The one line under a consumable's name: whether it is tracked, and how
  /// long it is expected to last.
  String _summarise(BuildContext context, ConsumableType type) {
    if (!type.active) {
      return context.l10n.settingsConsumableOff;
    }
    return context.formatDuration(
      type.defaultDurationMinutes == null
          ? null
          : Duration(minutes: type.defaultDurationMinutes!),
    );
  }
}

/// The name Home greets the user by.
class _NameTile extends ConsumerWidget {
  const _NameTile({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(context.l10n.settingsName),
      subtitle: Text(profile.displayName),
      trailing: const Icon(Icons.edit_outlined),
      onTap: () async {
        final String? name = await _TextPrompt.show(
          context,
          title: context.l10n.settingsName,
          hint: context.l10n.settingsNameHint,
          initial: profile.displayName,
          emptyError: context.l10n.settingsNameRequired,
        );
        if (name != null) {
          await ref.read(settingsControllerProvider).setName(name);
        }
      },
    );
  }
}

/// The language the app runs in.
class _LanguageTile extends ConsumerWidget {
  const _LanguageTile({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ListTile(
          title: Text(context.l10n.settingsLanguage),
          trailing: DropdownButton<String>(
            value: profile.languageCode,
            onChanged: (String? code) async {
              if (code == null) {
                return;
              }
              // Applied in the same frame and stored, the way onboarding does
              // it. A language that took effect on the next launch would read
              // as the setting not having worked.
              ref.read(localeOverrideProvider.notifier).set(Locale(code));
              await ref.read(settingsControllerProvider).setLanguage(code);
            },
            items: <DropdownMenuItem<String>>[
              for (final String code in AppInfo.supportedLanguageCodes)
                DropdownMenuItem<String>(
                  value: code,
                  child: Text(_languageName(code)),
                ),
            ],
          ),
        ),
        _Note(context.l10n.settingsLanguageNote),
      ],
    );
  }

  /// Each language named in itself, which is how somebody who cannot read the
  /// current one finds their way out.
  static String _languageName(String code) => switch (code) {
    'es' => 'Español',
    _ => 'English',
  };
}

/// How glucose numbers are written, if the user writes one down.
class _UnitsTile extends ConsumerWidget {
  const _UnitsTile({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ListTile(
          title: Text(context.l10n.settingsUnits),
          trailing: DropdownButton<GlucoseUnit>(
            value: profile.glucoseUnit,
            onChanged: (GlucoseUnit? unit) async {
              if (unit != null) {
                await ref.read(settingsControllerProvider).setUnit(unit);
              }
            },
            items: <DropdownMenuItem<GlucoseUnit>>[
              for (final GlucoseUnit unit in GlucoseUnit.values)
                DropdownMenuItem<GlucoseUnit>(
                  value: unit,
                  child: Text(unit.label(context.l10n)),
                ),
            ],
          ),
        ),
        // The one setting that could imply BlauLoop does something with
        // glucose. It does not, and this is where to say so.
        _Note(context.l10n.settingsUnitsNote),
      ],
    );
  }
}

/// The hour of day the user would rather make changes at.
class _PreferredTimeTile extends ConsumerWidget {
  const _PreferredTimeTile({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int? minute = profile.preferredChangeMinuteOfDay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ListTile(
          title: Text(context.l10n.settingsPreferredTime),
          subtitle: Text(
            minute == null
                ? context.l10n.settingsPreferredTimeNone
                : context.formatMinuteOfDay(minute),
          ),
          trailing: minute == null
              ? const Icon(Icons.edit_outlined)
              : TextButton(
                  onPressed: () => ref
                      .read(settingsControllerProvider)
                      .setPreferredTime(null),
                  child: Text(context.l10n.settingsClearPreferredTime),
                ),
          onTap: () async {
            final TimeOfDay? picked = await showTimePicker(
              context: context,
              initialTime: minute == null
                  ? const TimeOfDay(hour: 9, minute: 0)
                  : TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
            );
            if (picked != null) {
              await ref
                  .read(settingsControllerProvider)
                  .setPreferredTime(picked.hour * 60 + picked.minute);
            }
          },
        ),
        _Note(context.l10n.settingsPreferredTimeNote),
      ],
    );
  }
}

/// A settings section heading.
class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.sm),
      child: Text(
        text,
        style: context.textStyles.titleSmall?.copyWith(
          color: context.colors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The small print under a setting, where a setting needs explaining.
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

/// Asks for one line of text.
class _TextPrompt extends StatefulWidget {
  const _TextPrompt({
    required this.title,
    required this.hint,
    required this.initial,
    required this.emptyError,
  });

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String hint,
    required String initial,
    required String emptyError,
  }) {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) => _TextPrompt(
        title: title,
        hint: hint,
        initial: initial,
        emptyError: emptyError,
      ),
    );
  }

  final String title;
  final String hint;
  final String initial;
  final String emptyError;

  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
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
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 60,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(errorText: _error),
            onSubmitted: (String _) => _submit(),
          ),
          Text(
            widget.hint,
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
    final String value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _error = widget.emptyError);
      return;
    }
    Navigator.of(context).pop(value);
  }
}
