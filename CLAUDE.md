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
- Input bindings: `luajit tools/make_bindings.lua` writes every bindable key in `input/controls`
  into `input/game.input_binding` (rerun after changing the key list).
- Wall digits: `python3 tools/make_digits.py` bakes `view/digits.png` (Outfit, distance field).
- Regenerate icons / sounds: `python3 tools/make_icons.py`, `python3 tools/make_sounds.py`
  (then refresh `ui/hud.atlas` from `ui/icons/*.png`). New or updated fonts: run
  `tools/merge_font_overlaps.py` (needs fonttools and skia-pathops).
- Run: the Defold editor's HTTP API (`.internal/editor.port` and `.internal/editor.token`):
  `POST /command/run`, `GET /console`, `POST /command/fetch-libraries`.
- Hot reload: `tools/hot_reload.sh` (makes the editor rescan the disk, then reloads; never compile
  in between). Modules end with `return hot(..., M)` (`core/hot`) so reloaded code reaches those
  who required them; modules keeping state in locals (`view/resources`, `view/audio`,
  `ui/models`, `render/frame`) do not, and need a restart. Values applied once (a resting piece's
  look, a bound board) show a change only when next applied.
- Automation Bridge (a debug-only dependency) on the engine port from the run response:
  `/automation-bridge/v2/screenshot`, `input/click|drag|key|wheel` (window pixels, origin top-left).
  Wait ~10 s after run before screenshots; the first frames are blank while data loads.

## Layout (dependencies point downward)
- `main/`: the outer loop (`main.script`, phase order and screen contract documented at the top),
  screens (`menu_screen`, `select_screen`, `play_screen`), `sheets` (panel stack), `catalog`,
  `storage` (two alternating save slots; the newest that loads wins).
- `game/`: pure session logic: `play` (drag, settle, turn, nudge, undo), `progress` (solved
  levels, rule cards seen), `lessons` (which rule cards a level uses), `settings`,
  `save_data` (versioned save format: migrations, level fingerprints, validation on load).
- `core/`: pure puzzle model: `level` (ASCII parsing), `shape`, `orient` (24 rotations),
  `grid`, `channels` (per-ray monoids: light, pattern), `projection` (folds channels), `rules`, `state`, `history`, `raycast`.
- `input/`: `controls` (every keyboard action, its label, HUD button and default keys; the
  bindable keys; rebinding), `actions` (Defold → raw events; keys through the player's keymap),
  `router` (controls claim input), `gestures`, `interpret`.
- `view/`: `board_view` (pieces), `walls_view` (projection panels), `board_pool` (boards reused
  for the whole run: runtime resources are rewritten in place, never released, since released
  ones were not freed), `tray_view`, `thumbs` (live level thumbnails, built a few per frame), `orbit` (camera rig), `cameras` (shared view/projection matrices), `mesh_gen`, `piece_look`, `audio` (cue queue),
  `theme` (**all colours and lighting: restyle here**), `palette`.
- `ui/`: pure layouts (`hud_layout`, `panel_layout`, `select_layout` (one chapter per page,
  computed once per screen size and chapter; scroll and the sideways slide are offsets on the GUI
  roots, nodes pooled by slot), `sheets` content), `models`
  (layouts published to GUI scripts), GUI scripts (`hud`, `panel`, `select`).
- `render/game.render_script`: background → `gui_back` (select screen) → board (panels, cubes,
  glass blended over them) → tray → optional
  scaled-target blit → GUI.
- `docs/mechanics.md`: agreed design for mechanics beyond silhouettes (not built yet).
- `docs/art_direction.md`: the agreed look (geometric) and its clarity rules; check visual, sound and UI work against it.
- `levels/`: `index.lua` lists packs; each pack has `pack.lua` and level files; `showcase.lua` is
  the menu sculpture; `rules/<id>.lua` are the rule cards (title, text, optional `touch` text,
  and a tiny level as the card's scene), one per id in `game/lessons`.
- Rule cards: a level's unseen cards open as modal sheets on entry; the Rules list (main menu,
  pause, HUD "?") reopens any card seen. `view/card_scene` draws the card's level far below the
  board with its own camera into the card's viewport, after the GUI.
- Walls: a level may set `walls = { front = "count", side = "parity" }` (default `light`); the
  operator replaces light on that wall (`core/channels`: count sums cubes, parity XORs them).

## Conventions
snake_case variables, camelCase functions, comments only where needed, Lua 5.1/LuaJIT.
GUI scripts only draw what `ui/models` publishes; input decisions happen in `main` phases.
Never commit or modify git; the user does that.
Budgets: check resource use against engine limits whenever content or UI grows. Known limits:
font batches 128 (text nodes batch only when adjacent in draw order, so GUIs put text on their
own layers, as `ui/select.gui` does), GUI `max_nodes` (select 512, about 300 used: one chapter
plus a dot per pack; hud and panel 256), `max_count` 512
game objects, wall textures 8x8, runtime resources never freed (reuse through pools).

## Status (eighth session)
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

Seventh session (mechanics, teaching, controls). Per-wall operators: count walls (digits from a
baked Outfit atlas, up to 99, so sum walls with numbered pieces stay possible) and parity walls
(dashed frame, a ring where an even, non-zero number of cubes cancel); hatching marks any wrong
covered cell. The solver counts cubes per ray, caps count rays and checks rays no remaining
piece can reach; all 100 earlier levels profile as before. Parity is loose (Step 18 solutions,
Bridge 44 under two views) and slow on tall towers (six did not finish in 20 s); count is tight
(nearly every basics/towers drawing turns unique). Teaching (agreed design in memory
`teaching-design`): rule cards with live scenes, shown on first use and kept in a Rules list;
saves upgraded to version 2 (seen cards follow solved levels). Controls: `input/controls` table,
rebindable keys (Settings > Keys, saved as changes only), hover tooltips on HUD buttons, the
Playing card worded for touch or desktop. Hot reload works for outside edits (`tools/hot_reload.sh`,
`core/hot`). Tray pieces are sized by their bounding sphere (they overflowed the tray).

Eighth session: three packs after Glass, each level checked to have fewer solutions than the
same drawing with plain shadows (so its rule matters). Counting (20): 1-8 count on the front only,
9-20 on both walls, counts at most 3. Parity (20, accent rose): 1-2 two views, then a shadow
floor is added (two parity walls alone stay loose), parity on the front, then on both walls.
Ledger (20, accent sage): harder counting, numbers to 4, up to six pieces, a counting floor in
the last five. `tools/solve.lua` reports count load (largest number, share of cells showing 2+);
`tools/solver.lua` can keep found solutions. Level select: chapter pages (arrows, swipe,
left/right keys, a dot per chapter under the title), opening on the last played level's
chapter; the select's text batches by layer. Settings > Game: Open all levels.
Next: play-test the three packs.

Next, in order:
1. Patterns (draw the pattern channel), Spares, mixed packs (colour + count walls, sum walls),
   an authoring guide (carve, solve, the "rule matters" check).
2. Polish audit, including an engine-feature audit (window events, profiler, platform integrations).
3. Web/mobile builds and touch testing.
Deferred until play-testing of glass, count and parity asks for it: ray inspection
(`docs/mechanics.md`; pick a wall cell, light its ray's cubes, label the fold) and the wall
mark that opens a wall's rule card.
Art polish is done for now; motion only if play-testing asks for it.

To judge in play: count/parity wall readability (too many vs too few look alike; is parity's
ring enough), tooltips, keycap contrast and which cap is which in pairs, the first-time card
flow and the HUD "?" key (the user's save has seen every card), the Keys tab on mobile web
(HTML5 always counts as having a keyboard).

Untested or known: the level select's lag (chapter pages now build at most one chapter's thumbnails; judge again); touch gestures (twist direction), fullscreen toggle, WebGL1 `fwidth`, the
save on focus loss and quit, key press sinking, stacked glass (blending depends on draw order);
the editor linter shows stale warnings (e.g. `board_view.present` arity, `.axis` field).
