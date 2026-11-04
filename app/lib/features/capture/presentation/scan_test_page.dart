import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/config.dart';
import '../../../shared/widgets/vet_notice.dart';
import '../data/tooth_scanner.dart';

/// Pantalla TEMPORAL para verificar la integración con AI for Pet en un celular real
/// (clave, paquete y SHA-256 registrados). Cada escaneo consume un análisis del plan.
/// En la etapa 3 se reemplaza por el flujo completo: mascota → autorización → cámara →
/// envío a la API → resultado.
class ScanTestPage extends StatefulWidget {
  const ScanTestPage({super.key, this.scanner});

  final ToothScanner? scanner;

  @override
  State<ScanTestPage> createState() => _ScanTestPageState();
}

class _ScanTestPageState extends State<ScanTestPage> {
  // Identificadores de prueba con formato UUID, como los que dará la API.
  static const _testUserId = '00000000-0000-4000-8000-000000000001';
  static const _testPetId = '00000000-0000-4000-8000-000000000002';

  late final ToothScanner _scanner =
      widget.scanner ?? ToothScanner(sdkKey: AppConfig.aiforpetSdkKey);

  bool _scanning = false;
  String? _message;
  ToothScanResult? _result;

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _message = null;
      _result = null;
    });
    try {
      final result = await _scanner.scan(
        userId: _testUserId,
        petId: _testPetId,
      );
      setState(() {
        _result = result;
        _message = result == null ? 'Escaneo cancelado.' : null;
      });
    } on ToothScannerException catch (e) {
      setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Prueba · AI for Pet')),
      bottomNavigationBar: const VetNotice(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Pantalla de prueba de la integración. Abre la cámara de dientes de AI for Pet '
            'y muestra el resultado tal como lo devuelve el SDK.',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _scanning ? null : _scan,
            icon: const Icon(Icons.camera_alt_outlined),
            label: Text(_scanning ? 'Escaneando…' : 'Escanear dientes'),
          ),
          if (_message != null) ...[
            const SizedBox(height: 16),
            Text(_message!, key: const Key('scan-message')),
          ],
          if (result != null) ...[
            const SizedBox(height: 16),
            _StatusChip(status: result.providerStatus),
            const SizedBox(height: 12),
            SelectableText(
              const JsonEncoder.withIndent('  ').convert(result.json),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'NORMAL' => ('Verde · sin signos', Colors.green),
      'CAUTION' => ('Amarillo · vigilar', Colors.amber),
      'WARNING' => ('Rojo · consultar pronto', Colors.red),
      _ => ('Estado desconocido: $status', Colors.grey),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(
        avatar: CircleAvatar(backgroundColor: color),
        label: Text(label),
      ),
    );
  }
}
