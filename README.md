# Pup Rescue

A 3D top-down maze puzzle built with **Godot 4.6**. Tap or click the floor to guide a puppy through procedurally generated mazes: collect the key, open the door, then reach the exit.

## Requirements

- [Godot 4.6](https://godotengine.org/download) (Forward Plus; project uses Jolt Physics)
- Windows recommended (project sets D3D12 rendering driver)

## Run locally

1. Open Godot 4.6 and choose **Import**.
2. Select the `project.godot` file in this folder (`pup-rescue/project.godot`).
3. Press **F5** (Play) or use **Project → Run**.

The main scene is `scenes/Game.tscn`.

## Controls

- **Desktop:** click or click-drag on the floor to set the puppy’s destination.
- **Mobile:** touch and drag on the floor (same raycast logic).
- **Restart:** top-left button reloads the current level.
- **Win panel:** after reaching the exit (with key collected), use **Next Level** or **Restart Level**.

## Project layout

| Path | Purpose |
|------|---------|
| `scripts/game.gd` | Level flow, input, UI, key/door/exit logic |
| `scripts/level_generator.gd` | Procedural maze (recursive backtracker) |
| `scripts/level_data.gd` | Level sizing and micro test map |
| `scripts/maze_builder.gd` | ASCII maze → 3D walls and door |
| `scripts/puppy_controller.gd` | Player movement and breed mesh |
| `scripts/camera3D.gd` | Orthographic camera fit to maze bounds |
| `scenes/Game.tscn` | Main scene |
| `scenes/Puppy.tscn` | Player (voxel dog models) |
| `assets/Voxel*.obj` | Husky, Labrador, Pitbull meshes |

## Editor options (Game root)

- `test_mode` — use the small hand-authored test maze.
- `auto_fit_camera_on_load` — orthographic camera frames the maze on each load.
- `randomize_each_load` — vary maze layout when restarting or advancing levels.

## Player breed

On the **Puppy** scene instance, set **Breed** on `puppy_controller.gd` to `HUSKY`, `LABRADOR`, or `PITBULL`.

## Version control

`.gitignore` excludes `.godot/` import cache. Commit source assets and scenes; do not commit `.godot/` unless your team agrees otherwise.
