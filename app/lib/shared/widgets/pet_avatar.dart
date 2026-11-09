import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

/// Foto circular del perro (guardada en el teléfono) o su inicial sobre un pastel.
/// Lleva un Hero para viajar entre la lista y la ficha.
class PetAvatar extends ConsumerWidget {
  const PetAvatar({
    super.key,
    required this.petId,
    required this.name,
    this.size = 56,
    this.hero = true,
    this.ring,
  });

  final String petId;
  final String name;
  final double size;
  final bool hero;

  /// Borde de color (por ejemplo, el perro seleccionado).
  final Color? ring;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = ref.watch(petPhotoProvider(petId)).value;
    final (bg, ink) = PetPalette.forId(petId, Theme.of(context).brightness);
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        image: photo == null
            ? null
            : DecorationImage(image: MemoryImage(photo), fit: BoxFit.cover),
        border: ring == null ? null : Border.all(color: ring!, width: 3),
      ),
      alignment: Alignment.center,
      child: photo == null
          ? Text(
              initial,
              style: TextStyle(
                fontFamily: AppTheme.headingFont,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.42,
                color: ink,
              ),
            )
          : null,
    );
    avatar = ExcludeSemantics(child: avatar);
    return hero ? Hero(tag: 'pet-avatar-$petId', child: avatar) : avatar;
  }
}
