import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/analysis_history_provider.dart';
import '../providers/camera_provider.dart';
import '../widgets/glass.dart';

/// Home landing: centered hero, session overview stats, safety reminders.
/// Section switches live in the navigation rail / bottom bar.
class LandingView extends StatefulWidget {
  const LandingView({super.key});

  @override
  State<LandingView> createState() => _LandingViewState();
}

class _LandingViewState extends State<LandingView> with TickerProviderStateMixin {
  late final AnimationController _glowCycle;

  @override
  void initState() {
    super.initState();
    _glowCycle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowCycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cameras = context.watch<CameraProvider>();
    final history = context.watch<AnalysisHistoryProvider>();

    final activeFeeds = cameras.cameras.where((c) => c.isActive).length;
    final videoRuns = history.byKind(AnalysisKind.video).length;
    final photoRuns = history.byKind(AnalysisKind.photo).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 36),
      child: Column(
        children: [
          _LandingHero(glowAnimation: _glowCycle),
          const SizedBox(height: 36),
          _OverviewHeading(),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final maxCard = w >= 560 ? (w - 32) / 3 : (w >= 360 ? w / 2 - 20 : w);
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                alignment: WrapAlignment.center,
                children: [
                  _StatOrb(
                    icon: Icons.podcasts_rounded,
                    label: 'Live feeds on',
                    value: '$activeFeeds',
                    accent: const Color(0xFF5BB0FF),
                    maxWidth: maxCard.clamp(140.0, 220.0),
                  ),
                  _StatOrb(
                    icon: Icons.movie_rounded,
                    label: 'Videos analyzed',
                    value: '$videoRuns',
                    accent: const Color(0xFF9B8CFF),
                    maxWidth: maxCard.clamp(140.0, 220.0),
                  ),
                  _StatOrb(
                    icon: Icons.photo_library_rounded,
                    label: 'Photos analyzed',
                    value: '$photoRuns',
                    accent: const Color(0xFF5FD4B3),
                    maxWidth: maxCard.clamp(140.0, 220.0),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 36),
          _SafetyTipsSection(),
        ],
      ),
    );
  }
}

class _LandingHero extends StatelessWidget {
  const _LandingHero({required this.glowAnimation});

  final Animation<double> glowAnimation;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final headlineSize = (w * 0.078).clamp(26.0, 42.0).toDouble();

    return AnimatedBuilder(
      animation: glowAnimation,
      builder: (context, _) {
        final pulse = glowAnimation.value;
        final glowA = 0.22 + pulse * 0.18;
        final glowB = 0.12 + pulse * 0.1;

        return SizedBox(
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                child: IgnorePointer(
                  child: Transform.scale(
                    scale: 1.02 + pulse * 0.04,
                    child: Container(
                      width: math.min(w * 0.92, 540),
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.circular(120),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563C8).withValues(alpha: glowA),
                            blurRadius: 56 + pulse * 22,
                            spreadRadius: 8 + pulse * 6,
                          ),
                          BoxShadow(
                            color: const Color(0xFF5FD4B3).withValues(alpha: glowB),
                            blurRadius: 44 + pulse * 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, t, child) => Opacity(
                        opacity: t,
                        child: Transform.translate(
                          offset: Offset(0, 14 * (1 - t)),
                          child: child,
                        ),
                      ),
                      child: Text(
                        'AI INCIDENT RESPONSE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.42),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 1100),
                      curve: Curves.easeOutCubic,
                      builder: (context, t, _) {
                        return Opacity(
                          opacity: t,
                          child: Transform.translate(
                            offset: Offset(0, 22 * (1 - t)),
                            child: Text(
                              'One calm command center\nfor live awareness',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: headlineSize,
                                height: 1.12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                                color: Colors.white.withValues(alpha: 0.96),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 1300),
                      curve: Curves.easeOutCubic,
                      builder: (context, t, _) => Opacity(
                        opacity: t,
                        child: Transform.translate(
                          offset: Offset(0, 12 * (1 - t)),
                          child: Text(
                            'Streams, AI detections, and evidence — use the rail or tabs to move.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14.5,
                              height: 1.45,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.48),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OverviewHeading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'Session overview',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 13,
        letterSpacing: 2,
        fontWeight: FontWeight.w600,
        color: Colors.white.withValues(alpha: 0.38),
      ),
    );
  }
}

class _StatOrb extends StatelessWidget {
  const _StatOrb({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.maxWidth,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth, minWidth: 132),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.scale(scale: 0.94 + 0.06 * t, child: child),
        ),
        child: GlassPanel(
          borderRadius: 20,
          blurSigma: 14,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accent.withValues(alpha: 0.45),
                      accent.withValues(alpha: 0.08),
                    ],
                  ),
                ),
                child: Icon(icon, color: Colors.white.withValues(alpha: 0.95), size: 26),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: Colors.white.withValues(alpha: 0.96),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SafetyTipsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tips = <({IconData icon, String text})>[
      (icon: Icons.health_and_safety_outlined, text: 'Wear required PPE and visible ID on site.'),
      (icon: Icons.door_front_door_outlined, text: 'Keep exits and muster routes clear at all times.'),
      (icon: Icons.local_fire_department_outlined, text: 'Know alarm points and assembly areas.'),
      (icon: Icons.visibility_outlined, text: 'Review high-risk camera zones during shift handover.'),
      (icon: Icons.report_gmailerrorred_outlined, text: 'Escalate anomalies early — evidence saves time.'),
      (icon: Icons.battery_charging_full_rounded, text: 'Check backup power for critical feeds regularly.'),
    ];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - t)),
            child: GlassPanel(
              borderRadius: 22,
              blurSigma: 16,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, size: 20, color: Colors.amber.shade200.withValues(alpha: 0.85)),
                      const SizedBox(width: 10),
                      Text(
                        'Safety reminders',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: tips.map((tip) {
                      return _TipPill(icon: tip.icon, text: tip.text);
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TipPill extends StatefulWidget {
  const _TipPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  State<_TipPill> createState() => _TipPillState();
}

class _TipPillState extends State<_TipPill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: _hover ? 0.18 : 0.1),
          ),
          color: Colors.white.withValues(alpha: _hover ? 0.07 : 0.04),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 18, color: const Color(0xFF8EC9FF).withValues(alpha: 0.9)),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                widget.text,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
