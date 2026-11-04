import 'dart:convert';

/// Resultado de ejemplo OFICIAL de AI for Pet (`sdk-callback-single.json`, publicado en
/// https://sdk.aiforpet.com/docs/TTcare_SDK_Single_Callback_Examples.zip), cambiando
/// `petType` de CAT a DOG. Sirve para simular el escaneo donde no existe el SDK
/// (navegador, escritorio). No es un análisis real.
Map<String, dynamic> officialSampleToothResult({
  required String userId,
  required String petId,
}) {
  final result = jsonDecode(_officialSampleJson) as Map<String, dynamic>;
  return {...result, 'petType': 'DOG', 'userId': userId, 'petId': petId};
}

const _officialSampleJson = '''
{
  "status": "SUCCESS",
  "petType": "CAT",
  "part": "TOOTH",
  "createdAt": 1792530000000,
  "subPart": "TLEFT",
  "positionCode": "TLEFT",
  "response": {
    "status": "CAUTION",
    "title": "Check the findings below.",
    "analyzedDate": "2026. 10. 21 06:00",
    "symptoms": [
      {
        "code": "inflammation",
        "name": "Inflammation",
        "abnormLevel": 1,
        "abnormalLevel": 1,
        "isAbnormal": true,
        "resultLabel": "abnormal",
        "cropImageUrl": "https://example.invalid/crop.jpg",
        "heatmapUrl": "https://example.invalid/inflammation.jpg",
        "details": []
      },
      {
        "code": "calculus",
        "name": "Tartar",
        "abnormLevel": 0,
        "abnormalLevel": 0,
        "isAbnormal": false,
        "resultLabel": "normal",
        "cropImageUrl": "https://example.invalid/crop.jpg",
        "heatmapUrl": "https://example.invalid/calculus.jpg",
        "details": []
      }
    ]
  }
}
''';
