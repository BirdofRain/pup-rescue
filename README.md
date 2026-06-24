# Pup Rescue

**Project:** Pup Rescue · **Engine:** Godot 4 (developed on 4.6, Forward Plus)

A 3D top-down maze puzzle built with **Godot 4.6**. Guide a voxel pup through procedurally generated mazes: collect the key (from level 2 onward), open the pen gate or door, escort follower pups to the exit, and win.

## Core loop

1. Spawn into a procedurally generated maze.
2. Move the pup (click / drag / touch) toward objectives.
3. Collect the **key** (level 2+) to open the **pen gate / door**.
4. Free and **escort follower pups** to the **exit**.
5. Reach the exit to **win the level**, which **saves progress** and advances difficulty/island.
6. Spend earned coins on **upgrades, accessories, and companions**; continue to the next level.

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
| Rescue pen (`P`/`G`) | Post-carved room off the main path; key opens gate, small pups follow |
| Legacy rescues (`R`) | Only on older maps without a pen |
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

## Play in browser (Vercel)

The game can be exported as HTML5 and hosted on [Vercel](https://vercel.com).

1. Install [Godot 4.6.3](https://godotengine.org/download) and [Web export templates](https://godotengine.org/download) (4.6.3).
2. Log in once: `npx vercel login`
3. From `pup-rescue`, run:

```powershell
.\scripts\deploy-web.ps1
```

Or export manually in Godot (**Project → Export → Web**), then deploy the `build/web` folder:

```powershell
cd build\web
npx vercel deploy --prod
```

Share the `*.vercel.app` URL with family. **Controls:** click or tap the floor to move the puppy.

## Important systems

| System | Entry points | Notes |
|--------|--------------|-------|
| Save / persistence | `scripts/save_game.gd` (autoload) | `user://save.json` — level, rescues, breed, unlocks. Preserve schema; avoid breaking old saves. |
| Audio | `scripts/sfx_manager.gd` (autoload) | Procedural SFX, no audio files required. |
| Game loop & UI | `scripts/game.gd` | Pickups, HUD, win/restart, scene transitions. |
| Player movement | `scripts/puppy_controller.gd`, `scripts/player_input_controller.gd` | Grid-based walkability + breed mesh. |
| Maze generation | `scripts/level_generator.gd`, `scripts/maze_builder.gd`, `scripts/level_data.gd` | Procedural layout, walls, sizing. |
| Followers / rescue | `scripts/follower_*.gd`, `scripts/follower_squad.gd` | Escort logic for freed pups. |
| Progression | `scripts/progression/*`, `resources/progression/*` | Islands, levels, companions, accessories — keyed by **stable IDs**. |
| Cosmetics | `scripts/wardrobe.gd`, `scripts/accessory_catalog.gd`, `scripts/upgrade_catalog.gd` | Wardrobe, accessories, upgrades, ultra buffs. |
| Leaderboard | `scripts/leaderboard.gd` | Score display. |

## For future agents (Cursor)

- **Do not rewrite the whole project.** Make small, additive, reviewable changes.
- **Inspect relevant files before editing** and follow existing patterns/conventions.
- **Preserve** player movement, rescue logic, followers, keys, exits, save data, UI node references, and scene transitions.
- **Use stable IDs** for progression systems (islands, levels, companions, accessories). Never renumber or reuse IDs.
- **Avoid breaking existing saves** (`user://save.json`). If the save schema must change, add migration logic and defaults.
- After editing, **report the list of changed files and the manual test steps** needed to verify.
- See `.cursor/rules/pup-rescue.mdc` for the full agent ruleset.

## Manual testing checklist

After any change, open the project in Godot 4 and verify:

- [ ] Project opens without errors; `scenes/Menu.tscn` loads.
- [ ] **New Game** starts; **Continue** appears only when a save exists.
- [ ] Pup moves via click / drag (desktop) and touch (mobile).
- [ ] Level 1 (tutorial) is completable by reaching the exit (no key required).
- [ ] Level 2+ spawns a key; collecting it opens the pen gate / door.
- [ ] Follower pups can be freed and escorted to the exit.
- [ ] Reaching the exit shows the win panel and **Next Level** saves progress.
- [ ] Reload / restart regenerates a valid, solvable maze.
- [ ] Progression (islands / levels / companions / accessories) unlocks correctly.
- [ ] Wardrobe / accessories / upgrades apply and persist after restart.
- [ ] Existing saves still load (no reset / corruption).
- [ ] No new errors or orphan-node warnings in the Godot output.

## Version control

- `.gitignore` excludes Godot caches (`.godot/`, `.import/`), `*.translation`, build artifacts (`/build/`, `/android/`, `/ios/`), and OS/editor junk. Commit source assets, scenes, scripts, and Godot `*.import` metadata.
- `.gitattributes` configures **Git LFS** for binary game assets (`*.png`, `*.jpg`, `*.jpeg`, `*.webp`, `*.wav`, `*.mp3`, `*.ogg`, `*.glb`, `*.gltf`, `*.fbx`, `*.blend`, `*.obj`). Run `git lfs install` once per machine before committing new binaries.
