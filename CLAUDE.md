# Third Angle

A Defold 1.13 3D puzzle game: arrange coloured polycube pieces in a grid so their shadows match the
target projections on the walls. Targets desktop, mobile and web. Read `principles.md` first; the
code follows it (pure core, deciding vs doing, explicit frame phases, data as the single truth).
The title lives only in `game.project` (`[project] title`) and is read at runtime; the mark
(the third-angle projection symbol for a block) is drawn by `tools/make_icons.py`.

## Commands
- Specs: `busted` (LuaJIT; `.busted` config). Keep specs compact, one file per area in `spec/`.
- Level preview: `luajit tools/preview.lua levels/<pack>/<level>.lua`
- Level difficulty profile: `luajit tools/solve.lua [-s] levels/<pack>/*.lua` (exhaustive solver:
  solution count, candidates per piece, pieces that must turn, hidden cubes; `-s` one line each).
- Level carving: `luajit tools/carve.lua -k 3-5 -t 600 -r <seed> sculpture.lua` cuts a drawn
  sculpture into random pieces and prints the best cuts (fewest solutions) as level files.
  `-g cyan,yellow -q 1 -m 2` makes all but one piece glass and keeps cuts with 2+ mixed wall cells.
- Regenerate icons / sounds: `python3 tools/make_icons.py`, `python3 tools/make_sounds.py`
  (then refresh `ui/hud.atlas` from `ui/icons/*.png`). New or updated fonts: run
  `tools/merge_font_overlaps.py` (needs fonttools and skia-pathops).
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
- `view/`: `board_view` (pieces), `walls_view` (projection panels), `board_pool` (boards reused
  for the whole run: runtime resources are rewritten in place, never released, since released
  ones were not freed), `tray_view`, `thumbs` (live level thumbnails, built a few per frame), `orbit` (camera rig), `cameras` (shared view/projection matrices), `mesh_gen`, `piece_look`, `audio` (cue queue),
  `theme` (**all colours and lighting: restyle here**), `palette`.
- `ui/`: pure layouts (`hud_layout`, `panel_layout`, `select_layout` (computed once per screen size;
  scroll is one offset on the GUI root), `sheets` content), `models`
  (layouts published to GUI scripts), GUI scripts (`hud`, `panel`, `select`).
- `render/game.render_script`: background → `gui_back` (select screen) → board (panels, cubes,
  glass blended over them) → tray → optional
  scaled-target blit → GUI.
- `docs/mechanics.md`: agreed design for mechanics beyond silhouettes (not built yet).
- `docs/art_direction.md`: the agreed look (geometric) and its clarity rules; check visual, sound and UI work against it.
- `levels/`: `index.lua` lists packs; each pack has `pack.lua` and level files; `showcase.lua` is the menu sculpture.

## Conventions
snake_case variables, camelCase functions, comments only where needed, Lua 5.1/LuaJIT.
GUI scripts only draw what `ui/models` publishes; input decisions happen in `main` phases.
Never commit or modify git; the user does that.

## Status (sixth session, paused before Counting & parity)
Done: core model, rendering, camera (ortho snaps), drag by contact placement, HUD and rail, tray,
main menu, pause menu, tabbed settings (audio, display incl. DefOS fullscreen and render scale,
game, accessibility incl. colour-blind palettes, patterns, high contrast, UI size,
left-handed), fade transitions, synthesized audio. Level select: chapters (banner, intro, accent
from `pack.lua`), levels in switchback rows with a dotted trail, live 3D thumbnails that grow in
and sway. Saving: versioned format, two slots, boards dropped when their level changes, autosave
(0.5 s after changes settle, at least every 5 s, at once on solve, screen change, focus loss and
quit); undo history is kept per level for the session only.

Third session (art): the look is now `geometric` (`docs/art_direction.md`); the `workshop` and
`gallery` variants were removed in the fourth session. Pieces are one seamless body with bevels
from a per-face tangent stream, glossy; glass is frosted and blended in one pass. The board is an open box (walls stand on the floor at
the floor's edge). The floor shows only soft contact under pieces unless the top view is judged (its live cast shadow was removed in the fourth session as visually odd). Wall cells ease at a
constant speed and merge with neighbours continuously. Interface: Outfit (OFL), chamfered keys on
a solid lip that sink when pressed, side-column main menu on wide screens, chapter pages on the
level select, controls sized to fit beside their labels. The panel GUI pools item nodes by slot
(it used to run out of nodes).

Fourth session (polish): named Third Angle with a wordmark; the workshop and gallery variants
and their shader, GUI and asset paths removed; settings controls restyled as chamfered keys;
distinct view icons; a dry, physical sound set; the floor's live cast shadow removed; outgoing
buttons no longer linger over screen changes (the panel's fade stays above pooled nodes).

Fifth session (content and controls): pieces start at a resting pose derived from their shape
(`shape.rest`), so turning is part of solving; the save fingerprint includes solution poses.
Placement is by contact: a dragged piece rests against the face, floor or wall under the
pointer and the preview is always legal (nearest legal pose; a turn while dragging is never
hidden); turning a placed piece searches offsets within 3 cells.

Sixth session (content and performance). Content plan: about 8 packs of
about 20 levels, difficulty measured by the solver: Basics, Windows, Towers (up to 7 tall, depth
hidden from both walls) and Overhead (front, side and top; mostly height-map plans) are done at 20
each; Basics and Windows were play-tested at 11 levels ("feels good"), the additions and Towers and
Overhead await play-test. Glass (done, 20, walls only, awaits play-test): one tint, then mixing
(cyan + yellow = green), all three secondaries, then darkness from glass alone (crossed primaries,
or all three secondaries); opaque pieces in glass levels are `slate` so colour always means glass.
Every glass cut came out unique (colour tells pieces apart). Agreed chapter structure: each mechanic
gets its own intro pack, mixed packs later, several hundred levels in all. Next packs: Counting &
parity (new channels and drawing), Patterns (needs drawing), Spares (`use_all = false`); then
mixed packs and a capstone. Lessons from carving: symmetric or hollow sculptures (rings, mirrored spires,
diagonals with x = z) give many solutions under two views; break the symmetry, and avoid
single-cube leaves (carve then finds no cuts). A third view does not rescue frames: their cubes
are forced but pieces tile the edges many ways. Height maps (no overhangs) carve well under three
views. Performance: runtime buffers and textures were never freed by the engine after
`resource.release`, so boards come from `view/board_pool` (rebound in place; wall textures fixed at
8x8); thumbnails build two per frame; the level select layout is static and scroll is one offset,
with a fling; `play.display` caches its evaluation; settled wall layers and resting pieces cost
nothing per frame. Trackpads send the wheel as a held button with repeats; each repeat is a step.

Next, in order:
1. Art polish is done for now (fourth session); motion only if play-testing asks for it.
2. Mechanics prototype (`docs/mechanics.md`): ray inspection on hover, then draw the pattern
   channel.
3. Polish audit, including an engine-feature audit (window events, profiler, platform integrations).
4. Content (in progress): next session starts Counting & parity: sum and XOR channels in
   `core/channels`, solver pruning for non-idempotent channels (its `allowed` shortcut assumes
   idempotence), wall drawing (shade or digit, odd/even mark), carve support, then intro packs.
   Then Patterns (draw the pattern channel), Spares, mixed packs, an authoring guide.
5. Web/mobile builds and touch testing.

Untested or known: the level select still feels a little laggy (after the board pool, staggered
thumbnail builds and the static layout; profile before changing more; chapter pages are the agreed
next option); touch gestures (twist direction), fullscreen toggle, WebGL1 `fwidth`, the
save on focus loss and quit, key press sinking, stacked glass (blending depends on draw order);
the editor linter shows stale warnings (e.g. `board_view.present` arity, `.axis` field).
