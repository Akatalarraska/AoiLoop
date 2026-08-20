import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../shared/extensions/build_context_x.dart';
import '../data/local_notification_gateway.dart';
import '../data/notification_scheduler.dart';
import 'reminder_providers.dart';

/// Says, on Home, that reminders are not running.
///
/// An app that quietly fails to remind someone is worse than one that never
/// offered to. The whole point of the ledger under this is that AoiLoop can
/// tell the difference between "nothing is due" and "nothing can be
/// delivered", and this is where it says so.
///
/// Renders nothing when reminders are working, and nothing while the answer is
/// still being fetched — a banner that appears for one frame on every launch
/// would train people to ignore it.
class RemindersOffBanner extends ConsumerWidget {
  const RemindersOffBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ReminderSync? sync = ref.watch(reminderSyncProvider).value;
    if (sync == null || sync.enabled) {
      return const SizedBox.shrink();
    }

    return Card(
      color: context.colors.secondaryContainer,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                // Decorative: the heading beside it carries the meaning.
                ExcludeSemantics(
                  child: Icon(
                    Icons.notifications_off_outlined,
                    size: 20,
                    color: context.colors.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    context.l10n.notificationsOffTitle,
                    style: context.textStyles.labelLarge?.copyWith(
                      color: context.colors.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.l10n.notificationsOffBody,
              style: context.textStyles.bodyMedium?.copyWith(
                color: context.colors.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: () => _request(context, ref),
                child: Text(context.l10n.notificationsOffAction),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _request(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String denied = context.l10n.notificationsOffDenied;

    final bool granted = await ref
        .read(notificationGatewayProvider)
        .requestPermission();

    if (!granted) {
      // Said once, plainly. Once the OS has been told no, the app cannot ask
      // again — the dialog simply does not appear — so offering to retry would
      // be a button that does nothing.
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(denied)));
      return;
    }

    // Granted: everything the app wanted to schedule is still unscheduled, so
    // rebuild rather than waiting for the next launch.
    ref.invalidate(reminderSyncProvider);
  }
}
