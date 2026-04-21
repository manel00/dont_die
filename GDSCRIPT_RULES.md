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

### Spawn de Armas
- `WeaponSpawner` (autoload) genera **10 armas** automáticamente al inicio de la partida.
- Las armas aparecen en posiciones aleatorias en un radio de **50 metros** alrededor del jugador.
- Mínimo de **10 metros** de distancia del jugador para evitar spawn encima.

### Pickup Automático
- Al tocar visualmente el arma, se recoge automáticamente.
- **NO se puede recoger si ya tienes un arma equipada.** La función `pickup_styloo_weapon()` retorna inmediatamente si `has_weapon` es true.
- El jugador debe soltar primero su arma actual (presiona **Q**) antes de poder recoger otra.

### Armas Droppeadas
- Cuando sueltas un arma (tecla Q), aparece en el suelo.
- Las armas droppeadas **desaparecen después de 5 segundos** (auto-despawn).
- Cooldown de **0.5 segundos** tras droppear antes de poder recogerla (evitar recoger inmediatamente).

### Posición en Mano
- El arma equipada aparece en la **mano derecha** del personaje.
- Posición relativa fija: `Vector3(0.25, 0.6, 0.35)` (derecha, altura, frente).
- El arma es hijo de `visual_model` para rotar/sincronizar con el personaje.

## 7. Prevención de Matriz Singular (det == 0)
- **NUNCA** llames `look_at()` con un vector de dirección de longitud cero o que resulte en una matriz de transformación inválida (determinante = 0).
- **SIEMPRE** verifica que la dirección tenga longitud suficiente antes de usar `look_at()`:
  ```gdscript
  if direction.length() > 0.001:
      node.look_at(node.global_position + direction, Vector3.UP)
  ```
- Esto evita el crash `invert: Condition "det == 0" is true` en `core/math/basis.cpp`.

## 8. Gestión de Recursos (Materials)
- **NUNCA** llames `queue_free()` en objetos `Material` o `StandardMaterial3D`.
- Los materiales son recursos (`Resource`), no nodos (`Node`). No tienen el método `queue_free()`.
- Para liberar materiales duplicados, simplemente elimina las referencias:
  ```gdscript
  mesh.material_override = original_material
  duplicated_material = null  # Se libera automáticamente cuando no hay referencias
  ```
