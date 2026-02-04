import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cards/core/theme/app_theme.dart';
import 'package:cards/firebase/auth_services.dart';
import 'package:cards/features/nfc_tag/presentation/widgets/confirm_action_dialog.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final photoUrl = user?.photoURL;
    final displayName = user?.displayName ?? 'User';
    final email = user?.email ?? '';

    return GradientBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 3),
                        boxShadow: AppShadows.card,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(50),
                        child: photoUrl != null && photoUrl.isNotEmpty
                            ? Image.network(
                                photoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: AppColors.primary,
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                size: 50,
                                color: AppColors.primary,
                              ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      displayName,
                      style: AppTextStyles.headline,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      email,
                      style: AppTextStyles.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              PremiumCard(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Column(
                  children: [
                    _AccountOption(
                      icon: Icons.notifications_outlined,
                      title: 'Notifications',
                      subtitle: 'Manage notification preferences',
                      onTap: () {},
                    ),
                    const Divider(height: 1, indent: 68),
                    _AccountOption(
                      icon: Icons.security_outlined,
                      title: 'Security',
                      subtitle: 'Password and security settings',
                      onTap: () {},
                    ),
                    const Divider(height: 1, indent: 68),
                    _AccountOption(
                      icon: Icons.help_outline,
                      title: 'Help & Support',
                      subtitle: 'Get help with Reviews Everywhere',
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              PremiumCard(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Column(
                  children: [
                    _AccountOption(
                      icon: Icons.logout,
                      title: 'Logout',
                      subtitle: 'Sign out of your account',
                      color: AppColors.orange,
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => ConfirmActionDialog(
                            title: "Logout",
                            description: "Are you sure you want to log out of your account?",
                            cancelText: "Stay Logged In",
                            confirmText: "Logout",
                            icon: Icons.logout,
                            iconBgColor: AppColors.orange,
                            confirmButtonColor: AppColors.orange,
                            onCancel: () {},
                            onConfirm: () {
                              AuthService().logout(context);
                            },
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 68),
                    _AccountOption(
                      icon: Icons.delete_forever,
                      title: 'Delete Account',
                      subtitle: 'Permanently delete your account',
                      color: AppColors.orange,
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => ConfirmActionDialog(
                            title: "Delete Account?",
                            description: "This action cannot be undone. Are you sure?",
                            cancelText: "No, Keep",
                            confirmText: "Yes, Delete",
                            icon: Icons.delete_forever,
                            iconBgColor: AppColors.orange,
                            cancelButtonColor: Colors.white,
                            confirmButtonColor: AppColors.orange,
                            onCancel: () {},
                            onConfirm: () {
                              AuthService().deleteAccount(context);
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? color;
  final VoidCallback onTap;

  const _AccountOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.primary;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: effectiveColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: effectiveColor, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: color ?? AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
