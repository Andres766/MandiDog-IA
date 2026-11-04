/// Texto de autorización que muestra la app. Debe coincidir con
/// docs/datos-y-consentimiento.md §5 y con CONSENT_POLICY_VERSION de la API.
/// Si el texto cambia, se crea una versión nueva aquí y en la API.
const kConsentVersion = '2026-11-v2';

const kConsentIntro =
    'Para analizar la salud dental de tu perro, autorizas a MandiDog IA, proyecto de grado '
    'del programa de Ingeniería de Software de la Universidad Cooperativa de Colombia, '
    'sede Pasto, a:';

const kConsentPurposes = [
  'Enviar las fotos de los dientes de tu perro a AI for Pet, empresa de Corea del Sur que '
      'hace el análisis con inteligencia artificial en sus servidores. Junto con la foto solo '
      'se envía un identificador interno, no tu nombre ni tu correo.',
  'Guardar en MandiDog el resultado de cada análisis para mostrarte el historial.',
  'Usar los resultados, sin datos que te identifiquen, en la investigación académica del '
      'proyecto.',
];

const kConsentUnderstand = [
  'Sin esta autorización no puedes usar la cámara de análisis.',
  'Puedes revocarla en cualquier momento desde tu cuenta, y borrar tus perros o tu cuenta. '
      'Los datos que conserve AI for Pet se eliminan según su propio procedimiento.',
  'El resultado es orientativo, no es un diagnóstico y no reemplaza la consulta con un '
      'veterinario.',
];

const kConsentResponsible =
    'Responsable del tratamiento: proyecto MandiDog IA, Universidad Cooperativa de Colombia, '
    'sede Pasto. Encargado: AI for Pet Inc.';
