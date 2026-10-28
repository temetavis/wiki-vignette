# The Powderpost Psalm

A small vignette game for [microStudio](https://microstudio.dev), generated from 15 random Wikipedia articles.

## The 15 articles

Fetched from the Wikipedia random API (`list=random`, namespace 0, limit 15):

1. Västerby
2. Louis Gdalman
3. Assassination of Deryan Aktert
4. Burtsev
5. Watertown High School (Tennessee)
6. Tomorrow I Become a Woman
7. Clontuskert Abbey
8. Murat Šaran
9. Bani Mubarez
10. Mariam Ouédraogo
11. 1982 AIAW slow-pitch softball tournament
12. Trogoxylon parallelipipedum
13. List of animated television series of 2026
14. Vienna, City of Song (1923 film)
15. Ride (Oysterband album)

## The premise

The two most evocative articles — **Trogoxylon parallelipipedum**, a powderpost beetle that
reduces dry oak to flour-fine dust, and **Clontuskert**, a ruined medieval abbey in the west
of Ireland — combine into the game's working premise:

> Centuries after the last monk walked out of the abbey, a powderpost beetle
> makes its home in the old oak door of the ruin. Night after night it gnaws
> a psalm into the grain — one letter at a time — while the moon tracks
> across the broken roof and the wind reads the verses back through the
> empty windows.

**Gameplay:** you pilot the beetle across the door's wooden surface (arrow keys / mouse),
galing letters from the moonlit oak (Space or click). Fill the psalm line before moonset;
each carved letter also fills your dust jar, and fine dust drifts through the scene
as ambient texture.

## Run it

1. Open [microStudio](https://microstudio.dev) and create a new blank project
   (language: microScript 2.0, graphics: basic 2D API — the defaults).
2. Copy the contents of [`src/ms/main.ms`](src/ms/main.ms) into the Code tab
   (name the source file `main.ms`).
3. Press Run. No sprite assets are required — everything is drawn procedurally.

The whole game fits in a single source file.

## Controls

- Arrow keys / WASD — crawl across the door planks
- Mouse (hold) — steer toward the pointer
- SPACE / click / touch — gnaw the next letter (be near the pale ghost marker)

Each gnawed letter bursts sawdust, which also fills the jar in the lower left.
Complete all five psalm lines to finish the vignette.

## Art note

All visuals are provisional procedural placeholders, intended to be replaced by a
human artist. Beetle and scene drawing is isolated in one section of `main.ms`
(the `draw` function's beetle block and background blocks); game logic does not
depend on how art is drawn, so art can be swapped with no logic changes — either
edit the draw calls or replace them with `screen.drawSprite` calls using sprites
created in the editor.

## Verification

The game was verified headlessly against the real microStudio 2.0 parser, compiler,
and VM (extracted from the microStudio open-source runtime):

- parses with zero errors and zero warnings
- full gameplay simulation: init → title → carve → 5 verses → end → restart,
  with 144 gnawed letters and ~240k drawing calls, all arguments well-formed
- sample frames rendered from the recorded draw-call log confirm the visuals
