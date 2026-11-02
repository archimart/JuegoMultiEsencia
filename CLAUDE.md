# CLAUDE.md

Guía para Claude Code al trabajar en este repositorio. Responde siempre en español.

## Resumen del proyecto

**JuegoMultiPixelArt** es un juego multijugador 2D en pixel art hecho en Godot 4.6.
Cada jugador elige una raza, y cada raza obtiene un compañero que lo acompaña, pelea a su lado y sube de nivel.
Cada compañero complementa la debilidad de su raza, y entre ellos tienen sinergias para que los grupos con razas mezcladas sean más fuertes.

## Tecnología

- **Motor:** Godot 4.6
- **Lenguaje:** GDScript únicamente (no usar C#)
- **Renderer:** GL Compatibility
- **Tipo de juego:** 2D, vista top-down en 3/4 (estilo Kynseed / Stardew Valley)
- **Multijugador:** API de alto nivel de Godot con ENet (`MultiplayerSpawner`, `MultiplayerSynchronizer`, `@rpc`)
- **Física:** solo física 2D (CharacterBody2D, Area2D). Ignorar Jolt, es para 3D.

## Configuración de pixel art

- Resolución base: 640x360, ventana 1280x720 (window override)
- Stretch mode: `viewport`, aspect: `keep`, scale mode: `integer`
- Filtro de texturas por defecto: Nearest, sin mipmaps
- Mapas con `TileMapLayer` (no usar el nodo `TileMap` obsoleto) y Y-sort activado
- El origen de cada personaje, criatura y objeto debe estar en su base (los pies, la base del tronco) para que el Y-sort funcione

## Sprites y animaciones

- Los sprite sheets de Ninja Adventure tienen cada COLUMNA como una dirección (0 abajo, 1 arriba, 2 izquierda, 3 derecha) y cada FILA como un cuadro de animación. Las animaciones se forman bajando por una columna (caminar abajo = cuadros 0, 4, 8, 12), nunca avanzando por una fila.
- Algunas hojas tienen más filas (ataque, salto) o una organización distinta (algunos animales). Antes de usar una hoja nueva, abre la imagen y verifica sus filas y columnas reales.
- Todas las animaciones se construyen con la función compartida `build_frames` pasando las filas y columnas reales.
- La dirección de la animación la decide el componente compartido `DirectionAnimator` (con histéresis y umbral de velocidad). No duplicar lógica de dirección en cada escena.
- Solo llamar a `play()` cuando la animación cambia. Nunca reiniciar la animación en cada frame.
- Al recortar regiones de un tileset, verificar visualmente que el rectángulo no incluya pedazos de tiles vecinos.

## Assets

- **Ninja Adventure** (CC0): base del mundo, personajes, compañeros y monstruos.
- **Kenney Tiny Town, Tiny Dungeon y Tiny Farm** (CC0), en `assets/kenney/`: edificios de la ciudad, NPCs e iconos de objetos.
- Kenney: usar siempre `tilemap_packed.png` (sin separación) o los PNG individuales de `Tiles/`. Nunca `tilemap.png`, que tiene 1 px de separación entre tiles.
- Las casas de Kenney se componen con varios tiles (techo, pared, puerta, ventana); no existen como una sola imagen.
- Solo usar assets con licencia que permita uso comercial (CC0 o CC-BY con crédito). Registrar cada pack en `CREDITS.md` con autor, enlace y licencia.
- No generar arte. Si falta un sprite, preguntar o proponer uno existente con cambio de color (`modulate` o variantes de paleta).

## Diseño del juego

### Razas y compañeros

| Raza | Estilo | Compañero | Habilidad del compañero |
|---|---|---|---|
| Humano | Versátil | Halcón | Ataque en picado; marca enemigos |
| Orco | Fuerza bruta, lento | Lobo | Cuerpo a cuerpo; doble daño por la espalda |
| Elfo | Ágil, frágil | Espíritu del bosque | No ataca: cura al jugador y le pone escudo |
| Enano | Resistente, muy lento | Golem de piedra | Provoca a los monstruos para que lo ataquen a él |
| No-muerto | Daño sostenido | Familiar de sombras | Cada golpe cura al jugador la mitad del daño |

### Reglas de diseño

- Los datos se definen como `Resource` en `.tres`, nunca hardcodeados: `RaceData`, `CompanionData`, `MonsterData`, `RecipeData`, `ShopItemData`, objetos del inventario.
- Los compañeros comparten una escena base (seguir, atacar, volver, subir de nivel) y sus habilidades son componentes separados configurados desde `CompanionData`.
- Los compañeros atacan cuando un monstruo golpea al jugador o cuando el jugador ataca. Si el objetivo se aleja más de 150 px del jugador, vuelven.
- Los compañeros suben de nivel con la experiencia de los monstruos que mueren cerca del jugador; los valores por nivel están en `CompanionData`.
- La zona segura (la ciudad) no tiene monstruos, regenera vida y contiene la mesa de crafteo, el cofre y los NPCs.
- Al morir, el jugador suelta su inventario (excepto lo equipado) en una bolsa que dura 5 minutos. Lo guardado en el cofre no se pierde.

## Capas de colisión

1. Mundo (árboles, paredes, obstáculos)
2. Jugadores
3. Compañeros
4. Monstruos
5. Proyectiles
6. Recogibles (monedas, madera, bolsas)

Los compañeros voladores (halcón) no chocan con nada. Ningún compañero choca con su jugador.

## Estructura de carpetas

- `assets/` → sprites, tilesets y audio de packs externos (`assets/kenney/` para Kenney)
- `scenes/` → escenas `.tscn`
- `scripts/` → scripts `.gd`
- `resources/` → datos (`.tres`)
- `autoload/` → singletons (estado del juego, red, efectos)

## Convenciones

- Archivos y variables en `snake_case`; clases con `class_name` en `PascalCase`
- Señales en pasado: `health_changed`, `companion_leveled_up`
- Los nodos se comunican con señales, no con llamadas directas entre ramas no relacionadas
- Tipado estático en GDScript siempre que se pueda (`var speed: float = 100.0`)
- En scripts que reciben datos por `setup()`, no usar variables `@onready` antes de que el nodo esté en el árbol de escena
- Al renombrar una constante o variable, buscar y actualizar todas sus referencias en el proyecto

## Multijugador

- Todo se diseña pensando en que el servidor tiene la autoridad: daño, monstruos, árboles, oro, objetos, bolsas de muerte y hora del día.
- Los clientes envían su input; el servidor decide y sincroniza.
- Cada jugador tiene su propia raza, compañero, inventario y HUD.

## Depuración

- Teclas de depuración solo en builds de debug (`OS.is_debug_build()`):
  F1 recursos (madera, flechas, arco), F7 experiencia al compañero, y las que se agreguen para probar sistemas.
- Los labels de depuración son temporales: quitarlos cuando el problema esté resuelto.

## Forma de trabajar

- Avanzar en pasos pequeños que se puedan probar con F5
- No reescribir sistemas completos sin pedirlo
- Al terminar una tarea, explicar qué archivos se crearon o modificaron y cómo probarlo
- Si un archivo de assets no existe, preguntar en vez de inventar rutas
- Ante un bug visual que no se resuelve, diagnosticar primero (labels, teclas de depuración) antes de cambiar código
- Después de modificar scripts, verificar que no haya errores ejecutando:
  `C:\juegos\Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit`
  Revisar la salida y corregir cualquier "Parser Error" o "SCRIPT ERROR" antes de terminar. Mostrar la salida al usuario.

## Ejecutar el proyecto

Se ejecuta desde el editor de Godot (F5). Para ver errores en consola, usar:
`C:\juegos\Godot_v4.6.2-stable_win64_console.exe`
