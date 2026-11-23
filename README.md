# Third Angle

A 3D puzzle game: arrange coloured block pieces in a grid so their shadows match the target
projections on the walls. Built with Defold 1.13 for desktop, mobile and web.

## Playing
Drag pieces from the tray into the box; turn them with the buttons or keys. Solve a level when
every wall shows its target. Glass, count and parity walls add their own rules, introduced by
rule cards as they first appear.

## Building
- Open the project in the Defold editor and run it (Project > Build).
- Release zip: `tools/release.sh` writes `bundles/<version>/third-angle-<version>-wasm-web.zip`, ready to
  upload to itch.io as an HTML game or to serve from any static host (over HTTPS). Other Defold
  platforms can be named as arguments. The version is `[project] version` in `game.project`.
- Specs: `busted`.

`CLAUDE.md` and `principles.md` describe the code's layout and design; `docs/` holds the art
direction and mechanics notes.

## Credits
Font: Outfit (SIL Open Font License).
