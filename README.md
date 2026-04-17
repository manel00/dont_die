# Zombies 3D Twin-Stick Shooter

Welcome to the 3D zombie survival arena. This project features a structured city map, 4 unique player abilities, and a progression system with waves of enemies.

## Gameplay
Survival is your only goal. Face waves of zombies and survive as long as possible in the city arena.

### Abilities
The player has 4 main abilities triggered with keyboard keys:

*   **0 (Q / KEY_0): Katana Melee** - A quick close-range swing that deals high damage to enemies in front. (Cooldown: 0.5s)
*   **1 (KEY_1): Fireball** - Direct fire explosive projectile. Deals AOE damage on impact. (Cooldown: 2.0s)
*   **2 (KEY_2): AOE Explosion** - A powerful explosion centered on the player that pushes and damages nearby zombies. (Cooldown: 5.0s)
*   **3 (KEY_3): Weapon Shot** - Shoot rapid-fire projectiles in the direction you look. **Requires picking up a "Weapon" drop from enemies first.**

## Environment
The game takes place in a fixed city layout with roads, buildings, and street props. All buildings and props have static collisions.

## Technical Details
*   **Engine**: Godot 4.6 (Forward Plus)
*   **Multiplayer**: Support for LAN multiplayer with server-authoritative logic.
*   **Systems**: Wave handling, Loot system, HUD, and Navigation-based AI.

## Assets Used
*   **City Pack**: GLB/GLTF city assets for the environment.
*   **KayKit Skeletons**: Character models and animations.

---
Created with Godot MCP Pro.
