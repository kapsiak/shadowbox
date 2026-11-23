# Mechanics

Design decisions for puzzle mechanics beyond silhouettes. Agreed 2026-11-22. Built: the channel
fold (`core/channels`, `core/projection`) with light and pattern; glass pieces (multiplying
filters) and coloured light on walls; per-wall operators (2026-11-23): count walls (digits) and
parity walls (dashed frame, a ring where cubes cancel), each replacing light on its wall. Not
drawn yet: the pattern channel, coloured floor shadows. Open: sum walls (pieces carrying
numbers) and several operators on one wall, for mixed and late packs.

## Model: a wall folds along each ray

- Every piece has properties (colour, pattern, number, ...). Properties belong to the **piece**,
  never to single cubes: a multi-property piece is too hard to read.
- Every wall cell is a ray through the grid. The wall shows the values of the cubes on that ray,
  combined by the wall's **operator**: a fold with an identity (an empty cell contributes the identity).
- A mechanic is a **channel**: a pair *(value domain, operator)*. Channels compose as a strict
  product: each folds on its own and never reads another, so a cell holds one value per channel
  (e.g. light = red, pattern = grid) and only the view composes how that record looks.
- A level's channels follow from its pieces: light always, others once a piece sets them.
- Targets stay derived from the level's solution. Authoring does not change; only the meaning of
  "project" does. A silhouette is the light channel with only opaque pieces: white light, blocked by any cube.

| Mechanic          | Values      | Operator        | Wall shows                       |
|-------------------|-------------|-----------------|----------------------------------|
| Silhouette        | light (opaque = 0) | AND      | lit or dark                      |
| Glass mixing      | light (RGB bits) | AND (filtering) | light through stacked glass  |
| Patterns          | stripe bits | OR              | horizontal + vertical = grid     |
| Density           | count       | sum             | shade or digit                   |
| Parity            | present     | XOR             | pairs cancel                     |
| Clock arithmetic  | digits      | sum mod n       | digit (possible later, not planned) |
| Nearest colour    | colour      | first on ray    | order-dependent; see Direction   |

Opaque pieces are an absorbing element (darkness, wherever on the ray they sit), so opaque and
glass pieces mix without making order matter.

## Difficulty follows the operator's algebra

- **Idempotent** (OR, AND): redundant cubes are harmless; forgiving, for early chapters.
- **Invertible** (XOR, sums mod n): everything cancels, nothing is redundant; exact, for late chapters.
- **Mixed walls**: different operators per wall (front shows colour, side shows count) combine
  known mechanics into new puzzles cheaply.

## Direction

Each wall has a fixed light direction in the data model. Walls currently move to the far side of
the board from the camera; that is only valid for order-independent operators, so the main path
uses those (they are also the intuitive ones under a light fiction: shadows and coloured glass).
An order-dependent mechanic, if ever wanted, gets its own chapter with fixed walls and a camera
limited to the quadrant in front of them.

## Placement rules are a separate axis

Gravity, fixed blocks, obstacles and support change which placements are legal, not what walls
show. They live apart from projection (`core/sim`) and interleave with projection mechanics.

## Accessibility

Colours are bit sets; each bit also has its own stripe orientation, so colour-blind support is
the same value drawn redundantly rather than a separate palette.

## Roadmap (strawman)

1. Silhouettes  2. Glass mixing  3. Patterns and mixed features  4. Density  5. Mixed walls
6. Parity. Placement rules (gravity, then fixed blocks) slot between these.
First prototype: generalise `core/projection` to a fold with an operator, with glass mixing as
the first new operator.

## Open: legibility of glass

The first prototype's walls were hard to read. Status of the diagnosis:
- Done: colour carries content only and status uses shape (hatching for unwanted light, the
  target contour swallowed by a matching shadow).
- Done: glass is frosted, blended in one pass in a deep version of its light's colour, with no
  interior seams and bright edges. Walls seen through glass are dimmed, not recoloured, as behind
  any piece. (Keeping glass off the panels with a stencil was tried and dropped: its colour
  became too hard to see.)
- Done: neutral screens (geometric look), so received light shows its true colour.
- Open: nothing links a wall cell to the cubes on its ray (a selected piece outlines its cast,
  the other direction is missing). Ray inspection (highlight the ray's cubes, show the fold) is
  deferred until play-testing shows players need it.
- Open: stacked glass depends on draw order on screen (the walls show the true mix).

Teaching: one filter per ray before mixing.

The pattern channel is folded and judged in core but not drawn; no level may use it until it is.
