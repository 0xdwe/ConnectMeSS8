import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';
import '../tabs/about_features.dart';

Future<void> showAboutBottomSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const AboutModal(),
  );
}

class AboutModal extends StatelessWidget {
  const AboutModal({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

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
              padding: EdgeInsets.fromLTRB(
                AppSpacing.space4,
                AppSpacing.space2,
                AppSpacing.space4,
                AppSpacing.space6,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: tokens.border,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                    ),
                    SizedBox(height: AppSpacing.space4),
                    Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: tokens.aiGradient,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          boxShadow: [
                            BoxShadow(
                              color: tokens.primary.withValues(alpha: .24),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.diversity_3,
                          color: tokens.primaryOn,
                          size: 28,
                        ),
                      ),
                    ),
                    SizedBox(height: AppSpacing.space3),
                    Center(
                      child: Text(
                        'Connect Me',
                        style: AppTypography.glyph(
                          24,
                          color: tokens.ink,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(height: AppSpacing.space1),
                    Center(
                      child: Text(
                        'Version 3.0.0 (Build 42)',
                        style: AppTypography.caption(color: tokens.inkSubtle),
                      ),
                    ),
                    SizedBox(height: AppSpacing.space5),
                    Text(
                      "WHAT'S NEW IN V3",
                      style: AppTypography.caption(color: tokens.inkSubtle)
                          .copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                    ),
                    SizedBox(height: AppSpacing.space3),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: kAboutFeatures.length,
                      separatorBuilder: (_, _) =>
                          SizedBox(height: AppSpacing.space3),
                      itemBuilder: (context, index) {
                        final feature = kAboutFeatures[index];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 16,
                              height: 24,
                              alignment: Alignment.center,
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: tokens.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            SizedBox(width: AppSpacing.space3),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    feature.title,
                                    style: AppTypography.bodyLg(
                                      color: tokens.ink,
                                    ).copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  SizedBox(height: AppSpacing.space1),
                                  Text(
                                    feature.description,
                                    style: AppTypography.caption(
                                      color: tokens.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    SizedBox(height: AppSpacing.space6),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.primary,
                        foregroundColor: tokens.primaryOn,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Done',
                        style: AppTypography.body().copyWith(
                          fontWeight: FontWeight.w600,
                        ),
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
