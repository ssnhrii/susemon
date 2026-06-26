import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Widget pembungkus yang memberikan mesh gradient background
/// sesuai desain (seperti CSS: radial-gradient dari tiap sudut)
class MeshBackground extends StatelessWidget {
  final Widget child;
  const MeshBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topLeft,
          radius: 2.5,
          colors: [Color(0xFFEBF8FF), Color(0xFFF0F7FF)],
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              const Color(0xFFE0F0FF).withValues(alpha: 0.6),
              Colors.transparent,
              const Color(0xFFE8F4FC).withValues(alpha: 0.4),
            ],
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Glass card container (glassmorphism)
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Color? borderColor;
  final Color? color;
  final List<BoxShadow>? boxShadow;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 16,
    this.borderColor,
    this.color,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.5),
        ),
        boxShadow:
            boxShadow ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
      ),
      child: child,
    );
  }
}

/// Status badge pill
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color? backgroundColor;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// Gradient button sesuai desain
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool loading;
  final double height;

  const GradientButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.loading = false,
    this.height = 50,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryContainer],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Top app bar sesuai desain (glassmorphism)
class SusemonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final IconData? titleIcon;
  final List<Widget>? actions;
  final bool showBack;

  const SusemonAppBar({
    super.key,
    required this.title,
    this.titleIcon,
    this.actions,
    this.showBack = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              if (showBack)
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.primary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              if (titleIcon != null) ...[
                Icon(titleIcon, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              if (actions != null) ...actions!,
            ],
          ),
        ),
      ),
    );
  }
}
