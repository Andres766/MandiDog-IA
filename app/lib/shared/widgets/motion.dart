import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Entrada escalonada (aparece y sube un poco). Sin animación si el sistema pide
/// animaciones reducidas.
extension Entrance on Widget {
  Widget entrance(BuildContext context, {int index = 0, double offset = 0.08}) {
    if (MediaQuery.disableAnimationsOf(context)) return this;
    return animate(delay: (60 * index).ms)
        .fadeIn(duration: 320.ms, curve: Curves.easeOutCubic)
        .slideY(
          begin: offset,
          end: 0,
          duration: 380.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

/// Escala al presionar, como un botón físico.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, required this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool down) {
    if (widget.onTap != null && _down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down && !reduce ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
