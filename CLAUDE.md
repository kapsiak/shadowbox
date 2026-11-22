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
  screens (`menu_screen`, `select_screen`, `play_screen`), `sheets` (panel stack), `catalog`,
  `storage` (two alternating save slots; the newest that loads wins).
- `game/`: pure session logic: `play` (drag, settle, turn, nudge, undo), `progress`, `settings`,
  `save_data` (versioned save format: migrations, level fingerprints, validation on load).
- `core/`: pure puzzle model: `level` (ASCII parsing), `shape`, `orient` (24 rotations),
  `grid`, `channels` (per-ray monoids: light, pattern), `projection` (folds channels), `rules`, `state`, `history`, `raycast`.
- `input/`: `actions` (Defold → raw events), `router` (controls claim input), `gestures`, `interpret`.
- `view/`: `board_view` (pieces), `walls_view` (projection panels), `tray_view`, `thumbs` (live level
  thumbnails), `orbit` (camera rig), `cameras` (shared view/projection matrices), `mesh_gen`, `piece_look`, `audio` (cue queue),
  `theme` (**all colours and lighting: restyle here**), `palette`.
- `ui/`: pure layouts (`hud_layout`, `panel_layout`, `select_layout`, `sheets` content), `models`
  (layouts published to GUI scripts), GUI scripts (`hud`, `panel`, `select`).
- `render/game.render_script`: background → `gui_back` (select screen) → board (panels, cubes,
  glass multiplied over them) → tray → optional
  scaled-target blit → GUI.
- `docs/mechanics.md`: agreed design for mechanics beyond silhouettes (not built yet).
- `docs/art_direction.md`: the agreed theme (the shadow workshop); check visual, sound and UI work against it.
- `levels/`: `index.lua` lists packs; each pack has `pack.lua` and level files; `showcase.lua` is the menu sculpture.

## Conventions
snake_case variables, camelCase functions, comments only where needed, Lua 5.1/LuaJIT.
GUI scripts only draw what `ui/models` publishes; input decisions happen in `main` phases.
Never commit or modify git; the user does that.

## Status (end of second session)
Done: core model, rendering, camera (ortho snaps), drag with auto-settle, HUD and rail, tray,
main menu, pause menu, tabbed settings (audio, display incl. DefOS fullscreen and render scale,
game, accessibility incl. colour-blind palettes, patterns, high contrast, UI size,
left-handed), fade transitions, synthesized audio. Level select: chapters (banner, intro, accent
from `pack.lua`), levels in switchback rows with a dotted trail, live 3D thumbnails that grow in
and sway. Saving: versioned format, two slots, boards dropped when their level changes, autosave
(0.5 s after changes settle, at least every 5 s, at once on solve, screen change, focus loss and
quit); undo history is kept per level for the session only.

Next, in order:
1. Mechanics prototype (`docs/mechanics.md`): channel fold and glass done (`levels/glass` is a
   test pack); next, wall and glass legibility (see "Open" in `docs/mechanics.md`), then
   draw the pattern channel.
2. Art direction (`docs/art_direction.md`): the screens are done (paper, merged crisp shadows,
   pencil contours split by wanted light, hatching for unwanted shadow, wooden frame) and the
   theme is recoloured to the workshop palette. Still unchecked in play: glass light on paper,
   contour swallowing and ink on match, focus outline, floor shadow, high contrast. Next: blocks
   (lacquered wood, no seams, proper glass; tray glass reads opaque), room, interface and
   typography, sound, then chapter navigation as the sketchbook.
3. Polish audit, including an engine-feature audit (window events, profiler, platform integrations).
4. Content: real packs (`levels/towers` is a placeholder) and an authoring guide.
5. Web/mobile builds and touch testing.

Untested or known: touch gestures (twist direction), fullscreen toggle, WebGL1 `fwidth`, the
save on focus loss and quit; the four view buttons share near-identical icons; the editor linter
shows stale warnings (e.g. `board_view.present` arity, `.axis` field).
