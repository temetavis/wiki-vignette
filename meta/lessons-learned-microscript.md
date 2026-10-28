# Lessons Learned: microScript 2.0 for Coding Agents

Practical, verified findings for agents writing or reviewing microScript 2.0 code for
[microStudio](https://microstudio.dev). Everything below was confirmed during the
construction of this repo's game — either by reading the microStudio open-source
runtime (parser/compiler/VM) or by executing real project code headlessly against it.

**Scope:** microScript 2.0 (`microscript_v2`) with the basic 2D graphics API — the
default for new microStudio projects. This does **not** cover microScript 1.0
(interpreted/transpiled), Python, Lua, or JavaScript project types.

---

## 1. Syntax rules that trip up agents (all verified against the real parser)

### 1.1 There are NO arrow functions

```microscript
// WRONG - will not parse ("Expression expected")
init = ->
update = ->

// RIGHT - the only function syntax
init = function()
  // body
end

update = function()
  // body
end
```

The tokenizer emits `-` and `>` as two separate tokens (`MINUS` then `GREATER`);
there is no arrow token and no post-processing that combines them. Every official
tutorial and every live `microscript_v2` public project surveyed uses
`function() ... end`. If your training data contains `f = ->` examples for
microScript, that syntax does not exist in the shipped engine.

### 1.2 No single-line object literals with `key: value`

```microscript
// WRONG - "Syntax Error" (parser expects `identifier = value` inside object)
slot = object index: 1, ch: "a"
dust.push(object x: 1, y: 2)

// RIGHT - multi-line object with `=` assignments, closed by `end`
slot = object
  index = 1
  ch = "a"
end

// Also RIGHT - inside a function body:
dust.push(object
  x = 1
  y = 2
end)
```

### 1.3 `else if` does not exist — use `elsif`

```microscript
// WRONG - "Unterminated 'if'; no matching 'end' found"
if a then
  x = 1
else if b then   // the parser treats this as a new unterminated if
  x = 2
end

// RIGHT
if a then
  x = 1
elsif b then
  x = 2
else
  x = 3
end
```

### 1.4 Every block closes with `end` — including `object`

Functions, `if/elsif/else`, `for`, `while`, `object`, and `class` all require a
terminating `end`. The parser reports unterminated blocks with decent line/column
info: read `parser.error_info = {error, line, column}` after `parse()`.

### 1.5 No list comprehensions

```microscript
// WRONG
sparks = [s for s in sparks when s.life > 0]

// RIGHT - explicit loop
keep = []
for s in sparks
  if s.life > 0 then
    keep.push(s)
  end
end
sparks = keep
```

### 1.6 Valid and handy syntax (confirmed working)

```microscript
for i = 0 to text.length-1          // numeric for, bounds evaluated once
for item in list                     // for-in over arrays
if cond then statement end          // single-line if (needs `then` AND `end`)
if keyboard.LEFT then ax = ax-1 end // one-liners are fine inline
x = max(-84, min(84, x))            // min/max/sin/sqrt/abs/PI are globals
ch = "abc"[0]                       // string indexing works
"text".length                        // property access on string literal in for-bound works
a != b                               // inequality
n % 2                               // modulo
```

Note: `for i = 0 to text.length-1` parses fine, but prefer computing the bound into a
local first for readability — the engine evaluates bounds once, not per iteration.

### 1.7 Globals and assignment

Top-level variables (`G`, `beetle`, `slots`, etc.) are VM globals. Functions assigned
at top level become `Routine` objects on the VM global — callable from JS via
`processor.routineAsFunction(routine, context)(...args)` (see verification harness
notes in section 4). `local x = ...` inside a function creates a function-scoped local.

Assigning to API names (`screen`, `keyboard`, `mouse`, `random`, `print`, ...) at top
level produces a parser **warning** (`assigning_api_variable`) — visible in the editor.
Avoid it.

---

## 2. Runtime / API facts

### 2.1 Screen coordinate system

- **Center origin, y-up**: `(0,0)` is screen center; up is positive y.
- Default logical size is roughly 200x200 units, but use `screen.width` /
  `screen.height` — actual logical size depends on window aspect ratio and the
  project's aspect setting.
- Mouse/touch coordinates are already in this logical space (`mouse.x`, `mouse.y`,
  centered, y-up).

### 2.2 Drawing functions — color is the LAST argument

The signature list from the runtime (`static/js/runtime/screen.coffee` in the
[microStudio repo](https://github.com/pmgl/microstudio)):

```microscript
screen.fillRect(x, y, w, h, color)          // rect centered on (x,y)
screen.fillRound(x, y, w, h, color)         // ellipse centered on (x,y)
screen.fillRect(...)                        // centered, NOT top-left!
screen.drawRect(x, y, w, h, color)          // outline rect, centered
screen.drawLine(x1, y1, x2, y2, color)
screen.drawText(text, x, y, size, color)    // centered on (x,y), baseline middle
screen.drawTextOutline(text, x, y, size, color)
screen.textWidth(text, size)
screen.setAlpha(a)                          // 0..1; affects subsequent draws
screen.setLineWidth(w)
screen.drawSprite(sprite, x, y, w, h)       // w,h = sprite display size
screen.drawSpritePart(sprite, sx, sy, sw, sh, x, y, w, h)
screen.drawMap(map, x, y, w, h)
screen.clear(color)
screen.setColor(color)
screen.setLinearGradient(x1, y1, x2, y2, c1, c2)
screen.setRadialGradient(x, y, radius, c1, c2)
screen.setFont(font)
screen.setTranslation / setScale / setRotation / setDrawAnchor ...
```

Common agent mistakes to avoid:

- **`setFillColor` / `setStrokeColor` do not exist.** Use per-call `color` arguments
  or `screen.setColor`.
- **There is no `fillCircle`.** Use `fillRound` (an ellipse) or `fillArc`.
- **Rect drawing is CENTER-anchored**, not top-left. `fillRect(0, 0, w, h, c)` fills a
  rect centered on the screen center — perfect for full-screen washes.
- **`drawText` has no font-name parameter.** Fonts are selected via
  `screen.setFont(name)` after loading with `screen.loadFont(name)`. The fifth
  argument to `drawText` is the color.
- Colors: hex `"#rrggbb"`, `"rgb(r,g,b)"`, `"rgba(r,g,b,a)"`, and 3-digit
  base-10 numbers (`750` ≈ brown) all work. Named CSS colors generally work too
  (passed straight to canvas), but prefer hex.

### 2.3 Inputs

```microscript
// Keyboard: physical-key codes plus convenience directionals.
// "A" key reports as keyboard.A (event.key uppercased) AND keyboard.KEY_A (event.code)
keyboard.SPACE, keyboard.ENTER, keyboard.A, keyboard.KEY_A
keyboard.LEFT / RIGHT / UP / DOWN   // WASD or arrows, both feed these (see below)

// Edge events (reset each frame by the runtime):
keyboard.press.X    // 1 only on the frame the key went down
keyboard.release.X  // 1 only on the frame the key went up

// Mouse (all in logical screen coords):
mouse.x, mouse.y
mouse.pressed       // 1 while any button held; also mouse.left / middle / right
mouse.press         // 1 only on the frame of press (analogous to keyboard.press)

// Touch / unified pointer:
touch.touching      // 1 while touching screen; touch.press for the edge event
touch.x, touch.y    // last touch position
```

The runtime synthesizes `keyboard.UP/DOWN/LEFT/RIGHT` from both WASD and arrow keys
(`updateDirectional()` in `keyboard.coffee`), so checking `keyboard.LEFT` etc. covers
both. `mouse.pressed` is also set to 1 during touch input, so
"`mouse.pressed or touch.touching`" is the idiomatic "primary action held" check.

### 2.4 The lifecycle functions

```microscript
init = function()     // once at start (and whenever you call it manually to reset)
update = function()   // fixed 60 Hz
draw = function()     // every rendered frame
```

Re-calling `init()` by hand is the idiomatic reset/restart mechanism (the official
game tutorial does exactly this). Make sure `init` resets every piece of state it owns.

### 2.5 Math and random

`sin`, `cos`, `abs`, `min`, `max`, `sqrt`, `floor`, `ceil`, `round`, `pow`, `atan2`,
`PI` are all **global functions/objects** — no `Math.` prefix (there is no `Math`
object in the VM). `random.next()` returns `[0,1)`; `random.nextInt(n)` returns an
integer in `[0,n)`. `random` is a seeded PRNG reset per run.

### 2.6 Threads, `after`/`every`/`sleep`

microScript 2.0 has cooperative threads: `after 2s ->`-style syntax exists as
`after 2 do ... end` / `every 2 do ... end` (with `sleep`), spawning secondary
threads the runner time-slices. For a vignette game, frame-counting in `update` is
simpler and more deterministic — prefer it unless you truly need timers.

---

## 3. Project structure & delivery conventions

### 3.1 File layout

A microStudio project stores sources under `ms/` (code), plus `sprites/`, `maps/`,
`sounds/`, `music/`, `assets/`. When mirroring a project in a plain git repo:

```
src/ms/main.ms        // the code (or several .ms files; entry points are init/update/draw)
```

Multiple `.ms` files are supported (e.g. `0_main.ms`, `1_player.ms` in real projects)
and are concatenated into one global scope — order matters for top-level
initialization but not for function definitions.

### 3.2 Onboarding a human artist later

If art is provisional (procedural draw calls), keep ALL of it in clearly labeled
blocks inside `draw()` (e.g. one `// ---------- the beetle ----------` section), with
zero art constants referenced from `update()`. Swapping in real sprites then means
only editing those blocks into `screen.drawSprite("name", x, y, w, h)` calls plus
adding sprites in the editor. See this repo's `main.ms` for the pattern.

---

## 4. Verifying microScript headlessly (the big one)

**You can fully test microScript outside the browser.** The engine is plain
CoffeeScript-compiled JS in the microStudio repo
(`static/js/languages/microscript/v2/`). Recipe used for this repo:

1. Fetch from the [microStudio repo](https://github.com/pmgl/microstudio):
   `v2/{token,tokenizer,parser,program,routine,compiler,processor,runner,transpiler}.js`
   plus `../random.js` (the `Random` class lives in the v1 folder).
2. Load them into a Node `vm` context (they attach `this.Parser`, `this.Token`, etc.
   to the context global).
3. Build a mock environment:

   ```js
   const screen = { width: 200, height: 200,
     fillRect: (...a) => {...}, fillRound: ..., drawRect: ...,
     drawText: ..., drawLine: ..., setAlpha: ... };
   const keyboard = { press: {}, release: {} };
   const globalObj = { screen, keyboard, mouse: {x:0,y:0,pressed:0},
     touch: {touching:0}, system: {preemptive: 1, fps: 60},
     sin: Math.sin, cos: Math.cos, abs: Math.abs, min: Math.min, max: Math.max,
     sqrt: Math.sqrt, PI: Math.PI, print: ()=>{} };
   const microvm = { context: { global: globalObj, meta: { print: ()=>{} } } };
   ```

4. Run and drive:

   ```js
   const runner = new Runner(microvm);
   runner.run(source, "main.ms");        // top-level statements
   // IMPORTANT: runner.call(name) only QUEUES a call; execution happens in tick()
   const tick = () => runner.tick();
   const step = () => { runner.call("update"); tick(); runner.call("draw"); tick(); };

   runner.call("init"); tick();         // init runs
   // Call non-lifecycle Routine globals directly:
   const f = runner.main_thread.processor.routineAsFunction(globalObj.myFunc, microvm.context);
   const result = f(...args);
   ```

5. What this catches: **every** class of error in sections 1–2 — syntax errors (with
   line/column), wrong argument counts/undefined args to drawing functions (have the
   mock screen throw on `undefined`), logic bugs (assert on VM globals like
   `globalObj.G.scene` between steps), and full playthroughs (simulate input by
   mutating the mock `keyboard`/`mouse`/`touch` objects).
6. Bonus — render frames for visual inspection: record the draw-call log per frame
   from the mock screen and replay it with any rasterizer (Pillow was used here).
   Remember y-up/center-origin when replaying.

Gotchas discovered while building this harness:

- `runner.call("init")` / `call("update")` only enqueue `"init()"` on the main
  thread; **you must call `runner.tick()` afterwards** or nothing executes (this is
  not obvious from the runtime source).
- `random` must be provided; `Runner.init()` installs `new Random(0)` onto the VM
  global automatically — so seed the context with the `Random` class before `run()`.
- `system.preemptive` should be set (the runner reads it for time-slicing); plain
  `{preemptive: 1, fps: 60}` suffices for deterministic single-threaded tests.
- The v2 `Processor` file is required even though `Runner` constructs it — forgetting
  it fails with `ReferenceError: Processor is not defined` inside `Thread`.

### 4.1 Quick syntax-only check

If you only need parse validation (fast, no VM):

```js
const parser = new Parser(source, "main.ms");
parser.parse();
if (parser.error_info) { /* {error, line, column} */ }
console.log(parser.warnings);  // e.g. assigning_api_variable, assignment_as_condition
```

Do not use the **v1** parser (`static/js/languages/microscript/parser.js`) for v2
code — it rejects even `f = function() ... end` patterns differently and will
give false results.

---

## 5. Environment notes for agents

- **microstudio.dev documentation is a JS SPA** — fetching
  `microstudio.dev/documentation/...` returns the app shell, not content. The
  **tutorials are fetchable as plain Markdown** though, and are the best syntax
  reference: `https://microstudio.dev/tutorials/en/toc.md` then
  `/tutorials/en/{course}/{n}_{page}.md` (courses: `tour`, `programming`,
  `drawing`, `game`). They show canonical v2 style (`function() ... end`,
  `if ... then ... end`).
- **The definitive API list** is `static/js/runtime/screen.coffee` in the microStudio
  repo — `getInterface()` is the exact surface exposed to microScript as `screen.*`.
  `microvm.coffee` lists the exposed globals; `keyboard.coffee` documents key
  reporting (including the WASD/arrow synthesis and `press`/`release` edge events).
- **Ground truth for syntax questions:** the v2 parser source at
  `static/js/languages/microscript/v2/parser.{coffee,js}`. When in doubt, parse a
  minimal snippet with it (section 4.1) rather than guessing from Lua/JS analogy.
- **Public project sources** are readable (no auth) over the microStudio websocket:
  connect to `wss://microstudio.dev/`, send
  `{"name":"get_public_projects","request_id":1}`, then
  `{"name":"list_public_project_files","project":<numeric id>,"folder":"ms"}` and
  `{"name":"read_public_project_file","project":<id>,"file":"ms/<file>"}` — useful
  for sampling idiomatic v2 code in the wild. Filter list entries on
  `"language":"microscript_v2"`.

---

## 6. Checklist for a microScript 2.0 change

- [ ] No `->` anywhere; all functions are `function() ... end`
- [ ] Objects are multi-line `object ... end`; no `key: value` literals
- [ ] `elsif`, never `else if`
- [ ] Every `if`/`for`/`while`/`object`/`function` has its `end`
- [ ] No list comprehensions; use explicit loops
- [ ] Color is the last argument to every draw call
- [ ] No `setFillColor`/`fillCircle`/`screen.resize` (do not exist)
- [ ] Rects/text are CENTER-anchored, y-axis points up
- [ ] No `Math.` prefix; math functions and `PI` are globals
- [ ] `init` fully resets state (it doubles as restart)
- [ ] Parse-check with the v2 parser (and ideally run headless per section 4)
- [ ] Do not assign to API globals (`screen`, `mouse`, `random`, ...)
