# Art direction: the shadow workshop

Draft, chosen 2026-11-22 over "drafting room" and "gallery of light". Nothing here is built yet.
Every visual, sound and interface decision is checked against this page.

## Fiction

A puppet-maker's workshop. Blocks of lacquered wood sit on a workbench between paper screens;
light casts their shadows onto the paper, and each screen carries a pencil sketch of the shadow
the maker wants. You arrange the blocks until the shadows fill the sketches. Coloured glass
blocks tint the light that passes through them.

The levels are pages of the maker's sketchbook; a chapter is a time and place in the workshop.

## Pillars

1. **Light is the language.** Every state change shows as a change in light or shadow, not as a
   badge or colour code.
2. **Clarity before atmosphere.** Shadows on the screens are crisp and the target is always
   legible. Atmosphere (dust, glow, vignette, room) lives at the periphery and never on the
   puzzle.
3. **Handmade and quiet.** Wood, paper, graphite, brass, glass. Calm motion, soft sounds.
4. **Theme dresses surfaces, never the play space.** Walls, cells and pieces stay exact and
   stable as the camera turns; nothing themed is added to the scene that could occlude the board
   or appear and disappear with rotation. Theme lives in surfaces, periphery, motion, sound and
   interface.
5. **Colour carries content, shape carries status.** Piece and light colours are puzzle data;
   right, wrong and missing are shown by line, fill and hatching.

## Light

The light is implied and never shown: it comes from the viewer's side, which is always opposite
the walls (they flip to the far side of the board as the camera turns). Lit paper and crisp
shadow are its evidence; the projections are drawn exactly rather than simulated. A warm room
light, fixed in the world, shades the blocks themselves.

## The screens

- Paper in a thin wooden frame. Lit paper is warm and bright; shadow is a cool, crisp blue-grey
  (complementary to the lamplight, so the two never blur together).
- Target: a pencil outline of the wanted cells.
- Status by shape: a filled target loses its pencil line into the shadow; a missing cell stays
  bare paper inside its outline; unwanted shadow is hatched.
- Glass light lands on the paper as tinted light; the pencil outline shows the wanted tint as a
  coloured pencil line.
- Matching a screen inks the sketch (graphite to ink). Solving brightens the light on every screen.

## Blocks

- Pieces: lacquered wood, one solid body per piece (no visible seams between its cubes), bevelled
  edges that catch the light, mid-saturation colours with distinct lightness steps.
- Glass pieces: clear coloured glass with bright edges and fresnel, no interior seams.
- Picking up lifts the block and softens its shadow on the floor; placing settles it with a small
  wooden bounce.

## Room

Generated, no imported models: the workbench as the floor, a warm back wall with a window's light
falling across it, dust in the light at the edges of the view, a gentle vignette. Chapters change
the time of day (window light, light colour, ambient).

## Palette

Paper cream, oak and walnut, graphite ink, cool shadow blue-grey, lamplight amber. Piece colours
are lacquers that sit within that warmth. Colour-blind palettes and high contrast (white paper,
dark graphite) remain.

## Sound

Built on the synthesized set in `tools/make_sounds.py`: wooden clacks for pick and place, a paper
flutter when a screen matches, a small bell on solve, quiet room tone. Music is
sparse and acoustic (marimba, kalimba, felt piano), varying by chapter.

## Interface

Paper cards with graphite text and a lamplight-amber accent; pencil-line icons. Transitions dim
the light to warm dark and relight. Title type a warm serif, body a humanist sans.

## Chapter navigation

The level select is the sketchbook: a chapter index (the book's contents, one entry per chapter
with its time of day), then a page per chapter with the levels as sketches in the existing
switchback trail.

## Open

- Shadow art: targets that depict recognisable figures (a bird, a house) when read together.
- Typefaces (both open-licensed): to choose.
