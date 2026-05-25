# Pup Rescue

A 3D top-down maze puzzle built with **Godot 4.6**. Guide a voxel pup through procedurally generated mazes: collect the key (from level 2 onward), open the door, rescue optional pups, and reach the exit.

## Requirements

- [Godot 4.6](https://godotengine.org/download) (Forward Plus)
- Windows recommended (project uses D3D12 on Windows)

## Run

1. Open Godot 4.6 → **Import** → select `pup-rescue/project.godot`
2. Press **F5** (Play)

The main scene is `scenes/Menu.tscn`. From there you can start a **New Game**, **Continue** (if save exists), or open the **Test Maze**.

## Controls

- **Desktop:** click or drag on the floor to move the puppy
- **Mobile:** touch and drag on the floor
- **HUD:** Menu, Restart, Reload, Test maze toggle
- **Win panel:** Next Level (saves progress), Restart

## Features

| Feature | Description |
|---------|-------------|
| Main menu | Breed select, new / continue / test maze |
| Save game | `user://save.json` — level, total rescues, breed |
| Level 1 tutorial | Small maze, no key/door — reach exit only |
| Procedural levels | Maze size grows; wall color cycles per level |
| Rescue pups (`R`) | Optional pink markers; bonus rescue count |
| Movement | Grid-based walkability (reliable wall blocking) |
| SFX | Procedural beeps (no audio files required) |
| Pickup feedback | Particle burst on key, door, rescue, win |

## Project layout

| Path | Role |
|------|------|
| `scenes/Menu.tscn` | Main menu |
| `scenes/Game.tscn` | Gameplay |
| `scenes/Puppy.tscn` | Player |
| `scripts/save_game.gd` | Autoload — persistence |
| `scripts/sfx_manager.gd` | Autoload — sound |
| `scripts/game.gd` | Game loop, UI, pickups |
| `scripts/puppy_controller.gd` | Grid movement + breed mesh |
| `scripts/maze_builder.gd` | Thin wall visuals |
| `scripts/level_generator.gd` | Procedural maze |
| `scripts/level_data.gd` | Level sizing / test map |

## Editor options (Game root)

- `test_mode` — micro test maze (also toggled in HUD)
- `auto_fit_camera_on_load` — orthographic camera fit
- `randomize_each_load` — new maze layout each restart
- `ui_safe_margin` — HUD inset for notches / thumbs
- `pickup_radius` — key / rescue / exit collection distance

## Puppy breed

Set on the main menu or on the Puppy instance: **Husky**, **Labrador**, **Pitbull**.

## Version control

`.gitignore` excludes `.godot/`. Commit source assets and scenes.
