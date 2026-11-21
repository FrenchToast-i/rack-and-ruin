# Rack & Ruin — HTML5 Release Guide (Poki / CrazyGames / Coolmath)

## Current state

The project is Godot 4.7, GL Compatibility renderer, 1280x720 canvas with
`canvas_items` stretch + `expand` aspect. The shell constrains the game to a centered 16:9 frame (letterboxing excess viewport space rather than stretching controls offscreen). On a portrait phone the frame is unreadably small, so after TAP TO PLAY the shell shows a full-screen rotate prompt and removes it automatically when the device turns. Three Web export presets exclude `build/*` and `tests/*` from the PCK, so QA scripts never ship, and target
`build/poki/index.html`, `build/crazygames/index.html`, and
`build/coolmath/index.html` using `web/portal-shell.html`. The preset inserts
a portal target in the HTML head so the shell initializes only the matching
Poki or CrazyGames SDK; Coolmath builds never fetch third-party SDK scripts.
Exported Godot runtime files are roughly 39MB each, below CrazyGames' current
50MB initial download threshold but above Poki's 5MB load-time recommendation.
Thread support is OFF for broad iframe compatibility.

Coolmath's public developer material does not publish an SDK, so its preset
targets the HTML5 requirements only; integrate their SDK after receiving
private onboarding instructions. Poki and CrazyGames SDKs are loaded from
their official host URLs at runtime.

## Export once, verify everywhere

Install the matching Godot 4.7 Web export templates first. The target directory
must exist before export:

```bash
mkdir -p build/poki build/crazygames build/coolmath
godot --headless --path . --editor --quit
godot --headless --path . --export-release "Web - Poki" build/poki/index.html
godot --headless --path . --export-release "Web - CrazyGames" build/crazygames/index.html
godot --headless --path . --export-release "Web - Coolmath" build/coolmath/index.html
```

Run a local HTTP server from an output folder (never open via `file://`):

```bash
cd build/poki && python3 -m http.server 8901
```

Test each export locally and then in each portal's preview/QA tool. The
Coolmath preset has no portal scripts; it needs Coolmath's own review for any
SDK or licensing requirements. Portal SDK events must be verified in the real
preview wrappers; local preview shells cannot initialize those remote SDKs.

The shell selects its SDK from the preset's `__rackPortalTarget` (poki or
crazygames) before falling back to host matching, so a CrazyGames build served
from a local server never tries to load the Poki SDK and vice versa. A build
with neither target ships no third-party script at all (Coolmath).

Checklist per build: boots in under 10s on throttled 4G, canvas fills the
iframe, the game remains 16:9 on ultrawide/mobile screens, a portrait phone
shows the rotate prompt only after play begins and hides it on rotation, all 18 screens
reachable (title, how to play, vault, trophies, stake, practice, The Grind card,
map, encounter, reward, shop, event, boss intro, last call, settings, run
summary, House Duel result, Pass & Play result),
audio starts only
after TAP TO PLAY is pressed, mute works, no console errors, save/rep survives
reload (and fails silently in incognito without breaking the game). Trophies
must survive a reload and pay their reputation exactly once; the title's
daily countdown must tick down while the page sits open. COPY RESULT on the run
summary must either copy inside the portal iframe or say it is unavailable —
never claim success without writing the clipboard. Settings must survive a
reload too (volume, contrast, flash, shake, aim guide, fast resolve), and the
daily challenge must show the same date seed and twist, then keep its streak
and best across reloads. The Grind must deal a fresh rack from table one, keep a
parked tour in CONTINUE, and survive a reload with its deepest table and high
score. On the Grind card, verify TODAY'S LADDER starts the same seeded rack as
another browser profile, carries no vault perks, banks today's best on every
clear, pays reputation only once per day, and never removes a parked tour's
CONTINUE. FREE GRIND must keep the endless personal record intact. On a
table-rule day (open rack, corner only, slick
felt) confirm the table itself matches the card and the next normal table is
back to base rules. Starting a daily with a run in progress must leave
CONTINUE available. The opening table must be a three-pocket clear with at
least ten shots and the coach's FIRE instruction in its brief. Exhaust a table
with the favor unused: LAST CALL must appear before any defeat is recorded,
CALL IN THE FAVOR must rerack with the full budget, and a second loss must end
the tour without offering it again. With storage cleared, the first table must show the
three-step coach, advance it by aiming and changing power, and never show it
again after the first shot is fired. SIT DOWN on the title must deal a duel
table with a live race tile, hide HOUSE HEAT, and let a House miss hand the cue
back with an enabled FIRE button; verify a win, a loss and a pause-card
forfeit, then start a tour and confirm the House's boss aim is back to normal.
PASS & PLAY on the title must deal a local table with `PLAYER 1`/`PLAYER 2`
seats: a dry shot must show the `PASS THE CUE` card and turn FIRE into
`PLAYER n READY` (that press must not fire), a pot must stay with the seat
that shot, and END MATCH must show the series result card with REMATCH and
NEW RACK. Verify the winner's break on the rematch and that no ladder win,
streak or reputation moves. On Forms III and IV, a House pot must bolt one or
two pockets (never beyond the form's cap) and the brief must count them.
THE CUE CASE must list six finishes with locked cards naming their trophy
progress; clear a table, return to the case, and BRASS & BLACK must equip and
survive a reload. On the felt the stick must pull back with power and show the
equipped finish. HOUSE CAM must open its inset on a two-pot or banked pot,
keep FIRE usable while it plays, dismiss itself, and stay off when Settings →
House cam replays is OFF. It must not appear on a table-ending shot.

## Per-portal notes (researched Oct 2026)

- **Poki:** Testing opens your game folder in the Poki Inspector (not a
  single HTML file). Keep initial download ≤5MB and total ≤8MB as guidance;
  bundle all fonts/libs (external requests blocked by default); integrate
  the Poki SDK (loading, gameplay start/stop, ad-break mute) before
  submission; catch storage errors for incognito; support desktop + mobile +
  tablet at 16:9.
- **CrazyGames:** Upload via Developer Portal. Hard limits: 250MB total,
  ≤1,500 files, initial download ≤50MB (≤20MB for mobile-homepage
  eligibility); relative paths only; must run on a 4GB Chromebook in Chrome
  and Edge (poor Safari can get Safari disabled). SDK optional for Basic
  Launch, required with gameplay + muteAudio events for Full Launch.
- **Coolmath:** HTML5 only, no Flash/plugins; no ads, external links, or
  stats counters phoning home; no violence/foul language; disable name
  entry (we have none). Licensing is curated — SDK integration comes later
  if they pick the game up.

## Audio for web (what to ship)

Ship **WAV (QOA import) for the 14 short hooks, OGG for any future music /
room tone**. Never MP3 for loops (seam risk). Our hooks are all <0.8s, so
the whole SFX set stays well under 1MB. Note: Godot 4.3+ web audio uses
Sample playback by default — some effects are unsupported and loop offsets
can differ from desktop. Verify every hook in the exported build, not just
the editor. Thread support stays OFF for portal compat; if latency becomes
audible, re-test with it ON and confirm each portal still accepts the build
(COOP/COEP headers required).

## SDK status

`web/portal-shell.html` loads only the portal selected by each export preset.
On localhost/127.0.0.1 it skips live SDK initialization entirely, so developer
runs cannot pollute portal analytics; the real preview wrapper is the only place
SDK events are verified. On a portal host it initializes Poki/CrazyGames SDK,
then starts Godot after a TAP TO PLAY user gesture (also unlocking browser audio). Poki loading completion waits for
both game and SDK readiness. The Godot bridge sends lifecycle events and
reads CrazyGames `muteAudio`; pause/resume and leaving/entering gameplay
stop/start reporting. Coolmath output contains no third-party SDK requests.
Poki lifecycle start/stop hooks are de-duplicated.

No ad breaks are requested by the game yet. Before adding rewarded or midgame
ads, wire each portal's ad callbacks to pause simulation, stop gameplay,
disable input and mute audio on ad start; restore audio/input and resume
reporting on both finish and error. For Coolmath, do not bundle or call an SDK until its licensing team provides
integration details.

## Known blockers / verification scope

The Godot 4.7.2 Web export templates are installed here, and all three presets
export cleanly (last verified Nov 2026). The payload is ~39MB because of the
Godot runtime wasm, not game code; Poki's 5MB load-time guidance still needs a
runtime/asset budget pass before submission. Local QA can verify the shell,
rendering, save data, and the daily/vault flows, but Poki Inspector and the
CrazyGames preview wrapper are still required to confirm ad-break, QA-wrapper,
and mute events against the real portals.

Coolmath SDK integration is intentionally absent: public documentation says
to add its SDK if licensed but gives no script URL or API. Ask Coolmath for
its onboarding SDK before submitting. For Poki/CrazyGames, each export preset
selects the SDK directly; confirm events with each portal's real preview
wrapper.

Ad-break safety: runs persist at every map boundary (CONTINUE on title),
mid-shot interruptions resolve by cancelling physics cleanly when leaving
to the map, and the pause overlay (P / Start / II button) covers the table
during breaks.
