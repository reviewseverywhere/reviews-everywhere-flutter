import 'package:flutter/material.dart';
import 'package:cards/core/theme/app_theme.dart';

class TeamsPage extends StatelessWidget {
  const TeamsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Teams', style: AppTextStyles.h1),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Manage your teams and team members.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.xl),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Icon(
                        Icons.groups,
                        size: 40,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Team Management',
                      style: AppTextStyles.h3,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'View and manage your teams.\nThis feature is coming soon.',
                      style: AppTextStyles.body,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
