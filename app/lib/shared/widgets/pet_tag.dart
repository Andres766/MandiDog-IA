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

  bool _opening = false;

  void _startSwing() {
    if (MediaQuery.disableAnimationsOf(context)) return;
    _swing.forward(from: 0);
  }

  /// Deja ver el primer vaivén antes de abrir la ficha; sin animaciones abre ya.
  void _handleTap() {
    final onTap = widget.onTap;
    if (onTap == null) return _startSwing();
    if (MediaQuery.disableAnimationsOf(context)) return onTap();
    if (_opening) return;
    _opening = true;
    Future<void>.delayed(const Duration(milliseconds: 200), () {
      _opening = false;
      if (mounted) onTap();
    });
  }

  /// Oscilación amortiguada: unos grados que se apagan como una placa real.
  double _angle(double t) =>
      0.045 * math.exp(-4.5 * t) * math.sin(t * math.pi * 5);

  @override
  Widget build(BuildContext context) {
    final large = widget.large;
    final ring = large ? _Ring.large : _Ring.regular;

    final tag = AnimatedBuilder(
      animation: _swing,
      builder: (context, child) => Transform.rotate(
        angle: _angle(_swing.value),
        // Pivote donde el aro cuelga del collar: su punto más a la izquierda.
        alignment: Alignment.centerLeft,
        origin: Offset(ring.centerX - ring.radius, 0),
        child: child,
      ),
      child: _Ringed(
        ring: ring,
        body: SizedBox(
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
                ring.holeX + ring.holeRadius + (large ? 20 : 16),
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
      ),
    );

    return Semantics(
      button: widget.onTap != null,
      label: widget.semanticLabel,
      excludeSemantics: widget.semanticLabel != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _startSwing(),
        onTap: _handleTap,
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

/// Medidas de la perforación y del aro partido, desde el borde izquierdo de la placa.
class _Ring {
  const _Ring({
    required this.holeX,
    required this.holeRadius,
    required this.radius,
    required this.wire,
  });

  static const large = _Ring(holeX: 28, holeRadius: 10, radius: 21, wire: 2.2);
  static const regular = _Ring(holeX: 24, holeRadius: 8, radius: 17, wire: 2);
  static const mini = _Ring(holeX: 11, holeRadius: 4, radius: 8, wire: 1.4);

  /// Centro de la perforación.
  final double holeX;
  final double holeRadius;

  /// Radio del aro. El alambre descansa contra el borde izquierdo de la perforación,
  /// como en una placa que cuelga, y el aro sobresale de la placa por la izquierda.
  final double radius;
  final double wire;

  /// Distancia del centro del aro al centro de la perforación.
  double get reach => radius + holeRadius * 0.45;

  double get centerX => holeX - reach;

  /// Lado del lienzo cuadrado que contiene el aro completo.
  double get box => (radius + wire * 3) * 2;
}

/// Placa con su argolla: el aro se dibuja detrás de la placa, y encima solo se ve
/// la perforación (con el aro cruzándola) y el tramo de aro que pasa por delante.
class _Ringed extends StatelessWidget {
  const _Ringed({required this.ring, required this.body});

  final _Ring ring;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final ground = Theme.of(context).colorScheme.surface;
    Widget layer(bool front) => Positioned(
      left: ring.centerX - ring.box / 2,
      top: 0,
      bottom: 0,
      child: Center(
        child: ExcludeSemantics(
          child: SizedBox.square(
            dimension: ring.box,
            child: CustomPaint(
              painter: _RingPainter(ring: ring, ground: ground, front: front),
            ),
          ),
        ),
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [layer(false), body, layer(true)],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.ring, required this.ground, required this.front});

  final _Ring ring;
  final Color ground;
  final bool front;

  // Dos tonos: el claro se lee sobre las placas oscuras y el oscuro sobre el fondo.
  static const _steel = Color(0xFFBAC4CA);
  static const _steelShade = Color(0xFF66737B);

  /// Aro partido: dos vueltas de alambre, una junto a la otra.
  void _coil(Canvas canvas, Offset center, {double start = 0, double? sweep}) {
    for (final (offset, color) in [
      (0.0, _steel),
      (ring.wire * 1.4, _steelShade),
    ]) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ring.wire
        ..strokeCap = StrokeCap.round
        ..color = color;
      final rect = Rect.fromCircle(
        center: center,
        radius: ring.radius - offset,
      );
      if (sweep == null) {
        canvas.drawOval(rect, paint);
      } else {
        canvas.drawArc(rect, start, sweep, false, paint);
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    if (!front) {
      // Detrás de la placa: solo asoma el tramo que cuelga fuera.
      _coil(canvas, center);
      return;
    }
    final hole = center.translate(ring.reach, 0);
    final edgeX = center.dx - ring.centerX;

    // Perforación: deja ver el fondo, con el borde cortado un poco más oscuro.
    canvas.drawCircle(hole, ring.holeRadius, Paint()..color = ground);
    canvas.drawCircle(
      hole,
      ring.holeRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black.withValues(alpha: 0.22),
    );
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: hole, radius: ring.holeRadius)),
    );
    _coil(canvas, center);
    canvas.restore();

    // Tramo delantero: sale de la perforación hacia abajo y cruza el borde.
    final edgeAngle = math.acos(
      ((edgeX - center.dx) / ring.radius).clamp(-1.0, 1.0),
    );
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(edgeX, 0, size.width, size.height));
    _coil(canvas, center, sweep: edgeAngle);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.ground != ground || old.ring != ring || old.front != front;
}

/// Sello del nivel de riesgo sobre la placa o en listas: ícono + palabra + color.
/// [large] es el mismo sello a tamaño de titular (último escaneo y resultado).
class RiskStamp extends StatelessWidget {
  const RiskStamp({
    super.key,
    required this.level,
    this.dense = false,
    this.large = false,
  }) : assert(!(dense && large));

  final RiskLevel level;
  final bool dense;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final style = RiskStyle.of(context, level);
    return Semantics(
      label: 'Nivel ${style.short}: ${style.label}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: BorderRadius.circular(large ? 14 : 10),
          border: Border.all(
            color: style.foreground.withValues(alpha: 0.55),
            width: large ? 2 : 1.5,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: large ? 14 : 10,
            vertical: large ? 9 : (dense ? 3 : 5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                style.icon,
                size: large ? 26 : (dense ? 16 : 18),
                color: style.foreground,
              ),
              SizedBox(width: large ? 10 : 6),
              Flexible(
                child: Text(
                  style.label,
                  style: large
                      ? TextStyle(
                          fontFamily: AppTheme.headingFont,
                          color: style.foreground,
                          fontSize: 22,
                          height: 1.2,
                        )
                      : TextStyle(
                          color: style.foreground,
                          fontWeight: FontWeight.w700,
                          fontSize: dense ? 13 : 14,
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
    final hole = Offset(_Ring.regular.holeX, size.height / 2);
    canvas.drawCircle(hole, _Ring.regular.holeRadius, paint);
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
    const ring = _Ring.mini;
    return Align(
      alignment: Alignment.centerLeft,
      child: _Ringed(
        ring: ring,
        body: DecoratedBox(
          decoration: BoxDecoration(
            color: hue,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              ring.holeX + ring.holeRadius + 8,
              6,
              14,
              6,
            ),
            child: Text(
              name,
              style: const TextStyle(
                fontFamily: AppTheme.headingFont,
                color: Colors.white,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
