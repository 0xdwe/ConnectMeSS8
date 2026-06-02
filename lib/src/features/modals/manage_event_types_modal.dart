import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';

Future<void> showManageEventTypesModal(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const ManageEventTypesModal(),
  );
}

class ManageEventTypesModal extends ConsumerStatefulWidget {
  const ManageEventTypesModal({super.key});

  @override
  ConsumerState<ManageEventTypesModal> createState() =>
      _ManageEventTypesModalState();
}

class _ManageEventTypesModalState extends ConsumerState<ManageEventTypesModal> {
  final eventType = TextEditingController();
  final editValue = TextEditingController();
  String? editing;

  @override
  void dispose() {
    eventType.dispose();
    editValue.dispose();
    super.dispose();
  }

  Future<void> _addEventType() async {
    final controller = ref.read(appControllerProvider.notifier);
    try {
      await controller.addEventType(eventType.text);
      eventType.clear();
    } catch (_) {
      if (mounted) {
        _showFailure('Could not add event type. Try again.');
      }
    }
  }

  Future<void> _renameEventType(String oldValue) async {
    final controller = ref.read(appControllerProvider.notifier);
    try {
      await controller.renameEventType(oldValue, editValue.text);
      if (mounted) {
        setState(() => editing = null);
      }
    } catch (_) {
      if (mounted) {
        _showFailure('Could not rename event type. Try again.');
      }
    }
  }

  Future<void> _deleteEventType(String type) async {
    final controller = ref.read(appControllerProvider.notifier);
    try {
      await controller.deleteEventType(type);
    } catch (_) {
      if (mounted) {
        _showFailure('Could not delete event type. Try again.');
      }
    }
  }

  void _showFailure(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final types = ref.watch(
      appControllerProvider.select((state) => state.eventTypes),
    );
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * .88;

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: ClipRRect(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.lg),
            ),
            child: Material(
              color: tokens.surfaceSunken,
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: Column(
                  children: [
                    _ManageHeader(tokens: tokens),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.space4,
                          AppSpacing.space4,
                          AppSpacing.space4,
                          AppSpacing.space5,
                        ),
                        children: [
                          _InfoBanner(tokens: tokens),
                          SizedBox(height: AppSpacing.space4),
                          _AddEventTypeField(
                            controller: eventType,
                            onSubmitted: (_) => _addEventType(),
                            onAdd: _addEventType,
                          ),
                          SizedBox(height: AppSpacing.space4),
                          for (final type in types) ...[
                            _EventTypeTile(
                              type: type,
                              editController: editValue,
                              editing: editing == type,
                              isDefault: AppController.defaultEventTypes
                                  .contains(type),
                              onStartEdit: () {
                                editValue.text = type;
                                setState(() => editing = type);
                              },
                              onCancelEdit: () {
                                setState(() => editing = null);
                              },
                              onSaveEdit: () => _renameEventType(type),
                              onDelete: () => _deleteEventType(type),
                            ),
                            SizedBox(height: AppSpacing.space3),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ManageHeader extends StatelessWidget {
  const _ManageHeader({required this.tokens});

  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.space2),
      decoration: BoxDecoration(
        color: tokens.surfaceSunken,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Close',
            onPressed: Navigator.of(context).pop,
            icon: Icon(Icons.close, color: tokens.primary),
          ),
          Expanded(
            child: Text(
              'Manage Event Types',
              style: AppTypography.h2(color: tokens.ink),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'Search event types',
            onPressed: null,
            icon: Icon(Icons.search, color: tokens.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.tokens});

  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space3,
      ),
      decoration: BoxDecoration(
        color: tokens.primaryTint,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: tokens.primary.withValues(alpha: .16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: tokens.primary, size: 18),
          SizedBox(width: AppSpacing.space3),
          Expanded(
            child: Text(
              'Default event types cannot be deleted. Custom types can be edited or removed.',
              style: AppTypography.caption(color: tokens.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddEventTypeField extends StatelessWidget {
  const _AddEventTypeField({
    required this.controller,
    required this.onSubmitted,
    required this.onAdd,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('new-event-type-field'),
              controller: controller,
              textInputAction: TextInputAction.done,
              onSubmitted: onSubmitted,
              decoration: InputDecoration(
                hintText: 'Add new event type',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.space4,
                  vertical: AppSpacing.space4,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.space2),
            child: IconButton.filled(
              key: const Key('add-event-type-button'),
              tooltip: 'Add event type',
              onPressed: onAdd,
              style: IconButton.styleFrom(
                backgroundColor: tokens.primary,
                foregroundColor: tokens.primaryOn,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              icon: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventTypeTile extends StatelessWidget {
  const _EventTypeTile({
    required this.type,
    required this.editController,
    required this.editing,
    required this.isDefault,
    required this.onStartEdit,
    required this.onCancelEdit,
    required this.onSaveEdit,
    required this.onDelete,
  });

  final String type;
  final TextEditingController editController;
  final bool editing;
  final bool isDefault;
  final VoidCallback onStartEdit;
  final VoidCallback onCancelEdit;
  final VoidCallback onSaveEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final accent = isDefault ? tokens.primary : tokens.secondary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space3,
      ),
      decoration: BoxDecoration(
        color: tokens.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: tokens.border.withValues(alpha: .7)),
      ),
      child: Row(
        children: [
          _EventTypeIcon(type: type, accent: accent),
          SizedBox(width: AppSpacing.space3),
          Expanded(
            child: editing
                ? TextField(
                    controller: editController,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => onSaveEdit(),
                    decoration: const InputDecoration(
                      labelText: 'Event type name',
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type,
                        style: AppTypography.bodyLg(
                          color: tokens.ink,
                        ).copyWith(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: AppSpacing.space1),
                      _EventTypeBadge(
                        label: isDefault ? 'Default' : 'Custom',
                        color: accent,
                      ),
                    ],
                  ),
          ),
          SizedBox(width: AppSpacing.space2),
          if (editing) ...[
            IconButton(
              tooltip: 'Save event type',
              onPressed: onSaveEdit,
              icon: Icon(Icons.check, color: tokens.primary),
            ),
            IconButton(
              tooltip: 'Cancel edit',
              onPressed: onCancelEdit,
              icon: Icon(Icons.close, color: tokens.inkMuted),
            ),
          ] else ...[
            IconButton(
              tooltip: 'Edit event type',
              onPressed: onStartEdit,
              icon: Icon(Icons.edit_outlined, color: tokens.ink),
            ),
            IconButton(
              tooltip: isDefault ? 'Default event type' : 'Delete event type',
              onPressed: isDefault ? null : onDelete,
              icon: Icon(
                Icons.delete_outline,
                color: isDefault
                    ? tokens.inkSubtle.withValues(alpha: .5)
                    : tokens.danger,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EventTypeIcon extends StatelessWidget {
  const _EventTypeIcon({required this.type, required this.accent});

  final String type;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .12),
        shape: BoxShape.circle,
      ),
      child: Icon(_iconForEventType(type), color: accent, size: 22),
    );
  }
}

class _EventTypeBadge extends StatelessWidget {
  const _EventTypeBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.space2,
          vertical: 2,
        ),
        child: Text(
          label,
          style: AppTypography.caption(
            color: color,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

IconData _iconForEventType(String type) {
  final value = type.toLowerCase().trim();
  if (value.contains('plan') || value.contains('schedule')) {
    return Icons.event_available_outlined;
  }
  if (value.contains('remind') || value.contains('alert')) {
    return Icons.notifications_none_outlined;
  }
  if (value.contains('birth') || value.contains('anniversary')) {
    return Icons.cake_outlined;
  }
  if (value.contains('meet') ||
      value.contains('team') ||
      value.contains('sync')) {
    return Icons.groups_2_outlined;
  }
  if (value.contains('call') ||
      value.contains('phone') ||
      value.contains('facetime')) {
    return Icons.call_outlined;
  }
  if (value.contains('dinner') ||
      value.contains('lunch') ||
      value.contains('meal') ||
      value.contains('food')) {
    return Icons.restaurant_outlined;
  }
  if (value.contains('coffee') ||
      value.contains('tea') ||
      value.contains('cafe')) {
    return Icons.local_cafe_outlined;
  }
  if (value.contains('workshop') ||
      value.contains('class') ||
      value.contains('school') ||
      value.contains('study')) {
    return Icons.school_outlined;
  }
  if (value.contains('travel') ||
      value.contains('trip') ||
      value.contains('flight')) {
    return Icons.flight_takeoff_outlined;
  }
  if (value.contains('gift') || value.contains('party')) {
    return Icons.card_giftcard_outlined;
  }
  return Icons.event_note_outlined;
}
