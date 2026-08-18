import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../onboarding_controller.dart';
import '../widgets/onboarding_step_layout.dart';

/// Language choice, applied the instant it is tapped.
///
/// Each language is written in itself — *Español*, *English* — so it can be
/// found by someone who cannot read the language the app happens to be in.
class LanguageStep extends ConsumerWidget {
  const LanguageStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? chosen = ref
        .watch(onboardingControllerProvider)
        .draft
        .languageCode;
    // Before an explicit choice, the ticked option is whatever the app is
    // already showing, which is the system language.
    final String effective =
        chosen ?? Localizations.localeOf(context).languageCode;

    return OnboardingStepLayout(
      title: context.l10n.onboardingLanguageTitle,
      body: context.l10n.onboardingLanguageBody,
      children: <Widget>[
        RadioGroup<String>(
          groupValue: effective,
          onChanged: (String? value) {
            if (value != null) {
              ref
                  .read(onboardingControllerProvider.notifier)
                  .setLanguage(value);
            }
          },
          child: Column(
            children: <Widget>[
              for (final (String code, String label) in <(String, String)>[
                ('es', context.l10n.languageSpanish),
                ('en', context.l10n.languageEnglish),
              ])
                RadioListTile<String>(value: code, title: Text(label)),
            ],
          ),
        ),
      ],
    );
  }
}
