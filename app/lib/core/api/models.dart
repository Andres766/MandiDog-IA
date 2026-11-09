import '../theme/risk_style.dart';

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;

class Consent {
  const Consent({
    required this.currentVersion,
    required this.acceptedVersion,
    required this.acceptedAt,
    required this.required,
  });

  factory Consent.fromJson(Map<String, dynamic> json) => Consent(
    currentVersion: json['current_version'] as String,
    acceptedVersion: json['accepted_version'] as String?,
    acceptedAt: _date(json['accepted_at']),
    required: json['required'] as bool,
  );

  final String currentVersion;
  final String? acceptedVersion;
  final DateTime? acceptedAt;

  /// true si el usuario debe aceptar la versión vigente antes de escanear.
  final bool required;
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    required this.consent,
    this.role = 'owner',
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    email: json['email'] as String?,
    displayName: json['display_name'] as String?,
    consent: Consent.fromJson(json['consent'] as Map<String, dynamic>),
    role: json['role'] as String? ?? 'owner',
  );

  final String id;
  final String? email;
  final String? displayName;
  final Consent consent;

  /// owner, vet o admin. Veterinarios y administradores ven la validación clínica.
  final String role;

  bool get canValidate => role == 'vet' || role == 'admin';
}

enum PetSex {
  male('male', 'Macho'),
  female('female', 'Hembra'),
  unknown('unknown', 'No sé');

  const PetSex(this.api, this.label);

  final String api;
  final String label;

  static PetSex parse(String? value) => PetSex.values.firstWhere(
    (s) => s.api == value,
    orElse: () => PetSex.unknown,
  );
}

class LastAnalysis {
  const LastAnalysis({required this.riskLevel, required this.createdAt});

  final RiskLevel riskLevel;
  final DateTime createdAt;
}

class Pet {
  const Pet({
    required this.id,
    required this.name,
    this.breed,
    this.sex = PetSex.unknown,
    this.birthDate,
    this.weightKg,
    this.lastAnalysis,
  });

  factory Pet.fromJson(Map<String, dynamic> json) {
    final last = json['last_analysis'];
    final level = last is Map<String, dynamic>
        ? RiskLevel.parse(last['risk_level'] as String?)
        : null;
    return Pet(
      id: json['id'] as String,
      name: json['name'] as String,
      breed: json['breed'] as String?,
      sex: PetSex.parse(json['sex'] as String?),
      birthDate: json['birth_date'] is String
          ? DateTime.tryParse(json['birth_date'] as String)
          : null,
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      lastAnalysis: level == null
          ? null
          : LastAnalysis(
              riskLevel: level,
              createdAt: _date((last as Map<String, dynamic>)['created_at'])!,
            ),
    );
  }

  final String id;
  final String name;
  final String? breed;
  final PetSex sex;
  final DateTime? birthDate;
  final double? weightKg;
  final LastAnalysis? lastAnalysis;

  /// "3 años", "7 meses" o null.
  String? ageLabel([DateTime? now]) {
    final birth = birthDate;
    if (birth == null) return null;
    final today = now ?? DateTime.now();
    var months = (today.year - birth.year) * 12 + today.month - birth.month;
    if (today.day < birth.day) months--;
    if (months < 1) return 'Menos de 1 mes';
    if (months < 12) return months == 1 ? '1 mes' : '$months meses';
    final years = months ~/ 12;
    return years == 1 ? '1 año' : '$years años';
  }
}

enum FindingStatus {
  normal('Normal'),
  abnormal('Signos detectados'),
  unknown('No evaluado');

  const FindingStatus(this.label);

  final String label;

  static FindingStatus parse(String? value) => switch (value) {
    'normal' => FindingStatus.normal,
    'abnormal' => FindingStatus.abnormal,
    _ => FindingStatus.unknown,
  };
}

class Finding {
  const Finding({required this.code, required this.name, required this.status});

  factory Finding.fromJson(Map<String, dynamic> json) => Finding(
    code: json['code'] as String,
    name: json['name'] as String,
    status: FindingStatus.parse(json['status'] as String?),
  );

  final String code;
  final String name;
  final FindingStatus status;
}

class Analysis {
  const Analysis({
    required this.id,
    required this.riskLevel,
    required this.findings,
    required this.subPart,
    required this.modelVersion,
    required this.recommendation,
    required this.createdAt,
    this.photoUrls = const [],
  });

  factory Analysis.fromJson(Map<String, dynamic> json) => Analysis(
    id: json['analysis_id'] as String,
    riskLevel: RiskLevel.parse(json['risk_level'] as String?) ?? RiskLevel.red,
    findings: (json['findings'] as List)
        .map((f) => Finding.fromJson(f as Map<String, dynamic>))
        .toList(),
    subPart: json['sub_part'] as String?,
    modelVersion: json['model_version'] as String,
    recommendation: json['recommendation'] as String,
    createdAt: _date(json['created_at'])!,
    photoUrls: ((json['photo_urls'] as List?) ?? const []).cast<String>(),
  );

  final String id;
  final RiskLevel riskLevel;
  final List<Finding> findings;
  final String? subPart;
  final String modelVersion;
  final String recommendation;
  final DateTime createdAt;

  /// Recortes de la foto analizada, alojados por AI for Pet. Pueden vencer.
  final List<String> photoUrls;

  /// Resultado de ejemplo usado donde no existe el SDK (navegador): no es un análisis real.
  bool get isSimulated => modelVersion.endsWith('-simulacion');

  String? get positionLabel => switch (subPart) {
    'TLEFT' => 'Dientes del lado izquierdo',
    'TCENTER' => 'Dientes del frente',
    'TRIGHT' => 'Dientes del lado derecho',
    _ => null,
  };

  List<Finding> get abnormalFindings =>
      findings.where((f) => f.status == FindingStatus.abnormal).toList();
}

// ------------------------------------------------------- validación clínica

enum VetAssessment {
  sinSignos(
    'sin_signos',
    'Sin signos',
    'No observo sarro ni inflamación de encías.',
  ),
  conSignos(
    'con_signos',
    'Con signos',
    'Observo sarro, inflamación u otro signo dental.',
  ),
  noEvaluable(
    'no_evaluable',
    'No evaluable',
    'No puedo valorar este caso con certeza.',
  );

  const VetAssessment(this.api, this.label, this.help);

  final String api;
  final String label;
  final String help;

  static VetAssessment parse(String? value) => VetAssessment.values.firstWhere(
    (v) => v.api == value,
    orElse: () => VetAssessment.noEvaluable,
  );
}

/// Caso para valorar a ciegas: no trae el resultado de la IA.
class PendingCase {
  const PendingCase({
    required this.analysisId,
    required this.createdAt,
    required this.subPart,
    required this.petName,
    required this.breed,
    required this.photoUrls,
  });

  factory PendingCase.fromJson(Map<String, dynamic> json) => PendingCase(
    analysisId: json['analysis_id'] as String,
    createdAt: _date(json['created_at'])!,
    subPart: json['sub_part'] as String?,
    petName: json['pet_name'] as String,
    breed: json['breed'] as String?,
    photoUrls: (json['photo_urls'] as List).cast<String>(),
  );

  final String analysisId;
  final DateTime createdAt;
  final String? subPart;
  final String petName;
  final String? breed;
  final List<String> photoUrls;

  String? get positionLabel => switch (subPart) {
    'TLEFT' => 'Dientes del lado izquierdo',
    'TCENTER' => 'Dientes del frente',
    'TRIGHT' => 'Dientes del lado derecho',
    _ => null,
  };
}

/// Lo que la API revela después de registrar la valoración.
class ValidationReveal {
  const ValidationReveal({
    required this.assessment,
    required this.aiRiskLevel,
    required this.aiSeesSigns,
    required this.agreement,
  });

  factory ValidationReveal.fromJson(Map<String, dynamic> json) =>
      ValidationReveal(
        assessment: VetAssessment.parse(json['vet_assessment'] as String?),
        aiRiskLevel:
            RiskLevel.parse(json['ai_risk_level'] as String?) ?? RiskLevel.red,
        aiSeesSigns: json['ai_sees_signs'] as bool,
        agreement: json['agreement'] as bool?,
      );

  final VetAssessment assessment;
  final RiskLevel aiRiskLevel;
  final bool aiSeesSigns;
  final bool? agreement;
}

class AgreementMatrix {
  const AgreementMatrix({
    required this.n,
    required this.truePositive,
    required this.falsePositive,
    required this.falseNegative,
    required this.trueNegative,
    required this.sensitivity,
    required this.specificity,
    required this.accuracy,
  });

  factory AgreementMatrix.fromJson(Map<String, dynamic> json) =>
      AgreementMatrix(
        n: json['n'] as int,
        truePositive: json['true_positive'] as int,
        falsePositive: json['false_positive'] as int,
        falseNegative: json['false_negative'] as int,
        trueNegative: json['true_negative'] as int,
        sensitivity: (json['sensitivity'] as num?)?.toDouble(),
        specificity: (json['specificity'] as num?)?.toDouble(),
        accuracy: (json['accuracy'] as num?)?.toDouble(),
      );

  final int n;
  final int truePositive;
  final int falsePositive;
  final int falseNegative;
  final int trueNegative;
  final double? sensitivity;
  final double? specificity;
  final double? accuracy;
}

class ValidationSummary {
  const ValidationSummary({
    required this.validations,
    required this.notEvaluable,
    required this.criterion,
    required this.overall,
    required this.byCephalicGroup,
    required this.byBreed,
  });

  factory ValidationSummary.fromJson(Map<String, dynamic> json) {
    Map<String, AgreementMatrix> group(Object? raw) => {
      for (final e in (raw as Map<String, dynamic>).entries)
        e.key: AgreementMatrix.fromJson(e.value as Map<String, dynamic>),
    };
    return ValidationSummary(
      validations: json['validations'] as int,
      notEvaluable: json['not_evaluable'] as int,
      criterion: json['criterion'] as String,
      overall: AgreementMatrix.fromJson(
        json['overall'] as Map<String, dynamic>,
      ),
      byCephalicGroup: group(json['by_cephalic_group']),
      byBreed: group(json['by_breed']),
    );
  }

  final int validations;
  final int notEvaluable;
  final String criterion;
  final AgreementMatrix overall;
  final Map<String, AgreementMatrix> byCephalicGroup;
  final Map<String, AgreementMatrix> byBreed;
}
