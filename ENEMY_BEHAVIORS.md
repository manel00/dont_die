# ENEMY_BEHAVIORS.md
# Documento de Comportamientos de Enemigos
# Proyecto: Don't Die | Actualizado: 2026-04-20

---

## Reglas Generales

- Todos los enemigos heredan de `EnemyBase` (`entities/enemies/base/EnemyBase.gd`)
- La IA usa una máquina de estados: `IDLE → CHASE → ATTACK → STRAFE / RETREAT → DEAD`
- El daño lo gestiona el servidor; los clientes solo reciben sincronización visual
- Los enemigos tienen culling de distancia: se congelan a más de 50 unidades del jugador

---

## Tipos de Enemigos

### 🦴 Minion (`entities/enemies/minion/`)
- **Modelo:** KayKit Skeleton básico
- **Comportamiento:** Melee. Se acerca al jugador y golpea a corto rango.
- **Stats:** HP 450 | Daño 30 | Velocidad 6.24 | Rango 2.5
- **Ataque:** Cuerpo a cuerpo directo, sin proyectiles.

---

### 🔮 Mage (`entities/enemies/mage/Mage.gd`)
- **Modelo:** KayKit Skeleton_Mage + bastón (Skeleton_Staff.gltf)
- **Rol:** MINIBOSS ranged — lanza proyectiles elementales múltiples
- **Stats:** HP 350 | Daño 50 | Velocidad 1.6 | Rango 15.0 | Cooldown 1.5s
- **Ataque:** Lanza **3 proyectiles en abanico** simultáneamente, uno de cada tipo elemental:
  - 🧊 **ICE** (azul, `Color(0.2, 0.6, 1.0)`) — velocidad 20 — lento, efecto gélido
  - 🔥 **FIRE** (rojo, `Color(1.0, 0.3, 0.0)`) — velocidad 30 — rápido, ardiente
  - ⚡ **ELECTRIC** (amarillo, `Color(0.9, 0.9, 0.1)`) — velocidad 35 — el más rápido
- **Spread:** los 3 proyectiles salen con ±15° de ángulo en abanico horizontal
- **Visual:** Luz azulada pulsante (OmniLight3D) + textura mecha aleatoria
- **NOTA:** Los magos son los ÚNICOS que lanzan múltiples bolas de colores distintos

---

### 🤖 Ranger / Mecha (`entities/enemies/ranger/Ranger.gd`)
- **Modelo:** KayKit Skeleton_Rogue + ballesta (Skeleton_Crossbow.gltf)
- **Rol:** Ranged — dispara proyectiles eléctricos rápidos y frecuentes
- **Stats:** HP 180 | Daño 15 | Velocidad 1.4 | Rango 18.0 | Cooldown 0.7s
- **Ataque:** Dispara **1 bola eléctrica amarilla** por ronda, cadencia alta
  - Color: `Color(0.9, 0.95, 0.1)` — amarillo eléctrico brillante
  - Velocidad proyectil: 40.0 — muy rápido
  - Luz naranja-amarilla en el proyectil (OmniLight3D)
- **NOTA:** Los mechas/rangers NO lanzan múltiples bolas ni bolas de colores distintos.
  Su identidad visual es la bola eléctrica amarilla de alta cadencia.

---

### 🛡️ Shield (`entities/enemies/shield/`)
- **Modelo:** KayKit Skeleton con escudo
- **Comportamiento:** Melee con bloqueo de frontal. Alta defensa.

---

### 🗡️ Rogue (`entities/enemies/rogue/`)
- **Modelo:** KayKit Skeleton_Rogue
- **Comportamiento:** Melee rápido, flanquea y ataca desde los lados

---

### 🧟 Zombie (`entities/enemies/zombie/`)
- **Comportamiento:** Melee lento pero muy resistente. Solo persigue, no retrocede nunca.

---

### 💀 Boss (`entities/enemies/boss/Boss.gd`)
- **Modelo:** Textura MechaGolem fija (índice 4 de MECHA_MODELS)
- **Comportamiento:** Jefe final con múltiples fases

---

## Tabla Resumen de Proyectiles

| Enemigo  | ¿Dispara? | Cantidad | Color          | Cooldown |
|----------|-----------|----------|----------------|----------|
| Minion   | ❌ No     | —        | —              | —        |
| Mage     | ✅ Sí     | 3 balas  | Azul/Rojo/Amarillo (ICE/FIRE/ELECTRIC) | 1.5s |
| Ranger   | ✅ Sí     | 1 bala   | Amarillo eléctrico | 0.7s |
| Rogue    | ❌ No     | —        | —              | —        |
| Shield   | ❌ No     | —        | —              | —        |
| Zombie   | ❌ No     | —        | —              | —        |
| Boss     | ✅ Sí     | Variable | Variable       | Variable |

---

## Sistema de Granada (Jugador)

- **Archivo:** `entities/player/weapons/GrenadeProjectile.gd`
- **Efecto:** `entities/effects/ExplosionEffect.gd`
- **Radio de explosión:** 6.0 unidades (mitad del radio original 12.0)
- **Daño:** Solo a enemigos que físicamente **están dentro** del radio en el momento de la explosión
- **Falloff:** Daño reduce linealmente con la distancia (100% en el centro, 10% en el borde)
- **Visual:** Onda expansiva naranja, bola de fuego central, partículas, flash en enemigos golpeados

---

## Notas de Diseño

- **Magos:** Son los únicos "casters" multi-proyectil. Su identidad es el abanico de 3 elementos.
- **Rangers/Mechas:** Identidad = cadencia alta + color eléctrico único. NO múltiples colores.
- Los valores de cooldown de los rangers están pensados para ser agresivos (disparo cada ~0.7s)
  frente a los magos que tienen un ataque más cinematográfico pero más espaciado.
