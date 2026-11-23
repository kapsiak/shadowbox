# Art direction: geometric

Chosen 2026-11-22 after trying three looks side by side (the others, `workshop` and `gallery`,
were removed and remain in git history before the fourth session).
Every visual, sound and interface decision is checked against this page.

## The feel

**Geometric, satisfying, clever.**

- Geometric: a light, precise world of solid shapes. Clean lines, chamfers that echo the cubes'
  bevels, an isometric lattice behind everything.
- Satisfying: things are physical. Glossy moulded pieces, keys that sink onto their lip when
  pressed, pieces that snap, walls that respond when matched.
- Clever: restraint. Neutral surfaces, one bold accent, nothing decorative in the play space.

## Clarity rules

Colour and transparency are puzzle data, so any look must keep them legible:

1. Judged surfaces (the screens and the shadows on them) are neutral: near-white and graphite.
   Colour on a screen means only received light.
2. The surroundings stay out of the puzzle's hue range: neutral, low in saturation.
3. The board is the extreme of the frame's values: the white screens are the brightest thing.
4. Saturation belongs to puzzle content. The interface is neutral plus one accent (coral).

The workshop look broke rules 1 and 2: cream paper tinted the received light toward yellow and the
warm room shared the yellow and orange pieces' hues.

## Board

- Screens: crisp white with a graphite shadow and a light grey frame; the floor and the two walls
  meet as an open box.
- Pieces: glossy moulded plastic in saturated toy colours (`palettes.default` in `view/theme.lua`),
  rounded bevels, one body per piece. Glass: frosted, a deep version of its light's colour.

## Room

A soft mid-light grey, dimmer than the screens, with a faint isometric lattice that fades out
behind the board. Nothing in the room moves or competes with the board.

## Interface

- Keys: chamfered corners on a solid, darker lip; a pressed key sinks onto its lip. Secondary
  keys are white with ink text; the main action is a coral key with white text.
- Sheets: the same chamfered key shape, larger. Modal sheets sit on a light frosted veil.
- The tray: a flat, chamfered slab on a lip.
- Main menu: on wide screens the wordmark and keys form a left column, the turning showcase
  board stands on the right.
- Controls: tracks are chamfered bars; toggle knobs and the selected segment are small white
  keys on a lip; slider knobs are coral keys (white would vanish on the white row).
- Type: Outfit (OFL), Bold for titles and Medium for everything else, with overlapping outlines
  merged (`tools/merge_font_overlaps.py`) so distance-field glyphs have no seams.
- Wordmark: the mark, then "Third Angle" in Outfit Bold. The mark is the third-angle projection
  symbol drawn for a block: a square frustum end on (nested squares, the inner one coral) beside
  its front view (a trapezoid) on a shared centre line.
- View icons: a cube with the viewed face solid and an arrow pointing at it from the camera's
  side; the free view is a three-tone cube.

## Sound

Dry and physical, like the pieces: short plastic clicks and thumps for interface and moves,
muted plucks (felt on wood) for a matched wall and the solve, a low soft pad with sparse muted
notes for music. No ringing bells or long reverb tails; the earlier chime set felt too "chimey".

## Open

- Motion for "satisfying" if play-testing asks for it: a landing bounce, a stronger wall
  response, a staged solve. The current feel was judged good enough in the fourth session.
