# Rack & Ruin — Audio Brief for the Sound Artist

You have never seen this game. Start with section 1. Everything else will
make sense after that.

## 1. What the game sounds like (plain English)

A quiet pool hall. Wood knocks, balls click, a pocket swallows a ball with
a rattle. UI ticks. Winning a table plays a warm chime. Scratching (cue
ball falls in a pocket — the main mistake) plays an obvious fail buzz.
Bosses get a deep ominous hit. No music yet — silence between shots is
intentional, so each sound effects must carry weight.

## 2. What is a "hook"? (your question, answered)

A hook is just a named moment in the code where the game says "play a
sound now". The full list lives in one function: `scripts/main.gd::_sfx(kind)`.
You do NOT need to read code. Think of it as a cue sheet:

- Game event happens (e.g. ball hits rail) → code calls `_sfx("rail")` →
  engine plays whatever file is registered for `rail`.

Your job: deliver one or more audio files per hook name. The coder wires
filenames to hook names. If you want a new moment to have sound (e.g.
"streak builds"), propose a new hook name and we add one line of code.
Nothing else changes.

## 3. Is 7 sounds enough? No. Full cue sheet (18 deliverables)

The old 7 were placeholders. Deliver these:

**Gameplay (timing-critical, keep under 0.3s except where noted):**
1. `fire` — cue stick strikes cue ball. Woody thock + felt. 0.12s.
2. `rail` — any ball hits rail or barrier. Short knock. 0.05s. Plays OFTEN —
   keep it quiet and non-fatiguing. Provide 2 variants, round-robin.
3. `ball_click` (NEW) — ball hits ball. Sharp click. 0.05s. 2 variants.
   Currently reuses `rail`; split it so collisions and rails sound different.
4. `pocket` — target ball drops. Drop + rattle. 0.14s. Provide 3 variants.
   This is the core dopamine hit — the most important sound in the game.
5. `scratch` — cue ball pocketed (failure). Low buzz/fail. 0.25s. Must read
   as punishment, clearly worse than `pocket`.
6. `foul` (NEW) — illegal first contact (no rail/pocket involved). Dry
   whistle or muted thud. 0.15s.
7. `streak` (NEW) — streak multiplier increases (3rd+ consecutive pocket).
   Rising tick layered over `pocket`. 0.10s.
8. `bank` (NEW) — bank shot confirmed (rail then pocket). Metallic edge on
   the pocket tail. 0.15s. Can be a layer mixed with `pocket`.

**UI / structure:**
9. `click` — buttons, power adjust. Soft tick. 0.05s.
10. `reward` — reward/shop/event choice taken. Warm major chime. 0.18s.
11. `boss` — boss intro shown. Deep ominous hit. 0.40s.
12. `victory` (NEW) — House beaten. 3-note resolve. ~0.8s.
13. `defeat` (NEW) — run ends. 2-note fall. ~0.8s.
14. `cash` (NEW) — cash awarded (node clear, shop buy). Coin-ish tick.
   0.10s. Must not clash with `reward`.

**Ambience (optional this pass, list so we scope it):**
15. `room_tone` (LATER) — 30s loopable hall bed. Not requested now.
16. Music stems (LATER) — title drone, map loop, boss pulse. Not requested
    now; leave headroom in the mix.

Priority order if time is short: pocket ×3, fire, scratch, rail ×2,
ball_click ×2, click, reward, boss. Then foul/bank/streak/cash/victory/defeat.

## 4. WAV vs OGG vs MP3 — what to deliver (your question, answered)

Short answer: **deliver WAV masters (44.1kHz 16-bit mono); we ship OGG
for music/long sounds and WAV for short SFX in the HTML5 build.**

Why, specifically for Godot 4 HTML5 (verified against current docs):

- **WAV:** lowest decode CPU, sample-exact timing, supports embedded loop
  points and forward/ping-pong/backward loops. Downside: raw PCM is huge
  (~88 KB/s mono). Godot imports WAV as QOA-compressed by default, so the
  exported file is much smaller than the master — short SFX stay WAV.
- **OGG Vorbis:** best size/quality for music, voice, long effects
  (~16 KB/s stereo at 128k). Higher decode CPU than WAV/MP3, and web
  Sample-playback looping needs testing in the exported build, not just
  the editor. Use for anything over ~1s.
- **MP3:** broadest browser-native support and lower decode CPU than OGG,
  but larger than OGG at equal quality and the worst choice for seamless
  loops (encoder delay/padding causes seams). Only use if the source is
  already MP3.

Portal constraints that drive this: Poki targets ~5MB initial / 8MB total
and 10s loads; CrazyGames caps 50MB initial (20MB for mobile homepage)
and tests on 4GB Chromebooks + Safari. Our SFX set as WAV/QOA stays tiny;
any future music ships as OGG.

Practical rule: you send WAV masters, named below. The coder picks import
settings (WAV/QOA for the 14 short hooks, OGG if we add room tone/music).

## 5. Mix rules

- Master VOLUME setting (0/40/80/100%) already exists in Settings and
  scales everything in `_sfx`. Mix at 80%.
- `rail`/`ball_click` fire constantly — keep them 6-10dB under `pocket`.
- `pocket` sits on top; `scratch` sits underneath everything emotionally.
- No sound may exceed 0.8s except victory/defeat stingers.
- Test on laptop speakers: ball clicks must survive tiny drivers.

## 6. Specs + filenames

- WAV 44.1kHz 16-bit mono, peaks at -3dB, no clipping.
- `fire_01.wav`, `rail_01.wav`, `rail_02.wav`, `ball_click_01.wav`,
  `ball_click_02.wav`, `pocket_01..03.wav`, `scratch_01.wav`,
  `foul_01.wav`, `streak_01.wav`, `bank_01.wav`, `click_01.wav`,
  `reward_01.wav`, `boss_01.wav`, `victory_01.wav`, `defeat_01.wav`,
  `cash_01.wav`.
- Include your DAW session + exports in one folder. One folder, relative
  paths only (portals reject absolute paths).
- Browser rule that affects you: audio must start from a user gesture
  (click/key). The game's first sound only plays after START is pressed —
  do not deliver autoplay beds.

## 7. Checklist

- [ ] Priority set (pocket×3, fire, scratch, rail×2, ball_click×2, click, reward, boss)
- [ ] Second set (foul, bank, streak, cash, victory, defeat)
- [ ] Laptop-speaker pass at 80% volume
- [ ] Masters as WAV, noted which future stems should ship OGG
