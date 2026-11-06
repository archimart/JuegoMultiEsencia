# Reporte de trabajo nocturno

## Estado de tareas

- [x] 1. Espada de hierro, pico y poción de vida
- [x] 2. Vetas de mineral en cueva y montañas
- [x] 3. Menú principal
- [x] 4. Menú de pausa
- [x] 5. Opciones
- [x] 6. Pantalla de muerte
- [x] 7. Inventario en cuadrícula con icono, cantidad y tooltip
- [x] 8. Barra rápida con teclas 1–8 y slot resaltado
- [x] 9. Crafteo con íconos y cantidades coloreadas
- [x] 10. Confirmación al eclosionar huevos raros/épicos
- [x] 11. Spawner por zonas
- [x] 12. Tienda del Comerciante
- [x] 13. Mensajes de primeros pasos

---

## Decisiones tomadas

### Tarea 1
- Receta de poción de vida usa `{"wood": 3}` como ingrediente placeholder. Cambiar a hierbas cuando exista el sprite.
- Espada de hierro y pico comparten `{"iron_ingot": 2, "wood": 1}`.

### Tarea 2
- 11 vetas en superficie (bordes norte/oeste/este del mapa) además de las de cueva existentes.

### Tarea 3
- Nombre provisional del juego: "PIXEL QUEST". Cambiar cuando se defina el nombre oficial.
- El botón Créditos lee `CREDITS.md` y agrega aviso de licencia de Godot.

### Tarea 4
- Pausa con `get_tree().paused = true`. Input de pausa en `world.gd`.

### Tarea 5
- Volumen música en bus "Music" (si existe); SFX en bus "Master".
- Escala UI: enteros 1–4. Ajustes persistidos en `user://options.cfg`.

### Tarea 6
- Fade-in de 1.2s en pantalla de muerte. Ítems equipados no se pierden.

### Tarea 7
- Tooltip muestra: nombre, estado equipado, stats de arma, uso de poción, progreso de huevo.
- Para armas busca `weapon_{id}.tres`; si existe, muestra daño/rango/cooldown.

### Tarea 8
- Teclas 1–8 seleccionan slot con borde azul claro.
- Número de tecla visible en cada slot (esquina superior izquierda).
- Presionar slot de poción llama `_use_health_potion()`; slot de huevo intenta eclosionar.

### Conflicto tecla [H]
- `world.gd` tiene ayuda en [H]; `player.gd` usa [H] para poción de vida.
- `player.gd._unhandled_input` corre primero. Pendiente: reasignar ayuda a [F2].

### Tarea 9
- Cada receta: icono del resultado + lista de ingredientes con íconos.
- Cantidades en verde si alcanza, rojo si falta.
- Panel ampliado a 280×200px.

### Tarea 10
- Huevos comunes eclosionan directamente.
- Huevos raros, épicos o shiny muestran diálogo de confirmación con color de rareza.
- Si el huevo no tiene kills suficientes, muestra aviso con progreso.

### Tarea 11
- Zona cercana (<450px del centro): corazón, mapache, slime, seta.
- Zona media (450–950px): slime, seta, araña, murciélago, gólem.
- Zona lejana (>950px): araña, gólem, escorpión, serpiente, cráneo, espíritu.
- Cueva (x≥3800): murciélago, escorpión, cráneo, espíritu.

### Tarea 12
- El NPC "Comerciante" existente (CityNPC) ahora tiene `shop_scene`.
- CityNPC detecta al jugador con Area2D y muestra "[E] nombre" cuando está cerca.
- Tienda compra: flechas x10 (5 oro), poción x1 (3 oro), espada de hierro x1 (15 oro).
- Tienda vende: madera (1 oro/u), mineral (2 oro/u), lingote de hierro (5 oro/u).
- Vender items los vende todos de una vez (no por unidad).

### Tarea 13
- Sistema `TutorialSystem` autoload con 5 pasos, persistidos en `user://tutorial.cfg`.
- Triggers: primer movimiento (move), abrir inventario (inventory), recoger madera (wood), abrir tienda (shop), recibir daño (hp).
- El tip se muestra como notice del jugador usando la señal existente `notice_requested`.

---

## Imágenes a generar con PixelLab

*(ninguna pendiente — todos los assets se tomaron de los packs existentes)*

---

## Cómo probar

1. Presionar **F5** en Godot para iniciar. Aparece el menú principal.
2. Seleccionar raza → aparece el mundo.
3. **Movimiento**: WASD → aparece tip de tutorial.
4. **Inventario**: [I] → muestra íconos con tooltip al hover.
5. **Hotbar**: teclas 1–8 → slot se resalta en azul.
6. **Poción**: tener una poción en el inventario, presionar [H] o la tecla del slot.
7. **Crafteo**: acercarse a la mesa, [E] → ver íconos de ingredientes en verde/rojo.
8. **Tienda**: acercarse al Comerciante en la villa, [E] → comprar/vender.
9. **Minar**: necesitas pico; acércate a veta de mineral, [E].
10. **Huevo raro/épico**: al tener kills suficientes, seleccionar slot → confirmación.
11. **Pausa**: [Esc] durante juego → menú de pausa.
12. **Opciones**: desde menú principal o pausa → ajusta volumen y escala.
13. **Muerte**: al morir → pantalla "HAS CAÍDO" con objetos perdidos → reaparecer.
