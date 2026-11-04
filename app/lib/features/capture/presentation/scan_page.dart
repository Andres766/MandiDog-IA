import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config.dart';
import '../../../core/ids.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/page_body.dart';
import '../../../shared/widgets/states.dart';
import '../../auth/auth_widgets.dart';
import '../data/sample_result.dart';
import '../data/tooth_scanner.dart';

enum _Phase { idle, scanning, saving }

/// Escaneo guardado localmente hasta que la API lo confirme (para reintentar sin
/// repetir el escaneo ni gastar otro análisis de AI for Pet).
class _PendingScan {
  _PendingScan({required this.result, required this.simulated})
    : clientScanId = uuidV4();

  final Map<String, dynamic> result;
  final bool simulated;
  final String clientScanId;
}

class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key, required this.petId});

  final String petId;

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  _Phase _phase = _Phase.idle;
  _PendingScan? _pending;
  String? _error;

  bool get _sdkAvailable => ref.read(sdkAvailableProvider);

  Future<void> _scan() async {
    setState(() {
      _phase = _Phase.scanning;
      _error = null;
    });
    try {
      final me = await ref.read(meProvider.future);
      if (me.consent.required) {
        // Defensa extra: sin autorización vigente no se abre la cámara.
        if (mounted) {
          context.pushReplacement(
            '/consent?next=${Uri.encodeComponent('/pets/${widget.petId}/scan')}',
          );
        }
        return;
      }

      final Map<String, dynamic> result;
      if (_sdkAvailable) {
        final scan = await ref
            .read(toothScannerProvider)
            .scan(userId: me.id, petId: widget.petId);
        if (scan == null) {
          if (mounted) {
            setState(() => _phase = _Phase.idle);
            showMessage(context, 'Escaneo cancelado.');
          }
          return;
        }
        result = scan.json;
      } else {
        result = officialSampleToothResult(userId: me.id, petId: widget.petId);
      }
      _pending = _PendingScan(result: result, simulated: !_sdkAvailable);
      await _save();
    } on ToothScannerException catch (e) {
      _fail(e.message);
    } catch (e) {
      _fail(friendlyError(e));
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.idle;
      _error = message;
    });
  }

  Future<void> _save() async {
    final pending = _pending!;
    setState(() {
      _phase = _Phase.saving;
      _error = null;
    });
    try {
      final analysis = await ref
          .read(apiProvider)
          .submitScan(
            petId: widget.petId,
            clientScanId: pending.clientScanId,
            sdkVersion: pending.simulated
                ? '${AppConfig.aiforpetSdkVersion}-simulacion'
                : AppConfig.aiforpetSdkVersion,
            result: pending.result,
          );
      refreshPetData(ref, widget.petId);
      if (mounted) {
        context.pushReplacement(
          '/pets/${widget.petId}/analyses/${analysis.id}',
          extra: analysis,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = _Phase.idle;
          _error =
              'No pudimos guardar el resultado, pero tu escaneo no se perdió. '
              '${friendlyError(e)}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final busy = _phase != _Phase.idle;
    final retrySave =
        _pending != null && _phase == _Phase.idle && _error != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Escanear dientes')),
      body: PageBody(
        children: [
          Text(
            'Antes de empezar',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: Spacing.md),
          const _Tip(
            icon: Icons.wb_sunny_outlined,
            title: 'Busca buena luz',
            text:
                'Luz natural o una lámpara. Evita el reflejo del flash sobre los dientes.',
          ),
          const _Tip(
            icon: Icons.front_hand_outlined,
            title: 'Levanta el labio con suavidad',
            text: 'Que se vean bien los dientes y las encías.',
          ),
          const _Tip(
            icon: Icons.center_focus_strong_outlined,
            title: 'Acércate y enfoca',
            text:
                'La cámara de AI for Pet te guía con un marco y revisa la nitidez.',
          ),
          const _Tip(
            icon: Icons.swap_horiz,
            title: 'Un lado por escaneo',
            text: 'Izquierda, frente o derecha. Puedes repetir para cada lado.',
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'La cámara de AI for Pet está en inglés. También puedes elegir una foto de la '
            'galería: debe medir al menos 1400 × 1400 píxeles.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          if (!_sdkAvailable) ...[
            const SizedBox(height: Spacing.md),
            Card(
              color: scheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(Spacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.science_outlined,
                      color: scheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Text(
                        'Modo simulación: la cámara de AI for Pet solo existe en Android. '
                        'Se usará el resultado de ejemplo oficial y quedará marcado como '
                        'simulado.',
                        key: const Key('simulation-notice'),
                        style: TextStyle(color: scheme.onTertiaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: Spacing.lg),
          FormError(_error),
          if (retrySave) ...[
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Reintentar envío'),
            ),
            const SizedBox(height: Spacing.sm),
            OutlinedButton(
              onPressed: () => setState(() {
                _pending = null;
                _error = null;
              }),
              child: const Text('Descartar y escanear de nuevo'),
            ),
          ] else
            BusyButton(
              label: switch (_phase) {
                _Phase.scanning => 'Esperando la cámara…',
                _Phase.saving => 'Guardando resultado…',
                _Phase.idle =>
                  _sdkAvailable ? 'Abrir cámara' : 'Simular escaneo',
              },
              icon: _sdkAvailable
                  ? Icons.photo_camera_outlined
                  : Icons.science_outlined,
              busy: busy,
              onPressed: _scan,
            ),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: CircleAvatar(
              radius: 20,
              backgroundColor: scheme.primaryContainer,
              child: Icon(icon, size: 22, color: scheme.onPrimaryContainer),
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(text, style: TextStyle(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
