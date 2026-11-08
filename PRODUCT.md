# Product

<!-- impeccable:product-schema 1 -->

> Escrito el 2026-11-08 sin entrevista: el usuario pidió avanzar sin estar presente. Todo
> lo marcado *(inferido)* sale de las conversaciones del proyecto y debe confirmarse.

## Platform

android

## Users

- **Dueños de perros en Colombia (Pasto y región)**, en español, que quieren saber si los
  dientes y encías de su perro necesitan atención. Usan el celular en casa, con el perro
  al lado, a menudo con una sola mano libre porque con la otra sostienen al animal.
  *(inferido del flujo de captura)*
- **Veterinarios** que participan en la validación clínica del proyecto de grado.
- **Evaluadores académicos** (director y jurados de la UCC) que revisan la app en la
  sustentación.

## Product Purpose

MandiDog IA permite revisar de forma orientativa la salud dental de un perro con una foto:
el análisis lo hace el SDK de AI for Pet y la app devuelve un semáforo (verde, amarillo,
rojo), los hallazgos (sarro, inflamación de encías) y qué hacer. Guarda el historial por
perro. Éxito: el dueño entiende el resultado sin ayuda y, cuando corresponde, consulta al
veterinario a tiempo. No es un diagnóstico.

## Positioning

Proyecto de grado de Ingeniería de Software de la Universidad Cooperativa de Colombia,
sede Pasto: lleva un análisis dental con IA de nivel comercial (AI for Pet) a dueños de
perros en español, con consentimiento conforme a la Ley 1581 y validación clínica con
veterinarios locales.

## Operating Context

- Captura: cámara del SDK de AI for Pet (interfaz en inglés) o foto de la galería
  (mínimo 1400 × 1400 px); la foto sale hacia los servidores de AI for Pet en Corea del Sur.
- Antes de la primera captura el usuario debe aceptar la autorización de datos.
- La app habla con una API propia (FastAPI) que guarda perros, historial y autorizaciones.

## Capabilities and Constraints

- Detecta solo sarro (`calculus`) e inflamación de encías (`inflammation`); no detecta
  fracturas, tumores ni maloclusión.
- AI for Pet no entrega porcentajes de confianza: no se muestran.
- El aviso "Este resultado es orientativo y no es un diagnóstico: consulta siempre a tu
  veterinario" debe estar siempre visible en pantallas de resultado y no puede ocultarse.
- Android 9 o superior. Flutter, Material 3.
- Sin fotos propias de la app: no se guarda ni se muestra la foto analizada.

## Brand Commitments

- Nombre: **MandiDog IA**. Identificador `co.edu.ucc.mandidog`.
- Tipografías ya incluidas en la app: Varela Round y Nunito Sans (SIL OFL). *(inferido:
  elegidas en la etapa 3, no exigidas por el usuario)*
- No hay logotipo ni marca gráfica previa.

## Evidence on Hand

- Ejemplo oficial de resultado de AI for Pet y un análisis real hecho el 2026-11-04 en un
  Galaxy S25 Ultra (WARNING, inflamación y sarro, dientes izquierdos).
- No hay fotos de perros, testimonios ni cifras de precisión propias: no inventarlas.

## Product Principles

1. Orientar, nunca diagnosticar: cada resultado lleva a la consulta veterinaria.
2. El riesgo se entiende sin color: ícono, palabra y color juntos.
3. El consentimiento es explícito y revocable antes de que la foto salga del teléfono.
4. Español claro para cualquier dueño, sin jerga clínica innecesaria.

## Accessibility & Inclusion

WCAG AA de contraste en texto, objetivos táctiles de 48 dp, lector de pantalla (TalkBack)
y texto del sistema grande. Uso con una sola mano. *(inferido)*
