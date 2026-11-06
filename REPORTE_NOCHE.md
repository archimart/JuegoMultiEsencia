# Reporte de trabajo nocturno

## Estado de tareas

- [x] 1. Espada de hierro, pico y poción de vida
- [x] 2. Vetas de mineral en cueva y montañas
- [x] 3. Menú principal
- [x] 4. Menú de pausa
- [x] 5. Opciones
- [x] 6. Pantalla de muerte
- [x] 7. Inventario en cuadrícula con icono, cantidad y tooltip
- [ ] 8. Barra rápida con teclas 1–8
- [ ] 9. Crafteo con íconos
- [ ] 10. Confirmación al eclosionar huevos raros/épicos
- [ ] 11. Spawner por zonas
- [ ] 12. Tienda del Comerciante
- [ ] 13. Mensajes de primeros pasos

---

## Decisiones tomadas

### Tarea 1
- Receta de poción de vida usa `{"wood": 3}` como ingrediente placeholder. Cambiar a hierbas cuando exista el sprite.
- Espada de hierro y pico comparten `{"iron_ingot": 2, "wood": 1}`.

### Tarea 2
- Se agregaron 11 vetas en superficie (bordes norte/oeste/este del mapa) además de las de cueva existentes.

### Tarea 3
- Nombre provisional del juego: "PIXEL QUEST". Cambiar cuando se defina el nombre oficial.
- El botón Créditos lee `CREDITS.md` y agrega aviso de licencia de Godot.

### Tarea 4
- El menú de pausa usa `get_tree().paused = true` con `process_mode = ALWAYS`. El input de pausa vive en `world.gd`.

### Tarea 5
- El volumen de música usa el bus "Music" (si existe); SFX usa el bus "Master".
- Escala de UI: enteros 1–4 (640×360 a 2560×1440).
- Ajustes persistidos en `user://options.cfg`.

### Tarea 6
- La pantalla de muerte tiene animación fade-in de 1.2s.
- El botón "REAPARECER" llama a `player.do_respawn()` y se cierra.
- Los ítems equipados no se pierden al morir.

### Tarea 7
- El tooltip muestra: nombre, estado equipado, stats de arma (daño/rango/cooldown), uso de poción, progreso de huevo.
- Para armas busca `weapon_{id}.tres`; si existe, muestra los campos de `WeaponData`.
- El clic derecho en un slot sigue llamando `equip_item`.

### Conflicto de tecla [H]
- `world.gd` tiene un panel de ayuda en [H]; `player.gd` usa [H] para poción de vida.
- Por ahora `player.gd._unhandled_input` corre primero y consume el evento. Pendiente: reasignar ayuda a [F2] o mover poción a otro slot de la barra rápida.

---

## Imágenes a generar con PixelLab

*(ninguna pendiente — todos los assets se tomaron de los packs existentes)*
