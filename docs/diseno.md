# Diseño de la app

Sistema visual de MandiDog IA. Partió de la skill **ui-ux-pro-max** (generador de sistema
de diseño para "app de salud veterinaria, confianza, calma"), que propuso un estilo
minimalista, un teal clínico y tipografías redondeadas. Los ajustes que se hicieron, y por
qué, están marcados con **Ajuste**.

Implementación: `app/lib/core/theme/app_theme.dart` y `risk_style.dart`.

## Principios

1. **No es un diagnóstico.** El aviso "Este resultado es orientativo y no es un
   diagnóstico: consulta siempre a tu veterinario" va fijo al pie de las pantallas con
   resultados y no se puede cerrar ni desplazar.
2. **El semáforo nunca depende solo del color.** Cada nivel tiene ícono, texto y color, y
   una etiqueta para lectores de pantalla ("Nivel Rojo: Consulta pronto").
3. **Verde, amarillo y rojo significan riesgo y nada más.** Ningún botón ni acento usa esos
   colores, para que una acción no se confunda con una alerta.
4. **Lenguaje claro en español**, con mensajes de error que dicen qué hacer.

## Color

| Rol | Valor | Nota |
|---|---|---|
| Semilla | `#0D9488` (teal) | Material 3 genera la paleta clara y oscura |
| Fondo (claro) | `#F0FDFA` | Teal muy suave |
| Botón principal | primario de Material (tono 40) | **Ajuste:** `#0D9488` con texto blanco no llega a 4.5:1; el tono 40 sí |
| Acento naranja `#EA580C` | **No se usa** | **Ajuste:** se confundía con los niveles amarillo/rojo |

Semáforo (`RiskColors`), texto sobre fondo con contraste ≥ 4.5:1:

| Nivel | Texto | Ícono | Claro (texto / fondo) | Oscuro (texto / fondo) |
|---|---|---|---|---|
| Verde | Sin signos de riesgo | `check_circle_outline` | `#166534` / `#DCFCE7` | `#BBF7D0` / `#14532D` |
| Amarillo | Conviene vigilar | `visibility_outlined` | `#854D0E` / `#FEF9C3` | `#FEF08A` / `#713F12` |
| Rojo | Consulta pronto | `priority_high_rounded` | `#991B1B` / `#FEE2E2` | `#FECACA` / `#7F1D1D` |

## Tipografía

| Uso | Familia | Por qué |
|---|---|---|
| Títulos | **Varela Round** | Redondeada y cercana (recomendación de la skill para apps de mascotas) |
| Texto | **Nunito Sans** 400/600/700 | Legible, con interlineado 1.5 |

Las tipografías van **incluidas en la app** (`app/assets/fonts/`, licencia SIL OFL) en lugar
de descargarse de Google en cada uso: funcionan sin conexión y no envían datos a terceros.
Sus licencias aparecen en *Mi cuenta → Licencias de software*.

## Medidas

- Ritmo de espaciado de 4/8 dp: 4, 8, 16, 24, 32.
- Botones de al menos **48 dp** de alto; radio de 16 en tarjetas, campos y botones.
- Contenido con ancho máximo de 640 dp (tabletas y navegador).
- Tema claro y oscuro según el sistema.

## Pantallas

| Pantalla | Ruta | Contenido |
|---|---|---|
| Acceso | `/login`, `/register`, `/reset-password` | Correo y contraseña con *autofill*; en modo dev, usuario de prueba |
| Mis perros | `/` | Tarjetas con el último resultado; aviso si falta la autorización |
| Agregar / editar perro | `/pets/new`, `/pets/:id/edit` | Nombre (obligatorio), raza, sexo, nacimiento y peso, con errores junto a cada campo |
| Ficha del perro | `/pets/:id` | Datos, botón **Escanear dientes** e historial |
| Autorización | `/consent` | Texto completo, casilla sin marcar y "Aceptar y continuar"; revocar si ya fue aceptada |
| Escaneo | `/pets/:id/scan` | Guía de 4 consejos, cámara del SDK (o simulación) y reintento si falla el envío |
| Resultado | `/pets/:id/analyses/:id` | Nivel, hallazgos, qué hacer y aviso fijo; marca visible si es simulado |
| Mi cuenta | `/account` | Autorización, cerrar sesión, eliminar cuenta, licencias |

## Lista de verificación aplicada (ui-ux-pro-max)

- [x] Sin emojis como íconos; una sola familia (Material)
- [x] Color nunca como único indicador
- [x] Contraste ≥ 4.5:1 en texto, revisado en tema claro y oscuro
- [x] Áreas táctiles ≥ 48 dp y estados deshabilitados claros
- [x] Campos con etiqueta visible, ayuda y error junto al campo
- [x] *Autofill* para gestores de contraseñas
- [x] Etiquetas para lector de pantalla en el semáforo y en los botones de solo ícono
- [x] Zonas seguras (barra de estado y gestos) respetadas
- [ ] Prueba con TalkBack y con el texto del sistema al máximo en un celular real (pendiente)
