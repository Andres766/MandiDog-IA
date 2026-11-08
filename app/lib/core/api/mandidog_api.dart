import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Error de la API con el formato `{"error": {"code", "message"}}`.
/// `message` está en español y se puede mostrar tal cual.
class ApiException implements Exception {
  const ApiException(this.code, this.message, {this.statusCode});

  final String code;
  final String message;
  final int? statusCode;

  bool get isOffline => code == 'api_unreachable';

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

/// Cliente de la API de MandiDog.
///
/// Se identifica con el token de Firebase (`Authorization: Bearer`) o, en modo
/// desarrollo, con el header `X-Dev-User`.
class MandiDogApi {
  MandiDogApi({
    required this.baseUrl,
    required Future<String?> Function() idToken,
    required String? Function() devUser,
    http.Client? client,
  }) : _idToken = idToken,
       _devUser = devUser,
       _client = client ?? http.Client();

  final String baseUrl;
  final Future<String?> Function() _idToken;
  final String? Function() _devUser;
  final http.Client _client;

  Future<UserProfile> me() async =>
      UserProfile.fromJson(await _send('GET', '/api/v1/me'));

  Future<UserProfile> acceptConsent(String policyVersion) async =>
      UserProfile.fromJson(
        await _send('PUT', '/api/v1/me/consent', {
          'policy_version': policyVersion,
        }),
      );

  Future<void> revokeConsent() => _send('DELETE', '/api/v1/me/consent');

  Future<void> deleteAccount() => _send('DELETE', '/api/v1/me');

  Future<List<Pet>> pets() async => [
    for (final p in await _send('GET', '/api/v1/pets') as List)
      Pet.fromJson(p as Map<String, dynamic>),
  ];

  Future<Pet> pet(String id) async =>
      Pet.fromJson(await _send('GET', '/api/v1/pets/$id'));

  Future<Pet> createPet(Map<String, Object?> data) async =>
      Pet.fromJson(await _send('POST', '/api/v1/pets', data));

  Future<Pet> updatePet(String id, Map<String, Object?> changes) async =>
      Pet.fromJson(await _send('PATCH', '/api/v1/pets/$id', changes));

  Future<void> deletePet(String id) => _send('DELETE', '/api/v1/pets/$id');

  Future<List<Analysis>> history(String petId, {int limit = 50}) async => [
    for (final a
        in await _send('GET', '/api/v1/pets/$petId/analyses?limit=$limit')
            as List)
      Analysis.fromJson(a as Map<String, dynamic>),
  ];

  // Validación clínica (solo veterinarios).
  Future<List<PendingCase>> pendingCases() async => [
    for (final c in await _send('GET', '/api/v1/validations/pending') as List)
      PendingCase.fromJson(c as Map<String, dynamic>),
  ];

  Future<ValidationReveal> submitValidation(
    String analysisId,
    VetAssessment assessment,
    String? notes,
  ) async => ValidationReveal.fromJson(
    await _send('POST', '/api/v1/analyses/$analysisId/validation', {
      'vet_assessment': assessment.api,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    }),
  );

  Future<ValidationSummary> validationSummary() async =>
      ValidationSummary.fromJson(
        await _send('GET', '/api/v1/validations/summary'),
      );

  /// Registra un escaneo. Si falla la red, reintentar con el MISMO [clientScanId]:
  /// la API devuelve el análisis ya guardado en vez de duplicarlo.
  Future<Analysis> submitScan({
    required String petId,
    required String clientScanId,
    required String sdkVersion,
    required Map<String, dynamic> result,
  }) async => Analysis.fromJson(
    await _send('POST', '/api/v1/analysis', {
      'pet_id': petId,
      'client_scan_id': clientScanId,
      'sdk_platform': 'android',
      'sdk_version': sdkVersion,
      'result': result,
    }),
  );

  /// Un proxy puede responder HTML (por ejemplo, un 502): eso no es JSON.
  static Object? _decode(List<int> bytes) {
    if (bytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(bytes));
    } on FormatException {
      return null;
    }
  }

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers['Content-Type'] = 'application/json';
    final token = await _idToken();
    final devUser = _devUser();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    } else if (devUser != null) {
      request.headers['X-Dev-User'] = devUser;
    }
    if (body != null) request.body = jsonEncode(body);

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _client.send(request));
    } on http.ClientException {
      throw const ApiException(
        'api_unreachable',
        'No pudimos conectarnos con el servidor. Revisa tu conexión e inténtalo de nuevo.',
      );
    }

    final decoded = _decode(response.bodyBytes);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final error = decoded is Map<String, dynamic> ? decoded['error'] : null;
    if (error is Map<String, dynamic>) {
      throw ApiException(
        '${error['code']}',
        '${error['message']}',
        statusCode: response.statusCode,
      );
    }
    throw ApiException(
      'http_${response.statusCode}',
      response.statusCode >= 500
          ? 'El servidor tuvo un problema. Inténtalo de nuevo en unos minutos.'
          : 'No pudimos completar la solicitud (${response.statusCode}).',
      statusCode: response.statusCode,
    );
  }
}
