import 'dart:convert';

import 'package:flutter/services.dart';

/// Resultado del SDK de AI for Pet tal como llega (se envía sin cambios a la API).
class ToothScanResult {
  const ToothScanResult({required this.raw, required this.json});

  /// Texto JSON original.
  final String raw;

  /// El mismo JSON ya decodificado.
  final Map<String, dynamic> json;

  /// `NORMAL`, `CAUTION` o `WARNING`; null si el SDK no lo incluyó.
  String? get providerStatus {
    final response = json['response'];
    return response is Map<String, dynamic>
        ? response['status'] as String?
        : null;
  }
}

class ToothScannerException implements Exception {
  const ToothScannerException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'ToothScannerException($code): $message';
}

/// Abre la cámara de dientes del SDK de AI for Pet (código nativo en MainActivity.kt).
///
/// Antes de llamar a [scan], la app debe confirmar que el usuario aceptó la autorización
/// de datos vigente (`GET /api/v1/me` → `consent.required == false`): en cuanto se toma
/// la foto, el SDK la envía a los servidores de AI for Pet.
class ToothScanner {
  ToothScanner({required this.sdkKey, MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'co.edu.ucc.mandidog/aiforpet';

  final String sdkKey;
  final MethodChannel _channel;

  /// [userId] y [petId] son los UUID de nuestra API, nunca datos personales.
  /// Devuelve null si el usuario cierra la cámara sin terminar.
  Future<ToothScanResult?> scan({
    required String userId,
    required String petId,
  }) async {
    if (sdkKey.isEmpty) {
      throw const ToothScannerException(
        'missing_sdk_key',
        'Falta la clave del SDK. Compila con --dart-define=AIFORPET_SDK_KEY=...',
      );
    }

    final String? raw;
    try {
      raw = await _channel.invokeMethod<String>('scanTeeth', {
        'sdkKey': sdkKey,
        'userId': userId,
        'petId': petId,
      });
    } on PlatformException catch (e) {
      throw ToothScannerException(
        e.code,
        e.message ?? 'Error del SDK de AI for Pet',
      );
    }

    if (raw == null || raw.isEmpty) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const ToothScannerException(
        'invalid_result',
        'El SDK devolvió un resultado ilegible.',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ToothScannerException(
        'invalid_result',
        'El SDK devolvió un formato inesperado.',
      );
    }
    return ToothScanResult(raw: raw, json: decoded);
  }
}
