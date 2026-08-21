import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../shared/extensions/build_context_x.dart';
import '../../../shared/widgets/responsive_page.dart';
import '../../settings/data/user_profile_repository.dart';
import '../data/inventory_repository.dart';
import 'inventory_providers.dart';

/// The places supplies are kept.
///
/// Optional, and the screen says so: most people keep everything in one
/// cupboard and never need this. It exists because a child at school or a
/// second household is exactly the situation BlauLoop is for, and "I have
/// eight sensors" is the wrong answer when six of them are at the other house.
///
/// Removing a place hides it rather than deleting it, and the stock filed in
/// it survives — it simply stops being filed anywhere.
class InventoryLocationsScreen extends ConsumerWidget {
  const InventoryLocationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<InventoryLocation> locations =
        ref.watch(inventoryLocationsProvider).value ??
        const <InventoryLocation>[];

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.inventoryLocations)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addLocation(context, ref),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.inventoryLocationAdd),
      ),
      body: SafeArea(
        child: ResponsivePage(
          children: <Widget>[
            Text(
              context.l10n.inventoryLocationsIntro,
              style: context.textStyles.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            if (locations.isEmpty)
              Text(
                context.l10n.inventoryLocationsEmpty,
                style: context.textStyles.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              )
            else
              for (final InventoryLocation location in locations)
                ListTile(
                  key: ValueKey<String>(location.id),
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text(location.name),
                  trailing: TextButton(
                    onPressed: () => ref
                        .read(inventoryRepositoryProvider)
                        .deactivateLocation(location.id),
                    child: Text(context.l10n.inventoryLocationRemove),
                  ),
                ),

            // Clears the floating button.
            const SizedBox(height: AppSpacing.xxxl * 2),
          ],
        ),
      ),
    );
  }

  Future<void> _addLocation(BuildContext context, WidgetRef ref) async {
    final String? name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) => const _NewLocationSheet(),
    );

    final UserProfile? profile = ref.read(primaryProfileProvider).value;
    if (name == null || profile == null) {
      return;
    }
    await ref
        .read(inventoryRepositoryProvider)
        .createLocation(userProfileId: profile.id, name: name);
  }
}

/// Asks for a name and nothing else.
class _NewLocationSheet extends StatefulWidget {
  const _NewLocationSheet();

  @override
  State<_NewLocationSheet> createState() => _NewLocationSheetState();
}

class _NewLocationSheetState extends State<_NewLocationSheet> {
  final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              context.l10n.inventoryLocationAdd,
              style: context.textStyles.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: context.l10n.inventoryLocationName,
              ),
              onChanged: (String _) => setState(() {}),
              onSubmitted: (String _) => _submit(),
            ),
            const SizedBox(height: AppSpacing.sm),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: AppSpacing.sm,
              overflowAlignment: OverflowBarAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.l10n.actionCancel),
                ),
                FilledButton(
                  // A place needs a name; the column requires one and an
                  // unnamed place would be unfindable anyway.
                  onPressed: _name.text.trim().isEmpty ? null : _submit,
                  child: Text(context.l10n.actionAdd),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final String name = _name.text.trim();
    if (name.isNotEmpty) {
      Navigator.of(context).pop(name);
    }
  }
}
