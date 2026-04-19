# Godot 4 Development Best Practices & Fixes

Esta es una guía de reglas para evitar errores comunes heredados de cambios estructurales en el proyecto "test_godot".

## 1. Integridad de Funciones en Controladores
- **NUNCA** elimines la declaración de una función (`func _name():`) al simplificar su lógica interna.
- Si una función como `_handle_shooting` o `_is_shooting` es llamada en `_physics_process`, debe existir una definición válida para evitar errores de parseo en tiempo de ejecución.
- Al realizar limpiezas de código, utiliza herramientas de búsqueda (grep) para encontrar todas las llamadas a la función antes de borrarla.

## 2. Prevención de Z-Fighting (Flickering)
- Evita superponer mallas (meshes) a la misma altura exacta (Y).
- Para el suelo, utiliza superficies sólidas únicas (como un solo `CSGBox3D` o `PlaneMesh`) en lugar de baldosas individuales que se solapan en los bordes.
- Si es necesario usar baldosas, aplica un ínfimo offset vertical (`0.001`) entre ellas para que el motor de renderizado sepa cuál pintar encima.

## 3. Mapeo de Teclas Físicas vs InputMap
- Para prototipos rápidos o reglas de usuario específicas (ej: "Tecla 0" o "Tecla 1"), utiliza `Input.is_physical_key_pressed(KEY_0)` para asegurar que el control funcione sin depender de que el `project.godot` esté sincronizado.
- Asegúrate de que las constantes `KEY_0`, `KEY_1`, etc., se usen correctamente en Godot 4 (GDScript 2.0).

## 4. Gestión de Enemigos y Rendimiento
- Mantén siempre un límite (cap) de enemigos activos en el `WaveManager.gd`. Superar los 50-100 enemigos simultáneos en una escena 3D compleja sin optimización puede causar caídas de frames críticas (lag).
- Al spawnear, verifica que el nodo padre (ej: `Enemies`) exista antes de añadir hijos para evitar errores de referencia nula.

## 5. Respawn y Persistencia del Jugador
- Cuando el jugador muere, es preferible realizar un `teleport` y resetear la vida en lugar de hacer `queue_free()` si no hay un sistema de Game Over robusto, para evitar romper referencias en el HUD o en los Bots aliados.

## 6. Sistema de Armas Styloo
- **NO se puede recoger un arma del suelo si ya tienes una equipada.** Primero debes soltar la tuya (presiona Q o la tecla de drop) para poder recoger otra del suelo.
- El temporizador `_despawn_timer` en `StylooWeaponPickup.gd` debe actualizarse en `_process()` para permitir recoger armas droppeadas después de 0.5 segundos.
