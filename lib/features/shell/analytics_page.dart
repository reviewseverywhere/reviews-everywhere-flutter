import 'package:flutter/material.dart';
import 'package:cards/core/theme/app_theme.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Analytics', style: AppTextStyles.h1),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Track your review performance and insights.',
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
                        color: AppColors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Icon(
                        Icons.analytics,
                        size: 40,
                        color: AppColors.blue,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Analytics Dashboard',
                      style: AppTextStyles.h3,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'View detailed analytics about your reviews.\nThis feature is coming soon.',
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
