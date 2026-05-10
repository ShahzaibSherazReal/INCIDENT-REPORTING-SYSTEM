import 'dart:ui';

import 'package:flutter/material.dart';

/// Shared tokens for glass UI.
abstract final class AppChrome {
  static const double radiusLg = 22;
  static const double radiusMd = 16;
  static const double radiusSm = 12;
  static const double blurSigma = 14;

  static Color glassTint(BuildContext context) => Colors.white.withValues(alpha: 0.07);
  static Color glassBorder(BuildContext context) => Colors.white.withValues(alpha: 0.14);
}

/// Full-screen gradient used behind glass panels.
class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF08080C),
                Color(0xFF0E1220),
                Color(0xFF0A1528),
                Color(0xFF080810),
              ],
              stops: <double>[0.0, 0.35, 0.7, 1.0],
            ),
          ),
        ),
        // Soft accent orbs
        const Positioned(
          top: -80,
          right: -60,
          child: _GlowOrb(color: Color(0xFF1E4A8C), size: 180),
        ),
        const Positioned(
          bottom: 100,
          left: -100,
          child: _GlowOrb(color: Color(0xFF0D6E4E), size: 220),
        ),
        if (child != null) child!,
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.35), Colors.transparent],
          ),
        ),
      ),
    );
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = AppChrome.radiusLg,
    this.blurSigma = AppChrome.blurSigma,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            color: AppChrome.glassTint(context),
            border: Border.all(color: AppChrome.glassBorder(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: padding ?? EdgeInsets.zero,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Compact pill label (e.g. Guest, count).
class GlassChip extends StatelessWidget {
  const GlassChip({
    super.key,
    required this.label,
    this.icon,
    this.accent = const Color(0xFF3B9EFF),
  });

  final String label;
  final IconData? icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: accent.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: accent),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PulseLoader extends StatefulWidget {
  const PulseLoader({super.key, this.size = 52});

  final double size;

  @override
  State<PulseLoader> createState() => _PulseLoaderState();
}

class _PulseLoaderState extends State<PulseLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B9EFF).withValues(alpha: 0.15 + t * 0.25),
                blurRadius: 16 + t * 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: CircularProgressIndicator(
            strokeWidth: 2.8,
            valueColor: AlwaysStoppedAnimation(
              Color.lerp(const Color(0xFF3B9EFF), const Color(0xFF6BC4FF), t),
            ),
          ),
        );
      },
    );
  }
}
