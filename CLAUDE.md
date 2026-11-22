# ProjectionGame (working title)

A Defold 1.13 3D puzzle game: arrange coloured polycube pieces in a grid so their shadows match the
target projections on the walls. Targets desktop, mobile and web. Read `principles.md` first; the
code follows it (pure core, deciding vs doing, explicit frame phases, data as the single truth).
The working title lives only in `game.project` (`[project] title`) and is read at runtime.

## Commands
- Specs: `busted` (LuaJIT; `.busted` config). Keep specs compact, one file per area in `spec/`.
- Level preview: `luajit tools/preview.lua levels/<pack>/<level>.lua`
- Regenerate icons / sounds: `python3 tools/make_icons.py`, `python3 tools/make_sounds.py`
  (then refresh `ui/hud.atlas` from `ui/icons/*.png`).
- Run: the Defold editor's HTTP API (`.internal/editor.port` and `.internal/editor.token`):
  `POST /command/run`, `GET /console`, `POST /command/hot-reload`, `POST /command/fetch-libraries`.
- Automation Bridge (a debug-only dependency) on the engine port from the run response:
  `/automation-bridge/v2/screenshot`, `input/click|drag|key|wheel` (window pixels, origin top-left).
  Wait ~10 s after run before screenshots; the first frames are blank while data loads.

## Layout (dependencies point downward)
- `main/`: the outer loop (`main.script`, phase order and screen contract documented at the top),
  screens (`menu_screen`, `select_screen`, `play_screen`), `sheets` (panel stack), `catalog`, `storage`.
- `game/`: pure session logic: `play` (drag, settle, turn, nudge, undo), `progress`, `settings`.
- `core/`: pure puzzle model: `level` (ASCII parsing), `shape`, `orient` (24 rotations),
  `grid`, `projection`, `rules`, `state`, `history`, `raycast`.
- `input/`: `actions` (Defold → raw events), `router` (controls claim input), `gestures`, `interpret`.
- `view/`: `board_view` (pieces), `walls_view` (projection panels), `tray_view`, `orbit` (camera
  rig), `cameras` (shared view/projection matrices), `mesh_gen`, `piece_look`, `audio` (cue queue),
  `theme` (**all colours and lighting: restyle here**), `palette`.
- `ui/`: pure layouts (`hud_layout`, `panel_layout`, `select_layout`, `sheets` content), `models`
  (layouts published to GUI scripts), GUI scripts (`hud`, `panel`, `select`).
- `render/game.render_script`: background → board → tray → optional scaled-target blit → GUI.
- `levels/`: `index.lua` lists packs; each pack has `pack.lua` and level files; `showcase.lua` is the menu sculpture.

## Conventions
snake_case variables, camelCase functions, comments only where needed, Lua 5.1/LuaJIT.
GUI scripts only draw what `ui/models` publishes; input decisions happen in `main` phases.
Never commit or modify git; the user does that.

## Status (end of first session)
Done: core model, rendering, camera (ortho snaps), drag with auto-settle, HUD and rail, tray,
main menu, pause menu, tabbed settings (audio, display incl. DefOS fullscreen and render scale,
game, accessibility incl. colour-blind palettes, patterns, high contrast, UI size,
left-handed), fade transitions, saved progress, settings and in-progress boards, synthesized audio.

Next, in order:
1. Level select redesign: packs as chapters (accent colour and intro line from `pack.lua`),
   levels on a winding path, live 3D thumbnails (solved boards are saved in `boards`), ambient motion.
2. Final art style (a theme plus assets; deferred by the user to a dedicated session).
3. Content: packs 1–2 and an authoring guide. 4. Web/mobile builds and touch testing.
5. Mechanic packs (colored projections, gravity via `core/sim`, top view, glass).

Untested or known: touch gestures (twist direction), fullscreen toggle, WebGL1 `fwidth`; the
editor linter shows stale warnings (e.g. `board_view.present` arity, `.axis` field).
