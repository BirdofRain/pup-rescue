# AGENTS.md

See `README.md` for gameplay, project layout, and the manual test checklist, and
`.cursor/rules/pup-rescue.mdc` for the agent ruleset (small additive changes, preserve
gameplay/save systems, stable progression IDs).

## Cursor Cloud specific instructions

Pup Rescue is a single-process **Godot 4.6** GDScript game (no backend/DB/services). The
only runtime needed is the Godot engine loading `scenes/Menu.tscn` (autoloads `SaveGame`
and `SfxManager` load automatically). The Godot 4.6 editor/headless binary is preinstalled
at `/usr/local/bin/godot` (i.e. `godot`).

### Running the automated tests (headless, no display needed)
The project's tests are bespoke headless `SceneTree` scripts under `tools/` (no GUT/gdUnit,
no CI). Exit code 0 = pass:

```
godot --headless --path . --script res://tools/validate_progression.gd
godot --headless --path . --script res://tools/test_puppy_session_tracker.gd
godot --headless --path . --script res://tools/test_rescue_room.gd
godot --headless --path . --script res://tools/test_new_game.gd
```

### Running the game with a GUI (headless VM)
The VM has no GPU, so use Mesa software rendering (lavapipe). An X server is already on
`DISPLAY=:1` with the `xfwm4` window manager. Run on the existing display with:

```
mkdir -p /tmp/xdg-runtime && chmod 700 /tmp/xdg-runtime
DISPLAY=:1 XDG_RUNTIME_DIR=/tmp/xdg-runtime VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json \
  godot --path . --resolution 1000x680
```

Godot's Forward+ renderer runs fine on the `llvmpipe`/lavapipe software Vulkan device.
ALSA "cannot find card" warnings are expected (no audio device) and harmless — audio falls
back to the dummy driver.

### Non-obvious caveats (important)
- **Reload-phase parse errors are non-fatal.** On startup Godot prints errors like
  `argument 3 should be "ProgressionRegistry" but is "ProgressionRegistry"`
  (`island_progress.gd`) and a depended `save_game.gd` "Failed to load script". These come
  from a cyclic `class_name` / preloaded-script identity quirk during the all-scripts
  reload; the scripts resolve correctly at runtime (the headless tests exercise
  `save_game.gd` and pass). Do not treat these as blocking.
- **The GUI main menu is non-interactive under Godot 4.6 stable.** `scripts/menu.gd` fails
  to parse (`menu.gd:471` assigns `BoxContainer.ALIGNMENT_CENTER` to a
  `FlowContainer.alignment`, which 4.6 rejects as a cross-enum type error). The menu still
  *renders* (UI is defined in `Menu.tscn`), but the buttons (New Game, etc.) do nothing
  because the script never attaches. To test gameplay directly, launch the gameplay scene:
  `godot --path . res://scenes/Game.tscn` (the `Game.tscn` runtime island-progression errors
  about `default_entry` are non-fatal — the maze, puppy, HUD, and movement work).
- **Driving input from automated tooling:** keyboard/mouse events only reach Godot when its
  window has focus. Use `xdotool search --name PupRescue` then `windowactivate`/`windowfocus`
  before sending input. Movement = arrow keys or WASD (held), or click-drag on the floor
  (single quick clicks barely move the pup; it follows while the button is held).

### Lint
There is no linter configured in this repo (no `.gdlintrc`, no gdtoolkit). "Compile"
validation is effectively the headless test runs above, which surface any parse errors.
