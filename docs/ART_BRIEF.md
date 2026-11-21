# Rack & Ruin — Art Brief for the Graphic Designer

You have never seen this game. This document explains what it is, what every
screen looks like, and exactly what to draw. Read it top to bottom.

## 1. What the game is (60 seconds)

Rack & Ruin is a single-player pool roguelite, heavily inspired by Balatro's
look and structure:

- You play one pool table at a time ("encounter").
- Each table has a contract, e.g. "Score 95 points" or "Pocket 4 balls
  without scratching".
- You aim with the mouse, set power, press FIRE. Balls resolve with simple
  2D physics.
- Winning a table gives you a choice of 1 of 3 upgrades (Cues, Chalks,
  Relics), then you pick the next stop on a branching road map.
- The run ends at the final boss, THE HOUSE, at the bottom of the map.
- Lose condition: you run out of shots before finishing the contract.

Visual target: **retro pixel, Balatro-like**. Chunky frames, thick outlines,
dithered felt, cream/gold display type, mint highlights, dark teal-brown
background. Base canvas is **1280x720**. Design on a **320x180 pixel grid
scaled 4x** (so 1 art pixel = 4 screen pixels). All outlines should be
2 art pixels (8 screen pixels) or thicker. No thin 1px lines, no gradients
smoother than 4 steps, no photorealism.

Palette (exact hex, do not invent new hues without asking):

- Background deep teal-black `#101820`, panel `#1D3038`, panel alt `#29424A`
- Frame brown-grey `#26343B`, dark frame `#172229`
- Gold `#F2BD58` (headers, power, reachable map), mint `#8FE1BD`
  (scores, streaks, confirmations), muted blue-grey `#8CA5AD` (help text)
- Danger red `#EF6B64`, ink `#091116`, cream `#F4EAD5`

## 2. Is the playfield too big? (your question, answered)

Yes, right now the green rectangle dominates because it is flat color with
thin rails. Do NOT shrink the simulation. Instead, make it *feel* smaller
with art:

- TABLE area in code is `Rect2(370, 148, 850, 398)` on the 1280x720 canvas.
  Keep those numbers. Your art wraps around them.
- Draw a thick wooden rail **outside** the green: 24 screen px (6 art px)
  of wood on all four sides, with corner caps. This visually contains the
  table the way Balatro contains the card table.
- Pockets sit ON the rail corners/edges (6 total: 4 corners + 2 side
  middles). Draw them as dark holes overlapping the wood, diameter
  ~66 screen px. The wood between pockets is what makes the table feel
  smaller and chunkier.
- Felt gets a pixel dither (2 greens alternating) + dark vignette at the
  edges, so the middle reads as the active zone.

If after that it still feels massive, we will shrink ball radius and pocket
capture together in code. That is a code task, not an art task.

## 3. Balls: plain base first, numbers second (your request)

You asked for plain balls with numbers added afterwards. We will do exactly
that as **two separate layers**:

**Layer A — base ball (you draw this):**
One 36x36 screen px sprite (9x9 art px) per ball *type*, NO number, NO text:

| Type | Color | Marking (shape only, no numbers) |
|---|---|---|
| cue | cream `#F0F0EA` | tiny dot top-left highlight |
| standard | team colors (red/blue/yellow/purple/green) | white shine dot |
| heavy | darker orange/brown | thick dark ring inside edge |
| light | pale version of team color | thin broken ring |
| anchor | danger red `#E85B4F` | bracket arcs (we draw a red orbit ring in code until you deliver) |
| prism/wild | teal/purple | small diamond pip |

Keep every base perfectly circular and centered. Same silhouette for all.
Only color + ring/pip differs, so colorblind players still get shape cues.

**Layer B — number (code draws this on top):**
The game draws the ball's value (e.g. 15, 20, 25, 30) in pixel font,
centered, cream with 2px ink outline, on top of your base. You do NOT bake
numbers into the sprite. Deliver one test sheet showing each base with
"20" overlaid so we can check contrast. If a base color is too light for
cream text, tell us and we will switch that type to ink text.

Sizes: base 36px diameter on screen. Number cap-height ~14px. Outline 2px.

## 4. Priority 1 assets, each explained (the old "part 4")

These are the in-table sprites. "Priority 1" just means: without these the
game looks like programmer geometry.

1. **Felt tile** — 32x32 screen px tilable dither (two greens). Covers the
   850x398 green rect. Plus a separate vignette overlay (dark edges,
   transparent middle), same size as the table.
2. **Wood rail set** — 4 straight pieces + 4 corner caps, 24px thick. Dark
   wood `#9A6A38` shadow side + lighter top edge. Corners must have room
   for a pocket hole on top.
3. **Pocket holes** — 2 variants: corner (round, 66px) and side (slightly
   oval, 60px). Near-black center `#050A0D`, gold rim `#BD8740` 3px.
   Corner and side must be distinguishable at a glance because the SIDE
   ACTION relic pays +12 only in side pockets.
4. **Aim kit (this was the confusing one — full breakdown):**
   - *Dotted cue line:* 8px dash, 6px gap, cream, 3px thick. Shows where
     the cue ball will travel. Length = power (short = soft, long = hard).
   - *Gold bounce rings:* when the predicted line hits a rail, draw a gold
     ring (7px dot + 12px halo) + tiny label "BOUNCE 1/2/3". Max 3 bounces.
     This is the Angry-Birds part: the player sees the zig-zag before
     firing.
   - *Green CONTACT ring + ghost arrow:* when the line will hit a ball
     first, draw a mint ring around that ball + short arrow showing which
     way that ball will be knocked + "CONTACT" label. This is the most
     important aiming feedback.
   - *Cue-stick pullback:* short brown stick behind the cue ball pointing
     away from aim. Longer = more power. Tip stripe shows english
     (red = left, mint = right). You draw the stick; code positions it.
5. **The House's Spot:** one brass compass ring on the felt, 34px radius:
   3px gold rim, four ticks at the compass points, a small diamond centre mark
   and a 9px `SPOT` chip nearby. It must read as a painted position target,
   not a ball, pocket, zone or UI warning; draw it under the balls and let the
   cue ball cover it when parked.
6. **Zones ("what are zones?"):** colored transparent rectangles ON the
   felt that change physics. Four kinds, each needs a fill + 2px border +
   small-caps label in the top-left of the rect:
   - ICE (blue `#52BFF2` 25%): balls glide farther.
   - MUD (amber `#B87333` 22%): balls slow down fast.
   - ELASTIC (teal `#2E9EBF` 24%): balls speed up slightly.
   - DRIFT (violet `#8556C7` 16%): balls get pushed right.
   Draw them as translucent pixel cross-hatch, not flat alpha, so they read
   as retro.
7. **Barriers:** solid dark-red blocks (`#5B2024` fill, `#EE6B4F` 3px
   edge) that balls bounce off. Pixel wood/metal rivets at corners.

## 5. The map ("explain the map")

The map (screen name "THE TOUR") is a vertical road from top to bottom.
12 nodes in 5 rows. The player starts at the top node and picks ONE
connected node per step. Unpicked branches are skipped forever. Every road
ends at THE HOUSE at the bottom.

Rows:
- Row 1: 1 start table (The Gatehouse).
- Row 2: shop (Chalk Market) | table (Frozen Lane) | event (Back Room).
- Row 3: elite (Locksmith's Run) | table (Long Rail) | shop (Feltworks) | elite (The Trap).
- Row 4: event (Lucky Break) | shop (Last Call).
- Row 5: boss (The Locksmith) then final boss (The House).

Node icons (5 types x 3 states = 15 sprites, 38px circles):
- ● TABLE (gold dot), ◆ SHOP (diamond), ? EVENT (question), ▲ ELITE
  (triangle), ◈ BOSS (double diamond).
- States: reachable (gold glow + pulse), locked (grey), done (mint check).
Lines between nodes: reachable = gold 2px over thick translucent underlay;
locked = thin grey.

## 6. Every screen, described (Priority 2, fully expanded)

"Title hero" and "BUILD YOUR LINE treatment" explained below in context.

1. **Title (RACK & RUIN):** full-screen. Left: giant cream headline —
   that headline style IS the "title hero": 42pt pixel display font, cream
   `#F4EAD5`, with the words "BUILD YOUR LINE." as the tagline underneath
   in 20pt. ("Treatment" means: cream color, hard shadow 2px down-right in
   ink, tight line spacing — use this same treatment for all screen
   headlines.) Right: "STARTING LOADOUT" card listing House Cue +
   Banker's Chalk + stake/rep/best. Buttons: START NEW RUN, PRACTICE,
   COLLECTION, SETTINGS, HOW TO PLAY, STAKE. Bottom: one-line controls.
   You deliver: background felt-table illustration (dark, blurred), button
   theme (normal/hover/pressed/disabled/focus), headline font setup.
2. **How to Play:** one big card with 6 numbered steps. Needs number
   medallions 1-6 (gold circles, ink numerals).
3. **Map (THE TOUR):** header (title + cash + run/score), map-key line,
   region banner ("REGION 1 // THE FELT DISTRICT"), instruction line,
   12 node buttons, bottom route + build strip. Needs node icons, route
   lines, region banner plate.
4. **Encounter (the pool table):** header (table name + contract +
   shot/left/fouls/streak). Left: TABLE BRIEF card (hint text, contract %
   bar, last-result line, english readout, build strip). Center: the table
   itself. Bottom: SHOT CONTROLS dock (power bar 340px, −/+ buttons,
   ENG−/ENG+ buttons, big FIRE SHOT primary, MAP secondary, control hint
   line). FIRE must be the biggest, gold, unmissable.
5. **Reward Room:** headline (table name + score), 3 cards (type + tier,
   name, description, TAKE THIS button). Card size 330x235.
6. **Shop (Chalk Market):** cash headline, 3 cards (type, name, body,
   price, BUY button, disabled state when broke), REROLL button, LEAVE.
7. **Event (Back Room):** flavor headline + 3 cards (title, body, CHOOSE).
8. **Boss intro:** boss name huge in red 40pt, SIGNATURE RULE card (rule
   24pt cream, hint 15pt, phase line 13pt muted), ENTER BOSS TABLE +
   RETURN TO MAP.
9. **Victory/Defeat summary:** big result headline (gold "A CLEAN BREAK"
   or red "THE HOUSE WINS"), 4-5 stat lines centered, route line, 2-3
   buttons.
10. **Collection (Run Build):** ACTIVE BUILD cards (3), ROUTE LOG card,
    ACQUIRED THIS RUN card, cash/tables/score strip, codex line
    ("CODEX x/8"). Needs card dividers and empty-state illustration.
11. **Settings:** ACCESSIBILITY card (6 toggle buttons + explanations) and
    CONTROLS card (reference text). Toggle ON/OFF must read as pixel
    switch, not just text.

## 7. High contrast mode (do we need it? Yes)

Yes. It is an accessibility setting in the game, and portals (especially
Coolmath, which serves schools) care about readability. When ON, the game
forces all body text to pure white and strengthens borders. Your job: test
every card at both settings. Muted `#8CA5AD` text becomes white — make sure
card backgrounds are dark enough for white to pass contrast on all 11
screens. Deliver a contrast checklist screenshot set (each screen, both
modes). No extra art, just verification.

## 8. Delivery specs

- 1280x720 canvas, 16:9. Design pixel grid 320x180 @4x. Sprites as PNG,
  1x + 2x, plus source (Aseprite preferred).
- Keep all text OUT of sprites (code renders text for localization).
- Typography: the shipped display/headline face is **Bebas Neue** (SIL OFL,
  `assets/fonts/`), used in caps for titles, card names and big readouts.
  Body copy stays in the engine sans at 10–13px. Do not bake type into art.
- Safe area: 32px margins, top 104px header reserved on every screen.
- Name files by screen + element: `table/felt_tile.png`,
  `table/rail_h.png`, `balls/base_heavy.png`, `ui/btn_primary.png`,
  `map/node_elite_reachable.png`, etc.
- First delivery: felt, rails, pockets, 6 ball bases, aim kit. Second:
  map icons + buttons. Third: screen banners + empty states.

## 9. Checklist

- [ ] Felt tile + vignette + wood rails + corner caps
- [ ] Corner + side pocket variants
- [ ] 6 plain ball bases (no numbers) + contrast test with overlaid values
- [ ] Aim kit: dash, bounce ring, CONTACT ring, ghost arrow, cue stick
- [ ] 4 zone cross-hatches + labels + barrier block
- [ ] 15 map node sprites + route lines
- [ ] Button theme (5 states incl. focus) + panel frames + headline font
- [ ] Title background + boss banners + how-to medallions
- [ ] High-contrast screenshot pass, all screens
