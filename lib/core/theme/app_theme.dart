import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary = Color(0xFF0075FD);
  static const primaryLight = Color(0xFFE6F1FF);
  static const accent = Color(0xFFF75013);
  static const accentLight = Color(0xFFFEECE6);
  
  static const blue = Color(0xFF0075FD);
  static const orange = Color(0xFFF75013);
  static const green = Color(0xFF0B7A3C);
  static const greenLight = Color(0xFFE8F5ED);
  static const red = Color(0xFFE53935);
  
  static const backgroundTop = Color(0xFFEAF3FF);
  static const backgroundBottom = Color(0xFFFFFFFF);
  static const surface = Colors.white;
  static const surfaceVariant = Color(0xFFF4F7FB);
  
  static const textPrimary = Color(0xFF0B1220);
  static const textSecondary = Color(0xFF5B677A);
  static const textMuted = Color(0xFF6B7688);
  
  static const border = Color(0xFFE5E7EB);
  static const divider = Color(0xFFF3F4F6);
}

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const input = 16.0;
  static const pill = 999.0;
}

class AppShadows {
  static List<BoxShadow> get card => [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
  
  static List<BoxShadow> get elevated => [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
  ];

  static List<BoxShadow> get button => [
    BoxShadow(
      color: AppColors.primary.withOpacity(0.25),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get bottomNav => [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 16,
      offset: const Offset(0, -4),
    ),
  ];
}

class AppTextStyles {
  static TextStyle get headline => GoogleFonts.raleway(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.25,
    letterSpacing: -0.3,
  );

  static TextStyle get h1 => GoogleFonts.raleway(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.25,
    letterSpacing: -0.3,
  );
  
  static TextStyle get h2 => GoogleFonts.raleway(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
  );
  
  static TextStyle get h3 => GoogleFonts.raleway(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
  
  static TextStyle get body => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.6,
  );

  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.55,
  );
  
  static TextStyle get bodyBold => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  
  static TextStyle get caption => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
  );

  static TextStyle get sectionLabel => GoogleFonts.raleway(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.textMuted,
    letterSpacing: 0.8,
  );
  
  static TextStyle get button => GoogleFonts.montserrat(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
  );
  
  static TextStyle get label => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  static TextStyle get stepPill => GoogleFonts.montserrat(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );
}

class AppWidgets {
  static InputDecoration inputDecoration({
    required String label,
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool readOnly = false,
  }) {
    return InputDecoration(
      labelText: label.isNotEmpty ? label : null,
      hintText: hint,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon ?? (readOnly ? const Icon(Icons.lock_outline, size: 18, color: AppColors.textMuted) : null),
      filled: true,
      fillColor: AppColors.surfaceVariant,
      labelStyle: AppTextStyles.label,
      hintStyle: AppTextStyles.caption,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 18,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.orange),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.orange, width: 2),
      ),
      errorStyle: const TextStyle(color: AppColors.orange, fontSize: 12),
    );
  }
  
  static ButtonStyle primaryButton({Color? backgroundColor}) {
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor ?? AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      minimumSize: const Size(double.infinity, 54),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      textStyle: AppTextStyles.button,
    ).copyWith(
      shadowColor: WidgetStateProperty.all(AppColors.primary.withOpacity(0.25)),
    );
  }

  static ButtonStyle secondaryButton() {
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      backgroundColor: Colors.transparent,
      minimumSize: const Size(double.infinity, 54),
      side: const BorderSide(color: AppColors.primary, width: 1.5),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      textStyle: AppTextStyles.button,
    );
  }

  static ButtonStyle destructiveButton({bool outline = false}) {
    if (outline) {
      return OutlinedButton.styleFrom(
        foregroundColor: AppColors.orange,
        backgroundColor: Colors.transparent,
        minimumSize: const Size(double.infinity, 54),
        side: const BorderSide(color: AppColors.orange, width: 1.5),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        textStyle: AppTextStyles.button,
      );
    }
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.orange,
      foregroundColor: Colors.white,
      elevation: 0,
      minimumSize: const Size(double.infinity, 54),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      textStyle: AppTextStyles.button,
    );
  }
  
  static ButtonStyle outlineButton({Color? borderColor}) {
    return OutlinedButton.styleFrom(
      foregroundColor: borderColor ?? AppColors.primary,
      side: BorderSide(color: borderColor ?? AppColors.primary, width: 1.5),
      minimumSize: const Size(double.infinity, 54),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      textStyle: AppTextStyles.button,
    );
  }
}

class GradientBackground extends StatelessWidget {
  final Widget child;
  
  const GradientBackground({super.key, required this.child});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.backgroundTop,
            AppColors.backgroundBottom,
          ],
          stops: [0.0, 0.5],
        ),
      ),
      child: child,
    );
  }
}

class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? maxWidth;
  
  const PremiumCard({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: maxWidth != null ? BoxConstraints(maxWidth: maxWidth!) : null,
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.card,
      ),
      child: child,
    );
  }
}

class StepPill extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  
  const StepPill({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 100),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        'Step $currentStep of $totalSteps',
        style: AppTextStyles.stepPill,
        maxLines: 1,
        overflow: TextOverflow.visible,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class InfoBanner extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color? color;
  final bool isWarning;
  
  const InfoBanner({
    super.key,
    required this.message,
    this.icon = Icons.lightbulb_outline,
    this.color,
    this.isWarning = false,
  });
  
  @override
  Widget build(BuildContext context) {
    final bannerColor = isWarning ? AppColors.orange : (color ?? AppColors.primary);
    final bgColor = isWarning ? AppColors.accentLight : AppColors.primaryLight;
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Icon(icon, color: bannerColor, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: bannerColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData? icon;
  final Color color;
  
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.icon,
    required this.color,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: AppTextStyles.sectionLabel,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;
  final bool isPrimary;
  final bool isDestructive;
  
  const ActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
    this.enabled = true,
    this.isPrimary = false,
    this.isDestructive = false,
  });
  
  @override
  Widget build(BuildContext context) {
    final bgColor = isPrimary 
        ? AppColors.primary 
        : isDestructive 
            ? AppColors.surface 
            : AppColors.surface;
    final textColor = isPrimary ? Colors.white : AppColors.textPrimary;
    final descColor = isPrimary ? Colors.white.withOpacity(0.85) : AppColors.textSecondary;
    final iconBgColor = isPrimary 
        ? Colors.white.withOpacity(0.2) 
        : isDestructive 
            ? AppColors.accentLight 
            : color.withOpacity(0.1);
    final iconColor = isPrimary ? Colors.white : color;
    
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: isPrimary ? AppShadows.button : AppShadows.card,
              border: isDestructive ? Border.all(color: AppColors.orange.withOpacity(0.3), width: 1.5) : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 26, color: iconColor),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: descColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: isPrimary ? Colors.white.withOpacity(0.7) : AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
