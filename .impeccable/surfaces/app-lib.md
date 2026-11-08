---
version: 1
slug: "app-lib"
primary_target: "app/lib"
related_targets: []
---

# App MandiDog IA (Flutter, Android)

Scope: toda la app (acceso, Mis perros, ficha, autorización, guía de escaneo, resultado, cuenta). Mode: Operate.
Audience: dueños de perros en Pasto, celular en una mano, perro al lado. Task: registrar perros, escanear dientes, entender el semáforo, ver historial.
Constraints: aviso del veterinario fijo en resultados; riesgo siempre ícono+texto+color; verde/amarillo/rojo solo para riesgo; Material 3; 48 dp.
Decision: tomada sin el usuario (pidió avanzar mientras trabaja); dirección asignada por la tirada, sin re-roll.

## Direction contract

THESIS: Cada perro es su placa de collar: una chapa anodizada con su nombre grabado y una argolla. La app refuse la lista gris de tarjetas idénticas de "app de salud" con un solo acento teal.

OWN-WORLD: Fondo de aluminio cepillado frío (claro #EEF2F3, oscuro #111619); tinta grafito. Cada perro tiene un tono anodizado propio (teal, cobalto, violeta, petróleo, grafito), nunca verde/ámbar/rojo. La placa: rectángulo de esquinas muy redondeadas con argolla perforada a la izquierda y aro partido dibujado; nombre grabado en Varela Round grande en blanco sobre el tono. El color de acción (teal profundo) aparece solo en lo que se toca. Riesgo: sello con ícono+palabra en verde/ámbar/rojo.

STORY: El dueño ve a sus perros como placas, reconoce a cada uno por color y nombre, ve su último sello de riesgo, abre la placa, escanea y lee un resultado que siempre lo manda al veterinario cuando hace falta.

FIRST VIEWPORT: "Mis perros": barra superior con título y acceso a cuenta; columna de placas a ancho completo (alto ~120 dp), cada una con argolla, nombre grabado, raza/edad y sello del último resultado; botón flotante "Agregar perro" abajo a la derecha. Ficha: placa grande arriba en el tono del perro, debajo el botón principal "Escanear dientes", luego el historial con el escaneo más reciente destacado.

FORM: placa de identificación del collar (aluminio anodizado grabado), candidato 5 de 7 de la lista propia. seed:dfcb06f551b4179c
Raises: de la superficie de consumo cálida, el color de acción reservado a lo accionable; del horario de aerolínea, pocos tamaños y jerarquía por peso; del mapa de metro, el escaneo más reciente arde y los anteriores ceden; del pase de abordar, el cambio importante se resalta.
Signature move: la placa se mece desde su argolla al tocarla (rotación con resorte, pivote en la argolla), desactivada con animaciones reducidas.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
