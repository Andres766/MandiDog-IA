---
name: MandiDog IA
description: Revisión orientativa de la salud dental del perro con una foto; cada perro es su placa de collar.
colors:
  accion-teal: "#0F6E73"
  aluminio-claro: "#EEF2F3"
  aluminio-oscuro: "#111619"
  tinta-grafito: "#1C2329"
  tinta-clara: "#E3E8EA"
  lamina-clara: "#FFFFFF"
  lamina-oscura: "#181F23"
  borde-claro: "#D3DADD"
  borde-oscuro: "#2E383E"
  placa-cobalto: "#2D4FA6"
  placa-violeta: "#5B45A8"
  placa-ciruela: "#7A3B69"
  placa-bronce: "#7A4A2B"
  placa-grafito: "#3B4752"
  acero-aro: "#BAC4CA"
  acero-aro-sombra: "#66737B"
  riesgo-verde-tinta: "#166534"
  riesgo-verde-fondo: "#DCFCE7"
  riesgo-ambar-tinta: "#854D0E"
  riesgo-ambar-fondo: "#FEF9C3"
  riesgo-rojo-tinta: "#991B1B"
  riesgo-rojo-fondo: "#FEE2E2"
  riesgo-verde-tinta-oscuro: "#BBF7D0"
  riesgo-verde-fondo-oscuro: "#14532D"
  riesgo-ambar-tinta-oscuro: "#FEF08A"
  riesgo-ambar-fondo-oscuro: "#713F12"
  riesgo-rojo-tinta-oscuro: "#FECACA"
  riesgo-rojo-fondo-oscuro: "#7F1D1D"
typography:
  placa-nombre-grande:
    fontFamily: "Varela Round, sans-serif"
    fontSize: "34px"
    fontWeight: 400
    lineHeight: 1.1
    letterSpacing: "0.2px"
  placa-nombre:
    fontFamily: "Varela Round, sans-serif"
    fontSize: "26px"
    fontWeight: 400
    lineHeight: 1.1
    letterSpacing: "0.2px"
  headline:
    fontFamily: "Varela Round, sans-serif"
    fontSize: "24px"
    fontWeight: 400
    lineHeight: 1.33
  title:
    fontFamily: "Varela Round, sans-serif"
    fontSize: "22px"
    fontWeight: 400
    lineHeight: 1.27
  sello-grande:
    fontFamily: "Varela Round, sans-serif"
    fontSize: "22px"
    fontWeight: 400
    lineHeight: 1.2
  seccion:
    fontFamily: "Nunito Sans, sans-serif"
    fontSize: "16px"
    fontWeight: 700
    lineHeight: 1.5
  body-large:
    fontFamily: "Nunito Sans, sans-serif"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.5
  body:
    fontFamily: "Nunito Sans, sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.5
  boton:
    fontFamily: "Nunito Sans, sans-serif"
    fontSize: "16px"
    fontWeight: 700
  sello:
    fontFamily: "Nunito Sans, sans-serif"
    fontSize: "14px"
    fontWeight: 700
  meta:
    fontFamily: "Nunito Sans, sans-serif"
    fontSize: "13px"
    fontWeight: 400
rounded:
  sello: "10px"
  sello-grande: "14px"
  md: "16px"
  placa: "26px"
  placa-grande: "32px"
  pastilla: "999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "16px"
  lg: "24px"
  xl: "32px"
  objetivo-tactil: "48px"
  ancho-maximo: "640px"
components:
  boton-principal:
    backgroundColor: "{colors.accion-teal}"
    textColor: "{colors.lamina-clara}"
    typography: "{typography.boton}"
    rounded: "{rounded.md}"
    height: "48px"
  boton-contorno:
    textColor: "{colors.accion-teal}"
    typography: "{typography.boton}"
    rounded: "{rounded.md}"
    height: "48px"
  boton-flotante:
    backgroundColor: "{colors.accion-teal}"
    textColor: "{colors.lamina-clara}"
    typography: "{typography.boton}"
    height: "56px"
  tarjeta:
    backgroundColor: "{colors.lamina-clara}"
    rounded: "{rounded.md}"
    padding: "16px"
  campo:
    backgroundColor: "{colors.lamina-clara}"
    rounded: "{rounded.md}"
  placa:
    backgroundColor: "{colors.placa-cobalto}"
    textColor: "{colors.lamina-clara}"
    typography: "{typography.placa-nombre}"
    rounded: "{rounded.placa}"
    padding: "16px 16px 16px 48px"
  placa-grande:
    backgroundColor: "{colors.placa-cobalto}"
    textColor: "{colors.lamina-clara}"
    typography: "{typography.placa-nombre-grande}"
    rounded: "{rounded.placa-grande}"
    padding: "22px 22px 22px 58px"
  placa-mini:
    backgroundColor: "{colors.placa-grafito}"
    textColor: "{colors.lamina-clara}"
    rounded: "{rounded.pastilla}"
    padding: "6px 14px 6px 23px"
  sello-riesgo-rojo:
    backgroundColor: "{colors.riesgo-rojo-fondo}"
    textColor: "{colors.riesgo-rojo-tinta}"
    typography: "{typography.sello}"
    rounded: "{rounded.sello}"
    padding: "5px 10px"
  sello-riesgo-verde:
    backgroundColor: "{colors.riesgo-verde-fondo}"
    textColor: "{colors.riesgo-verde-tinta}"
    typography: "{typography.sello}"
    rounded: "{rounded.sello}"
    padding: "5px 10px"
  sello-riesgo-ambar:
    backgroundColor: "{colors.riesgo-ambar-fondo}"
    textColor: "{colors.riesgo-ambar-tinta}"
    typography: "{typography.sello}"
    rounded: "{rounded.sello}"
    padding: "5px 10px"
  sello-riesgo-grande:
    backgroundColor: "{colors.riesgo-rojo-fondo}"
    textColor: "{colors.riesgo-rojo-tinta}"
    typography: "{typography.sello-grande}"
    rounded: "{rounded.sello-grande}"
    padding: "9px 14px"
---

# Design System: MandiDog IA

## Overview

**Creative North Star: "La placa de collar"**

Cada perro es su placa de identificación: una chapa de aluminio anodizado en un tono propio, con el nombre grabado en blanco y una argolla con aro partido que la cuelga del borde izquierdo. Todo lo demás es el aluminio cepillado y frío sobre el que cuelgan las placas, escrito en tinta grafito. El dueño reconoce a cada perro por color y nombre antes de leer nada, y el último sello de riesgo va estampado en la propia placa.

El sistema es Material 3 en Flutter, nativo de Android, con densidad tranquila para una mano: columnas a ancho completo, márgenes de 16 dp, objetivos de 48 dp y pocos tamaños de letra, con la jerarquía hecha por peso y por la familia redondeada de los titulares. El color está estrictamente repartido por significado: el teal profundo solo en lo que se toca, verde, ámbar y rojo solo para el riesgo, y los tonos de las placas solo para identificar perros. El escaneo más reciente se muestra grande; los anteriores ceden en filas compactas.

La app rechaza la lista gris de tarjetas idénticas de "app de salud" con un único acento teal. El único gesto expresivo es físico: la placa se mece desde su argolla al tocarla, y desaparece cuando el sistema pide reducir animaciones.

**Key Characteristics:**
- Placas anodizadas a ancho completo con argolla y aro de acero dibujados, nombre grabado en Varela Round blanca.
- Fondo de aluminio frío (claro y oscuro), tinta grafito, láminas blancas o casi negras con borde fino.
- Color con un solo significado por familia: acción, riesgo o identidad del perro.
- Riesgo siempre como sello: ícono + palabra + color.
- Aviso del veterinario fijo al pie de todo resultado.

## Colors

Aluminio frío y grafito como base; tres familias de color con significado exclusivo cada una.

### Primary
- **Teal de acción** (accion-teal): semilla de `ColorScheme.fromSeed`. Material 3 deriva de ella los roles tonales (primario, contenedores); en claro el primario se ve teal profundo y en oscuro un cian claro con texto oscuro. Pinta botones llenos, botón flotante "Agregar perro", botones de contorno y de texto, casillas y anillos de foco. Nada que no se pueda tocar lleva teal.

### Secondary
- **Pizarra de aviso** (rol `secondaryContainer` derivado de la semilla): fondo del aviso del veterinario y del aviso de autorización pendiente en "Mis perros". Es el tono de los avisos que acompañan, no de las acciones.

### Tertiary
- **Contenedor terciario** (rol `tertiaryContainer` derivado): avisos de modo simulación y modo desarrollo; el texto "Resultado simulado" usa el rol `tertiary`. Marca lo que no es un análisis real.

### Neutral
- **Aluminio claro** y **aluminio oscuro**: fondo de pantalla (scaffold y barra superior, que no se tiñe al desplazar).
- **Tinta grafito** y **tinta clara**: texto sobre el fondo en cada tema; también color de los titulares.
- **Lámina clara** y **lámina oscura** (`surfaceContainerLowest`): fondo de tarjetas y campos de texto.
- **Borde claro** y **borde oscuro** (`outlineVariant`): borde de 1 dp de las tarjetas.
- **Acero del aro** y **sombra del aro**: las dos vueltas de alambre del aro partido; la clara se lee sobre las placas, la oscura sobre el fondo.

### Tonos de placa
- **Cobalto**, **violeta**, **ciruela**, **bronce** y **grafito**: uno por perro, elegido de forma estable a partir de su id. El grafito es también la placa de la marca en las pantallas de acceso. Todos llevan texto blanco con contraste de 7.3:1 a 9.5:1.

### Riesgo
- **Verde, ámbar y rojo**, cada uno con tinta y fondo por tema (claro: tinta oscura sobre fondo pálido; oscuro: tinta pálida sobre fondo profundo), contraste de 6.4:1 a 7.5:1. Se usan en el sello de riesgo y en el ícono y la palabra de cada hallazgo del resultado.

### Named Rules
**The Semáforo Exclusivo Rule.** Verde, ámbar y rojo significan nivel de riesgo y nada más: ni éxito de formulario, ni placas, ni decoración. Los errores de formulario usan el rol `errorContainer` de Material, no la tinta roja de riesgo.

**The Nunca Solo Color Rule.** El riesgo se muestra siempre con ícono + palabra + color juntos (verde: círculo con visto, "Sin signos de riesgo"; amarillo: ojo, "Conviene vigilar"; rojo: signo de exclamación, "Consulta pronto"), y el lector de pantalla lee "Nivel [color]: [palabra]".

**The Teal Se Toca Rule.** El teal de acción aparece solo en elementos accionables. Si algo es teal y no responde al toque, está mal.

**The Placa Sin Semáforo Rule.** Ningún tono de placa puede ser verde, ámbar, rojo ni parecido al teal de acción, y todos deben llevar texto blanco con contraste de al menos 4.5:1.

## Typography

**Display Font:** Varela Round (con sans-serif)
**Body Font:** Nunito Sans (con sans-serif)

**Character:** Varela Round, de un solo peso, da el redondeo amable de una letra grabada en metal; Nunito Sans carga el texto corrido y la jerarquía por peso (400, 600, 700). Las dos fuentes van incluidas en la app (SIL OFL).

### Hierarchy
- **Nombre en placa** (Varela Round 400; 34 sp en la ficha, 26 sp en la lista; interlínea 1.1): el nombre grabado del perro, máximo dos líneas.
- **Headline** (Varela Round 400, 24 sp): título de pantalla dentro del contenido ("Antes de empezar").
- **Title** (Varela Round 400, 22 sp): barra superior y títulos de estado vacío.
- **Sello grande** (Varela Round 400, 22 sp, interlínea 1.2): la palabra de riesgo en el resultado y en el último escaneo.
- **Sección** (Nunito Sans 700, 16 sp): títulos de sección ("Lo que encontró el análisis", "Historial").
- **Body** (Nunito Sans 400, 16 sp y 14 sp, interlínea 1.5): textos de recomendación y descripciones.
- **Botón** (Nunito Sans 700 en botones llenos y flotante, 600 en contorno y texto; 16 sp).
- **Sello** (Nunito Sans 700, 14 sp; 13 sp en el historial): la palabra de riesgo en placas y filas.
- **Meta** (Nunito Sans 400, 13 sp, color `onSurfaceVariant`): fechas, lado del escaneo.

### Named Rules
**The Grabado Redondo Rule.** Varela Round es para nombres de perro, titulares y la palabra del sello grande; nunca para párrafos ni etiquetas pequeñas. Como tiene un solo peso, la jerarquía se hace por tamaño y no por negrita.

## Layout

Una sola columna centrada con ancho máximo de 640 dp (tabletas y navegador), márgenes laterales de 16 dp, 8 dp arriba y 32 dp abajo. Ritmo de 4/8 dp: 4, 8, 16, 24 y 32 dp; los títulos de sección abren con 24 dp y cierran con 8 dp. Las placas ocupan todo el ancho y se apilan con separación regular; el aro sobresale por la izquierda dentro del margen. La acción principal de "Mis perros" es un botón flotante extendido abajo a la derecha; en la ficha, la placa grande va arriba, luego el botón "Escanear dientes" y luego el historial con el último escaneo destacado. En resultados, el aviso del veterinario ocupa la franja inferior fija (`bottomNavigationBar`) respetando el área segura.

### Named Rules
**The Pulgar Rule.** Todo objetivo táctil mide al menos 48 dp; los botones tienen 48 dp de alto mínimo y ancho completo cuando son la acción principal de la pantalla.

## Elevation & Depth

Plano por defecto: tarjetas con elevación 0, borde de 1 dp y la barra superior sin tinte al desplazar. La única sombra del sistema es la de la placa, que cuelga sobre el aluminio.

### Shadow Vocabulary
- **Placa colgada** (desplazamiento 0, 3 dp; desenfoque 8 dp; negro al 18 %): solo en `PetTag`, para que la chapa se despegue del fondo.

### Named Rules
**The Solo Cuelga La Placa Rule.** Las tarjetas, avisos y campos no llevan sombra; la profundidad es exclusiva de la placa.

## Shapes

Esquinas muy redondeadas en todo. Radio de 16 dp para tarjetas, botones, campos y avisos; 26 dp para la placa y 32 dp para la placa grande; la placa mini es una pastilla completa. El sello de riesgo tiene 10 dp (14 dp en grande) y un borde de su propia tinta al 55 % (1.5 dp, 2 dp en grande). La silueta que identifica al sistema es la perforación circular a la izquierda de la placa (que deja ver el fondo) atravesada por un aro partido de dos vueltas de alambre que sobresale del borde. La placa sin grabar (estado vacío) es el mismo contorno en línea discontinua con la perforación dibujada.

## Components

### Buttons
Firmes y redondeados, siempre teal.
- **Shape:** esquinas suaves (16 dp), alto mínimo de 48 dp.
- **Primary:** botón lleno en el primario derivado del teal, Nunito Sans 700 a 16 sp; con carga, un indicador circular de 22 dp ocupa su lugar sin cambiar el tamaño.
- **Secondary:** botón de contorno, Nunito Sans 600 a 16 sp, a menudo con ícono ("Escanear otro lado", "Reintentar").
- **Text:** botón de texto, 48 × 48 dp mínimo, Nunito Sans 600.
- **Flotante:** extendido, primario/onPrimary, Nunito Sans 700 a 16 sp ("Agregar perro").

### Cards / Containers
- **Corner Style:** 16 dp.
- **Background:** lámina clara u oscura; los avisos usan contenedores secundario o terciario.
- **Shadow Strategy:** ninguna (ver Elevation & Depth).
- **Border:** 1 dp en `outlineVariant`.
- **Internal Padding:** 16 dp; las listas dentro de tarjetas separan filas con divisores de 1 dp.

### Inputs / Fields
- **Style:** relleno con la lámina, contorno de Material con radio de 16 dp.
- **Error:** mensaje de formulario en `errorContainer` con ícono de error, anunciado como región viva.

### Navigation
Barra superior en el color del fondo, título en Varela Round a 22 sp alineado a la izquierda, acceso a cuenta como ícono a la derecha. Sin barra de pestañas: la navegación es por pila (placa → ficha → escaneo → resultado).

### Placa de collar (`PetTag`)
La firma del sistema. Chapa en el tono del perro, perforación con aro de acero, nombre grabado, subtítulo en blanco al 86 % ("Pug · 3 años · 8,5 kg") y, debajo, el sello del último escaneo o "Sin escaneos aún". En la lista mide unos 120 dp de alto; en la ficha es la variante grande. Se lee como un solo botón con etiqueta completa para TalkBack. Al tocarla se mece desde el punto donde el aro cuelga: oscilación amortiguada de 900 ms (amplitud 0.045 rad que se apaga), y la ficha abre 200 ms después para dejar ver el primer vaivén.

### Placa mini (`TagChip`)
Pastilla en el tono del perro con aro pequeño y nombre en Varela Round 15 sp; identifica al perro en escaneo y resultado.

### Sello de riesgo (`RiskStamp`)
Ícono + palabra + color con borde de su tinta. Tres tamaños: compacto (historial, ícono 16), normal (placa, ícono 18) y grande (resultado y último escaneo, ícono 26, palabra en Varela Round 22 sp).

### Aviso del veterinario (`VetNotice`)
Franja fija al pie de toda pantalla de resultado, en `secondaryContainer`, con ícono de maletín médico y el texto "Este resultado es orientativo y no es un diagnóstico: consulta siempre a tu veterinario." No se puede cerrar, ocultar ni desplazar fuera de la pantalla, y su texto no se repite dentro del contenido.

### Estados
Vacío y error centrados: ícono de 40 dp en `onSurfaceVariant`, título en Varela Round, mensaje y una acción de contorno. Carga con indicador circular etiquetado.

## Do's and Don'ts

### Do:
- **Do** mostrar el riesgo siempre con ícono + palabra + color usando `RiskStamp` o `RiskStyle`.
- **Do** reservar el teal de acción a botones, botón flotante, casillas y demás elementos que respondan al toque.
- **Do** identificar a cada perro con su tono de placa (`TagHue.forId`) y su nombre en Varela Round blanca, con la placa completa en lista y ficha y la placa mini en las demás pantallas.
- **Do** fijar `VetNotice` al pie de cada pantalla de resultado.
- **Do** mantener objetivos táctiles de 48 dp y el ritmo de 4/8 dp.
- **Do** respetar las animaciones reducidas: sin vaivén de la placa y apertura inmediata de la ficha al tocarla.

### Don't:
- **Don't** usar verde, ámbar o rojo para algo que no sea nivel de riesgo, ni comunicar el riesgo solo con color.
- **Don't** agregar tonos de placa verdes, ámbar, rojos o parecidos al teal, ni tonos que no lleguen a 4.5:1 con texto blanco.
- **Don't** pintar de teal (ni de sus contenedores primarios) superficies que no se tocan.
- **Don't** permitir cerrar, ocultar o desplazar el aviso del veterinario.
- **Don't** poner sombra a tarjetas o avisos; la única sombra es la de la placa.
- **Don't** mostrar porcentajes de confianza ni la foto analizada.
