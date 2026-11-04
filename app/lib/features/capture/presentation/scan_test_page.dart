import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/api/mandidog_api.dart';
import '../../../core/config.dart';
import '../../../core/ids.dart';
import '../../../shared/widgets/vet_notice.dart';
import '../data/sample_result.dart';
import '../data/tooth_scanner.dart';

/// Pantalla TEMPORAL para probar la integración completa:
/// autorización → escaneo (SDK real en Android, ejemplo oficial en otras plataformas) →
/// registro en la API → resultado. En la etapa 3 se reemplaza por el flujo definitivo.
class ScanTestPage extends StatefulWidget {
  const ScanTestPage({
    super.key,
    required this.api,
    required this.scanner,
    required this.sdkAvailable,
  });

  final MandiDogApi api;
  final ToothScanner scanner;
  final bool sdkAvailable;

  @override
  State<ScanTestPage> createState() => _ScanTestPageState();
}

class _ScanTestPageState extends State<ScanTestPage> {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _pet;
  bool _busy = false;
  String? _message;

  Map<String, dynamic>? _sdkResult;
  String? _pendingScanId;
  Map<String, dynamic>? _analysis;

  bool get _consentRequired => _user?['consent']?['required'] != false;
  String get _policyVersion => '${_user?['consent']?['current_version']}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } on ApiException catch (e) {
      setState(() => _message = e.message);
    } on ToothScannerException catch (e) {
      setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() => _run(() async {
    final user = await widget.api.me();
    final pets = await widget.api.pets();
    final pet = pets.isNotEmpty
        ? pets.first as Map<String, dynamic>
        : await widget.api.createPet('Mascota de prueba');
    setState(() {
      _user = user;
      _pet = pet;
    });
  });

  Future<void> _acceptConsent() => _run(() async {
    final user = await widget.api.acceptConsent(_policyVersion);
    setState(() => _user = user);
  });

  Future<void> _scan() => _run(() async {
    setState(() {
      _sdkResult = null;
      _analysis = null;
    });
    final userId = '${_user!['id']}';
    final petId = '${_pet!['id']}';

    if (widget.sdkAvailable) {
      final scan = await widget.scanner.scan(userId: userId, petId: petId);
      if (scan == null) {
        setState(() => _message = 'Escaneo cancelado.');
        return;
      }
      _sdkResult = scan.json;
    } else {
      _sdkResult = officialSampleToothResult(userId: userId, petId: petId);
    }
    // Un id por escaneo: si el envío falla, el reintento usa el mismo.
    _pendingScanId = uuidV4();
    await _submit();
  });

  Future<void> _submit() async {
    final analysis = await widget.api.submitScan(
      petId: '${_pet!['id']}',
      clientScanId: _pendingScanId!,
      sdkVersion: widget.sdkAvailable
          ? AppConfig.aiforpetSdkVersion
          : '${AppConfig.aiforpetSdkVersion}-simulacion',
      result: _sdkResult!,
    );
    setState(() {
      _analysis = analysis;
      _pendingScanId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ready = _user != null && _pet != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Prueba de integración')),
      bottomNavigationBar: const VetNotice(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_message != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                key: const Key('message'),
                leading: const Icon(Icons.info_outline),
                title: Text(_message!),
                trailing: _user == null
                    ? TextButton(
                        onPressed: _load,
                        child: const Text('Reintentar'),
                      )
                    : null,
              ),
            ),
          if (ready) ...[
            _ConsentCard(
              pending: _consentRequired,
              version: _policyVersion,
              enabled: !_busy,
              onAccept: _acceptConsent,
            ),
            const SizedBox(height: 12),
            _ScanCard(
              sdkAvailable: widget.sdkAvailable,
              petName: '${_pet!['name']}',
              enabled: !_busy && !_consentRequired,
              onScan: _scan,
              onRetrySubmit: _pendingScanId != null && _sdkResult != null
                  ? () => _run(_submit)
                  : null,
            ),
          ],
          if (_analysis != null) ...[
            const SizedBox(height: 12),
            _AnalysisCard(analysis: _analysis!),
          ],
          if (_sdkResult != null) ...[
            const SizedBox(height: 12),
            ExpansionTile(
              title: const Text('JSON devuelto por el SDK'),
              children: [
                SelectableText(
                  const JsonEncoder.withIndent('  ').convert(_sdkResult),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ConsentCard extends StatelessWidget {
  const _ConsentCard({
    required this.pending,
    required this.version,
    required this.enabled,
    required this.onAccept,
  });

  final bool pending;
  final String version;
  final bool enabled;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    if (!pending) {
      return Card(
        child: ListTile(
          leading: const Icon(
            Icons.verified_user_outlined,
            color: Colors.green,
          ),
          title: const Text('1. Autorización aceptada'),
          subtitle: Text('Versión $version'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1. Autorización de datos',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Para analizar la salud dental de tu perro, la foto se envía a AI for Pet, '
              'empresa de Corea del Sur que hace el análisis con inteligencia artificial. '
              'Solo se envía un identificador interno, no tu nombre ni tu correo. '
              'Puedes revocar esta autorización cuando quieras.',
            ),
            CheckboxListTile(
              key: const Key('consent-checkbox'),
              contentPadding: EdgeInsets.zero,
              value: false,
              onChanged: enabled ? (_) => onAccept() : null,
              title: Text('Acepto la autorización (versión $version)'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanCard extends StatelessWidget {
  const _ScanCard({
    required this.sdkAvailable,
    required this.petName,
    required this.enabled,
    required this.onScan,
    required this.onRetrySubmit,
  });

  final bool sdkAvailable;
  final String petName;
  final bool enabled;
  final VoidCallback onScan;
  final VoidCallback? onRetrySubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '2. Escanear los dientes de $petName',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (!sdkAvailable) ...[
              const SizedBox(height: 8),
              const Text(
                'Simulación: el SDK de AI for Pet solo funciona en Android. Aquí se usa '
                'el resultado de ejemplo oficial de AI for Pet, que sí se registra en la '
                'API (marcado como "simulacion").',
                key: Key('simulation-notice'),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: enabled ? onScan : null,
                  icon: Icon(
                    sdkAvailable
                        ? Icons.camera_alt_outlined
                        : Icons.science_outlined,
                  ),
                  label: Text(
                    sdkAvailable ? 'Escanear dientes' : 'Simular escaneo',
                  ),
                ),
                if (onRetrySubmit != null)
                  OutlinedButton.icon(
                    onPressed: onRetrySubmit,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar envío'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard({required this.analysis});

  final Map<String, dynamic> analysis;

  static const _levels = {
    'green': ('Verde · sin signos de riesgo', Colors.green),
    'yellow': ('Amarillo · conviene vigilar', Colors.amber),
    'red': ('Rojo · consulta pronto', Colors.red),
  };
  static const _findingStatus = {
    'normal': 'Normal',
    'abnormal': 'Signos detectados',
    'unknown': 'No evaluado',
  };

  @override
  Widget build(BuildContext context) {
    final (label, color) =
        _levels[analysis['risk_level']] ??
        ('${analysis['risk_level']}', Colors.grey);
    final findings = (analysis['findings'] as List)
        .cast<Map<String, dynamic>>();
    return Card(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: color, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 10, backgroundColor: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final f in findings)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  f['status'] == 'abnormal'
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline,
                ),
                title: Text('${f['name']}'),
                trailing: Text(_findingStatus[f['status']] ?? '${f['status']}'),
              ),
            const SizedBox(height: 8),
            Text('${analysis['recommendation']}'),
            const SizedBox(height: 8),
            Text(
              'Registrado por la API · ${analysis['model_version']}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
