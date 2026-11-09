import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/risk_style.dart';

enum RiskBadgeSize { small, medium, large }

/// Píldora del nivel de riesgo: ícono + palabra + color, nunca solo color.
class RiskBadge extends StatelessWidget {
  const RiskBadge({
    super.key,
    required this.level,
    this.size = RiskBadgeSize.medium,
  });

  final RiskLevel level;
  final RiskBadgeSize size;

  @override
  Widget build(BuildContext context) {
    final style = RiskStyle.of(context, level);
    final (icon, font, padH, padV) = switch (size) {
      RiskBadgeSize.small => (15.0, 12.5, 10.0, 4.0),
      RiskBadgeSize.medium => (18.0, 14.0, 12.0, 6.0),
      RiskBadgeSize.large => (24.0, 18.0, 18.0, 10.0),
    };
    return Semantics(
      label: 'Nivel ${style.short}: ${style.label}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: style.background,
          shape: const StadiumBorder(),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(style.icon, size: icon, color: style.foreground),
              SizedBox(width: size == RiskBadgeSize.large ? 8 : 5),
              Flexible(
                child: Text(
                  style.label,
                  style: TextStyle(
                    fontFamily: size == RiskBadgeSize.large
                        ? AppTheme.headingFont
                        : AppTheme.bodyFont,
                    color: style.foreground,
                    fontWeight: size == RiskBadgeSize.large
                        ? FontWeight.w800
                        : FontWeight.w700,
                    fontSize: font,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Anillo que se llena con el color del nivel alrededor de una foto o avatar
/// (al estilo de los resultados de SkinVision). Sin animación si se piden
/// animaciones reducidas.
class RiskRing extends StatelessWidget {
  const RiskRing({
    super.key,
    required this.level,
    required this.child,
    this.size = 168,
    this.stroke = 10,
  });

  final RiskLevel level;
  final Widget child;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final style = RiskStyle.of(context, level);
    final track = Theme.of(context).colorScheme.outlineVariant;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: reduce ? 1 : 0, end: 1),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => CustomPaint(
          painter: _RingPainter(
            progress: t,
            color: style.foreground,
            track: track,
            stroke: stroke,
          ),
          child: child,
        ),
        child: Padding(
          padding: EdgeInsets.all(stroke + 6),
          child: ClipOval(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.stroke,
  });

  final double progress;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawOval(rect, base);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      base
        ..color = color
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}
