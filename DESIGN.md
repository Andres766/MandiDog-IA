# Diseño de MandiDog IA

App de cuidado de mascotas en la línea de PetDesk, Petcube y TTcare (AI for Pet): fondo
claro y cálido, tarjetas blancas redondeadas, botones en píldora, la foto de cada perro en
un círculo y el resultado presentado como en SkinVision (foto, sello del nivel y una
recomendación clara). La fuente de verdad es el código: `app/lib/core/theme/app_theme.dart`
y `app/lib/shared/widgets/`.

## Reglas que no se rompen

1. **El semáforo es exclusivo del riesgo.** Verde, ámbar y rojo solo aparecen en el nivel
   de un escaneo y en sus hallazgos. Ni la marca, ni los perros, ni las alertas de la app
   los usan.
2. **Nunca solo color.** Todo nivel lleva ícono + palabra + color (`RiskBadge`) y una
   etiqueta accesible ("Nivel Rojo: Consulta pronto").
3. **El aviso del veterinario es fijo.** `VetNotice` va al pie de toda pantalla con un
   resultado y no se puede cerrar ni desplazar.
4. **Las fotos de los perros no salen del teléfono.** Se guardan en la carpeta privada de
   la app (`PetPhotoStore`).
5. **Movimiento con permiso.** Todas las animaciones se apagan con "reducir animaciones"
   del sistema.
6. **Objetivos táctiles de 48 dp o más.** Botones principales de 54 dp.

## Color

| Rol | Claro | Oscuro |
|---|---|---|
| Marca / acción (`primary`) | `#4A5FD9` cobalto | `#9AA8FF` |
| Marca profunda | `#2B3A8C` | — |
| Tinte de marca (`primaryContainer`) | `#E9ECFC` | `#2B3A8C` |
| Lila de acento (ilustraciones) | `#B8A8F0` | `#B8A8F0` |
| Fondo (`surface`) | `#FAF6F0` crema | `#12141C` |
| Tarjetas (`surfaceContainerLowest`) | `#FFFFFF` | `#1B1E29` |
| Tinta (`onSurface`) | `#1C2333` | `#ECEEF5` |
| Texto secundario | `#5F6576` | `#AEB3C2` |
| Bordes finos (`outlineVariant`) | `#ECE6DC` | `#2C3040` |

Riesgo (`RiskColors`, tinta sobre fondo con contraste ≥ 4,5:1):

| Nivel | Claro (tinta / fondo) | Oscuro (tinta / fondo) |
|---|---|---|
| Verde · Sin signos de riesgo | `#166534` / `#DCFCE7` | `#BBF7D0` / `#14532D` |
| Ámbar · Conviene vigilar | `#854D0E` / `#FEF3C7` | `#FEF08A` / `#713F12` |
| Rojo · Consulta pronto | `#991B1B` / `#FEE2E2` | `#FECACA` / `#7F1D1D` |

Perros sin foto (`PetPalette`): inicial sobre un pastel estable según su id (pervinca,
lila, cielo, arena o pizarra; nunca verde, ámbar ni rojo).

## Tipografía

Incluidas en la app (funcionan sin conexión, licencia SIL OFL):

- **Nunito** 600/700/800 para títulos, nombres de perros, el logotipo y el sello grande.
- **DM Sans** 400/500/600/700 para texto, botones, campos y etiquetas.

Títulos en 800 con espaciado −0,2; texto con altura de línea 1,5.

## Forma y medidas

- Ritmo de 4/8 dp (`Spacing`): 4, 8, 16, 24, 32, 48.
- Radios: 20 dp tarjetas, 16 dp campos y avisos, 28 dp hojas, encabezados y tarjeta del
  perro elegido; píldora en botones, sellos y chips.
- Tarjetas blancas con borde fino y sin sombra; ancho máximo del contenido 640 dp.

## Marca

- **Logo:** un molar invertido cuyas raíces son las orejas de un perro y cuya corona es su
  cara, con un destello. Fuentes en `app/tool/brand/*.svg`; se renderizan con
  `node tool/brand/render.mjs`. En la app: `BrandLogo` (cuadrado azul), `BrandMark` (solo
  la figura, para fondos azules) y `BrandWordmark`.
- **Ilustraciones** (`assets/illustrations/`): planas, en azul cobalto, lila y blanco, con
  el mismo perro-diente; el círculo de fondo lo dibuja la app con el color del tema
  (`Illustration`).

## Componentes

| Componente | Uso |
|---|---|
| `AuthScaffold` | Acceso, registro y recuperación: encabezado azul con la marca y hoja crema que sube. |
| `GoogleButton`, `OrDivider` | "Continuar con Google" con el logo oficial. |
| `PetAvatar` | Foto circular del perro o su inicial; lleva Hero entre inicio y ficha. |
| `RiskBadge` (small/medium/large) | Sello del nivel en píldora. |
| `RiskRing` | Anillo que se llena con el color del nivel alrededor de la foto analizada. |
| `AnalysisPhoto` | Recorte de la foto de AI for Pet; si no carga, una huella sobre el color del nivel. |
| `LatestScanCard`, `HistoryTimeline` | Último escaneo y línea de tiempo de los anteriores. |
| `VetNotice` | Aviso fijo del veterinario. |
| `EmptyState`, `ErrorView`, `LoadingView` | Estados vacíos, de error y de carga. |

## Pantallas

1. **Arranque:** el nativo de Android (azul con la figura) continúa en Flutter: el perro
   aparece con un rebote, brilla y entran el nombre y el lema (≈1,4 s).
2. **Presentación** (solo la primera vez): tres pasos con ilustración, puntos y "Saltar".
3. **Acceso:** correo y contraseña, Google, enlace a registro; en modo desarrollo, usuario
   de prueba.
4. **Inicio:** saludo, fila de avatares con "Agregar" (patrón de PetDesk), tarjeta del perro
   elegido con su última revisión y "Revisar sus dientes", y un consejo de cuidado dental.
5. **Ficha del perro:** encabezado con la foto grande y botón de cámara, datos en píldoras,
   "Escanear dientes", último escaneo y línea de tiempo.
6. **Antes de escanear:** el perro arriba y cuatro consejos en tarjetas.
7. **Resultado:** foto analizada en el anillo, sello grande, descripción, hallazgos con
   chips, "Qué hacer ahora" y aviso fijo.
8. **Mi cuenta:** tarjeta del usuario, privacidad, validación clínica (veterinarios),
   sesión y acerca de.

## Movimiento

- Transición entre pantallas: eje compartido horizontal (`animations`).
- Entrada escalonada de bloques: aparece y sube 8 % en ~380 ms (`Entrance.entrance`).
- Botones de avatar que se encogen al presionarlos (`Pressable`).
- Esqueleto con brillo mientras cargan los perros.
- Anillo del resultado que se llena en 1,1 s.
