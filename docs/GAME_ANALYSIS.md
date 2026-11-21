# Rack & Ruin — Game Analysis (current build)

## What it is now

A complete single-run pool roguelite: aim → power → english → fire →
deterministic physics → tag scoring → contract → route choice → build →
two phased boss gates → House → summary with same-seed retry. Lose on
exhausted shot budget. Win only at the bottom House node.

## MDA read

- Mechanics: mouse/touch/gamepad aim, power 0.08–1.0, side/follow english,
  the House's Spot (pot, then park the cue on the brass ring for score and a
  shot back), 6 contracts, foul/scratch economy (double tax in elites/bosses), streak /
  bank / combo / rail / side-pocket multipliers, 21-piece tiered build pool,
  seeded shops, stage-scaled events, branching map with two-tap preview
  cards, shuffled per-run scenario deck (Gatehouse always opens), 2
  two-phase bosses, stakes 0–2, THE HOUSE'S TERMS (four run contracts that
  reshape scoring: straight Mark, bank-paying Banker, cluster-paying Collector,
  cash-rush Grifter), pause, retry-seed, run history, mid-run
  continue, daily challenge (date seed, daily twist, streak, day best), THE
  VAULT (three permanent reputation upgrades),  HOUSE HEAT (a per-table meter
  filled by pots that buys one double-score shot with its scratch forgiven),
  THE HOUSE'S WAGER (an optional 20/50 cash stake on a scored table, paying
  2× on a standard clear and 3× on an elite or boss, forfeited on a loss or
  walk-out and disabled on shared dailies),
  THE HOUSE'S FAVOR (one rescue per tour before a loss is recorded), THE HOUSE
  PLAYS (its phase two takes a real shot after every dry player shot, with
  ball in hand when blocked, and bolts a pocket per pot), THE HOUSE DUEL
  (a one-rack race to five pockets against four forms — aim, ball in hand,
  and one or two bolted pockets), PASS & PLAY (the same race with two humans
  on one keyboard, a handoff gate, a session series and the winner breaking
  the next rack), first-run nudge, keyboard and controller focus on every
  screen's primary action.
- Dynamics: bank routing vs safe clears, combo setups in clusters, streak
  protection timing, elite risk for tier-2 pieces, cash-vs-shots event math,
  spare-cash wagering on tables you expect to clear versus saving for a shop,
  english risk on tight rails, phase-2 adaptation (House kills side payouts,
  Locksmith overpays banks — greed flips value mid-fight; the House physically
  removes pockets, so the player's scoring geometry shrinks while the target
  stays fixed, and a perfect table denies it a single turn).
- Run identity: a signed term changes the shot worth taking before the first
  table. Banker routes through cushions, Collector hunts clusters, Grifter buys
  a first piece with a thinner budget; the last term is remembered so a player
  can specialise or deliberately switch. This is the replay hook that used to
  be carried by the stake slider alone.
- Aesthetics: reading → planning → commit → payoff → adapt. Every miss maps
  to power, angle, position, accepted risk, or a misunderstood build piece.
  The House speaks on the map and in the summary, so failure has a face and a
  voice instead of an anonymous score line.

## Player types

- Achievers: stakes, best score, rep, codex 8/8, House clears, 8-run history,
  daily streaks.
- Explorers: seed variants, drift/mud/elastic bands, 8 scenarios, seeded
  shop stock + reroll pools.
- Killers (vs self): tight budgets, no-scratch contracts, high-stake House,
  same-seed mastery via RETRY SEED.
- Socializers: seed sharing (seed on title/map/victory/defeat) now with a
  `RR1-seed-term-stake` challenge code the title can consume, so a copied
  result is playable by a friend without a server; route stories, and PASS &
  PLAY — two people on one keyboard with a live series,
  a handoff card and a rematch, no account or second device. Online
  multiplayer remains out of scope (no server).

## Flow / balance

- Early: Gatehouse/Frozen/Open, 8–9 shots, tier-1 pieces and 50-cash shops.
  Learn banks, ice, streaks.
- Mid: elites + Crossfire/Anchor/Vault, -1 shot, +35 target, foul tax,
  70-cash tier-2 shops, scaled events. Tier-2 pieces unlock at stage 4+.
- Late: Locksmith (130, a banked pot pays its pocket value again, triple past
  half) → House (165, double foul cost; at half score it takes the cue after
  every dry shot and shuts a pocket per pot, capped at three). Both racks hold
  110 base value plus the gate anchor, so the target fits the rack instead of
  demanding perfection. Elites use a depth-scaled score ask (90–110) rather
  than adding 35 to a target that might be a count.
- Stakes 1/2: -1 shot, +15 target at 2. Cash rewards scale with danger
  (20 / +15 elite / +30 boss).

## Retention loops

- **A second front door.** THE HOUSE DUEL is the shortest complete session:
  one rack, first to five pockets, no map, no build, no shot budget. The
  Croupier is a teaching opponent (loose aim, never takes ball in hand); the
  Shark places the cue; the Closer bolts one pocket shut on a pot; the true
  House bolts two. Each form is a rule you can see on the felt, not another
  accuracy number. Beating the highest form reached unlocks the next, every
  win pays reputation, and first win / five-streak / Form IV are trophies. It
  matters for portals because a new visitor can play a real match in two
  minutes without learning the tour, and a returning player has a ladder
  record that is independent of every tour save.

- **A second seat.** PASS & PLAY turns the duel into a couch game: two humans,
  one keyboard, first to five, a handoff card that stops out-of-turn fire, a
  session series, and the winner breaking the next rack. A rematch is one
  click. Nothing is written to meta, so a shared session cannot farm the
  ladder or touch a parked tour. This is the portal differentiator a solo pool
  roguelite otherwise lacks: a visitor can bring a friend without an account,
  a phone or a server, and the result card gives them a reason to run it
  back.

- **A signature stick.** THE CUE CASE turns six trophies into six visible cue
  finishes: the stick on the felt is the player's, not the game's. It is a
  cosmetic sink with no power attached, which makes it safe for dailies and
  duels, and it gives the trophy shelf a payoff in the action instead of only
  in a menu. A first-session player starts with HOUSE ASH and can earn BRASS &
  BLACK by clearing one table, so the case begins paying immediately.

- **A leave worth playing.** THE HOUSE'S SPOT adds the missing half of pool:
  a pot pays, but parking the cue on the brass ring pays score, heat and a
  shot back. The ring moves after every park, so position is a live skill
  rather than a one-off bonus; THE HOUSE MARK build piece turns it into a
  repeatable engine, and DEAD EYE gives the shelf a mastery chase. It asks a
  spatial question on every shot without adding a screen or a confirmation.

- **A broadcast moment.** HOUSE CAM records every player shot and replays a
  two-pot or banked pot in a slow-motion inset over the felt. It never pauses
  play or blocks FIRE, so it adds the "that was a highlight" feeling without
  adding a wait to a portal session. It is the strongest screenshot/share
  moment in the game and the first thing a new player sees that reads as
  produced rather than prototyped.

- **A term worth mastering.** Four run contracts sit above the route: THE MARK
  (baseline), THE BANKER (banked pots +60%, direct pots 25% off, one fewer
  shot), THE COLLECTOR (multi-ball pots +60%, singles 20% off, one fewer shot),
  and THE GRIFTER (+40 cash, +20 per clear, scratches +1 shot). The last term
  is remembered across sessions and the opening table keeps a 10-shot floor,
  so a new player can choose a knife without cutting the tutorial. Each term
  makes the same rack ask a different question, which is the cheapest possible
  content multiplier for a pool roguelite.

- **Par chase.** Each table posts the House's par next to its contract. Clearing
pays the contract; beating par pays bonus cash, so a safe clear and a statement
clear are different outcomes without gating progress on either.
- **Daily challenge.** The date is the seed, so every player gets the same
tour without a server or an account. On top of the route, one date-picked
twist changes the day: five pay-rule twists (rail pay, bank pay, side pockets,
opening cash, extra shot) and three table rules that rebuild the rack itself
(no blocks, corner pockets only, slick felt). Today's best and a day-streak
live in local meta and show on the title card; the run summary repeats them.
Starting or finishing a daily never writes the normal run save, so it cannot
wipe an in-progress tour. It is the reason a portal visitor has to come back
tomorrow.

- **THE GRIND.** A fast endless mode sits beside the tour: procedural racks,
  one build pick per clear, a depth-scaled target and tightening shot budget,
  and an elite score gate every fifth table. Beating a rack's par banks one
  extra shot for the next rack, so the par line becomes a skill chase rather
  than a dead stat. A saved pace split from the best run shows `PACE +n` / `-n`
  at every table, so a replay races a visible rival instead of a number that
  only changes after the run. There is no map, no favor and no continue, so it is the
  pure score chase a portal session wants: lose, see the deepest table, and try
  again. The title opens a rules card with the saved record, depth and high
  score persist locally, and two shelf milestones (five and ten tables) give
  the chase a long arc. It is replayability without new
  scenario art: the existing procedural generator and reward room carry it.

- **THE DAILY LADDER.** The same endless format becomes a shared daily event:
  one date-seeded rack sequence, base rules for everyone, its own daily best
  and streak, and a replay-proof one-payout-per-day reputation guard. It gives
  a portal visitor two reasons to return — a personal free-run record and a
  fair board they can compare with a friend — without a server, account or
  leaderboard. The Grind button's readiness dot makes the fresh ladder visible
  from the title, and both modes preserve a parked tour.

- **THE VAULT.** Reputation used to be a score with no use. It now buys
  three permanent upgrades (starting cue, +1 shot per table, +20 opening
  cash) at 5 / 9 / 14 REP. Unlocks live in local meta and apply when a normal
  tour starts; dailies ignore them so the shared table stays fair, and a run
  in progress keeps the loadout it began with. The title marks an affordable
  piece, the vault shows progress toward the next one, and the run summary
  links straight to it. This is the loop that turns a series of runs into a
  profile.
- **Run history and record.** Best score, runs, reputation, the last eight
  runs, and the build sheet all persist, so a session has visible continuity.
- **THE HOUSE'S FAVOR.** A lost table pauses on LAST CALL before anything is
  recorded. One favor per tour reracks that table with its full budget and keeps
  the route alive; declining ends the run honestly. It is the theme's promise
  (the House always collects) as a safety net, and it converts the most common
  portal bounce — one bad table — into another attempt at the same rack.
- **Same-seed retry.** RETRY SEED replays a route to learn it; the seed is on
  the title, map, and summary so players can share it.
- **THE HOUSE PLAYS.** The final boss's second phase gives the antagonist a
  cue, not a bigger number. Every dry player shot hands it the table; it takes
  ball in hand when blocked and pots with a real physics shot. Each pot bolts
  one pocket shut for the rest of the rack (three max) while the ball is
  spotted back, so the contract stays winnable and the pressure is geometric.
  It is the one fight a player can win without the House ever standing, and
  SHUT OUT pays for exactly that.

- **A nemesis that remembers.** THE HOUSE REMEMBERS turns the finale into a
  personal rematch. A winning tour teaches the House one habit — rails,
  streaks, multi-ball pots or scratches — and the next finale taxes exactly
  that habit: banked pots pay half, chains pay 40% less, a pocket opens
  bolted, or phase two starts at a third of its number. The read is on the
  title ledger, the route's House card, the boss intro and the live brief, so
  the counter-build is a decision, not a gotcha. Settling it pays +2 REP and
  clears the book (SETTLED UP / NO READ), and a win with no dominant habit
  leaves no read at all: variety is the safe play. It is the retention loop a
  static boss cannot provide — the same player meets a different finale —
  and it costs one meta string, four counters and one rule per table.

## Platform posture (HTML5 portals)

- 1280×720, `canvas_items` + `expand`, resizable — fills 16:9 iframes.
- `scripts/core/portal_sdk.gd`: loading/gameplay/happy-time events, portal
  mute respected, storage failures degrade to a warning. Real portal JS
  globals get mapped at shell-integration time.
- Audio starts on user gesture only; touch aim + FIRE button + pause/mute
  controls work without a keyboard; gamepad fully mapped.
- Whole project ~240KB of code — far under Poki (~5/8MB guidance) and
  CrazyGames (50MB initial) budgets even before art/audio land.

## Remaining gaps (production)

1. Final art/audio (see ART_BRIEF / AUDIO_BRIEF).
   The ~38 MB Godot WebAssembly build is still the top Poki risk against its
   ~5 MB initial-download guidance; the new presentation work adds no assets
   and does not move that number.
2. Portal JS shell integration (map globals, ad-break mute wiring).
3. Server-backed leaderboards. Shareable daily/runs text and local records are built; there is no backend to rank them.
4. Controller rebinding screen.
5. Content is at 13 scenarios, 26 pieces and 3 event decks; the next step is
   authored set-piece bosses rather than more standard racks, and a second
   grudge per finale once the read is proven in portal playtests.
6. The duel ladder has four accuracy tiers but only one rule set; forms could
   gain authored behaviours (banks only, a shot clock, one pocket shut per
   pot) once the base race is proven in portal playtests.

## Solvability spot-check (headless bot, Oct 2026)

A throwaway bot played 6 seeded tables with direct shots only: half fell to
accident-level aim, the rest need deliberate banks/kicks (Locksmith's slabs,
the Trap's boxed cue). Re-ran with ghost-ball pocket aiming: similar split —
barrier tables punish straight lines, which is the design intent, not a bug.
All barriers were verified to have gaps (no fully enclosed targets), so every
table is completable; the Trap punishes players who cannot find the kick,
which is correct for its elite slot but worth watching in playtests if it
appears on standard nodes.

## Solvability spot-check (ghost-ball bot, Nov 2026)

`bot_playtest` now aims through the ghost-ball line to each pocket, falls back
to the lowest-cut option when every lane is blocked, buys the cheapest
affordable shop piece and takes the walk-away event. Across 12 seeded runs it
clears 34 tables (one to three per run) with no softlocks; every shot settles.
It clears the opening table on most seeds, so the first contract is reachable
with plain ghost-ball aim. The bot still loses runs because it ignores
contract type (it does not hunt banks or set up combos), never uses spin, and
never deliberately banks — a bot limitation, not an unwinnable game. The
Locksmith's bank gate and The House's closed sides are intended execution
walls. The bot counts only real table clears now; shops and events advance the
route but no longer inflate TABLES CLEARED, lifetime tables, best_tables or the
six/eight-table trophies (which were impossible once the count was honest).

## Duel bot check (Nov 2026)

`bot_playtest` plays three seeded duels on every form with the same ghost-ball
player. It won 3/3 on Form I, 2/3 on Form II, 3/3 on Form III and 1/3 on Form
IV, with no stuck cue, no House turn that failed to return the table, no match
trapped outside a result screen, and no aim at a bolted pocket. Those numbers
are a sanity curve, not a difficulty grade: the bot never uses spin, safeties
or a bank, so a human has more room on every form. Form I is deliberately the
teaching match, and Form IV is deliberately a wall for the basic bot.

It also plays three full PASS & PLAY matches with the same bot in both seats
(P1 2/3, P2 1/3). Each match runs through the real handoff press, real physics
and the real result card, and asserts the House ladder record does not move —
that is the proof the second seat is a human turn, not a renamed AI turn.

## Acceptance

- `smoke_test`: seeded assembly, 6 pockets, 4+ targets, variant difference,
  deterministic resolve.
- `gameplay_playtest`: boot, route lock, framed table, aim/power/fire,
  one-shot resolution, first contact, reward/shop/collection/boss/settings/
  defeat/victory flows, plus retry-seed, pause/resume, boss phase trigger,
  distinct shop stock, non-empty run history, save/continue round-trip,
  two-tap preview-then-enter, a full screen walk (howto, practice, event
  resolve, continue-without-save), daily seed stability, streak and day-best
  rules, daily-vs-run-save isolation, vault cost/apply/daily-exclusion/
  persistence rules, settings persistence, challenge-code generation/parsing/
  invalid rejection/start-with-exact-seed-term-stake, and map-card name
  uniqueness across seeds. The duel block covers rack ownership, turn hand-back after a
  House miss, the fifth-pot result, form unlocks, the Closer/House pocket
  caps, forfeit streaks, the race tile, parked-save isolation and the tour's
  House-aim reset. The Pass & Play block covers seat scoring, the handoff gate
  (FIRE must not fire), the series rematch and the winner's break, abandon
  handling, and the rule that a local match never writes reputation, wins or
  streak. The bot plays all four forms and three local matches to a result.
  The test uses isolated save slots, so a developer's real meta can neither
  change nor be changed by a test run.
