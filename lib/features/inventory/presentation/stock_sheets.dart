import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../shared/extensions/build_context_x.dart';
import '../../../shared/extensions/date_time_format.dart';
import '../../settings/data/user_profile_repository.dart';
import '../data/inventory_repository.dart';
import '../domain/inventory_view.dart';
import 'inventory_providers.dart';

/// What the user is being asked for.
enum StockAction {
  /// Units arriving from the pharmacy, as a new batch.
  add,

  /// The real number, replacing whatever the app thought.
  correct,

  /// The level to warn at.
  minimum,
}

/// Adds stock, corrects a count, or sets the level to warn at.
///
/// One sheet for three jobs because they are the same shape — a whole number
/// and a confirm — and three near-identical sheets would drift apart in copy
/// and in validation.
///
/// Correcting by hand is deliberately as prominent as adding. Automatic
/// decrementing is a convenience, and a convenience the user cannot override
/// is a trap: counts drift, boxes get borrowed, someone else restocks the
/// cupboard. The person holding the supplies is the authority, and the app
/// must never argue with them about what is in their own drawer.
class StockSheet extends ConsumerStatefulWidget {
  const StockSheet({required this.card, required this.action, super.key});

  static Future<bool> show(
    BuildContext context, {
    required InventoryCard card,
    required StockAction action,
  }) async {
    final bool? saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) => StockSheet(card: card, action: action),
    );
    return saved ?? false;
  }

  final InventoryCard card;
  final StockAction action;

  @override
  ConsumerState<StockSheet> createState() => _StockSheetState();
}

class _StockSheetState extends ConsumerState<StockSheet> {
  late final TextEditingController _amount;
  String? _lot;
  DateTime? _expiry;
  String? _locationId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Adding starts empty, because the answer is whatever just arrived and any
    // number the app suggested would be a guess. The other two start at what
    // is already stored, because those are corrections to a known figure.
    _amount = TextEditingController(
      text: switch (widget.action) {
        StockAction.add => '',
        StockAction.correct => '${widget.card.total}',
        StockAction.minimum => '${widget.card.minimum}',
      },
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  String get _title => switch (widget.action) {
    StockAction.add => context.l10n.inventoryAddStock,
    StockAction.correct => context.l10n.inventoryCorrectCount,
    StockAction.minimum => context.l10n.inventorySetMinimum,
  };

  String get _label => switch (widget.action) {
    StockAction.add => context.l10n.inventoryAddQuantity,
    StockAction.correct => context.l10n.inventoryExactQuantity,
    StockAction.minimum => context.l10n.inventoryMinimumField,
  };

  @override
  Widget build(BuildContext context) {
    final bool isAdding = widget.action == StockAction.add;
    final List<InventoryLocation> locations =
        ref.watch(inventoryLocationsProvider).value ??
        const <InventoryLocation>[];

    return SafeArea(
      child: ConstrainedBox(
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
                      Text(_title, style: context.textStyles.headlineSmall),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        widget.card.type.name,
                        style: context.textStyles.titleMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      TextField(
                        controller: _amount,
                        enabled: !_saving,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: _label,
                          helperText: widget.action == StockAction.minimum
                              ? context.l10n.inventoryMinimumHint
                              : null,
                          errorText: _error,
                        ),
                      ),

                      if (isAdding) ...<Widget>[
                        const SizedBox(height: AppSpacing.lg),
                        TextField(
                          enabled: !_saving,
                          onChanged: (String value) => _lot = value,
                          decoration: InputDecoration(
                            labelText: context.l10n.inventoryLotOptional,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _ExpiryRow(
                          expiry: _expiry,
                          onEdit: _saving ? null : _pickExpiry,
                        ),
                        if (locations.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.lg),
                          _LocationField(
                            locations: locations,
                            selected: _locationId,
                            enabled: !_saving,
                            onChanged: (String? id) =>
                                setState(() => _locationId = id),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: AppSpacing.sm,
                overflowAlignment: OverflowBarAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: Text(context.l10n.actionCancel),
                  ),
                  FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: Text(context.l10n.actionSave),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickExpiry() async {
    final DateTime today = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expiry ?? today,
      // Stock already past its date is a real thing to have in a cupboard, and
      // recording it is how the user finds out. Refusing the date would only
      // hide it.
      firstDate: DateTime(today.year - 5),
      lastDate: DateTime(today.year + 15),
    );
    if (picked != null && mounted) {
      setState(() => _expiry = picked);
    }
  }

  Future<void> _submit() async {
    final int? value = int.tryParse(_amount.text.trim());
    if (value == null || value < 0) {
      setState(() => _error = context.l10n.inventoryInvalidQuantity);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String saved = context.l10n.inventorySaved;
    final String failed = context.l10n.inventoryFailed;

    bool ok = true;
    try {
      await _write(value);
    } on Object {
      ok = false;
    }

    if (!mounted) {
      return;
    }
    if (!ok) {
      setState(() => _saving = false);
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(failed)));
      return;
    }

    navigator.pop(true);
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(saved)));
  }

  Future<void> _write(int value) async {
    final InventoryRepository repository = ref.read(
      inventoryRepositoryProvider,
    );
    final UserProfile profile = ref.read(primaryProfileProvider).requireValue!;

    switch (widget.action) {
      case StockAction.add:
        // A new batch rather than a bump to an existing one, because a
        // delivery has its own lot number and its own expiry date. Merging it
        // into the last batch would attribute this box's date to that one.
        await repository.createItem(
          userProfileId: profile.id,
          consumableTypeId: widget.card.type.id,
          quantity: value,
          minimumQuantity: widget.card.minimum,
          locationId: _locationId,
          lotNumber: _lot?.trim().isEmpty ?? true ? null : _lot!.trim(),
          expirationDate: _expiry,
        );

      case StockAction.correct:
        await _correctTo(repository, profile, value);

      case StockAction.minimum:
        await repository.setTypeMinimum(
          userProfileId: profile.id,
          consumableTypeId: widget.card.type.id,
          minimum: value,
        );
    }
  }

  /// Makes the total equal [value], across however many batches there are.
  ///
  /// The user answers for the consumable, not for a carton — they counted what
  /// is in the drawer. So the correction is applied to the batch expiring
  /// soonest and the rest are emptied, which keeps the total honest and keeps
  /// the stock that survives the correction the stock that goes off first.
  Future<void> _correctTo(
    InventoryRepository repository,
    UserProfile profile,
    int value,
  ) async {
    final List<InventoryItem> batches = widget.card.batches;
    if (batches.isEmpty) {
      await repository.createItem(
        userProfileId: profile.id,
        consumableTypeId: widget.card.type.id,
        quantity: value,
      );
      return;
    }

    await repository.setQuantity(batches.first.id, value);
    for (final InventoryItem batch in batches.skip(1)) {
      if (batch.quantity != 0) {
        await repository.setQuantity(batch.id, 0);
      }
    }
  }
}

/// The expiry date, and the way to set one.
class _ExpiryRow extends StatelessWidget {
  const _ExpiryRow({required this.expiry, required this.onEdit});

  final DateTime? expiry;
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
                context.l10n.inventoryExpiryOptional,
                style: context.textStyles.labelMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                expiry == null
                    ? context.l10n.inventoryExpiryNone
                    : context.formatDay(expiry!),
                style: context.textStyles.titleMedium,
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onEdit,
          child: Text(context.l10n.inventoryExpiryChoose),
        ),
      ],
    );
  }
}

/// Which place this batch is kept in. Only shown once places exist.
class _LocationField extends StatelessWidget {
  const _LocationField({
    required this.locations,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final List<InventoryLocation> locations;
  final String? selected;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: selected,
      decoration: InputDecoration(labelText: context.l10n.inventoryLocation),
      items: <DropdownMenuItem<String?>>[
        DropdownMenuItem<String?>(
          child: Text(context.l10n.inventoryLocationNone),
        ),
        for (final InventoryLocation location in locations)
          DropdownMenuItem<String?>(
            value: location.id,
            child: Text(location.name),
          ),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }
}
