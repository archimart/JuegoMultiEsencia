# CLAUDE.md

Guía para Claude Code al trabajar en este repositorio. Responde siempre en español.

## Resumen del proyecto

**JuegoMultiPixelArt** es un juego multijugador 2D en pixel art hecho en Godot 4.6.
Cada jugador elige una raza, y cada raza obtiene un compañero que lo acompaña y complementa su debilidad.
Los compañeros tienen sinergias entre sí para que los grupos con razas mezcladas sean más fuertes.

## Tecnología

- **Motor:** Godot 4.6
- **Lenguaje:** GDScript únicamente (no usar C#)
- **Renderer:** GL Compatibility
- **Tipo de juego:** 2D, vista top-down en 3/4 (estilo Kynseed / Stardew Valley)
- **Multijugador:** API de alto nivel de Godot con ENet (`MultiplayerSpawner`, `MultiplayerSynchronizer`, `@rpc`)
- **Física:** solo física 2D (CharacterBody2D, Area2D). Ignorar Jolt, es para 3D.

## Configuración de pixel art

- Resolución base: 640x360
- Stretch mode: `viewport`, aspect: `keep`, scale mode: `integer`
- Filtro de texturas por defecto: Nearest, sin mipmaps
- Animaciones de personajes en 4 direcciones (arriba, abajo, izquierda, derecha)
- Mapas con `TileMapLayer` (no usar el nodo `TileMap` obsoleto) y Y-sort activado

## Diseño del juego

### Razas y compañeros

| Raza | Estilo | Compañero | Qué aporta |
|---|---|---|---|
| Humano | Versátil | Halcón explorador | Revela enemigos y recursos |
| Elfo | Ágil, frágil | Espíritu del bosque | Escudos y curación ligera |
| Enano | Resistente, lento | Golem de piedra | Carga objetos, bloquea pasillos |
| Orco | Fuerza bruta | Lobo de guerra | Marca enemigos y flanquea |
| No-muerto | Daño sostenido | Familiar de sombras | Roba vida y distrae |

### Reglas de diseño

- Los datos de razas y compañeros se definen como `Resource` personalizados (`RaceData`, `CompanionData`) guardados en `.tres`, nunca hardcodeados en scripts.
- El compañero sigue al jugador y actúa con IA simple. No lo controla el jugador directamente.
- Primero se construye todo para un solo jugador; el multijugador se agrega después sobre esa base.
- Empezar con 2 razas (Humano y Orco) y sus compañeros antes de añadir las demás.

## Estructura de carpetas

- `assets/` → sprites, tilesets y audio descargados (packs externos, no generar arte)
- `scenes/` → escenas `.tscn` (player, companion, world, ui)
- `scripts/` → scripts `.gd`
- `resources/` → datos de razas y compañeros (`.tres`)
- `autoload/` → singletons (por ejemplo, gestor de red y estado del juego)

## Convenciones

- Archivos y variables en `snake_case`; clases con `class_name` en `PascalCase`
- Señales en pasado: `health_changed`, `companion_summoned`
- Los nodos se comunican con señales, no con llamadas directas entre ramas no relacionadas
- Tipado estático en GDScript siempre que se pueda (`var speed: float = 100.0`)
- En multijugador, el servidor tiene la autoridad; los clientes envían input y el servidor decide

## Forma de trabajar

- Avanzar en pasos pequeños que se puedan probar con F5
- No reescribir sistemas completos sin pedirlo
- Al terminar una tarea, explicar qué archivos se crearon o modificaron y cómo probarlo
- Si un archivo de assets no existe, preguntar en vez de inventar rutas

## Ejecutar el proyecto

Se ejecuta desde el editor de Godot (F5). Para ver errores en consola, usar:
`C:\juegos\Godot_v4.6.2-stable_win64_console.exe`