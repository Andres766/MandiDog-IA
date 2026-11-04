import 'dart:convert';

import 'package:http/http.dart' as http;

/// Error de la API con el formato `{"error": {"code", "message"}}`.
/// `message` está en español y se puede mostrar tal cual.
class ApiException implements Exception {
  const ApiException(this.code, this.message, {this.statusCode});

  final String code;
  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

/// Cliente mínimo de la API de MandiDog.
///
/// Por ahora se identifica con `X-Dev-User` (AUTH_MODE=dev). En la etapa 3 se reemplaza
/// por el token de Firebase Auth.
class MandiDogApi {
  MandiDogApi({
    required this.baseUrl,
    required this.devUser,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String devUser;
  final http.Client _client;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (devUser.isNotEmpty) 'X-Dev-User': devUser,
  };

  Future<Map<String, dynamic>> me() async => await _send('GET', '/api/v1/me');

  Future<Map<String, dynamic>> acceptConsent(String policyVersion) async =>
      await _send('PUT', '/api/v1/me/consent', {
        'policy_version': policyVersion,
      });

  Future<List<dynamic>> pets() async => await _send('GET', '/api/v1/pets');

  Future<Map<String, dynamic>> createPet(String name) async =>
      await _send('POST', '/api/v1/pets', {'name': name});

  /// Registra un escaneo. Si falla la red, reintentar con el MISMO [clientScanId]:
  /// la API devuelve el análisis ya guardado en vez de duplicarlo.
  Future<Map<String, dynamic>> submitScan({
    required String petId,
    required String clientScanId,
    required String sdkVersion,
    required Map<String, dynamic> result,
  }) async => await _send('POST', '/api/v1/analysis', {
    'pet_id': petId,
    'client_scan_id': clientScanId,
    'sdk_platform': 'android',
    'sdk_version': sdkVersion,
    'result': result,
  });

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers.addAll(_headers);
    if (body != null) request.body = jsonEncode(body);

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _client.send(request));
    } on http.ClientException {
      throw ApiException(
        'api_unreachable',
        'No se pudo conectar con la API ($baseUrl). ¿Está corriendo?',
      );
    }

    final decoded = response.body.isEmpty
        ? null
        : jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;

    final error = decoded is Map<String, dynamic> ? decoded['error'] : null;
    throw ApiException(
      error is Map<String, dynamic>
          ? '${error['code']}'
          : 'http_${response.statusCode}',
      error is Map<String, dynamic>
          ? '${error['message']}'
          : 'La API respondió ${response.statusCode}.',
      statusCode: response.statusCode,
    );
  }
}
