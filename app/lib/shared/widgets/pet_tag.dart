import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/risk_style.dart';

/// La placa de collar: la identidad de cada perro en la app.
///
/// Chapa en el tono anodizado del perro, argolla perforada a la izquierda y nombre
/// grabado. Al tocarla se mece desde la argolla (sin movimiento si el sistema pide
/// animaciones reducidas).
class PetTag extends StatefulWidget {
  const PetTag({
    super.key,
    required this.hue,
    required this.name,
    this.subtitle,
    this.risk,
    this.emptyRiskText,
    this.large = false,
    this.onTap,
    this.semanticLabel,
  });

  final Color hue;
  final String name;
  final String? subtitle;
  final RiskLevel? risk;
  final String? emptyRiskText;
  final bool large;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  State<PetTag> createState() => _PetTagState();
}

class _PetTagState extends State<PetTag> with SingleTickerProviderStateMixin {
  late final _swing = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void dispose() {
    _swing.dispose();
    super.dispose();
  }

  void _startSwing() {
    if (MediaQuery.disableAnimationsOf(context)) return;
    _swing.forward(from: 0);
  }

  /// Oscilación amortiguada: unos grados que se apagan como una placa real.
  double _angle(double t) =>
      0.045 * math.exp(-4.5 * t) * math.sin(t * math.pi * 5);

  @override
  Widget build(BuildContext context) {
    final large = widget.large;
    final ringSize = large ? 26.0 : 20.0;
    final ringLeft = large ? 18.0 : 14.0;

    final tag = AnimatedBuilder(
      animation: _swing,
      builder: (context, child) => Transform.rotate(
        angle: _angle(_swing.value),
        // Pivote en el centro de la argolla.
        alignment: Alignment.centerLeft,
        origin: Offset(ringLeft + ringSize / 2, 0),
        child: child,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: widget.hue,
                borderRadius: BorderRadius.circular(large ? 32 : 26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    offset: const Offset(0, 3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  ringLeft + ringSize + (large ? 20 : 16),
                  large ? 22 : 16,
                  large ? 22 : 16,
                  large ? 22 : 16,
                ),
                child: _Engraving(
                  name: widget.name,
                  subtitle: widget.subtitle,
                  risk: widget.risk,
                  emptyRiskText: widget.emptyRiskText,
                  large: large,
                ),
              ),
            ),
          ),
          Positioned(
            left: ringLeft,
            top: 0,
            bottom: 0,
            child: Center(child: _RingHole(size: ringSize)),
          ),
        ],
      ),
    );

    return Semantics(
      button: widget.onTap != null,
      label: widget.semanticLabel,
      excludeSemantics: widget.semanticLabel != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _startSwing(),
        onTap: widget.onTap ?? _startSwing,
        child: tag,
      ),
    );
  }
}

class _Engraving extends StatelessWidget {
  const _Engraving({
    required this.name,
    required this.subtitle,
    required this.risk,
    required this.emptyRiskText,
    required this.large,
  });

  final String name;
  final String? subtitle;
  final RiskLevel? risk;
  final String? emptyRiskText;
  final bool large;

  @override
  Widget build(BuildContext context) {
    const engraved = Colors.white;
    final soft = Colors.white.withValues(alpha: 0.86);
    final sub = subtitle;
    final level = risk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: AppTheme.headingFont,
            fontSize: large ? 34 : 26,
            height: 1.1,
            letterSpacing: 0.2,
            color: engraved,
          ),
        ),
        if (sub != null && sub.isNotEmpty) ...[
          const SizedBox(height: Spacing.xs),
          Text(sub, style: TextStyle(color: soft, fontSize: 15, height: 1.3)),
        ],
        const SizedBox(height: Spacing.sm + 4),
        if (level != null)
          RiskStamp(level: level)
        else if (emptyRiskText != null)
          Text(
            emptyRiskText!,
            style: TextStyle(color: soft, fontWeight: FontWeight.w600),
          ),
      ],
    );
  }
}

/// Argolla perforada: el agujero deja ver el fondo y un aro partido de acero lo cruza.
class _RingHole extends StatelessWidget {
  const _RingHole({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final ground = Theme.of(context).colorScheme.surface;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _RingPainter(ground: ground)),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.ground});

  final Color ground;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    // Perforación: deja ver el fondo, con un bisel claro como el metal cortado.
    canvas.drawCircle(center, radius, Paint()..color = ground);
    canvas.drawCircle(
      center,
      radius - 0.75,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.4),
    );
    // Aro partido: entra por la perforación y sale por el borde izquierdo de la placa.
    final ringRadius = radius * 1.35;
    final ringCenter = center.translate(-radius * 1.05, 0);
    final steel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.5, size.width * 0.13)
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF9AA6AD);
    canvas.drawArc(
      Rect.fromCircle(center: ringCenter, radius: ringRadius),
      -math.pi * 0.30,
      math.pi * 1.75,
      false,
      steel,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.ground != ground;
}

/// Sello del nivel de riesgo sobre la placa o en listas: ícono + palabra + color.
class RiskStamp extends StatelessWidget {
  const RiskStamp({super.key, required this.level, this.dense = false});

  final RiskLevel level;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final style = RiskStyle.of(context, level);
    return Semantics(
      label: 'Nivel ${style.short}: ${style.label}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: style.foreground.withValues(alpha: 0.55),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 10,
            vertical: dense ? 3 : 5,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(style.icon, size: dense ? 16 : 18, color: style.foreground),
              const SizedBox(width: 6),
              Text(
                style.label,
                style: TextStyle(
                  color: style.foreground,
                  fontWeight: FontWeight.w700,
                  fontSize: dense ? 13 : 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Contorno punteado de una placa aún sin grabar (estado vacío).
class BlankTag extends StatelessWidget {
  const BlankTag({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _DashedTagPainter(color: scheme.outline, ground: scheme.surface),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(64, 28, 24, 28),
        child: child,
      ),
    );
  }
}

class _DashedTagPainter extends CustomPainter {
  _DashedTagPainter({required this.color, required this.ground});

  final Color color;
  final Color ground;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(26)),
      );
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 14) {
        canvas.drawPath(metric.extractPath(d, d + 8), paint);
      }
    }
    final hole = Offset(24, size.height / 2);
    canvas.drawCircle(hole, 10, paint);
  }

  @override
  bool shouldRepaint(_DashedTagPainter old) => old.color != color;
}

/// Placa mini: identifica al perro en pantallas que no son su ficha (por ejemplo,
/// el resultado de un escaneo).
class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.hue, required this.name});

  final Color hue;
  final String name;

  @override
  Widget build(BuildContext context) {
    final ground = Theme.of(context).colorScheme.surface;
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: hue,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: ground,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                name,
                style: const TextStyle(
                  fontFamily: AppTheme.headingFont,
                  color: Colors.white,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
