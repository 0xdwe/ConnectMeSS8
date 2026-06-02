import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';

/// Shows the custom designed bottom sheet modal for managing category items.
/// Configured with top rounded corners and premium raised backdrop color.
Future<void> showManageCategoriesModal(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const ManageCategoriesModal(),
  );
}

class ManageCategoriesModal extends ConsumerStatefulWidget {
  const ManageCategoriesModal({super.key});

  @override
  ConsumerState<ManageCategoriesModal> createState() =>
      _ManageCategoriesModalState();
}

class _ManageCategoriesModalState extends ConsumerState<ManageCategoriesModal> {
  final category = TextEditingController();

  @override
  void dispose() {
    category.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    final categories = ref.watch(
      appControllerProvider.select((state) => state.categories),
    );

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
          child: Material(
            color: tokens.surfaceSunken,
            child: Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.space6,
                right: AppSpacing.space6,
                top: 14,
                bottom: bottomInset + AppSpacing.space6,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: tokens.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header Row with close action
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Manage Categories',
                          style: AppTypography.h1(
                            color: tokens.ink,
                          ).copyWith(fontSize: 22),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        color: tokens.inkSubtle,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // CURRENT CATEGORIES Section
                  Text(
                    'CURRENT CATEGORIES',
                    style: AppTypography.caption(color: tokens.primary)
                        .copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                  ),
                  const SizedBox(height: 14),

                  // Category Chips wrap
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((item) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.primaryTint,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: tokens.primary.withValues(alpha: .16),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item,
                              style: AppTypography.body().copyWith(
                                color: tokens.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () async {
                                try {
                                  await ref
                                      .read(appControllerProvider.notifier)
                                      .deleteCategory(item);
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Could not delete category.',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                              child: Icon(
                                Icons.close,
                                color: tokens.primary.withValues(alpha: .8),
                                size: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),

                  // CREATE NEW Section
                  Text(
                    'CREATE NEW',
                    style: AppTypography.caption(color: tokens.inkSubtle)
                        .copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                  ),
                  const SizedBox(height: 10),

                  // Text Field rounded container (enlarged vertical padding for premium feel)
                  Container(
                    decoration: BoxDecoration(
                      color: tokens.surfaceRaised,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: tokens.border),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: TextField(
                      controller: category,
                      style: AppTypography.body(color: tokens.ink),
                      decoration: InputDecoration(
                        hintText: 'e.g. Hiking Club',
                        hintStyle: AppTypography.body(color: tokens.inkMuted),
                        border: InputBorder.none,
                        isDense: true,
                        suffixIcon: Icon(
                          Icons.edit_outlined,
                          color: tokens.inkSubtle,
                          size: 18,
                        ),
                        suffixIconConstraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Add Category pilled action button with Shadow (taller height)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: tokens.primary.withValues(alpha: .3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: tokens.primary,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: () async {
                        if (category.text.trim().isEmpty) return;
                        try {
                          await ref
                              .read(appControllerProvider.notifier)
                              .addCategory(category.text);
                          category.clear();
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Could not add category. Try again.',
                                ),
                              ),
                            );
                          }
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add, color: Colors.white, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            'Add Category',
                            style: AppTypography.body(
                              color: Colors.white,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
