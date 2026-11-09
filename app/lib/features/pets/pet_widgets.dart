import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/api/models.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/risk_style.dart';
import '../../shared/widgets/motion.dart';
import '../../shared/widgets/risk_badge.dart';
import '../../shared/widgets/states.dart';

final _dateTime = DateFormat("d MMM y · h:mm a", 'es');

String formatDateTime(DateTime value) => _dateTime.format(value);

/// "hoy, 10:48 a. m.", "ayer, …" o "4 de noviembre".
String relativeDay(DateTime when) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(when.year, when.month, when.day);
  final hour = DateFormat('h:mm a', 'es').format(when);
  final days = today.difference(day).inDays;
  if (days == 0) return 'hoy, $hour';
  if (days == 1) return 'ayer, $hour';
  if (days < 7) return 'hace $days días';
  return DateFormat("d 'de' MMMM", 'es').format(when);
}

/// "Pug · 3 años · 8,5 kg"
String petSummary(Pet pet) {
  final weight = pet.weightKg == null
      ? null
      : '${NumberFormat.decimalPattern('es').format(pet.weightKg)} kg';
  return [pet.breed, pet.ageLabel(), weight].whereType<String>().join(' · ');
}

/// "inflamación de encías, sarro (cálculo dental)" o "Sin signos detectados".
String findingsSummary(Analysis analysis) {
  final abnormal = analysis.abnormalFindings.map((f) => f.name.toLowerCase());
  return abnormal.isEmpty
      ? 'Sin signos detectados'
      : 'Signos: ${abnormal.join(', ')}';
}

/// Recorte de la foto analizada (alojado por AI for Pet). Si no hay foto o el enlace
/// venció, muestra un diente sobre el color del nivel.
class AnalysisPhoto extends StatelessWidget {
  const AnalysisPhoto({
    super.key,
    required this.analysis,
    this.size = 56,
    this.circle = true,
  });

  final Analysis analysis;
  final double size;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final style = RiskStyle.of(context, analysis.riskLevel);
    final placeholder = ColoredBox(
      color: style.background,
      child: Center(
        child: Icon(
          Icons.pets,
          size: size * 0.42,
          color: style.foreground.withValues(alpha: 0.7),
        ),
      ),
    );
    final url = analysis.photoUrls.firstOrNull;
    final image = url == null
        ? placeholder
        : Image.network(
            url,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => placeholder,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : placeholder,
          );
    return SizedBox.square(
      dimension: size,
      child: circle
          ? ClipOval(child: image)
          : ClipRRect(
              borderRadius: BorderRadius.circular(size * 0.28),
              child: image,
            ),
    );
  }
}

/// El escaneo más reciente: foto, sello del nivel y signos.
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
    final scheme = Theme.of(context).colorScheme;
    final detail = [
      relativeDay(analysis.createdAt),
      ?analysis.positionLabel,
    ].join(' · ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Row(
            children: [
              AnalysisPhoto(analysis: analysis, size: 72, circle: false),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RiskBadge(level: analysis.riskLevel),
                    const SizedBox(height: Spacing.sm),
                    Text(
                      findingsSummary(analysis),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    if (analysis.isSimulated)
                      Text(
                        'Resultado simulado',
                        style: TextStyle(
                          color: scheme.tertiary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
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

/// Escaneos anteriores como línea de tiempo.
class HistoryTimeline extends StatelessWidget {
  const HistoryTimeline({
    super.key,
    required this.analyses,
    required this.onOpen,
  });

  final List<Analysis> analyses;
  final void Function(Analysis) onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final (i, analysis) in analyses.indexed)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 28,
                  child: Column(
                    children: [
                      Container(
                        width: 2,
                        height: 22,
                        color: i == 0
                            ? Colors.transparent
                            : scheme.outlineVariant,
                      ),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: RiskStyle.of(
                            context,
                            analysis.riskLevel,
                          ).foreground,
                        ),
                      ),
                      Expanded(
                        child: Container(
                          width: 2,
                          color: i == analyses.length - 1
                              ? Colors.transparent
                              : scheme.outlineVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.sm),
                    child: _HistoryEntry(
                      analysis: analysis,
                      onTap: () => onOpen(analysis),
                    ),
                  ),
                ),
              ],
            ),
          ).entrance(context, index: i),
      ],
    );
  }
}

class _HistoryEntry extends StatelessWidget {
  const _HistoryEntry({required this.analysis, required this.onTap});

  final Analysis analysis;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              AnalysisPhoto(analysis: analysis, size: 48, circle: false),
              const SizedBox(width: 12),
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
                    const SizedBox(height: 4),
                    RiskBadge(
                      level: analysis.riskLevel,
                      size: RiskBadgeSize.small,
                    ),
                    const SizedBox(height: 4),
                    Text(findingsSummary(analysis)),
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

/// Hoja para tomar, elegir o quitar la foto del perro. La foto se guarda solo en el
/// teléfono.
Future<void> choosePetPhoto(
  BuildContext context,
  WidgetRef ref, {
  required String petId,
  required bool hasPhoto,
}) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.md,
          0,
          Spacing.md,
          Spacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Foto de tu perro',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              'Se guarda solo en este teléfono.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.md),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.hide_image_outlined),
                title: const Text('Quitar foto'),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
          ],
        ),
      ),
    ),
  );
  if (action == null) return;
  final store = ref.read(petPhotoStoreProvider);
  try {
    if (action == 'remove') {
      await store.delete(petId);
    } else {
      final picked = await ImagePicker().pickImage(
        source: action == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 900,
        maxHeight: 900,
        imageQuality: 85,
      );
      if (picked == null) return;
      await store.save(petId, await picked.readAsBytes());
    }
    ref.invalidate(petPhotoProvider(petId));
  } catch (_) {
    if (context.mounted) {
      showMessage(
        context,
        'No pudimos usar esa foto. Revisa el permiso de cámara o elige otra.',
      );
    }
  }
}
