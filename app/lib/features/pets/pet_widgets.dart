import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/models.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/risk_badge.dart';

final _dateTime = DateFormat("d MMM y · h:mm a", 'es');

String formatDateTime(DateTime value) => _dateTime.format(value);

/// "Pug · 3 años · 8,5 kg"
String petSummary(Pet pet) {
  final weight = pet.weightKg == null
      ? null
      : '${NumberFormat.decimalPattern('es').format(pet.weightKg)} kg';
  return [pet.breed, pet.ageLabel(), weight].whereType<String>().join(' · ');
}

class PetAvatar extends StatelessWidget {
  const PetAvatar({super.key, required this.name, this.radius = 24});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: radius,
        backgroundColor: scheme.primaryContainer,
        child: Text(
          name.isEmpty ? '?' : name.characters.first.toUpperCase(),
          style: TextStyle(
            fontFamily: AppTheme.headingFont,
            fontSize: radius * 0.8,
            color: scheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}

class PetCard extends StatelessWidget {
  const PetCard({super.key, required this.pet, required this.onTap});

  final Pet pet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final summary = petSummary(pet);
    final last = pet.lastAnalysis;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Row(
            children: [
              PetAvatar(name: pet.name),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pet.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (summary.isNotEmpty)
                      Text(
                        summary,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    const SizedBox(height: Spacing.sm),
                    if (last != null)
                      RiskBadge(level: last.riskLevel)
                    else
                      Text(
                        'Sin escaneos aún',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              ExcludeSemantics(
                child: Icon(
                  Icons.chevron_right,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
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
                    const SizedBox(height: Spacing.sm),
                    RiskBadge(level: analysis.riskLevel),
                    const SizedBox(height: Spacing.sm),
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
                child: Icon(
                  Icons.chevron_right,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
