# Rack & Ruin

A scenario-first pool roguelite. The authoritative gameplay specification is in [`docs/GAMEPLAY_DESIGN.md`](docs/GAMEPLAY_DESIGN.md). Full reanalysis is in [`docs/GAME_ANALYSIS.md`](docs/GAME_ANALYSIS.md).

## Run

Open this directory in Godot 4.7+ and press **F6/F5**, or run:

```bash
godot --path .
```

## Controls

- Mouse aims; touch drag and the left/right controller stick aim too. Aim only updates over the felt: moving the pointer across the dock or the table brief never re-aims, so reaching for FIRE cannot swing the shot. Dotted line = cue path, gold rings = rail bounces, green ghost = first ball contact + target direction, blue dashed = post-contact cue path. When the ghost line sends a target into a pocket and nothing blocks the path, a gold pocket line and ring confirm the pot.
- Your cue is on the felt: it pulls back with power, slides to the english side of the ball, and thrusts through contact. Its finish is the one equipped in THE CUE CASE, so a milestone is visible on every shot.
- HOUSE CAM: a two-pot or banked pot opens a slow-motion inset over the top-right of the felt while live play keeps running. It is presentation only, never blocks a shot, and can be switched off in Settings → House cam replays.
- THE HOUSE'S SPOT: one brass ring sits on every scored table. Pot a ball and leave the cue ball inside the ring to pay `SPOT +10`, charge House Heat, and return one shot the first time on that table. The spot re-rolls to a new open patch of felt after every park. THE HOUSE MARK (a tier-2 CONTROL cue) raises the pay to +15 and returns a shot on every park.
- Power: drag the meter, wheel, `W`/`S`, or gamepad X/Y.
- English: drag the SPIN pad (up = follow, down = draw, sides = english, centre = none). Keys `A`/`D` side spin, `Q`/`E` follow/draw, `X` or gamepad B clears.
- `Space`/`Enter`, gamepad A, or `FIRE SHOT` shoots. Table clicks never fire. While a shot resolves, the same button reads `SPEED UP` and pressing it runs the rest of the physics instantly, so nobody waits on a rattling pocket.
- `R` retries the encounter layout at the same seed. `Esc` returns to map; on any menu it is the BACK button (map: first press drops a preview, second leaves for the title). `P` or gamepad Start pauses (touch: II button). `M` mutes.
- THE HOUSE'S NUMBER: every table posts a par score next to the contract. Clearing pays on the contract alone; beating par pays 15 extra cash and a HOUSE PAYS toast, so the score line is a performance grade instead of dead weight. Score tables set par just above their own ask, count tables scale it by stage and danger.
- HOUSE HEAT: pots charge a per-table meter (fouls drain it). At 100% the dock button turns gold — press it or `F` to call the House: that shot scores double and its scratch costs no shot. Heat empties at every table, so the call is earned inside the rack it saves; ten calls unlock a trophy.
- THE HOUSE'S FAVOR: once per tour, a lost table offers a rescue before the run is recorded — call it in to rerack the same table with its full shot budget, or end the run. The favor is visible on every table brief once it is spent.
- Fouls/scratches cost shots (double in bosses/elites). Streaks multiply pockets. A target must actually drop to pay base score: rails touched by a miss do not score, and bank bonuses only pay for a banked pot. Rail-build pieces and the RAIL WEEK daily still pay per cushion, labelled RAIL PAY.
- Bosses hit PHASE 2 at half score. The Locksmith's banked pots start paying triple. THE HOUSE TAKES THE TABLE: after any shot that pots nothing it picks up the cue, places it where it has a line (ball in hand), and shoots. Every ball it pots bolts one pocket shut — capped at three — and the ball is spotted back, so the rack's score ceiling never shrinks. The HUD counts shut pockets for the rest of the fight; the pockets themselves are drawn as bolted brass plates and physics ignores them. Beating The House without losing a pocket earns SHUT OUT.
- THE HOUSE REMEMBERS: when a tour beats The House, it studies the way you won and taxes that exact habit in the next finale — banked pots pay half, multi-ball pots pay 40% less, the rack opens with one pocket bolted, or phase two starts at a third of its number instead of half. The read is announced on the title ledger, the route's House card, the boss intro and the live table brief, so the counter-build is a choice rather than a surprise. It only touches the final House rack, never dailies, the Grind, duels or the Locksmith. Beating a grudge settles it for +2 REP (SETTLED UP, NO READ); a win with no dominant habit leaves the House with no read at all, so a varied build is the safe build.
- Defeat/victory screens offer RETRY SEED to replay the same tables.

## Run structure

- Title (stake toggle, loadout, cue case, daily card, duel card and Pass & Play) → **THE HOUSE'S TERMS** → Tour map → encounters → rewards → boss gates → The House → victory/defeat summary.
- THE HOUSE DUEL: the title's second front door. One rack, first to five pockets, no build and no shot budget; a pot keeps the cue and a miss hands it to the House. Four forms are four opponents, not four sliders: the Croupier never takes ball in hand, the Shark places it, the Closer bolts one pocket shut on a pot, and the true House bolts two. Beating the highest form reached unlocks the next, and wins, streaks and Form IV are tracked in local meta. Every win pays one reputation; a forfeit through the pause card breaks the streak. It is the two-minute portal session for a player who does not want a full tour yet, and it never reads or writes a parked run.
- PASS & PLAY: the same race with two humans on one keyboard. Player 1 breaks, the winner breaks the next rack, and a `PASS THE CUE` card plus a `PLAYER n READY` FIRE button keep a shared keyboard from firing out of turn. The series is kept for the session, shown on the header, brief and result card, and never written to meta; leaving reads `END MATCH`, not a forfeit. Rematch, new rack and the winner's break are one click away. It is the portal's couch mode: no account, no second device, no server.
- THE HOUSE'S SPOT: every scored table places one brass ring on open felt near the live targets. It is the game's position-play layer: a pot alone is not enough if the cue ends in the wrong place. The first park on a table returns one shot; every park pays score and heat, and the ring moves so the leave has to be earned again. THE HOUSE MARK build piece turns the ring into a repeatable engine (+15 and a shot every park). The shelf's DEAD EYE trophy tracks eight lifetime parks. Duels skip the ring because they already have a pocket race.
- THE CUE CASE: six cue finishes, each earned by a trophy rather than bought. HOUSE ASH is the starting stick; FIRST BREAK unlocks BRASS & BLACK, SHARP SHOT unlocks OLD IVORY, ON A RUN unlocks CARBON, HOUSE REGULAR unlocks THE CLOSER, and UNMASKED unlocks THE HOUSE'S OWN. The equipped finish is the stick drawn on every table, so the trophy shelf pays off in the core action. No finish changes a stat, a shot or a payout.
- HOUSE CAM: the broadcast layer. A shot that pots two targets, or one off a cushion, records its frames and replays them in a slow-motion inset with a HOUSE CAM / DOUBLE POT bug. It is the moment a great shot becomes a highlight instead of a line of score, and it runs beside live play rather than stopping it, so a portal session never waits on presentation.
- THE HOUSE'S TERMS: every normal run signs one of four identities before the first table. THE MARK is the untouched game; THE BANKER pays +60% on banked pots but cuts one shot per table and taxes direct pots 25%; THE COLLECTOR pays +60% on multi-ball pots with the same shot cut and a single-pot tax; THE GRIFTER starts +40 cash and pays +20 per clear, but scratches cost an extra shot. The last signed term is remembered, the opening table keeps its 10-shot floor, and dailies always play under THE MARK so the shared board stays fair.
- THE HOUSE'S WAGER: every scored route table can carry a 20 or 50 cash stake, chosen on the route card before the break. A standard clear returns 2x the stake; an elite or boss returns 3x. The stake is escrowed when the rack starts, so reading a preview is free, but a loss or leaving a live rack forfeits it to the House. Wagers are off on dailies and the shared ladder, where two players must face the same table. It turns spare cash into a per-table risk decision and gives the House one more way to collect.
- A lost table pauses on LAST CALL: one favor per tour can reset that rack and keep the run alive. It is offered on bosses too; declining records the defeat honestly.
- One connected route only: tap a node to preview its contract, tap again to enter. A map with only one open node preselects it, so the player can enter with one click. Shops, events, elites are choices, not checklists.
- Shuffled scenario deck per run (Gatehouse always opens); node names match their tables.
- THE HOUSE SPEAKS on the tour map: one line under the build sheet that reacts to run state (a scratch it kept, a three-shot streak, deep cash, or the untouched opening route). It gives the route an antagonist instead of one anonymous boss.
- 13 scenario families: Gatehouse, Frozen Lane, Locksmith's Run, Trap, Open Water, Crossfire, Anchor Yard, Prism Vault, Pinwheel, Split Channel, Drift Gate, Dead Pocket, Spring Board.
- 6 contracts: score, clear, bank-count, combo, ice-lane, no-scratch.
- 26 named build pieces (8 Cues, 9 Chalks, 9 Relics) in 2 tiers + shop reroll + 3 event decks with 3 choices each. THE HOUSE MARK is the position-play cue.
- Bosses: The Locksmith (Score 130, a banked pot pays its value twice, double foul cost) and The House (Score 165, double foul cost, and from half score it takes a shot after every miss and shuts a pocket for each ball it pots). Elites always ask for a real score, scaled by route depth rather than the rack's authored target.
- Practice table, a How to Play screen with live mini-diagrams, in-table briefs, controls sheet in Settings, Collection/Codex + 8-run history, persistent rep/best/runs, mid-run CONTINUE at map boundaries plus a TITLE exit on the map, stakes 0-2 (0 full shots, 1 -1 shot, 2 -1 shot +15 target).
- THE VAULT: reputation (earned on every finished tour) buys three permanent upgrades — starting cue, +1 shot on every table, +20 opening cash — at 5 / 9 / 14 REP. Unlocks persist in the meta file, apply only when a normal run starts (dailies stay level for everyone), and show on the title's starting-loadout card. The vault shows progress toward the next piece, and the run summary links straight to it.
- THE TROPHY SHELF: 31 milestones across first clears, both gates, deep routes, single-shot scores, streaks, scouted tables, daily streaks, the vault, a Stake 2 win, a shut-out House kill, two Grind depths, three House Duel feats, eight House Spot parks and two House grudges. Each pays reputation once; locked cards show live progress, the title shows the count, and an unlock raises one toast above the current screen.
- THE GRIND: the title's endless mode. Every rack is procedural, every clear opens the reward room, and the target climbs while the shot budget tightens. Every fifth rack is an elite score gate. Beating a rack's par banks one extra shot for the next rack, so overachieving buys breathing room. Your best run also leaves a pace split: the HUD shows `PACE +12` / `PACE -8` against that record at every table, turning the board into a live rival. There is no map, no favor and no continue; a lost rack ends the run and banks its depth immediately. Deepest table and high score persist, and two trophies (five and ten tables) give the mode a long chase. It is the fast portal session: one rack, one piece, one more.
- THE DAILY LADDER: the Grind card's shared challenge. One date-seeded rack sequence for every player, under base rules (no vault perks, no signed term), with its own daily best and a replay-proof one-payout-per-day reputation guard. Today's depth and high score bank on every clear; a separate streak rewards showing up, and the title's Grind button carries a quiet dot while the ladder is unplayed. The free Grind stays the endless personal-record chase. Both never touch a parked tour save.
- Run summary offers COPY RESULT: a one-line seed (or daily date, twist and streak) plus score and tables, written through the portal shell's clipboard fallback. The shell reports copy failure honestly instead of pretending it worked. A normal tour appends a challenge code (`RR1-seed-TERM-stake`); the title's **PLAY A CODE** card accepts a pasted code and starts that exact route, term and stake, so a shared result is playable by a friend without an account or server. Dailies and the Grind carry no code.
- Daily Challenge: one date-seeded tour for every player, plus one date-picked twist shown on the title card, map header, table brief and summary — five pay rules (rail, bank, side pockets, opening cash, extra shot) and three table rules that rebuild the rack (no blocks, corner pockets only, slick felt). The card counts down to the next daily, and a streak and today's best survive sessions. A daily never touches the normal run save, so an in-progress run survives it. Settings (contrast, flash, shake, aim guide, fast resolve, house cam, volume) persist between sessions.
- The opening table is a three-pocket clear with ten shots; tables two and three stay on clears before bank, combo and no-scratch contracts appear. Score asks on procedural racks are capped against the rack's live value.
- First-shot coach: a new player's first table shows one action at a time (aim, power, fire) on the lower cushion, ticks off as they do it, and retires for good once they fire. Practice and a first daily table coach too; later tables never do.
- Seeded shops (tier-priced, rerollable), stage-scaled events, pause overlay, portal-aware Web shell with Poki/CrazyGames lifecycle hooks.

## HTML5 portals

Three independent Web presets export to `build/poki`, `build/crazygames`, and `build/coolmath`. The responsive shell keeps the 16:9 game canvas centered in tall and ultrawide portal frames, waits for a click before starting the Web engine, and prompts a portrait phone to rotate once play begins. Test scripts are excluded from the exported PCK. Poki and CrazyGames SDK integrations activate in their portal-specific presets; Coolmath's SDK is not public and needs their licensing instructions. See [`docs/HTML5_RELEASE.md`](docs/HTML5_RELEASE.md).

```bash
mkdir -p build/poki build/crazygames build/coolmath
godot --headless --path . --export-release "Web - Poki" build/poki/index.html
godot --headless --path . --export-release "Web - CrazyGames" build/crazygames/index.html
godot --headless --path . --export-release "Web - Coolmath" build/coolmath/index.html
```

Install the matching Godot Web export templates first.

## Tests

```bash
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --script res://tests/gameplay_playtest.gd
godot --headless --path . --script res://tests/bot_playtest.gd   # 12 seeded runs + 12 duels + 3 local matches, softlock check
```

The gameplay playtest also covers the four run terms (selection, baked-in
shot/bank/cash effects, and Banker direct-vs-banked scoring), the daily
seed/streak rules, the rule that a daily cannot delete an in-progress run save,
vault cost/apply/daily-exclusion/persistence behavior, trophy
reachability/payout/persistence, the Grind's intro/clear/reward/gate/defeat
loop, par-beat shot banking, pace-split snapshots, the Daily Ladder's shared seed, base rules,
immediate records, one-payout-per-day reputation guard and parked-tour
preservation, the House Duel's rack ownership, turn hand-back, win/loss/forfeit
records, form unlocks, the Closer/House pocket caps, House aim reset when
returning to the tour, Pass & Play seat scoring, the handoff gate, series
rematch, no ladder writes from a local match, and parked-save isolation (the
bot additionally plays every form and three full local matches to a result),
the opening-table contract, share text (including challenge-code generation,
parsing inside a pasted result, invalid-code rejection and starting the named
run), settings persistence, map card name uniqueness, the House's Wager (escrow at the
break, even-money standard payout, daily exclusion, and loss/forfeit
handling), and the House's grudge book (read,
finale-only tax, bolted opening pocket, early phase two, +2 REP settlement and
cross-session persistence). It points the game at isolated test save slots,
so running it never reads or writes the developer's real meta. The bot walks
real shops and events instead of treating every map node as a table.

## Artist handoff

- Graphics: [`docs/ART_BRIEF.md`](docs/ART_BRIEF.md)
- Sound: [`docs/AUDIO_BRIEF.md`](docs/AUDIO_BRIEF.md)
- HTML5 portals: [`docs/HTML5_RELEASE.md`](docs/HTML5_RELEASE.md)
- Presentation is placeholder geometry + procedural tones by design. All hook points are named in the briefs.
