# Art direction: geometric

Chosen 2026-11-22 after trying three looks side by side (all still switchable, see Variants).
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
- Pieces: glossy moulded plastic in saturated toy colours (`palettes.default` of the variant),
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
- Type: Outfit (OFL), Bold for titles and Medium for everything else.

## Variants

`[theme] variant` in `game.project` picks a look at startup; `view/theme.lua` holds the base (the
workshop) and each variant's overrides.

- `geometric`: this direction.
- `gallery`: a dark neutral room, a spotlight and pool of light on the board, lacquer tiles. Clear
  but moody and flat.
- `workshop`: the first direction (paper screens, lacquered wood, plaster wall with window
  light, paper cards, oak tray). Warm but muddy; kept for reference.

## Open

- Motion and sound for "satisfying": pieces snapping with a small bounce and click, a wall that
  responds when matched, a solve that feels earned.
- A real wordmark (the title is a working title in plain type).
- Settings controls (tracks, knobs, segments) still use the older pill shapes.
- Icons: the four view buttons share near-identical icons.
- The pool of light in `gallery` sits at a fixed screen height, wrong on the menu.
