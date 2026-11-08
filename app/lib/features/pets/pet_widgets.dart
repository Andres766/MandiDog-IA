import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/risk_style.dart';
import '../../shared/widgets/pet_tag.dart';

final _dateTime = DateFormat("d MMM y · h:mm a", 'es');
final _date = DateFormat("d 'de' MMMM", 'es');

String formatDateTime(DateTime value) => _dateTime.format(value);

/// "Pug · 3 años · 8,5 kg"
String petSummary(Pet pet) {
  final weight = pet.weightKg == null
      ? null
      : '${NumberFormat.decimalPattern('es').format(pet.weightKg)} kg';
  return [pet.breed, pet.ageLabel(), weight].whereType<String>().join(' · ');
}

String _tagLabel(BuildContext context, Pet pet) {
  final last = pet.lastAnalysis;
  final summary = petSummary(pet);
  final String result;
  if (last == null) {
    result = 'Sin escaneos aún';
  } else {
    final style = RiskStyle.of(context, last.riskLevel);
    result =
        'Nivel ${style.short}: ${style.label}, del ${_date.format(last.createdAt)}';
  }
  return [pet.name, if (summary.isNotEmpty) summary, result].join(', ');
}

/// La placa de un perro en la lista "Mis perros".
class PetTagCard extends StatelessWidget {
  const PetTagCard({
    super.key,
    required this.pet,
    required this.onTap,
    this.large = false,
  });

  final Pet pet;
  final VoidCallback? onTap;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final summary = petSummary(pet);
    return PetTag(
      hue: TagHue.forId(pet.id),
      name: pet.name,
      subtitle: summary.isEmpty ? null : summary,
      risk: pet.lastAnalysis?.riskLevel,
      emptyRiskText: 'Sin escaneos aún',
      large: large,
      onTap: onTap,
      semanticLabel: _tagLabel(context, pet),
    );
  }
}

/// El escaneo más reciente: el que importa ahora, a tamaño completo.
class LatestScanCard extends StatelessWidget {
  const LatestScanCard({
    super.key,
    required this.analysis,
    required this.onTap,
  });

  final Analysis analysis;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = RiskStyle.of(context, analysis.riskLevel);
    final abnormal = analysis.abnormalFindings.map((f) => f.name.toLowerCase());
    return Material(
      color: style.background,
      borderRadius: BorderRadius.circular(Spacing.radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Row(
            children: [
              ExcludeSemantics(
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: style.foreground,
                  child: Icon(style.icon, color: style.background, size: 28),
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Último escaneo · ${formatDateTime(analysis.createdAt)}',
                      style: TextStyle(color: style.foreground, fontSize: 13),
                    ),
                    Text(
                      style.label,
                      style: TextStyle(
                        fontFamily: AppTheme.headingFont,
                        fontSize: 22,
                        color: style.foreground,
                      ),
                    ),
                    Text(
                      abnormal.isEmpty
                          ? 'Sin signos detectados'
                          : 'Signos: ${abnormal.join(', ')}',
                      style: TextStyle(color: style.foreground),
                    ),
                    if (analysis.isSimulated)
                      Text(
                        'Resultado simulado',
                        style: TextStyle(
                          color: style.foreground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              ExcludeSemantics(
                child: Icon(Icons.chevron_right, color: style.foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Escaneos anteriores: filas compactas que ceden protagonismo al más reciente.
class HistoryTile extends StatelessWidget {
  const HistoryTile({super.key, required this.analysis, required this.onTap});

  final Analysis analysis;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final abnormal = analysis.abnormalFindings.map((f) => f.name.toLowerCase());
    final detail = abnormal.isEmpty
        ? 'Sin signos detectados'
        : 'Signos: ${abnormal.join(', ')}';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: 12,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatDateTime(analysis.createdAt),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  RiskStamp(level: analysis.riskLevel, dense: true),
                  const SizedBox(height: 6),
                  Text(detail),
                  if (analysis.isSimulated)
                    Text(
                      'Resultado simulado',
                      style: TextStyle(
                        color: scheme.tertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            ExcludeSemantics(
              child: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
