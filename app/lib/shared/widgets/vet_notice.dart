import 'package:flutter/material.dart';

/// Aviso fijo de que el resultado no es un diagnóstico. Va en toda pantalla con resultados
/// y no se puede cerrar ni ocultar.
class VetNotice extends StatelessWidget {
  const VetNotice({super.key});

  static const text =
      'Este resultado es orientativo y no es un diagnóstico: consulta siempre a tu veterinario.';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: Border(top: BorderSide(color: scheme.outlineVariant)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: scheme.primaryContainer,
                child: Icon(
                  Icons.medical_services_outlined,
                  size: 18,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(color: scheme.onSurface, fontSize: 13.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
