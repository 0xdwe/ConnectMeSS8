import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';
import '../../widgets/chain_logo.dart';
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
        child: FractionallySizedBox(
          heightFactor: .94,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.space3),
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
              child: Material(
                color: tokens.surfaceRaised,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        key: const Key('about-feature-scroll'),
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.space5,
                          AppSpacing.space5,
                          AppSpacing.space5,
                          AppSpacing.space6,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Container(
                                width: 66,
                                height: 66,
                                decoration: BoxDecoration(
                                  gradient: tokens.aiGradient,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: tokens.primary.withValues(
                                        alpha: .26,
                                      ),
                                      blurRadius: 14,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: const LinkedChainLogo(
                                  size: 42,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(height: AppSpacing.space4),
                            Text(
                              'Connect Me',
                              textAlign: TextAlign.center,
                              style: AppTypography.glyph(
                                26,
                                color: tokens.ink,
                                weight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: AppSpacing.space2),
                            Center(
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: AppSpacing.space3,
                                  vertical: AppSpacing.space1,
                                ),
                                decoration: BoxDecoration(
                                  color: tokens.primaryTint,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                ),
                                child: Text(
                                  'Version 3.0.0 (Build 42)',
                                  style:
                                      AppTypography.caption(
                                        color: tokens.inkMuted,
                                      ).copyWith(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: .6,
                                      ),
                                ),
                              ),
                            ),
                            SizedBox(height: AppSpacing.space6),
                            Text(
                              "WHAT'S NEW IN V3",
                              textAlign: TextAlign.center,
                              style:
                                  AppTypography.caption(
                                    color: tokens.inkSubtle,
                                  ).copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.4,
                                  ),
                            ),
                            SizedBox(height: AppSpacing.space3),
                            Divider(color: tokens.border, height: 1),
                            SizedBox(height: AppSpacing.space4),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: kAboutFeatures.length,
                              separatorBuilder: (_, _) =>
                                  SizedBox(height: AppSpacing.space5),
                              itemBuilder: (context, index) => _AboutFeatureRow(
                                feature: kAboutFeatures[index],
                                icon: _featureIcons[index],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.space5,
                        AppSpacing.space4,
                        AppSpacing.space5,
                        AppSpacing.space5,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.surfaceSunken,
                        border: Border(top: BorderSide(color: tokens.border)),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          key: const Key('about-done-button'),
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tokens.primary,
                            foregroundColor: tokens.primaryOn,
                            elevation: 5,
                            shadowColor: tokens.primary.withValues(alpha: .3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: Text(
                            'Done',
                            style: AppTypography.body().copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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

const _featureIcons = <IconData>[
  Icons.psychology_outlined,
  Icons.favorite_border,
  Icons.cloud_sync_outlined,
  Icons.notifications_none,
  Icons.person_outline,
];

class _AboutFeatureRow extends StatelessWidget {
  const _AboutFeatureRow({required this.feature, required this.icon});

  final AboutFeature feature;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: tokens.primaryTint,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: tokens.primary, size: 21),
        ),
        SizedBox(width: AppSpacing.space4),
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
              SizedBox(height: AppSpacing.space2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: tokens.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.space2),
                  Expanded(
                    child: Text(
                      feature.description,
                      style: AppTypography.caption(
                        color: tokens.inkMuted,
                      ).copyWith(height: 1.45),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
