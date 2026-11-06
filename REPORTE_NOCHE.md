# Reporte de trabajo nocturno

> Sesión: 2026-11-04 / 05 · Commits: `10ee4b5` → `56d1d13`

---

## Estado de tareas

| # | Tarea | Estado |
|---|-------|--------|
| 1 | Espada de hierro, pico y poción de vida | ✅ Hecho |
| 2 | Vetas de mineral en cueva y montañas | ✅ Hecho |
| 3 | Menú principal (Jugar, Opciones, Créditos, Salir) | ✅ Hecho |
| 4 | Menú de pausa (Esc) | ✅ Hecho |
| 5 | Opciones (volumen, pantalla completa, escala UI) | ✅ Hecho |
| 6 | Pantalla de muerte con animación y objetos perdidos | ✅ Hecho |
| 7 | Inventario en cuadrícula con icono, cantidad y tooltip | ✅ Hecho |
| 8 | Barra rápida con teclas 1–8 y slot resaltado | ✅ Hecho* |
| 9 | Crafteo con íconos y cantidades coloreadas | ✅ Hecho |
| 10 | Confirmación al eclosionar huevos raros/épicos | ✅ Hecho |
| 11 | Spawner por zonas | ✅ Hecho |
| 12 | Tienda del Comerciante | ✅ Hecho* |
| 13 | Mensajes de primeros pasos (tutorial) | ✅ Hecho |

*Ver advertencias en sección de bugs conocidos.

---

## Bugs corregidos durante la sesión (post-tarea)

Estos errores se detectaron al probar y se corrigieron antes de cerrar:

| Bug | Archivo | Causa | Fix |
|-----|---------|-------|-----|
| Parser error tipo `inv` | `crafting_menu.gd:56` | `:=` con ternario Dictionary no puede inferir tipo | Cambio a `var inv: Dictionary =` |
| Crash al abrir inventario | `hud.gd:1268` | `%g` no existe en GDScript | Cambiado a `%d` y `%.2f` |
| Habilidades bloqueadas (1/2/3) | `hud.gd` | Hotbar capturaba KEY_1–8 con `set_input_as_handled()` | Las teclas ahora solo actualizan el visual, NO consumen el evento |
| UIManager sin guard | `world.gd:232` | Usaba `UIManager.is_menu_open()` directo | Añadido `has_node()` antes |
| `Array[Dictionary]` en const | `tutorial_system.gd` | GDScript no admite typed arrays de Dictionary en const | Cambiado a `const STEPS: Array` |
| `for entry: Dictionary in Array` | `shop_menu.gd` | Godot no permite tipo en iterador de Array sin tipo | Cambiado a `for entry in ...` |

---

## Bugs conocidos (pendientes para la próxima sesión)

### 1. Conflicto tecla [H]: ayuda vs poción
**Síntoma:** `world.gd` tiene el panel de ayuda en la acción `help` (mapeada a [H]). `player.gd` también usa [H] para usar la poción de vida. Como `player.gd._unhandled_input` corre antes, la poción gana siempre y el panel de ayuda no se puede abrir con [H].
**Fix sugerido:** Reasignar el panel de ayuda a [F2] en `world.gd`, o mover la poción de vida a [Q].

### 2. Tienda vende todo de golpe
**Síntoma:** Al hacer clic en "Vender Madera", se vende TODA la madera que tiene el jugador de una sola vez. No hay opción de cantidad.
**Fix sugerido:** Agregar slider o botones "+1 / +10 / Todo" en la fila de venta, o vender siempre de 1 en 1.

### 3. `merchant.tscn` / `merchant.gd` son archivos muertos
La Tarea 12 usa el nodo `CityNPC` existente con el campo `shop_scene`. Los archivos `scenes/merchant.tscn` y `scripts/merchant.gd` que creé son un duplicado que no se usa. No causan errores pero confunden.
**Fix sugerido:** Borrar los dos archivos en la próxima sesión.

### 4. Nombre del juego es placeholder
El menú principal dice "PIXEL QUEST" como título provisional.
**Fix sugerido:** Definir el nombre oficial y actualizar `scripts/main_menu.gd` y `project.godot`.

### 5. Tutorial: el tip "move" puede no conectar a tiempo
`TutorialSystem._ready()` llama `call_deferred("_show_step", "move")` antes de que el HUD haya conectado la señal `tip_requested`. Si el HUD se instancia después, el primer tip no llega.
**Fix sugerido:** Que `hud.gd` al conectarse pida el mensaje pendiente, o que `TutorialSystem` guarde el último tip no entregado.

### 6. Opciones: slider de Música no hace nada si el bus "Music" no existe
El proyecto no tiene un bus "Music" definido en AudioServer. El slider de volumen de música en el menú de opciones escribe en un bus que no existe y no tiene efecto.
**Fix sugerido:** Crear el bus "Music" en la configuración de audio de Godot (Audio → Add Bus → renombrar a "Music").

---

## Decisiones que tomé solo

| Decisión | Por qué |
|----------|---------|
| Poción de vida usa `{"wood": 3}` como ingrediente | No existe sprite de hierbas. Registrar como pendiente de PixelLab. |
| Espada de hierro y pico comparten `{"iron_ingot": 2, "wood": 1}` | Coherente con la progresión; sin receta específica pedida. |
| 11 vetas en superficie además de las de cueva | El mundo en superficie estaba vacío de recursos minerales. |
| La tienda vende todo de golpe, no por unidad | Es la forma más simple. Se puede iterar. |
| CityNPC como base del Comerciante (en vez de nueva escena) | Ya existía en el mundo, no había motivo para duplicarlo. |
| `TutorialSystem` conectado a `notice_requested` del jugador | Reutiliza el sistema de avisos ya existente en el HUD, sin nueva UI. |
| Tips del tutorial en 5 pasos, persistidos en disco | Garantiza que no se muestren en cada partida. |
| Zonas: 450 / 950 px de radio desde el centro | Basado en que la villa tiene radio ~200 px y el mapa es 3200 px. |
| Vender en tienda: 1 madera=1 oro, 1 mineral=2 oro, 1 lingote=5 oro | Refleja el ratio de conversión de materiales (3 mineral → 1 lingote). |
| Nombre placeholder "PIXEL QUEST" | Era necesario algo para el menú. |

---

## Cómo probar cada cosa

### Preparación rápida
1. Abrir el proyecto en Godot 4.6.
2. F5 → aparece el Menú Principal.
3. Jugar → Selección de raza → elegir raza y clase → confirmar.
4. En debug (F1 cuando esté en el mundo): da madera, flechas, mineral, lingote de hierro, arco y pico.

### Tarea 1 — Espada, pico y poción
- Craftear pico (2 lingotes + 1 madera) en la mesa → va al inventario.
- Acercarse a una veta de mineral con el pico → [E] → se recoge mineral.
- Sin pico → [E] en veta → aparece aviso "Necesitas un pico para minar".
- Craftear poción (3 madera) → presionar [H] → se gasta y recupera 20 HP.

### Tarea 2 — Vetas de mineral
- Explorar los bordes norte, oeste y este del mapa. Hay 11 vetas en superficie.
- Dentro de la cueva hay vetas adicionales.
- Las vetas agotadas se ven como roca gris; reaparecen en 90 segundos.

### Tarea 3 — Menú principal
- El menú tiene cuatro botones: Jugar, Opciones, Créditos, Salir.
- Créditos: muestra el contenido de CREDITS.md + aviso de licencia de Godot.
- Salir: cierra el juego.

### Tarea 4 — Pausa
- Durante el juego, presionar [Esc] → pausa con fondo oscuro y tres botones.
- Continuar: vuelve al juego. Opciones: abre opciones sin salir. Salir al menú: vuelve al menú principal.

### Tarea 5 — Opciones
- Desde el menú principal o desde la pausa → Opciones.
- Ajustar SFX: se escucha el cambio inmediatamente.
- Pantalla completa: alterna modo ventana / completo.
- Escala: 1× (640×360) a 4× (2560×1440). La ventana se redimensiona.
- Los ajustes persisten entre sesiones (guardado en `user://options.cfg`).

### Tarea 6 — Pantalla de muerte
- Dejar que un monstruo mate al jugador (o reducir HP manualmente).
- Aparece pantalla oscura con fade-in, título "HAS CAÍDO" en rojo y lista de ítems perdidos.
- Botón "REAPARECER": el jugador reaparece en el spawn con HP completo.
- Los ítems equipados NO se pierden. Los del inventario van a una bolsa en el suelo.

### Tarea 7 — Tooltip en inventario
- Abrir inventario [I] → pasar el cursor sobre cualquier slot.
- Armas: muestra Daño, Rango en px y Cooldown en segundos.
- Poción: muestra "+20 HP al usar" y "[H] para usar".
- Pico: muestra "Herramienta de minería".
- Huevo: muestra rareza y progreso de kills.

### Tarea 8 — Hotbar
- Las teclas 1–8 seleccionan el slot correspondiente (borde azul claro).
- El número de tecla aparece en la esquina superior izquierda de cada slot.
- Las teclas 1–3 siguen activando habilidades del guerrero/mago sin conflicto.

### Tarea 9 — Crafteo con íconos
- Acercarse a la mesa → [E] → cada receta muestra el ícono del resultado + íconos de ingredientes.
- Ingredientes disponibles en verde. Faltantes en rojo (ícono también enrojece).
- Botón "Craft" desactivado si faltan materiales.

### Tarea 10 — Confirmación huevo raro/épico
- Conseguir un huevo raro o épico y llenarlo de kills (F7 en debug da XP al compañero, no al huevo — ver nota).
- Al presionar la tecla de eclosión con un huevo listo y raro/épico → aparece diálogo de confirmación con el color de la rareza.
- Huevos comunes eclosionan directamente sin confirmación.

### Tarea 11 — Spawner por zonas
- Cerca de la villa (radio <450 px): corazones, mapaches, slimes, setas.
- A media distancia: aparecen arañas, murciélagos y gólems.
- Lejos del centro: escorpiones, serpientes, cráneos, espíritus.
- En la cueva: solo murciélagos, escorpiones, cráneos y espíritus.

### Tarea 12 — Tienda del Comerciante
- Ir a donde está el NPC "Comerciante" en la villa (a la izquierda del centro, pos ~1504, 1600).
- Al acercarse aparece "[E] Comerciante".
- Presionar [E] → se abre la tienda con pestañas Comprar / Vender.
- Comprar: flechas x10 (5 oro), poción x1 (3 oro), espada de hierro x1 (15 oro).
- Vender: madera, mineral, lingote de hierro (precio por unidad, se vende TODO de golpe).

### Tarea 13 — Tutorial
- Al moverse por primera vez: tip "Muévete con WASD | Ataca con clic izquierdo".
- Al abrir inventario [I] por primera vez: tip sobre equipar con clic derecho.
- Al recoger madera por primera vez: tip sobre la mesa de crafteo.
- Al abrir la tienda por primera vez: tip sobre vender materiales.
- Al recibir daño por primera vez: tip sobre los huevos de familiar.
- Cada tip solo aparece una vez (guardado en `user://tutorial.cfg`).
- Para ver todos los tips de nuevo: borrar `user://tutorial.cfg` o añadir un botón "Resetear tutorial" en opciones.

---

## Imágenes a generar con PixelLab

| Archivo destino | Tamaño | Descripción para PixelLab |
|-----------------|--------|---------------------------|
| `assets/Items/Herb.png` | 16×16 | Hierba medicinal, pixel art, hoja verde con borde oscuro, estilo Ninja Adventure, fondo transparente. Para reemplazar la madera en la receta de poción de vida. |

Solo una imagen pendiente. Todos los demás assets se tomaron de los packs existentes (Ninja Adventure, Kenney) o de los sprites generados con PixelLab antes del trabajo nocturno (vetas de mineral, lingotes, huevos).

---

## Archivos creados o modificados esta sesión

### Nuevos
- `scenes/main_menu.tscn` + `scripts/main_menu.gd`
- `scenes/pause_menu.tscn` + `scripts/pause_menu.gd`
- `scenes/options_menu.tscn` + `scripts/options_menu.gd`
- `scenes/death_screen.tscn` + `scripts/death_screen.gd`
- `scenes/shop_menu.tscn` + `scripts/shop_menu.gd`
- `scenes/merchant.tscn` + `scripts/merchant.gd` ← **ELIMINAR** (no se usa)
- `autoload/tutorial_system.gd`
- `resources/weapon_iron_sword.tres`, `item_iron_sword.tres`, `recipe_iron_sword.tres`
- `resources/item_pickaxe.tres`, `recipe_pickaxe.tres`
- `resources/item_health_potion.tres`, `recipe_health_potion.tres`
- `resources/item_iron_ingot.tres`, `recipe_iron_ingot.tres`
- `assets/Items/Egg.png`, `assets/Objects/IronOre.png`, `assets/Objects/IronOreDepleted.png`, `assets/Items/Resource/IronIngot.png`

### Modificados
- `scripts/hud.gd` — tooltip, hotbar, confirmación huevo, tutorial, pantalla de muerte
- `scripts/player.gd` — poción [H], `died` signal, `do_respawn()`, triggers de tutorial
- `scripts/world.gd` — vetas en superficie, menú de pausa, guard UIManager
- `scripts/crafting_menu.gd` — íconos de ingredientes
- `scripts/crafting_table.gd` — carga de las 3 recetas nuevas
- `scripts/spawner.gd` — zonas de dificultad
- `scripts/city_npc.gd` — soporte para abrir tienda
- `scripts/ore_node.gd` — pickaxe requerido, sprites de PixelLab
- `autoload/sfx.gd` — sonido "mine"
- `autoload/fx.gd` — partículas "mine"
- `autoload/ui_manager.gd` — `_apply_saved_options()` al arrancar
- `project.godot` — escena inicial cambiada a `main_menu.tscn`, `TutorialSystem` registrado

---

## Siguiente paso recomendado

**Prioridad 1 — Pulir lo que quedó a medias:**
1. Crear el bus "Music" en AudioServer (5 minutos en el editor).
2. Cambiar la ayuda de [H] a [F2] en el input map del editor.
3. Eliminar `scenes/merchant.tscn` y `scripts/merchant.gd`.
4. Generar `assets/Items/Herb.png` con PixelLab y actualizar `recipe_health_potion.tres`.

**Prioridad 2 — Siguiente sistema grande:**
El juego ya tiene monstruos, crafteo y comerciante, pero le falta economía de progresión. Las opciones más impactantes para la siguiente sesión:
- **Sistema de experiencia del jugador** (sube de nivel → más daño / HP) con la barra de XP que ya existe en el HUD.
- **Drops de oro y materiales** de los monstruos (actualmente los monstruos no dropean nada).
- **Objetos recogibles** en el suelo (baúles, piedras de runa, fragmentos de cristal) para dar razones de explorar las zonas lejanas.
