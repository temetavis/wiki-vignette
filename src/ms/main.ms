// ============================================================
//  THE POWDERPOST PSALM
//  A vignette game for microStudio, written in microScript.
//
//  Working premise, combined from 15 random Wikipedia articles
//  (the two anchors being "Trogoxylon parallelipipedum", a
//  powderpost beetle, and "Clontuskert", a ruined abbey):
//
//  Centuries after the last monk walked out, a powderpost
//  beetle makes its home in the old oak door of the abbey
//  ruin. Night after night it gnaws a psalm into the grain
//  - one letter at a time - while the moon tracks across
//  the broken roof and dust drifts through the empty windows.
//
//  Controls:
//    Arrows / WASD or mouse - crawl over the door planks
//    SPACE / click / touch - gnaw the next letter of the psalm
//
//  Sprites: this build draws everything procedurally, so it
//  runs with no sprite assets. All beetle/scene drawing is
//  isolated in one section, to be swapped for real sprites
//  by a human artist later (no game-logic changes needed).
// ============================================================

// ---------- palette ----------
SKY_DEEP = "#241b2e"
SKY_MID = "#332540"
RUIN = "#4a3650"
RUIN_DARK = "#2a1f35"
MOON = "#c7c2d4"
STONE = "#8c859b"
OAK_DEEP = "#3a2716"
OAK_MID = "#5c3f26"
OAK_LIGHT = "#7a5634"
GRAIN = "#31210f"
DUST_WARM = "#d9c9a3"
INK = "#c9b458"
TEXT_PALE = "#dfe4e2"
TEXT_DIM = "#8c859b"

// ---------- the psalm ----------
// Five lines carved into the door, one letter at a time.
psalm = [
  "out of the dust i am given a voice"
  "the oak remembers every hand it held"
  "let the moon read what i have written"
  "small is the beetle but wide is the night"
  "even a ruin keeps a song inside"
]

// ---------- helpers ----------

// letter slots for a psalm line: only non-space characters
letterSlots = function(lineIndex)
  text = psalm[lineIndex]
  slots = []
  for i = 0 to text.length-1
    ch = text[i]
    if ch != " " then
      slot = object
        index = i
        ch = ch
      end
      slots.push(slot)
    end
  end
  return slots
end

init = function()
  G = object
    t = 0
    frame = 0
    scene = "title"   // title | carve | verse | end
    moon = 0          // moon position across the sky, 0..1
    line = 0          // current psalm line index
    letters = 0       // letters carved on the current line
    jar = 0           // dust jar fill, 0..1
    verseTimer = 0
    gnawFlash = 0
  end

  // the beetle: a Trogoxylon parallelipipedum in miniature
  beetle = object
    x = 0
    y = -55
    vx = 0
    vy = 0
    dir = 1
    legPhase = 0
  end

  // ambient powder-post dust drifting through the ruin
  dust = []
  for i = 0 to 69
    mote = object
      x = random.next()*200-100
      y = random.next()*200-100
      vx = (random.next()-0.5)*0.1
      vy = (random.next()-0.5)*0.05
      s = 0.6+random.next()
      ph = random.next()*6.28
    end
    dust.push(mote)
  end

  // gnaw sparks, spawned when a letter is carved
  sparks = []

  // letter slots for the current line
  slots = letterSlots(0)

  // world position of slot n on the current line,
  // laid along a gentle arc across the door panel
  slotPos = function(n)
    count = slots.length
    if count > 1 then
      f = n/(count-1)
    else
      f = 0.5
    end
    return object
      x = -70+f*140
      y = -52+6*sin(f*PI)
    end
  end

  // gnaw the next letter; only when near its slot
  gnaw = function()
    if G.letters >= slots.length then return end
    pos = slotPos(G.letters)
    dx = pos.x-beetle.x
    dy = pos.y-beetle.y
    if dx*dx+dy*dy > 100 then return end
    for i = 0 to 9
      spark = object
        x = pos.x
        y = pos.y
        vx = (random.next()-0.5)*1.4
        vy = (random.next()-0.5)*1.4+0.4
        life = 1
      end
      sparks.push(spark)
    end
    G.gnawFlash = 1
    G.letters = G.letters+1
    G.jar = min(1,G.jar+0.12)
    if G.letters >= slots.length then
      G.scene = "verse"
      G.verseTimer = 0
    end
  end

  // advance to the next line, or finish the psalm
  nextLine = function()
    G.line = G.line+1
    if G.line >= psalm.length then
      G.scene = "end"
    else
      slots = letterSlots(G.line)
      G.letters = 0
      G.jar = 0
      G.scene = "carve"
    end
  end
end

// ============================================================
//  UPDATE
// ============================================================
update = function()
  G.t = G.t+1/60
  G.frame = G.frame+1
  G.moon = (G.moon+0.00035)%1
  if G.gnawFlash > 0 then G.gnawFlash = G.gnawFlash-0.05 end

  // dust drifts forever, through every scene
  for d in dust
    d.x = d.x+d.vx+0.03*sin(G.t+d.ph)
    d.y = d.y+d.vy
    if d.x < -100 then d.x = d.x+200 end
    if d.x > 100 then d.x = d.x-200 end
    if d.y < -100 then d.y = d.y+200 end
    if d.y > 100 then d.y = d.y-200 end
  end

  // sparks fall and fade
  for s in sparks
    s.x = s.x+s.vx
    s.y = s.y+s.vy
    s.vy = s.vy-0.03
    s.life = s.life-0.04
  end
  keep = []
  for s in sparks
    if s.life > 0 then keep.push(s) end
  end
  sparks = keep

  if G.scene == "title" then
    if keyboard.SPACE or keyboard.ENTER or mouse.pressed or touch.touching then
      G.scene = "carve"
    end

  elsif G.scene == "carve" then
    // ---- crawl ----
    ax = 0
    ay = 0
    if keyboard.LEFT then ax = ax-1 end
    if keyboard.RIGHT then ax = ax+1 end
    if keyboard.UP then ay = ay+1 end
    if keyboard.DOWN then ay = ay-1 end
    // mouse/touch steering toward the pointer
    if mouse.pressed or touch.touching then
      px = mouse.x
      py = mouse.y
      dx = px-beetle.x
      dy = py-beetle.y
      d2 = dx*dx+dy*dy
      if d2 > 4 then
        dist = sqrt(d2)
        ax = dx/dist
        ay = dy/dist
      end
    end
    beetle.vx = beetle.vx*0.82+ax*0.35
    beetle.vy = beetle.vy*0.82+ay*0.35
    beetle.x = beetle.x+beetle.vx
    beetle.y = beetle.y+beetle.vy
    if abs(beetle.vx) > 0.03 then
      if beetle.vx > 0 then
        beetle.dir = 1
      else
        beetle.dir = -1
      end
    end
    if ax != 0 or ay != 0 then beetle.legPhase = beetle.legPhase+0.35 end
    // keep the beetle on the door panel
    beetle.x = max(-84,min(84,beetle.x))
    beetle.y = max(-70,min(-30,beetle.y))

    // ---- gnaw ----
    if keyboard.SPACE or mouse.pressed or touch.touching then
      gnaw()
    end

  elsif G.scene == "verse" then
    // the finished line hangs in the air a moment
    G.verseTimer = G.verseTimer+1/60
    if G.verseTimer > 2 or keyboard.SPACE or mouse.pressed or touch.touching then
      nextLine()
    end

  elsif G.scene == "end" then
    if keyboard.SPACE or keyboard.ENTER or mouse.pressed or touch.touching then
      init()
    end
  end
end

// ============================================================
//  DRAW
// ============================================================
draw = function()
  // ---------- night sky ----------
  screen.fillRect(0,0,200,200,SKY_DEEP)
  screen.fillRect(0,70,200,30,SKY_MID)

  // ---------- moon, arcing over the broken roof ----------
  mx = -90+G.moon*180
  my = 88-46*sin(G.moon*PI)
  screen.fillRound(mx,my,13,13,MOON)
  screen.fillRound(mx+4,my+3,11,11,SKY_DEEP)

  // ---------- the ruined abbey (Clontuskert) ----------
  screen.fillRect(-100,-40,26,60,RUIN)         // broken gable, left
  screen.fillRect(-100,20,46,80,RUIN)
  screen.fillRect(-40,5,12,95,RUIN)            // pillar
  screen.fillRect(52,-18,14,118,RUIN)          // fragment, right
  screen.fillRect(70,12,30,88,RUIN)
  screen.fillRect(-100,88,200,12,RUIN)         // ground line
  // empty window openings, darker than the stone
  screen.fillRect(-92,-26,9,14,RUIN_DARK)
  screen.fillRect(-78,32,9,14,RUIN_DARK)
  screen.fillRect(-34,25,8,12,RUIN_DARK)
  screen.fillRect(78,28,10,14,RUIN_DARK)
  screen.fillRect(60,45,8,12,RUIN_DARK)

  // ---------- the oak door (the play surface) ----------
  screen.fillRect(-88,-76,176,130,OAK_DEEP)    // frame
  plankW = 176/6
  for i = 0 to 5
    if i%2 == 0 then
      tone = OAK_MID
    else
      tone = OAK_LIGHT
    end
    screen.fillRect(-84+i*plankW,-72,plankW-1,122,tone)
    // grain lines
    for g = 0 to 4
      gy = -66+g*24+(i*5)%11
      screen.fillRect(-83+i*plankW,gy,plankW-3,1,GRAIN)
    end
  end
  // moon glow tracking across the door
  glowX = -88+G.moon*176
  screen.setAlpha(0.10)
  screen.fillRect(glowX-16,-76,32,130,MOON)
  screen.setAlpha(1)
  // iron hinges, two
  screen.fillRect(-80,-60,12,4,RUIN_DARK)
  screen.fillRect(-80,40,12,4,RUIN_DARK)

  // ---------- carved psalm letters ----------
  for i = 0 to G.letters-1
    pos = slotPos(i)
    ch = slots[i].ch
    // carve mark in the wood
    screen.fillRound(pos.x-2,pos.y-2,4,4,"#171008")
    screen.fillRound(pos.x-1,pos.y+2.5,3,1,DUST_WARM)
    // the letter itself, faint gold
    screen.drawText(ch,pos.x,pos.y,7,INK)
  end
  // hint: the next letter to gnaw, as a pale ghost
  if G.scene == "carve" and G.letters < slots.length then
    pos = slotPos(G.letters)
    screen.setAlpha(0.4+0.3*sin(G.t*4))
    screen.fillRound(pos.x-2,pos.y-2,4,4,DUST_WARM)
    screen.setAlpha(1)
  end

  // ---------- dust motes ----------
  for d in dust
    screen.setAlpha(0.25+0.2*sin(G.t*2+d.ph))
    screen.fillRect(d.x,d.y,d.s,d.s,DUST_WARM)
  end
  screen.setAlpha(1)

  // ---------- gnaw sparks ----------
  for s in sparks
    screen.setAlpha(s.life)
    screen.fillRect(s.x,s.y,1.5,1.5,DUST_WARM)
  end
  screen.setAlpha(1)

  // ---------- the dust jar (bottom left) ----------
  screen.drawRect(-92,-84,12,16,STONE)
  if G.jar > 0 then
    h = 14*G.jar
    screen.fillRect(-91,-83+(14-h),10,h,INK)
  end

  // ---------- the beetle ----------
  // provisional procedural sprite; replace with real art later
  b = beetle
  wob = sin(b.legPhase)
  // body: two elytra
  screen.fillRound(b.x-4,b.y-3,8,6,"#20180f")
  screen.fillRect(b.x-0.5,b.y-3,1,6,OAK_DEEP)
  // head
  hx = b.x+b.dir*4
  screen.fillRound(hx-1.5,b.y-0.5,3,3,"#161009")
  // antennae
  screen.drawLine(hx+b.dir,b.y+1,hx+b.dir*3,b.y+4,"#161009")
  screen.drawLine(hx+b.dir,b.y+1,hx+b.dir*3,b.y-1,"#161009")
  // legs, wiggling when moving
  screen.fillRect(b.x-3,b.y-4,1,2+wob,"#161009")
  screen.fillRect(b.x+2,b.y-4,1,2-wob,"#161009")
  screen.fillRect(b.x-1,b.y+3,1,1.5-wob,"#161009")
  screen.fillRect(b.x+1,b.y+3,1,1.5+wob,"#161009")
  // gnaw flash at the mouth
  if G.gnawFlash > 0 then
    screen.setAlpha(G.gnawFlash)
    screen.fillRound(hx+b.dir*2-2,b.y-2,5,5,DUST_WARM)
    screen.setAlpha(1)
  end

  // ---------- vignette frame ----------
  screen.setAlpha(0.35)
  screen.fillRect(0,96,200,4,"#0a0810")
  screen.fillRect(0,-100,200,4,"#0a0810")
  screen.fillRect(-100,0,4,200,"#0a0810")
  screen.fillRect(96,0,4,200,"#0a0810")
  screen.setAlpha(1)

  // ---------- scene text ----------
  if G.scene == "title" then
    screen.setAlpha(0.92)
    screen.fillRect(0,0,200,200,SKY_DEEP)
    screen.setAlpha(1)
    screen.fillRound(40,62,16,16,MOON)
    screen.fillRound(45,65,13,13,SKY_DEEP)
    screen.drawText("THE POWDERPOST PSALM",0,20,12,TEXT_PALE)
    screen.drawText("a vignette of a beetle in a ruined abbey",0,4,6,STONE)
    screen.drawText("arrows / WASD or mouse to crawl",0,-20,6,TEXT_DIM)
    screen.drawText("SPACE or click near a letter to gnaw it",0,-30,6,TEXT_DIM)
    if sin(G.t*3) > 0 then
      screen.drawText("press SPACE to begin",0,-52,7,INK)
    end
    screen.drawText("born from 15 random wikipedia articles",0,-82,5,TEXT_DIM)

  elsif G.scene == "verse" then
    screen.setAlpha(0.8)
    screen.fillRect(0,0,200,200,SKY_DEEP)
    screen.setAlpha(1)
    screen.drawText(psalm[G.line],0,10,8,TEXT_PALE)
    screen.drawText("verse "+(G.line+1)+" of "+psalm.length,0,-4,6,INK)

  elsif G.scene == "end" then
    screen.setAlpha(0.9)
    screen.fillRect(0,0,200,200,SKY_DEEP)
    screen.setAlpha(1)
    screen.drawText("the door is full of psalms",0,24,8,TEXT_PALE)
    screen.drawText("the wind will read them back",0,12,8,INK)
    screen.drawText("SPACE to begin again",0,-10,6,TEXT_DIM)
  end
end
