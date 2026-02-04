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

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Account', style: AppTextStyles.h1),
            const SizedBox(height: AppSpacing.xl),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(color: AppColors.border, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      child: photoUrl != null && photoUrl.isNotEmpty
                          ? Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.person,
                                size: 50,
                                color: AppColors.textMuted,
                              ),
                            )
                          : Icon(
                              Icons.person,
                              size: 50,
                              color: AppColors.textMuted,
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    displayName,
                    style: AppTextStyles.h2,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    email,
                    style: AppTextStyles.body,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            _AccountOption(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: 'Manage notification preferences',
              onTap: () {},
            ),
            _AccountOption(
              icon: Icons.security_outlined,
              title: 'Security',
              subtitle: 'Password and security settings',
              onTap: () {},
            ),
            _AccountOption(
              icon: Icons.help_outline,
              title: 'Help & Support',
              subtitle: 'Get help with Reviews Everywhere',
              onTap: () {},
            ),
            const SizedBox(height: AppSpacing.xl),
            const Divider(),
            const SizedBox(height: AppSpacing.lg),
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
                    iconBgColor: Colors.orange,
                    confirmButtonColor: Colors.red,
                    onCancel: () {},
                    onConfirm: () {
                      AuthService().logout(context);
                    },
                  ),
                );
              },
            ),
            _AccountOption(
              icon: Icons.delete_forever,
              title: 'Delete Account',
              subtitle: 'Permanently delete your account',
              color: AppColors.red,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => ConfirmActionDialog(
                    title: "Delete Account?",
                    description: "This action cannot be undone. Are you sure?",
                    cancelText: "No, Keep",
                    confirmText: "Yes, Delete",
                    icon: Icons.delete_forever,
                    iconBgColor: Colors.red,
                    cancelButtonColor: Colors.white,
                    confirmButtonColor: Colors.red,
                    onCancel: () {},
                    onConfirm: () {
                      AuthService().deleteAccount(context);
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
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
    final effectiveColor = color ?? AppColors.textPrimary;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: effectiveColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: effectiveColor,
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
