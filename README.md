# Zig RPG Game Engine

A modular 2D RPG engine written in Zig, built on top of Raylib.

## Features

- Entity-Component System for game objects
- Dialogue system with branching conversations
- Quest system with objectives and rewards
- Inventory management
- Tile-based map system
- NPC interaction
- Save/load functionality

## Build Requirements

- Zig 0.11.0 or later
- Raylib 5.0 or later

## Building and Running

```bash
# Build the project
zig build

# Run the game
zig build run
```

## Project Structure

```
/src                  - Source code
  main.zig           - Entry point and game loop
  /engine            - Engine modules
    entity.zig       - Base entity and component system
    map.zig          - Tilemap loading, drawing, and collision
    dialogue.zig     - Dialogue system and rendering logic
    quest.zig        - Quest system and state tracking
    npc.zig          - NPC behaviors, state machine
    inventory.zig    - Inventory logic, item usage
    save.zig         - Save/load support
/assets              - Game assets
  /maps              - Map files
  /dialogues         - Dialogue trees
  /quests            - Quest definitions
  /textures          - Sprite sheets
build.zig            - Build file
CLAUDE.md            - Development guidelines
README.md            - This file
```

## Controls

- WASD/Arrow Keys: Move player
- E: Interact with NPCs and items
- I: Open/close inventory
- Q: Open/close quest log
- ESC: Pause/resume game

## Acknowledgments

- [Raylib](https://www.raylib.com/) - Used for window management, input, and rendering
- [Zig](https://ziglang.org/) - The programming language used
