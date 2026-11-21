extends Node2D

const BilliardsSimulator = preload("res://scripts/core/billiards_simulator.gd")
const ScenarioLibrary = preload("res://scripts/core/scenario_library.gd")
const PortalSDKScript = preload("res://scripts/core/portal_sdk.gd")
# Condensed signage face: used only for titles, names and readouts large enough
# to carry it. Body copy stays in the engine sans so small text stays legible.
const DISPLAY_FONT := preload("res://assets/fonts/BebasNeue-Regular.ttf")

const BG := Color("#101820")
const FRAME := Color("#26343b")
const FRAME_DARK := Color("#172229")
const PANEL := Color("#1d3038")
const PANEL_ALT := Color("#29424a")
const GOLD := Color("#f2bd58")
const MINT := Color("#8fe1bd")
const MUTED := Color("#8ca5ad")
const RED := Color("#ef6b64")
const INK := Color("#091116")
const DEEP_BANK_BONUS := 12
# HOUSE SETS: two and four pieces of one discipline stop being a pile of
# numbers and start being an identity. Each tier is a real rule the table can
# show, so a focused build plays differently from a spread of stat pieces.
const DISCIPLINES := ["BANK", "COMBO", "RAIL", "CONTROL", "TEMPO"]
const SET_BONUSES := {
	"BANK": [
		{"tier": 2, "name": "CALLED CUSHION", "body": "Every banked pot pays +15 extra score."},
		{"tier": 4, "name": "THE LONG WAY", "body": "Banked pots pay +30 extra and add +12 heat."},
	],
	"COMBO": [
		{"tier": 2, "name": "CHAIN REACTION", "body": "Each extra ball in a multi-pot pays +20."},
		{"tier": 4, "name": "JACKPOT", "body": "Extra balls pay +40, and the first multi-pot each table banks +1 shot and +10 heat."},
	],
	"RAIL": [
		{"tier": 2, "name": "RAIL RUN", "body": "A pot after 2+ rails pays +15 extra score."},
		{"tier": 4, "name": "TABLE SPEED", "body": "That bonus becomes +35, and each banked pot adds +10 heat."},
	],
	"CONTROL": [
		{"tier": 2, "name": "INSURED", "body": "Start every table with one streak guard."},
		{"tier": 4, "name": "CORKED", "body": "Start every table with a scratch guard too."},
	],
	"TEMPO": [
		{"tier": 2, "name": "FRONT FOOT", "body": "Every table starts with +1 shot."},
		{"tier": 4, "name": "HEAD START", "body": "Every table starts with +2 shots instead."},
	],
}
# Screen-space power meter: the visual bar is drawn at x320-640, y642-656.
# The pointer target is a taller strip around it so touch can grab it.
const POWER_METER_RECT := Rect2(310.0, 630.0, 340.0, 36.0)
# Screen-space spin pad: x = english, y = follow/draw with up as follow, the
# way a cue-ball strike point reads. Lives in the dock beside the power meter.
const SPIN_PAD_RECT := Rect2(860.0, 604.0, 72.0, 72.0)
# The encounter HUD sits over the play field. Aim must ignore pointers inside
# these panels: moving the mouse to FIRE used to swing the cue at the button,
# and a touch on FIRE aimed at the button before the shot fired.
const HUD_BRIEF_RECT := Rect2(18.0, 140.0, 322.0, 402.0)
const HUD_DOCK_RECT := Rect2(300.0, 578.0, 930.0, 130.0)

var simulator := BilliardsSimulator.new()
var library := ScenarioLibrary.new()
var spin_pad: SpinPad
var screen := "title"
var screen_root: Control
var scenario: Dictionary = {}
var seed_value := 104729
var run_seed := 104729
var last_seed := 104729
var run_contract := "mark"
# The contract screen remembers the last term signed across dailies and
# sessions; a daily forces the Mark without erasing the player's preference.
var last_signed_contract := "mark"
var stake := 0
var map_position := 0
var map_nodes: Array[Dictionary] = []
var map_edges: Array[Vector2i] = []
var map_unlocked: Array[int] = []
var current_node := -1
var pending_node := -1
var node_buttons: Array[Button] = []
# THE HOUSE'S WAGER: a table can carry a cash stake chosen on the route. The
# stake leaves run_cash when the rack starts, clears at the selected table's
# odds, or stays with the House on a loss or a walk-out. The daily tour is
# excluded so its shared board cannot be bought.
const WAGER_STAKES := [0, 20, 50]
var pending_wager := 0
var table_wager := 0
var last_wager_stake := 0
var last_wager_payout := 0

var score := 0
var run_score := 0
var run_cash := 60
var run_stage := 1
# Route depth and tables actually cleared are different numbers: shops and
# events advance run_stage but are not tables. Keep the honest total for the
# summary, the run log, trophies and sharing.
var run_tables_cleared := 0
var shots_remaining := 0
var shot_number := 0
var resolve_pockets := 0
var pocketed_count := 0
var bank_count := 0
var combo_shots := 0
var scratches := 0
var fouls := 0
var combo_streak := 0
var best_streak := 0
var run_best_streak := 0
var lane_pockets := 0
var bank_bonus := 0
var combo_bonus := 0
var rail_bonus := 0
var next_shot_modifier := 0
var streak_guard := 0
var scratch_guard := 0
var side_pocket_bonus := 0
# THE HOUSE'S FAVOR: one rescue per tour. A lost table is normally the end of
# the run; the favor reracks the same table with its full budget instead. It is
# the theme's promise (the House always collects) turned into a safety net, and
# it makes a first portal session survivable without softening the tables.
var favor_available := true
# THE HOUSE'S NUMBER: every table carries a par score. Clearing pays the
# contract; beating par pays 15 extra cash. It is deliberately optional — a
# contract clear must never depend on it — so it reads as a performance grade
# instead of a second gate.
var table_par := 0
# HOUSE HEAT is the in-table crescendo: pots fill a meter, and a full meter
# buys one House shot that doubles its score and eats a scratch penalty. It
# empties at every new table, so it rewards play inside the rack rather than
# hoarding across a tour.
const HEAT_FULL := 100.0
var heat := 0.0
var house_call_armed := false
var house_calls := 0
var house_shutouts := 0
# THE HOUSE REMEMBERS: `house_grudge` is the saved read it will carry into the
# next finale; `grudge_active` snapshots it at run start so a parked run keeps
# the rule it was begun under. Run counters feed the read at the next win.
var house_grudge := ""
var grudges_settled := 0
var grudge_active := false
var run_banks := 0
var run_scratches := 0
var run_combo_shots := 0
var summary_grudge_settled := false
var summary_grudge_name := ""
# THE HOUSE PLAYS: the final boss's phase two is a real turn. After a missed
# shot the House picks up the cue, and every ball it pots bolts one pocket
# shut. The ball is spotted back, so score potential stays intact and the
# pressure is spatial instead of an unwinnable target.
const HOUSE_POCKET_CAP := 3
var house_pending := 0.0
var house_shooting := false
var house_aim := Vector2.RIGHT
var house_place_from := Vector2.ZERO
var house_power := 0.5
var house_aim_error := 0.035
var house_turns := 0
# THE HOUSE DUEL: a turn-based pocket race on one rack, with no contract,
# build, shot budget or map. It is the game's second front door: the House's
# own table, its own rules, and four forms of it to beat.
const DUEL_TARGET := 5
# A local match may be a quick three, the house five, or a long seven. The AI
# ladder always plays the house race.
const DUEL_RACES := [3, 5, 7]
var duel_target := DUEL_TARGET
var duel_race := DUEL_TARGET
# The ladder is four opponents, not four accuracy sliders: the Croupier
# teaches (no ball in hand), the Shark places the cue, the Closer bolts one
# pocket shut, and the House shuts two. Each rule is visible on the felt and
# announced in the form tag, so a loss names what beat the player.
const DUEL_FORMS := [
	{"name": "THE CROUPIER", "tag": "A polite first game. It misses, and it never takes ball in hand.", "error": 0.105, "hand": false, "shut": 0},
	{"name": "THE SHARK", "tag": "It places the cue when you hide it, and rarely gives a line away.", "error": 0.068, "hand": true, "shut": 0},
	{"name": "THE CLOSER", "tag": "It takes what you leave, and bolts a pocket shut.", "error": 0.046, "hand": true, "shut": 1},
	{"name": "THE HOUSE", "tag": "Every angle. Every pot closes a pocket.", "error": 0.026, "hand": true, "shut": 2},
]
var duel_active := false
var duel_seed := 0
var duel_form := 0
var duel_player := 0
var duel_house := 0
var duel_turn_house := false
var duel_wins := 0
var duel_streak := 0
var duel_best_streak := 0
var duel_best_form := 0
var duel_forfeited := false
# PASS & PLAY: the same race with two humans on one device. It reuses the duel
# turn loop and score state, but replaces the House with Player 2. It never
# writes the House ladder (wins, streak, reputation); only the all-time couch
# record below persists.
var duel_local := false
var duel_handoff := false
# A local series is session-only: the winner breaks the next rack, so a
# rematch has a shape instead of resetting to the same first shot.
var duel_series_p1 := 0
var duel_series_p2 := 0
var duel_breaker := 0
# The all-time couch record is the only local stat that persists: it gives a
# returning pair a rivalry to settle without touching the House ladder.
var duel_couch_p1 := 0
var duel_couch_p2 := 0
var duel_winner := 1
var current_power := 0.48
var current_spin := Vector2.ZERO
var last_aim := Vector2.RIGHT
var encounter_is_elite := false
var encounter_is_boss := false
var boss_phase := 0
var resolving := false
var resolve_elapsed := 0.0
var shot_events: Array[Dictionary] = []
var last_result := "Read the contract, choose a line, and commit."
var result_color := Color("#d5e2e2")
var run_best_shot := 0
var active_cue := "House Cue"
var active_cue_id := "house"
var reward_offers: Array[Dictionary] = []
var shop_offers: Array[Dictionary] = []
var shop_prices: Array[int] = []
var shop_rerolls := 0
var event_choices: Array[Dictionary] = []
var reward_catalog: Array[Dictionary] = [
	{"id": "house", "type": "CUE", "name": "HOUSE CUE", "body": "Reliable. No bonus, no risk.", "bank": 0, "combo": 0, "shots": 0, "cash": 0, "rail": 0, "guard": 0, "scratch": 0, "side": 0, "tier": 0},
	{"id": "surveyor", "type": "CUE", "name": "THE SURVEYOR", "body": "+10 bank bonus. Longer rail preview.", "bank": 10, "combo": 0, "shots": 0, "cash": 0, "rail": 2, "guard": 0, "scratch": 0, "side": 0, "tier": 1},
	{"id": "deadweight", "type": "CUE", "name": "DEADWEIGHT", "body": "Heavy cue: +6 bank, +1 shot on heavies tables.", "bank": 6, "combo": 0, "shots": 1, "cash": 0, "rail": 0, "guard": 0, "scratch": 0, "side": 0, "tier": 1},
	{"id": "threader", "type": "CUE", "name": "THE THREADER", "body": "+1 shot, +4 combo. For combo hunters.", "bank": 0, "combo": 4, "shots": 1, "cash": 0, "rail": 0, "guard": 0, "scratch": 0, "side": 0, "tier": 2},
	{"id": "bankers_chalk", "type": "CHALK", "name": "BANKER'S CHALK", "body": "+8 bank bonus on every future table.", "bank": 8, "combo": 0, "shots": 0, "cash": 0, "rail": 0, "guard": 0, "scratch": 0, "side": 0, "tier": 1},
	{"id": "chain_chalk", "type": "CHALK", "name": "CHAIN CHALK", "body": "+10% multi-ball combo multiplier.", "bank": 0, "combo": 10, "shots": 0, "cash": 0, "rail": 0, "guard": 0, "scratch": 0, "side": 0, "tier": 1},
	{"id": "rail_chalk", "type": "CHALK", "name": "RAIL CHALK", "body": "+3 per rail contact, every shot.", "bank": 0, "combo": 0, "shots": 0, "cash": 0, "rail": 3, "guard": 0, "scratch": 0, "side": 0, "tier": 2},
	{"id": "steady_chalk", "type": "CHALK", "name": "STEADY CHALK", "body": "Keep your streak through one miss.", "bank": 0, "combo": 0, "shots": 0, "cash": 0, "rail": 0, "guard": 1, "scratch": 0, "side": 0, "tier": 2},
	{"id": "lucky_felt", "type": "RELIC", "name": "LUCKY FELT", "body": "+1 shot on the next encounter.", "bank": 0, "combo": 0, "shots": 1, "cash": 0, "rail": 0, "guard": 0, "scratch": 0, "side": 0, "tier": 1},
	{"id": "house_payout", "type": "RELIC", "name": "HOUSE PAYOUT", "body": "+45 cash for the next route decision.", "bank": 0, "combo": 0, "shots": 0, "cash": 45, "rail": 0, "guard": 0, "scratch": 0, "side": 0, "tier": 1},
	{"id": "corked_case", "type": "RELIC", "name": "CORKED CASE", "body": "Forgive one scratch this run.", "bank": 0, "combo": 0, "shots": 0, "cash": 0, "rail": 0, "guard": 0, "scratch": 1, "side": 0, "tier": 2},
	{"id": "side_action", "type": "RELIC", "name": "SIDE ACTION", "body": "Side pockets pay +12.", "bank": 0, "combo": 0, "shots": 0, "cash": 0, "rail": 0, "guard": 0, "scratch": 0, "side": 12, "tier": 2},
	{"id": "tally_chalk", "type": "CHALK", "name": "TALLY CHALK", "body": "+5 combo and +4 bank on every future table.", "bank": 4, "combo": 5, "shots": 0, "cash": 0, "rail": 0, "guard": 0, "scratch": 0, "side": 0, "tier": 1},
	{"id": "house_ledger", "type": "RELIC", "name": "HOUSE LEDGER", "body": "+60 cash now and +1 shot on the next table.", "bank": 0, "combo": 0, "shots": 1, "cash": 60, "rail": 0, "guard": 0, "scratch": 0, "side": 0, "tier": 2},
	{"id": "kick_sight", "type": "CUE", "name": "KICK SIGHT", "body": "+1 shot, +6 bank. Kick lines hold their speed.", "bank": 6, "combo": 0, "shots": 1, "cash": 0, "rail": 1, "guard": 0, "scratch": 0, "side": 0, "tier": 1},
	{"id": "carom_caller", "type": "CUE", "name": "CAROM CALLER", "body": "+8 combo. Caroms count toward your streak.", "bank": 0, "combo": 8, "shots": 0, "cash": 0, "rail": 0, "guard": 0, "scratch": 0, "side": 0, "tier": 1},
	{"id": "soft_touch", "type": "CHALK", "name": "SOFT TOUCH", "body": "+4 bank, +3 combo. Soft shots keep rolling.", "bank": 4, "combo": 3, "shots": 0, "cash": 0, "rail": 0, "guard": 0, "scratch": 0, "side": 0, "tier": 1},
	{"id": "rail_runner", "type": "CHALK", "name": "RAIL RUNNER", "body": "+2 per rail contact, +4 bank.", "bank": 4, "combo": 0, "shots": 0, "cash": 0, "rail": 2, "guard": 0, "scratch": 0, "side": 0, "tier": 1},
	{"id": "second_wind", "type": "RELIC", "name": "SECOND WIND", "body": "+1 shot next table, forgive one miss streak.", "bank": 0, "combo": 0, "shots": 1, "cash": 0, "rail": 0, "guard": 1, "scratch": 0, "side": 0, "tier": 2},
	{"id": "corner_office", "type": "RELIC", "name": "CORNER OFFICE", "body": "Side pockets pay +12, +1 shot on open tables.", "bank": 0, "combo": 0, "shots": 1, "cash": 0, "rail": 0, "guard": 0, "scratch": 0, "side": 12, "tier": 2},
	{"id": "cushion_credit", "type": "CHALK", "name": "CUSHION CREDIT", "body": "+6 per rail contact, +2 bank on a banked pot.", "bank": 2, "combo": 0, "shots": 0, "cash": 0, "rail": 6, "guard": 0, "scratch": 0, "side": 0, "tier": 1},
	{"id": "long_rail", "type": "CUE", "name": "THE LONG RAIL", "body": "+9 per rail contact, +1 shot next table.", "bank": 0, "combo": 0, "shots": 1, "cash": 0, "rail": 9, "guard": 0, "scratch": 0, "side": 0, "tier": 2},
	{"id": "rail_relay", "type": "RELIC", "name": "RAIL RELAY", "body": "+7 per rail contact, keep one streak through a miss.", "bank": 0, "combo": 0, "shots": 0, "cash": 0, "rail": 7, "guard": 1, "scratch": 0, "side": 0, "tier": 2},
	{"id": "safety_chalk", "type": "CHALK", "name": "SAFETY CHALK", "body": "Keep one streak through a miss.", "bank": 0, "combo": 0, "shots": 0, "cash": 0, "rail": 0, "guard": 1, "scratch": 0, "side": 0, "tier": 1},
	{"id": "cork_board", "type": "RELIC", "name": "CORK BOARD", "body": "Forgive two scratches this run.", "bank": 0, "combo": 0, "shots": 0, "cash": 0, "rail": 0, "guard": 0, "scratch": 2, "side": 0, "tier": 2},
	{"id": "house_mark", "type": "CUE", "name": "THE HOUSE MARK", "body": "Parking on the brass spot pays +15 and returns a shot every time.", "bank": 0, "combo": 0, "shots": 0, "cash": 0, "rail": 0, "guard": 0, "scratch": 0, "side": 0, "spot": 1, "tier": 2},
]
var flash_time := 0.0
var hitstop_time := 0.0
var animation_time := 0.0
var shake_trauma := 0.0
var shake_offset := Vector2.ZERO
var particles: Array[Dictionary] = []
var floaters: Array[Dictionary] = []
# Presentation-only motion: trails show where a ball has been, flashes mark
# the mouth it dropped into. Neither feeds back into the simulation.
var ball_trails: Dictionary = {}
var pocket_flashes: Array[Dictionary] = []
var settings_high_contrast := false
var settings_fast_resolve := false
var settings_reduced_flash := false
var settings_no_shake := false
var settings_guide := 1.0
var settings_volume := 0.8
var settings_house_cam := true
# The stick is drawn from its tip backwards; a short strike timer keeps the
# thrust visible for a beat after the cue ball has already left.
var cue_strike := 0.0
var cue_strike_pos := Vector2.ZERO
var cue_strike_dir := Vector2.RIGHT
# HOUSE CAM: a short slow-motion inset of a highlight pot. It records ball
# positions while the shot rolls and plays after scoring without ever holding
# up the next shot, the way a broadcast replay plays beside live play.
const HOUSE_CAM_SECONDS := 3.0
const HOUSE_CAM_STEP := 1.0 / 30.0
const HOUSE_CAM_MAX_FRAMES := 300
var house_cam_active := false
var house_cam_time := 0.0
var house_cam_duration := HOUSE_CAM_SECONDS
var house_cam_caption := ""
var house_cam_detail := ""
var house_cam_frames: Array[Dictionary] = []
var house_cam_marks: Array[Vector2] = []
var house_cam_bbox := Rect2()
var house_cam_clock := 0.0
# THE HOUSE'S SPOT: one brass ring on the felt per table. Pot a ball and leave
# the cue ball on it to earn a position bonus. It is the only rule that pays for
# where the cue stops, so every shot becomes two questions: did it drop, and did
# you leave yourself a good table?
const HOUSE_SPOT_RADIUS := 34.0
var house_spot := Vector2.ZERO
var house_spot_hits := 0
var house_spot_table_hits := 0
var house_spot_paid_shot := false
var house_spot_flash := 0.0
# A CONTROL build piece can turn the brass ring into a repeatable engine: every
# park pays bigger and returns the shot, not only the first one per rack.
var house_spot_boost := 0
var collection: Array[String] = []
var codex_seen: Array[String] = []
var menu_return_screen := "title"
var vault_return := "title"
var audio_players: Array[AudioStreamPlayer] = []
var sfx_cursor := 0
var sfx_cache: Dictionary = {}
var save_path := "user://rack_ruin_save.cfg"
var run_save_path := "user://rack_ruin_run.cfg"
var run_log: Array = []
var portal := PortalSDKScript.new()
var audio_unlocked := false
var paused := false
var hud_root: Control
var hud_run_label: Label
var hud_shot_label: Label
var hud_contract_label: Label
var hud_par_label: Label
var hud_contract_fill: ColorRect
var hud_result_label: Label
var hud_cue_label: Label
var hud_build_label: Label
var hud_guard_label: Label
var hud_mods_label: Label
var hud_set_label: Label
var hud_coach_label: Label
var hud_coach_step: Label
var hud_heat_label: Label
var hud_heat_button: Button
var hud_heat_fill: ColorRect
var hud_power_label: Label
var hud_power_fill: ColorRect
var hud_fire_button: Button
var pause_overlay: Control
var challenge_input: LineEdit
var challenge_error: Label
var halo_ready: StyleBoxFlat
var halo_pending: StyleBoxFlat
var reputation := 0
var best_score := 0
var total_runs := 0
# Daily challenge: one seeded tour per calendar day, identical for every
# player. Streak and best live in meta so a portal session can come back
# tomorrow and see what the visit earned.
var daily_active := false
var daily_key := ""
var daily_streak := 0
var daily_last_date := ""
var daily_best := 0
var daily_best_key := ""
# A daily pays reputation once per calendar day: replays are for the score and
# the streak, not the fastest rep farm in the game.
var daily_rep_key := ""
var last_rep_gain := 0
# THE GRIND is the endless rack mode: procedural tables until the line breaks.
# It is a session run, so the mode is not saved mid-rack; the records are.
var gauntlet_active := false
var gauntlet_best_stage := 0
var gauntlet_best_score := 0
# A Grind rack that beats par banks one extra shot for the next rack. It is
# consumed when that rack is built, so the chase rewards overachieving now
# without turning into a permanent budget increase.
var grind_par_shots := 0
# A set's first multi-pot refund is once per table: without that cap, a COMBO
# build could turn one lucky rack into an infinite shot bank.
var set_combo_shot_used := false
# A pace split is the cumulative run score after each cleared rack in the best
# run. The next run races that snapshot, so the record chase has a visible
# rival instead of a number that only changes after the run is over.
var grind_pace_splits: Array[int] = []
# THE DAILY LADDER: one date-seeded Grind sequence for every player, played
# under base rules with no vault perks. Best depth, streak and today's payout
# guard live beside the free-run record.
var grind_daily_active := false
var grind_daily_key := ""
var grind_daily_best_stage := 0
var grind_daily_best_score := 0
var grind_daily_last_date := ""
var grind_daily_streak := 0
var grind_daily_rep_key := ""
var grind_daily_pace_splits: Array[int] = []
# Per-run copies: the target is snapshotted at start so a run races the record
# it began against, never itself.
var run_pace_splits: Array[int] = []
var run_pace_target: Array[int] = []
# First-shot coach: three check-off steps on the first table a new player sees.
# It retires itself when they fire, so it never becomes a permanent tutorial.
var tutorial_seen := false
var coach_active := false
var coach_aimed := false
var coach_powered := false
# THE CUE CASE: cosmetic finishes for the stick the player holds. They are
# earned by trophies, never bought, so a finish is a scar from a real milestone
# and the trophy shelf pays off in every shot. Only the look changes.
const CUE_FINISHES := [
	{"id": "ash", "name": "HOUSE ASH", "note": "The plain cue every tour begins with.", "trophy": "", "butt": "#9a6a3a", "wrap": "#5d3d22", "shaft": "#e7dcc4", "accent": "#f2bd58"},
	{"id": "brass", "name": "BRASS & BLACK", "note": "Clear your first table.", "trophy": "first_break", "butt": "#262c31", "wrap": "#b8894a", "shaft": "#e3d3b0", "accent": "#f2bd58"},
	{"id": "ivory", "name": "OLD IVORY", "note": "Score 80 on a single shot.", "trophy": "sharp_shot", "butt": "#efe6d2", "wrap": "#2f5d4f", "shaft": "#f7efdd", "accent": "#b07c3c"},
	{"id": "carbon", "name": "CARBON", "note": "Pocket in five straight shots.", "trophy": "on_a_run", "butt": "#1b1f24", "wrap": "#3a4048", "shaft": "#c9d1d6", "accent": "#8fe1bd"},
	{"id": "oxblood", "name": "THE CLOSER", "note": "Win five House Duels in a row.", "trophy": "house_regular", "butt": "#5b1e22", "wrap": "#9c4a3c", "shaft": "#e6dcc4", "accent": "#ef6b64"},
	{"id": "house", "name": "THE HOUSE'S OWN", "note": "Beat The House at its true form.", "trophy": "unmasked", "butt": "#141a1e", "wrap": "#b02a26", "shaft": "#d8cbb8", "accent": "#f2bd58"},
]
var cue_finish := "ash"
# Reputation buys permanent upgrades in THE VAULT. Unlocks are stored by id
# and only ever applied to normal runs; dailies stay level for everyone.
var unlocks: Array[String] = []
var permanent_shot_bonus := 0
var vault_items: Array[Dictionary] = [
	{"id": "cue_rack", "name": "THE SURVEYOR", "body": "Start every run with THE SURVEYOR: +10 bank on every table and a longer rail preview.", "cost": 5},
	{"id": "allowance", "name": "FELT ALLOWANCE", "body": "One extra shot on every table of every tour.", "cost": 9},
	{"id": "house_credit", "name": "HOUSE CREDIT", "body": "Start every run with 80 cash instead of 60 — any shop piece, plus a reroll.", "cost": 14},
]
# Trophies are the long-term shelf: each one is a milestone that pays
# reputation once. Stats settle at the end of a tour, so a trophy can never
# unlock from a shot that was later cancelled by leaving the table.
var trophies: Array[String] = []
var runs_finished := 0
var wins := 0
var tables_cleared := 0
var best_tables := 0
var best_shot_ever := 0
var best_streak_ever := 0
var bosses_beaten := 0
var best_bosses_in_run := 0
var scouted: Array[String] = []
var dailies_played := 0
var best_daily_streak := 0
var best_build := 0
var best_set_tier := 0
var best_sets_in_run := 0
var stake2_wins := 0
var run_bosses_beaten := 0
var daily_reset_label: Label
var daily_label_timer := 0.0
var toast_layer: CanvasLayer
var toast_root: Control

func _ready() -> void:
	portal.notify_loading_start()
	_build_audio()
	_load_meta()
	_build_map()
	_build_screen_root()
	_show_title()
	portal.notify_loading_done()
	queue_redraw()

func _build_audio() -> void:
	# Eight players: a break shot layers rail, contact and pocket sounds inside
	# the same few frames, and four voices cut each other off.
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		audio_players.append(p)

func _sfx(kind: String, volume_db := 0.0) -> void:
	# Hook points for the SFX artist: one named event per game moment.
	# Procedural placeholder tone so the game is playable with no assets.
	# Browsers block audio before the first user gesture; the first call that
	# matters always follows a button press, which unlocks the context.
	if audio_players.is_empty():
		return
	if portal.is_muted_by_portal() or settings_volume <= 0.0:
		return
	if portal.is_web() and not audio_unlocked:
		audio_unlocked = true
	# Buffers are baked once per kind, two noise variants each. A break fires
	# twenty contact events in a few frames; rebuilding a wave for every one of
	# them stalled the main thread on phones and made the table sound like one
	# click repeated. Volume is applied per play, so the volume setting still
	# takes effect without re-baking.
	var variants: Array = sfx_cache.get(kind, [])
	if variants.is_empty():
		variants = [_bake_sfx(kind, 0), _bake_sfx(kind, 1)]
		sfx_cache[kind] = variants
	var p: AudioStreamPlayer = audio_players[sfx_cursor % audio_players.size()]
	sfx_cursor += 1
	p.stream = variants[sfx_cursor % variants.size()]
	p.volume_db = volume_db + linear_to_db(clampf(settings_volume, 0.01, 1.0))
	p.play()

func _bake_sfx(kind: String, variant: int) -> AudioStreamWAV:
	# Each event is a short pitched body plus a noise transient: a pure sine
	# reads as a menu beep, while felt and balls need the click of a real hit.
	var freq := 440.0
	var freq_end := 440.0
	var dur := 0.08
	var noise := 0.0
	var gain := 0.55
	var arpeggio := false
	match kind:
		"fire":
			freq = 168.0
			freq_end = 96.0
			dur = 0.15
			noise = 0.28
			gain = 0.7
		"rail":
			freq = 620.0
			freq_end = 380.0
			dur = 0.055
			noise = 0.82
			gain = 0.42
		"pocket":
			freq = 760.0
			freq_end = 420.0
			dur = 0.17
			noise = 0.35
			gain = 0.72
		"scratch":
			freq = 150.0
			freq_end = 80.0
			dur = 0.28
			noise = 0.45
			gain = 0.7
		"reward":
			freq = 560.0
			freq_end = 880.0
			dur = 0.20
			gain = 0.55
		"click":
			freq = 520.0
			freq_end = 440.0
			dur = 0.045
			noise = 0.15
			gain = 0.34
		"boss":
			freq = 104.0
			freq_end = 58.0
			dur = 0.5
			noise = 0.18
			gain = 0.8
		"ball_click":
			freq = 780.0
			freq_end = 520.0
			dur = 0.045
			noise = 0.55
			gain = 0.4
		"foul":
			freq = 300.0
			freq_end = 210.0
			dur = 0.18
			noise = 0.22
			gain = 0.55
		"streak":
			freq = 820.0
			freq_end = 1240.0
			dur = 0.12
			gain = 0.45
		"bank":
			freq = 700.0
			freq_end = 940.0
			dur = 0.16
			gain = 0.5
		"cash":
			freq = 1080.0
			freq_end = 1480.0
			dur = 0.12
			gain = 0.42
		"victory":
			freq = 520.0
			freq_end = 780.0
			dur = 0.42
			arpeggio = true
			gain = 0.65
		"defeat":
			freq = 210.0
			freq_end = 128.0
			dur = 0.36
			gain = 0.6
	# A hair of detune per variant: two identical clicks on one break sound
	# like a machine gun, two slightly different ones sound like a rack.
	var bend := 1.0 + 0.06 * float(variant)
	freq *= bend
	freq_end *= bend
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(n)
		var f := lerpf(freq, freq_end, t)
		if arpeggio:
			# A rising triad reads as a win; a sliding tone reads as a slide.
			f = freq * [1.0, 1.26, 1.5][int(t * 3.0)]
		phase += TAU * f / float(rate)
		var env := pow(1.0 - t, 2.4)
		var attack := minf(1.0, float(i) / 40.0)
		var tone := sin(phase) + 0.3 * sin(phase * 2.0)
		var sample := tone * (1.0 - noise) + randf_range(-1.0, 1.0) * noise
		var v := int(clampf(sample * env * attack * gain * 12000.0, -32768.0, 32767.0))
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav

func _load_meta() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) == OK:
		reputation = int(cfg.get_value("meta", "reputation", 0))
		best_score = int(cfg.get_value("meta", "best_score", 0))
		total_runs = int(cfg.get_value("meta", "total_runs", 0))
		run_log = cfg.get_value("meta", "run_log", [])
		daily_streak = int(cfg.get_value("meta", "daily_streak", 0))
		daily_last_date = str(cfg.get_value("meta", "daily_last_date", ""))
		daily_best = int(cfg.get_value("meta", "daily_best", 0))
		daily_best_key = str(cfg.get_value("meta", "daily_best_key", ""))
		daily_rep_key = str(cfg.get_value("meta", "daily_rep_key", ""))
		tutorial_seen = bool(cfg.get_value("meta", "tutorial_seen", false))
		unlocks = Array(cfg.get_value("meta", "unlocks", []), TYPE_STRING, "", null)
		trophies = Array(cfg.get_value("meta", "trophies", []), TYPE_STRING, "", null)
		# A finish removed from the catalog (or an old save) must never leave a
		# player holding an invisible cue.
		cue_finish = str(cfg.get_value("meta", "cue_finish", "ash"))
		if _cue_finish_index(cue_finish) < 0:
			cue_finish = "ash"
		last_signed_contract = str(cfg.get_value("meta", "last_contract", "mark"))
		runs_finished = int(cfg.get_value("meta", "runs_finished", 0))
		wins = int(cfg.get_value("meta", "wins", 0))
		tables_cleared = int(cfg.get_value("meta", "tables_cleared", 0))
		best_tables = int(cfg.get_value("meta", "best_tables", 0))
		best_shot_ever = int(cfg.get_value("meta", "best_shot_ever", 0))
		best_streak_ever = int(cfg.get_value("meta", "best_streak_ever", 0))
		bosses_beaten = int(cfg.get_value("meta", "bosses_beaten", 0))
		best_bosses_in_run = int(cfg.get_value("meta", "best_bosses_in_run", 0))
		scouted = Array(cfg.get_value("meta", "scouted", []), TYPE_STRING, "", null)
		dailies_played = int(cfg.get_value("meta", "dailies_played", 0))
		best_daily_streak = int(cfg.get_value("meta", "best_daily_streak", 0))
		best_build = int(cfg.get_value("meta", "best_build", 0))
		best_set_tier = int(cfg.get_value("meta", "best_set_tier", 0))
		best_sets_in_run = int(cfg.get_value("meta", "best_sets_in_run", 0))
		house_spot_hits = int(cfg.get_value("meta", "house_spot_hits", 0))
		stake2_wins = int(cfg.get_value("meta", "stake2_wins", 0))
		house_calls = int(cfg.get_value("meta", "house_calls", 0))
		house_shutouts = int(cfg.get_value("meta", "house_shutouts", 0))
		house_grudge = str(cfg.get_value("meta", "house_grudge", ""))
		if not HOUSE_GRUDGES.has(house_grudge):
			house_grudge = ""
		grudges_settled = int(cfg.get_value("meta", "grudges_settled", 0))
		duel_wins = int(cfg.get_value("meta", "duel_wins", 0))
		duel_streak = int(cfg.get_value("meta", "duel_streak", 0))
		duel_best_streak = int(cfg.get_value("meta", "duel_best_streak", 0))
		duel_best_form = clampi(int(cfg.get_value("meta", "duel_best_form", 0)), 0, DUEL_FORMS.size())
		duel_couch_p1 = maxi(int(cfg.get_value("meta", "duel_couch_p1", 0)), 0)
		duel_couch_p2 = maxi(int(cfg.get_value("meta", "duel_couch_p2", 0)), 0)
		gauntlet_best_stage = int(cfg.get_value("meta", "grind_best_stage", 0))
		gauntlet_best_score = int(cfg.get_value("meta", "grind_best_score", 0))
		grind_daily_key = str(cfg.get_value("meta", "grind_daily_key", ""))
		grind_daily_best_stage = int(cfg.get_value("meta", "grind_daily_best_stage", 0))
		grind_daily_best_score = int(cfg.get_value("meta", "grind_daily_best_score", 0))
		grind_daily_last_date = str(cfg.get_value("meta", "grind_daily_last_date", ""))
		grind_daily_streak = int(cfg.get_value("meta", "grind_daily_streak", 0))
		grind_daily_rep_key = str(cfg.get_value("meta", "grind_daily_rep_key", ""))
		grind_pace_splits = Array(cfg.get_value("meta", "grind_pace_splits", []), TYPE_INT, "", null)
		grind_daily_pace_splits = Array(cfg.get_value("meta", "grind_daily_pace_splits", []), TYPE_INT, "", null)
	# Settings persist too: a player who sets 35% volume or high contrast in a
	# portal session expects the next session to open the same way.
		settings_high_contrast = bool(cfg.get_value("settings", "high_contrast", false))
		settings_fast_resolve = bool(cfg.get_value("settings", "fast_resolve", false))
		settings_reduced_flash = bool(cfg.get_value("settings", "reduced_flash", false))
		settings_no_shake = bool(cfg.get_value("settings", "no_shake", false))
		settings_guide = 0.55 if float(cfg.get_value("settings", "guide", 1.0)) < 0.9 else 1.0
		settings_volume = clampf(float(cfg.get_value("settings", "volume", 0.8)), 0.0, 1.0)
		settings_house_cam = bool(cfg.get_value("settings", "house_cam", true))
		audio_unlocked = false
		portal.set_portal_muted(settings_volume <= 0.0)

func _save_meta() -> void:
	# Incognito / blocked storage must never break the game: ignore errors.
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "reputation", reputation)
	cfg.set_value("meta", "best_score", best_score)
	cfg.set_value("meta", "total_runs", total_runs)
	cfg.set_value("meta", "run_log", run_log)
	cfg.set_value("meta", "daily_streak", daily_streak)
	cfg.set_value("meta", "daily_last_date", daily_last_date)
	cfg.set_value("meta", "daily_best", daily_best)
	cfg.set_value("meta", "daily_best_key", daily_best_key)
	cfg.set_value("meta", "daily_rep_key", daily_rep_key)
	cfg.set_value("meta", "tutorial_seen", tutorial_seen)
	cfg.set_value("meta", "unlocks", unlocks)
	cfg.set_value("meta", "trophies", trophies)
	cfg.set_value("meta", "cue_finish", cue_finish)
	cfg.set_value("meta", "runs_finished", runs_finished)
	cfg.set_value("meta", "last_contract", last_signed_contract)
	cfg.set_value("meta", "wins", wins)
	cfg.set_value("meta", "tables_cleared", tables_cleared)
	cfg.set_value("meta", "best_tables", best_tables)
	cfg.set_value("meta", "best_shot_ever", best_shot_ever)
	cfg.set_value("meta", "best_streak_ever", best_streak_ever)
	cfg.set_value("meta", "bosses_beaten", bosses_beaten)
	cfg.set_value("meta", "best_bosses_in_run", best_bosses_in_run)
	cfg.set_value("meta", "scouted", scouted)
	cfg.set_value("meta", "dailies_played", dailies_played)
	cfg.set_value("meta", "best_daily_streak", best_daily_streak)
	cfg.set_value("meta", "best_build", best_build)
	cfg.set_value("meta", "best_set_tier", best_set_tier)
	cfg.set_value("meta", "best_sets_in_run", best_sets_in_run)
	cfg.set_value("meta", "house_spot_hits", house_spot_hits)
	cfg.set_value("meta", "stake2_wins", stake2_wins)
	cfg.set_value("meta", "house_calls", house_calls)
	cfg.set_value("meta", "house_shutouts", house_shutouts)
	cfg.set_value("meta", "house_grudge", house_grudge)
	cfg.set_value("meta", "grudges_settled", grudges_settled)
	cfg.set_value("meta", "duel_wins", duel_wins)
	cfg.set_value("meta", "duel_streak", duel_streak)
	cfg.set_value("meta", "duel_best_streak", duel_best_streak)
	cfg.set_value("meta", "duel_best_form", duel_best_form)
	cfg.set_value("meta", "duel_couch_p1", duel_couch_p1)
	cfg.set_value("meta", "duel_couch_p2", duel_couch_p2)
	cfg.set_value("meta", "grind_best_stage", gauntlet_best_stage)
	cfg.set_value("meta", "grind_best_score", gauntlet_best_score)
	cfg.set_value("meta", "grind_daily_key", grind_daily_key)
	cfg.set_value("meta", "grind_daily_best_stage", grind_daily_best_stage)
	cfg.set_value("meta", "grind_daily_best_score", grind_daily_best_score)
	cfg.set_value("meta", "grind_daily_last_date", grind_daily_last_date)
	cfg.set_value("meta", "grind_daily_streak", grind_daily_streak)
	cfg.set_value("meta", "grind_daily_rep_key", grind_daily_rep_key)
	cfg.set_value("meta", "grind_pace_splits", grind_pace_splits)
	cfg.set_value("meta", "grind_daily_pace_splits", grind_daily_pace_splits)
	var err := cfg.save(save_path)
	if err != OK:
		push_warning("meta save unavailable (portal storage blocked)")

func _save_settings() -> void:
	# Settings share the meta file but never rewrite the sections they do not
	# own, so a volume change cannot drop the run history by mistake.
	var cfg := ConfigFile.new()
	cfg.load(save_path)
	cfg.set_value("settings", "high_contrast", settings_high_contrast)
	cfg.set_value("settings", "fast_resolve", settings_fast_resolve)
	cfg.set_value("settings", "reduced_flash", settings_reduced_flash)
	cfg.set_value("settings", "no_shake", settings_no_shake)
	cfg.set_value("settings", "guide", settings_guide)
	cfg.set_value("settings", "volume", settings_volume)
	cfg.set_value("settings", "house_cam", settings_house_cam)
	if cfg.save(save_path) != OK:
		push_warning("settings save unavailable (portal storage blocked)")

# --- Daily challenge -----------------------------------------------------

func _today_key() -> String:
	return Time.get_date_string_from_system()

func _pretty_date(date_key: String) -> String:
	const MONTHS := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
	var parts := date_key.split("-")
	if parts.size() != 3:
		return date_key
	var month := clampi(int(parts[1]), 1, 12)
	return "%s %d" % [MONTHS[month - 1], int(parts[2])]

func _daily_seed_for(date_key: String) -> int:
	# Date-as-seed keeps every player's tour identical without a server.
	var digits := date_key.replace("-", "")
	if not digits.is_valid_int():
		return 20260101
	return int(digits)

# THE HOUSE'S TERMS: a run archetype chosen before the first table. The Mark
# is the untouched game and the safe first pick; the other three are real
# bargains. Score multipliers reshape what a pot is worth, so a Banker run
# hunts cushions and a Collector run hunts clusters instead of playing the same
# route with a different number. Costs are paid in the universal currency,
# shots, so a term changes decisions even on a clear contract.
const RUN_CONTRACTS := [
	{"id": "mark", "name": "THE MARK", "tagline": "Play it straight. The House has no read on you.",
		"edge": "No cut. The standard table, the standard pay.", "cost": "No cost. The honest game.",
		"cash": 0, "shots": 0, "bank": 0, "combo": 0, "rail": 0, "clear": 0, "foul_extra": false,
		"bank_mult": 1.0, "direct_mult": 1.0, "multi_mult": 1.0, "single_mult": 1.0},
	{"id": "banker", "name": "THE BANKER", "tagline": "Every cushion is collateral.",
		"edge": "Banked pots pay +60%. +18 bank pay and +2 per cushion.", "cost": "One fewer shot per table. Direct pots score 25% less.",
		"cash": 0, "shots": -1, "bank": 18, "combo": 0, "rail": 2, "clear": 0, "foul_extra": false,
		"bank_mult": 1.6, "direct_mult": 0.75, "multi_mult": 1.0, "single_mult": 1.0},
	{"id": "collector", "name": "THE COLLECTOR", "tagline": "Interest compounds.",
		"edge": "Multi-ball pots pay +60%. +8% combo pay.", "cost": "One fewer shot per table. Single pots score 20% less.",
		"cash": 0, "shots": -1, "bank": 0, "combo": 8, "rail": 0, "clear": 0, "foul_extra": false,
		"bank_mult": 1.0, "direct_mult": 1.0, "multi_mult": 1.6, "single_mult": 0.8},
	{"id": "grifter", "name": "THE GRIFTER", "tagline": "Cash now. Answers later.",
		"edge": "+40 opening cash. +20 cash for every table cleared.", "cost": "One fewer shot per table. Scratches cost an extra shot.",
		"cash": 40, "shots": -1, "bank": 0, "combo": 0, "rail": 0, "clear": 20, "foul_extra": true,
		"bank_mult": 1.0, "direct_mult": 1.0, "multi_mult": 1.0, "single_mult": 1.0},
]

# One twist per day, chosen by the date's route seed. Most map to a run
# modifier the game already understands; the table rules rebuild the rack
# itself (no blocks, closed side pockets, slick felt), so the daily is a
# featured mode rather than a second ruleset to balance.
const DAILY_TWISTS := [
	{"id": "rail_week", "name": "RAIL WEEK", "body": "EVERY RAIL BOUNCE PAYS +3", "rail": 3},
	{"id": "deep_felt", "name": "DEEP FELT", "body": "BANK SHOTS PAY +8", "bank": 8},
	{"id": "side_action", "name": "SIDE ACTION", "body": "SIDE POCKETS PAY +8", "side": 8},
	{"id": "opening_credit", "name": "OPENING CREDIT", "body": "START WITH 80 CASH", "cash": 20},
	{"id": "loose_felt", "name": "LOOSE FELT", "body": "+1 SHOT ON EVERY TABLE", "shots": 1},
	{"id": "open_table", "name": "OPEN TABLE", "body": "NO BLOCKS ON ROUTE TABLES", "table": "open", "table_hint": "Daily rule: route tables have no blocks today. Take the direct line."},
	{"id": "corner_only", "name": "CORNER ONLY", "body": "SIDE POCKETS ARE CLOSED", "table": "corner", "table_hint": "Daily rule: side pockets are closed today. Corner pockets only."},
	{"id": "slick_felt", "name": "SLICK FELT", "body": "BALLS ROLL LONGER", "table": "fast", "table_hint": "Daily rule: slick felt. Balls roll longer, so play softer."},
]

# THE HOUSE REMEMBERS. A tour that wins its way past the House teaches it one
# habit, and the next finale charges a tax on exactly that habit. Each grudge
# is announced before the player commits, is worth +2 REP to settle, and only
# ever touches the final House rack. A win with no dominant habit leaves it
# with no read at all, so changing the build is the way to stay unpredictable.
const HOUSE_GRUDGES := {
	"rails": {
		"name": "THE RAIL TAX",
		"bark": "You banked me out of my own house. The rails are mine now.",
		"tell": "You beat it off the rails.",
		"rule": "Banked pots pay half on this table.",
		"tag": "RAILS PAY HALF",
	},
	"streak": {
		"name": "THE LONG NIGHT",
		"bark": "You ran five straight and smiled. I have seen that before.",
		"tell": "You buried it under a long streak.",
		"rule": "It opens with one pocket already bolted shut.",
		"tag": "ONE POCKET BOLTED",
	},
	"chain": {
		"name": "THE SPLIT",
		"bark": "You took two at a time. I will not let the rack gather again.",
		"tell": "You chained multi-ball pots.",
		"rule": "Multi-ball pots pay 40% less on this table.",
		"tag": "CHAINS TAXED",
	},
	"scratch": {
		"name": "THE EARLY CALL",
		"bark": "You bled on my felt and still walked out. I do not wait for half now.",
		"tell": "You survived on scratches.",
		"rule": "It takes the table at a third of its number, not half.",
		"tag": "EARLY PHASE TWO",
	},
}

# The trophy shelf. `stat` names a persistent counter, `target` its threshold;
# the "unlocks" stat targets the full vault rather than a fixed number, so the
# shelf stays correct when the vault grows.
const TROPHIES := [
	{"id": "first_break", "name": "FIRST BREAK", "body": "Clear your first table.", "rep": 1, "stat": "tables_cleared", "target": 1},
	{"id": "opening_night", "name": "OPENING NIGHT", "body": "Finish a tour, win or lose.", "rep": 1, "stat": "runs_finished", "target": 1},
	{"id": "house_falls", "name": "THE HOUSE FALLS", "body": "Win a tour by beating The House.", "rep": 3, "stat": "wins", "target": 1},
	{"id": "lockpick", "name": "LOCKPICK", "body": "Beat The Locksmith.", "rep": 1, "stat": "bosses_beaten", "target": 1},
	{"id": "two_gates", "name": "BOTH GATES", "body": "Beat both bosses in one tour.", "rep": 2, "stat": "best_bosses_in_run", "target": 2},
	# A route passes through at most five table nodes (0, one of 2/4/5/7,
	# 10, 11). The old six/eight asks were only "reachable" because shop and
	# event stops were counted as cleared tables; an honest counter made them
	# impossible, so the shelf now describes the real route.
	{"id": "deep_route", "name": "DEEP ROUTE", "body": "Clear four tables in one tour.", "rep": 1, "stat": "best_tables", "target": 4},
	{"id": "clean_sweep", "name": "CLEAN SWEEP", "body": "Clear five tables in one tour.", "rep": 2, "stat": "best_tables", "target": 5},
	{"id": "sharp_shot", "name": "SHARP SHOT", "body": "Score 80 on a single shot.", "rep": 1, "stat": "best_shot_ever", "target": 80},
	{"id": "on_a_run", "name": "ON A RUN", "body": "Pocket in five straight shots.", "rep": 2, "stat": "best_streak_ever", "target": 5},
	{"id": "tourist", "name": "TOURIST", "body": "Play six different tables.", "rep": 1, "stat": "scouted", "target": 6},
	{"id": "cartographer", "name": "CARTOGRAPHER", "body": "Play ten different tables.", "rep": 2, "stat": "scouted", "target": 10},
	{"id": "daily_debut", "name": "DAILY DEBUT", "body": "Play a Daily Challenge.", "rep": 1, "stat": "dailies_played", "target": 1},
	{"id": "three_days", "name": "THREE DAYS IN", "body": "Keep a three-day daily streak.", "rep": 1, "stat": "best_daily_streak", "target": 3},
	{"id": "seven_straight", "name": "SEVEN STRAIGHT", "body": "Keep a seven-day daily streak.", "rep": 2, "stat": "best_daily_streak", "target": 7},
	{"id": "first_upgrade", "name": "FIRST UPGRADE", "body": "Install a vault upgrade.", "rep": 1, "stat": "unlocks", "target": 0},
	{"id": "vault_full", "name": "FULL VAULT", "body": "Own every vault upgrade.", "rep": 1, "stat": "unlocks", "target": 0},
	{"id": "build_six", "name": "SIX-PIECE", "body": "Hold six build pieces at once.", "rep": 1, "stat": "best_build", "target": 6},
	{"id": "high_roller", "name": "HIGH ROLLER", "body": "Win a tour at Stake 2.", "rep": 2, "stat": "stake2_wins", "target": 1},
	{"id": "in_good", "name": "IN GOOD WITH THE HOUSE", "body": "Call in ten House shots.", "rep": 1, "stat": "house_calls", "target": 10},
	{"id": "shut_out", "name": "SHUT OUT", "body": "Beat The House without letting it bolt a pocket.", "rep": 2, "stat": "house_shutouts", "target": 1},
	{"id": "one_more_rack", "name": "ONE MORE RACK", "body": "Clear five tables in one Grind.", "rep": 1, "stat": "best_grind_stage", "target": 5},
	{"id": "long_night", "name": "THE LONG NIGHT", "body": "Clear ten tables in one Grind.", "rep": 2, "stat": "best_grind_stage", "target": 10},
	{"id": "dead_eye", "name": "DEAD EYE", "body": "Park the cue on the House's spot eight times.", "rep": 2, "stat": "house_spot_hits", "target": 8},
	{"id": "two_of_a_kind", "name": "TWO OF A KIND", "body": "Complete a 2-piece House Set.", "rep": 1, "stat": "best_set_tier", "target": 2},
	{"id": "full_house", "name": "FULL HOUSE", "body": "Complete a 4-piece House Set.", "rep": 2, "stat": "best_set_tier", "target": 4},
	{"id": "set_collector", "name": "SET COLLECTOR", "body": "Hold three different House Sets in one run.", "rep": 2, "stat": "best_sets_in_run", "target": 3},
	{"id": "table_rent", "name": "TABLE RENT", "body": "Beat The House in a duel.", "rep": 1, "stat": "duel_wins", "target": 1},
	{"id": "house_regular", "name": "HOUSE REGULAR", "body": "Win five House Duels in a row.", "rep": 2, "stat": "duel_best_streak", "target": 5},
	{"id": "unmasked", "name": "UNMASKED", "body": "Beat The House at its true form.", "rep": 3, "stat": "duel_best_form", "target": 4},
	{"id": "settled_up", "name": "SETTLED UP", "body": "Beat The House while it held a grudge.", "rep": 2, "stat": "grudges_settled", "target": 1},
	{"id": "no_read", "name": "NO READ", "body": "Settle three of the House's grudges.", "rep": 3, "stat": "grudges_settled", "target": 3},
]

func _daily_twist(date_key: String) -> Dictionary:
	return DAILY_TWISTS[posmod(_daily_seed_for(date_key), DAILY_TWISTS.size())]

# Table rules change the rack itself instead of the payout. Dailies use them
# as twists; the House's phase two bolts pockets through its own shot instead,
# so that rule is earned on the felt rather than declared by a card.
func _daily_table_rule() -> String:
	if not daily_active or daily_key == "":
		return ""
	return str(_daily_twist(daily_key).get("table", ""))

func _apply_table_rule(rule: String) -> void:
	match rule:
		"open":
			simulator.barriers.clear()
		"corner":
			var kept: Array[Vector2] = []
			var kinds: Array[String] = []
			for i in simulator.pockets.size():
				if str(simulator.pocket_kinds[i]) == "corner":
					kept.append(simulator.pockets[i])
					kinds.append("corner")
			simulator.pockets = kept
			simulator.pocket_kinds = kinds
		"fast":
			simulator.friction = BilliardsSimulator.BASE_FRICTION * 0.8

# Local seconds until midnight: the daily card shows when the next tour opens,
# which is what turns "played today" into a reason to come back.
func _seconds_to_daily_reset() -> int:
	var now := Time.get_datetime_dict_from_system()
	var elapsed := int(now.hour) * 3600 + int(now.minute) * 60 + int(now.second)
	return clampi(86400 - elapsed, 0, 86400)

func _daily_reset_label() -> String:
	var secs := _seconds_to_daily_reset()
	if secs >= 3600:
		return "NEW DAILY  %dH %02dM" % [int(secs / 3600.0), int(float(secs % 3600) / 60.0)]
	if secs >= 60:
		return "NEW DAILY  %dM" % int(secs / 60.0)
	return "NEW DAILY  <1M"

func _is_previous_day(previous: String, current: String) -> bool:
	if previous == "" or current == "":
		return false
	var previous_unix := Time.get_unix_time_from_datetime_string(previous + "T00:00:00")
	var current_unix := Time.get_unix_time_from_datetime_string(current + "T00:00:00")
	return int(current_unix - previous_unix) == 86400

# The daily ladder rolls over at local midnight like the daily tour, but its
# bests are separate so a great ladder cannot masquerade as a tour result.
func _refresh_grind_daily() -> void:
	var today := _today_key()
	if grind_daily_key == today:
		return
	grind_daily_key = today
	grind_daily_best_stage = 0
	grind_daily_best_score = 0
	# Today's pace belongs to today's racks: a new seed means a new chase.
	grind_daily_pace_splits.clear()

func _grind_daily_played_today() -> bool:
	return grind_daily_key == _today_key() and grind_daily_best_stage > 0

func _grind_daily_streak_now() -> int:
	var today := _today_key()
	if grind_daily_last_date == today or _is_previous_day(grind_daily_last_date, today):
		return grind_daily_streak
	return 0

# Records are written against the key the run started under, not the clock at
# its end: a ladder that crosses midnight stays on the board it began on.
func _record_grind_daily_clear() -> void:
	if grind_daily_key == "":
		return
	grind_daily_best_stage = maxi(grind_daily_best_stage, run_tables_cleared)
	grind_daily_best_score = maxi(grind_daily_best_score, run_score)

func _record_grind_daily_end() -> void:
	if run_tables_cleared <= 0 or grind_daily_key == "":
		return
	grind_daily_best_stage = maxi(grind_daily_best_stage, run_tables_cleared)
	grind_daily_best_score = maxi(grind_daily_best_score, run_score)
	if grind_daily_last_date != grind_daily_key:
		grind_daily_streak = (grind_daily_streak + 1) if _is_previous_day(grind_daily_last_date, grind_daily_key) else 1
		grind_daily_last_date = grind_daily_key

# The pace board belongs to the deepest completed run. A shorter run never
# shortens it; a deeper run replaces it, and an equal-depth run replaces it only
# with a higher final score. The live run races its own start-time snapshot.
func _merge_grind_pace(board: Array[int]) -> void:
	if run_pace_splits.size() < board.size():
		return
	if run_pace_splits.size() == board.size():
		if board.is_empty() or run_score <= int(board[board.size() - 1]):
			return
	board.clear()
	for split in run_pace_splits:
		board.append(int(split))

func _update_grind_pace() -> void:
	if run_pace_splits.is_empty():
		return
	if grind_daily_active:
		_merge_grind_pace(grind_daily_pace_splits)
	else:
		_merge_grind_pace(grind_pace_splits)

func _grind_pace_label() -> String:
	if run_tables_cleared <= 0:
		return ""
	if run_pace_target.is_empty():
		if not run_pace_splits.is_empty():
			return "PACE SET"
		return ""
	if run_tables_cleared > run_pace_target.size():
		return "PACE CLEARED"
	var delta := run_score - int(run_pace_target[run_tables_cleared - 1])
	if delta == 0:
		return "PACE EVEN"
	if delta > 0:
		return "PACE +%d" % delta
	return "PACE %d" % delta

func _start_grind_daily() -> void:
	_sfx("click")
	_refresh_grind_daily()
	gauntlet_active = true
	grind_daily_active = true
	daily_active = false
	daily_key = ""
	run_contract = "mark"
	menu_return_screen = "title"
	run_seed = _daily_seed_for(grind_daily_key)
	last_seed = run_seed
	seed_value = run_seed
	_start_run_with_seed(true)

func _record_daily_result(date_key: String, run_score_value: int) -> void:
	if date_key == "":
		return
	if daily_best_key != date_key:
		daily_best_key = date_key
		daily_best = 0
	daily_best = maxi(daily_best, run_score_value)
	if daily_last_date != date_key:
		daily_streak = (daily_streak + 1) if _is_previous_day(daily_last_date, date_key) else 1
		daily_last_date = date_key

func _start_daily() -> void:
	_sfx("click")
	gauntlet_active = false
	grind_daily_active = false
	daily_active = true
	daily_key = _today_key()
	stake = 0
	run_seed = _daily_seed_for(daily_key)
	last_seed = run_seed
	seed_value = run_seed
	_start_run_with_seed(true)

func _has_run_save() -> bool:
	return FileAccess.file_exists(run_save_path)

func _save_run() -> void:
	# Map boundaries only: never mid-shot. Storage may be blocked — ignore.
	# A daily tour deliberately never touches the save slot, so starting or
	# finishing today's challenge leaves an in-progress run intact.
	if daily_active or (current_node == -1 and map_position == 0 and run_stage <= 1):
		return
	var cfg := ConfigFile.new()
	cfg.set_value("run", "version", 1)
	cfg.set_value("run", "run_seed", run_seed)
	cfg.set_value("run", "seed_value", seed_value)
	cfg.set_value("run", "last_seed", last_seed)
	cfg.set_value("run", "stake", stake)
	cfg.set_value("run", "run_contract", run_contract)
	cfg.set_value("run", "run_stage", run_stage)
	cfg.set_value("run", "run_tables_cleared", run_tables_cleared)
	cfg.set_value("run", "run_cash", run_cash)
	cfg.set_value("run", "run_score", run_score)
	cfg.set_value("run", "run_best_shot", run_best_shot)
	cfg.set_value("run", "run_best_streak", run_best_streak)
	cfg.set_value("run", "bank_bonus", bank_bonus)
	cfg.set_value("run", "combo_bonus", combo_bonus)
	cfg.set_value("run", "rail_bonus", rail_bonus)
	cfg.set_value("run", "side_pocket_bonus", side_pocket_bonus)
	cfg.set_value("run", "house_spot_boost", house_spot_boost)
	cfg.set_value("run", "streak_guard", streak_guard)
	cfg.set_value("run", "scratch_guard", scratch_guard)
	cfg.set_value("run", "favor_available", favor_available)
	cfg.set_value("run", "next_shot_modifier", next_shot_modifier)
	# Vault perks are baked into the run when it starts; saving the shot bonus
	# keeps a continued run from losing it at the first map boundary.
	cfg.set_value("run", "permanent_shot_bonus", permanent_shot_bonus)
	cfg.set_value("run", "run_bosses_beaten", run_bosses_beaten)
	cfg.set_value("run", "active_cue", active_cue)
	cfg.set_value("run", "active_cue_id", active_cue_id)
	cfg.set_value("run", "collection", collection)
	cfg.set_value("run", "codex_seen", codex_seen)
	cfg.set_value("run", "current_node", current_node)
	cfg.set_value("run", "map_position", map_position)
	cfg.set_value("run", "map_unlocked", map_unlocked)
	var done_flags: Array = []
	for n in map_nodes:
		done_flags.append(bool(n.done))
	cfg.set_value("run", "done_flags", done_flags)
	if cfg.save(run_save_path) != OK:
		push_warning("run save unavailable (portal storage blocked)")

func _load_run() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(run_save_path) != OK:
		return false
	if int(cfg.get_value("run", "version", 0)) != 1:
		return false
	gauntlet_active = false
	grind_daily_active = false
	daily_active = false
	daily_key = ""
	run_seed = int(cfg.get_value("run", "run_seed", run_seed))
	seed_value = int(cfg.get_value("run", "seed_value", seed_value))
	last_seed = int(cfg.get_value("run", "last_seed", run_seed))
	stake = int(cfg.get_value("run", "stake", 0))
	run_contract = str(cfg.get_value("run", "run_contract", "mark"))
	run_stage = int(cfg.get_value("run", "run_stage", 1))
	run_cash = int(cfg.get_value("run", "run_cash", 60))
	run_tables_cleared = int(cfg.get_value("run", "run_tables_cleared", -1))
	run_score = int(cfg.get_value("run", "run_score", 0))
	run_best_shot = int(cfg.get_value("run", "run_best_shot", 0))
	best_streak = 0
	run_best_streak = int(cfg.get_value("run", "run_best_streak", cfg.get_value("run", "best_streak", 0)))
	bank_bonus = int(cfg.get_value("run", "bank_bonus", 0))
	combo_bonus = int(cfg.get_value("run", "combo_bonus", 0))
	rail_bonus = int(cfg.get_value("run", "rail_bonus", 0))
	side_pocket_bonus = int(cfg.get_value("run", "side_pocket_bonus", 0))
	house_spot_boost = int(cfg.get_value("run", "house_spot_boost", 0))
	streak_guard = int(cfg.get_value("run", "streak_guard", 0))
	scratch_guard = int(cfg.get_value("run", "scratch_guard", 0))
	favor_available = bool(cfg.get_value("run", "favor_available", true))
	next_shot_modifier = int(cfg.get_value("run", "next_shot_modifier", 0))
	permanent_shot_bonus = int(cfg.get_value("run", "permanent_shot_bonus", 0))
	run_bosses_beaten = int(cfg.get_value("run", "run_bosses_beaten", 0))
	active_cue = str(cfg.get_value("run", "active_cue", "House Cue"))
	active_cue_id = str(cfg.get_value("run", "active_cue_id", "house"))
	collection = Array(cfg.get_value("run", "collection", []), TYPE_STRING, "", null)
	codex_seen = Array(cfg.get_value("run", "codex_seen", []), TYPE_STRING, "", null)
	current_node = int(cfg.get_value("run", "current_node", -1))
	map_position = int(cfg.get_value("run", "map_position", 0))
	map_unlocked = Array(cfg.get_value("run", "map_unlocked", [0]), TYPE_INT, "", null)
	_build_map()
	var done_flags: Array = cfg.get_value("run", "done_flags", [])
	for i in mini(done_flags.size(), map_nodes.size()):
		map_nodes[i].done = bool(done_flags[i])
	if run_tables_cleared < 0:
		# Saves written before the counter existed: reconstruct from the route.
		run_tables_cleared = 0
		for node in map_nodes:
			if bool(node.done) and str(node.type) not in ["shop", "event"]:
				run_tables_cleared += 1
	# A save taken mid-preview (Esc from an uncleared table) must not claim
	# a current route — the node replays fresh on continue.
	if current_node >= 0 and not bool(map_nodes[current_node].done):
		current_node = -1
	menu_return_screen = "title"
	_show_map()
	return true

func _clear_run_save() -> void:
	if FileAccess.file_exists(run_save_path):
		DirAccess.remove_absolute(run_save_path)

func _build_screen_root() -> void:
	screen_root = Control.new()
	screen_root.name = "ScreenUI"
	screen_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen_root)
	# Toasts live above every screen and outside screen_root, so a milestone
	# notice never counts as a screen child or intercepts a click.
	toast_layer = CanvasLayer.new()
	toast_layer.name = "ToastUI"
	toast_layer.layer = 17
	add_child(toast_layer)
	toast_root = Control.new()
	toast_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	toast_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_layer.add_child(toast_root)
	halo_ready = _box(Color(0, 0, 0, 0), Color(0.95, 0.74, 0.35, 0.5), 12, 2)
	halo_pending = _box(Color(0, 0, 0, 0), GOLD, 12, 3)

func _process(delta: float) -> void:
	animation_time += delta
	if flash_time > 0.0:
		flash_time -= delta
	if cue_strike > 0.0:
		cue_strike = maxf(cue_strike - delta, 0.0)
	if house_spot_flash > 0.0:
		house_spot_flash = maxf(house_spot_flash - delta, 0.0)
	if house_cam_active:
		house_cam_time -= delta
		if house_cam_time <= 0.0:
			house_cam_active = false
	# The daily card is the reason to come back at midnight, so its countdown
	# has to be live while the player sits on the title.
	if screen == "title" and is_instance_valid(daily_reset_label):
		daily_label_timer -= delta
		if daily_label_timer <= 0.0:
			daily_label_timer = 1.0
			daily_reset_label.text = _daily_reset_label()
	if shake_trauma > 0.0:
		shake_trauma = maxf(shake_trauma - 1.4 * delta, 0.0)
		var s := shake_trauma * shake_trauma
		shake_offset = Vector2(sin(animation_time * 31.0) * 10.0 * s, sin(animation_time * 27.0) * 8.0 * s)
		if settings_no_shake:
			shake_offset = Vector2.ZERO
	else:
		shake_offset = Vector2.ZERO
	# The beat before the House shoots is deliberate: the banner names what is
	# about to happen, so the player never loses the cue to an unseen force.
	if house_pending > 0.0 and screen == "encounter" and not paused and not resolving:
		house_pending -= delta
		if house_pending <= 0.0:
			house_pending = 0.0
			_house_take_shot()
	_update_particles(delta)
	queue_redraw()

func _update_particles(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		particles[i].life -= delta
		particles[i].pos += particles[i].vel * delta
		if particles[i].life <= 0.0:
			particles.remove_at(i)
	for i in range(floaters.size() - 1, -1, -1):
		floaters[i].life -= delta
		floaters[i].pos.y -= 34.0 * delta
		if floaters[i].life <= 0.0:
			floaters.remove_at(i)
	for i in range(pocket_flashes.size() - 1, -1, -1):
		pocket_flashes[i].life -= delta
		if pocket_flashes[i].life <= 0.0:
			pocket_flashes.remove_at(i)

# A short sampled trail is enough: it communicates speed and line without
# turning a break into a wall of paint. Resting balls drop their trail so the
# felt clears for the next planning read.
func _update_ball_trails() -> void:
	for ball in simulator.balls:
		if bool(ball.get("pocketed", false)) or ball.velocity.length() < 26.0:
			ball_trails.erase(ball.id)
			continue
		var trail: Array = ball_trails.get(ball.id, [])
		trail.append(ball.position)
		if trail.size() > 9:
			trail.pop_front()
		ball_trails[ball.id] = trail

# --- HOUSE CAM ------------------------------------------------------------
# One frame is a position list plus an alive mask, so a potted ball vanishes on
# the same frame the physics removed it. Thirty frames a second is enough for a
# slow-motion inset and costs far less than recording full ball dictionaries.
func _capture_house_cam_frame() -> void:
	var positions := PackedVector2Array()
	var alive := PackedByteArray()
	for ball in simulator.balls:
		positions.append(ball.position)
		alive.append(0 if bool(ball.get("pocketed", false)) else 1)
	house_cam_frames.append({"pos": positions, "alive": alive})
	while house_cam_frames.size() > HOUSE_CAM_MAX_FRAMES:
		house_cam_frames.pop_front()

func _house_cam_caption(pots: int, banked: bool) -> String:
	if pots >= 3:
		return "TRIPLE POT"
	if pots == 2:
		return "DOUBLE POT"
	if banked:
		return "BANKED POT"
	if pots == 1:
		return "CLEAN POT"
	return ""

# Only shots worth replaying are kept: two pots, or a pot that used a cushion.
# A table-ending shot skips the inset because the reward card is already the
# payoff, and a replay hidden behind it would only cost frames.
func _maybe_start_house_cam(pots: int, banked: bool, table_ends: bool) -> void:
	if not settings_house_cam or table_ends or house_cam_frames.size() < 6:
		house_cam_active = false
		house_cam_frames.clear()
		return
	var caption := _house_cam_caption(pots, banked)
	if caption == "" or (pots < 2 and not banked):
		house_cam_active = false
		house_cam_frames.clear()
		return
	house_cam_caption = caption
	house_cam_marks.clear()
	for event in shot_events:
		if event.type != "pocket":
			continue
		var ball := simulator.get_ball(event.ball_id)
		if ball.is_empty() or not ball.target:
			continue
		var pocket_index := int(event.get("pocket", -1))
		if pocket_index >= 0 and pocket_index < simulator.pockets.size():
			house_cam_marks.append(simulator.pockets[pocket_index])
	house_cam_bbox = _house_cam_bounds()
	house_cam_duration = clampf(float(house_cam_frames.size()) * HOUSE_CAM_STEP * 0.8, 1.5, HOUSE_CAM_SECONDS)
	house_cam_time = house_cam_duration
	house_cam_active = true

# The camera frames the back half of the shot, where the pot happens; the whole
# shot's bounding box would zoom out to the full table and lose the detail
# that makes a replay worth watching.
func _house_cam_bounds() -> Rect2:
	var bounds := Rect2()
	var has_point := false
	var start := int(float(house_cam_frames.size()) * 0.45)
	for index in range(start, house_cam_frames.size()):
		var frame: Dictionary = house_cam_frames[index]
		var positions: PackedVector2Array = frame.pos
		var alive: PackedByteArray = frame.alive
		for i in positions.size():
			if alive[i] == 0:
				continue
			var point := positions[i]
			if not has_point:
				bounds = Rect2(point, Vector2.ZERO)
				has_point = true
			else:
				bounds = bounds.expand(point)
	for mark in house_cam_marks:
		bounds = bounds.expand(mark)
	if not has_point:
		return Rect2(Vector2(500, 300), Vector2(400, 200))
	bounds = bounds.grow(48.0)
	if bounds.size.x < 360.0:
		bounds = Rect2(bounds.get_center() - Vector2(180, bounds.size.y * 0.5), Vector2(360, bounds.size.y))
	if bounds.size.y < 180.0:
		bounds = Rect2(bounds.get_center() - Vector2(bounds.size.x * 0.5, 90), Vector2(bounds.size.x, 180))
	return bounds

func _burst(pos: Vector2, color: Color, count := 10, speed := 160.0) -> void:
	if settings_reduced_flash and count > 6:
		count = 6
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pos.x * 13.0 + pos.y * 7.0 + animation_time * 60.0) + 5
	for i in count:
		var a := rng.randf_range(0.0, TAU)
		particles.append({"pos": pos, "vel": Vector2.RIGHT.rotated(a) * rng.randf_range(speed * 0.4, speed), "life": rng.randf_range(0.25, 0.6), "color": color})

func _floater(pos: Vector2, text: String, color: Color) -> void:
	floaters.append({"pos": pos, "text": text, "life": 1.1, "color": color})

func _add_trauma(amount: float) -> void:
	if settings_no_shake:
		return
	shake_trauma = clampf(shake_trauma + amount, 0.0, 1.0)

# Impact freeze owned by the game loop, not Engine.time_scale: the shot step is
# slowed for a few real frames, so menus, input and tests keep their timing.
func _hit_stop(duration: float) -> void:
	if settings_fast_resolve:
		return
	hitstop_time = maxf(hitstop_time, duration)

func _physics_process(delta: float) -> void:
	if paused:
		return
	if not resolving:
		return
	resolve_elapsed += delta
	var step_delta := delta
	if hitstop_time > 0.0:
		hitstop_time = maxf(hitstop_time - delta, 0.0)
		step_delta = delta * 0.18
	var events := simulator.step(step_delta)
	_update_ball_trails()
	if settings_house_cam and not house_shooting and not house_cam_frames.is_empty():
		house_cam_clock += step_delta
		if house_cam_clock >= HOUSE_CAM_STEP:
			house_cam_clock = 0.0
			_capture_house_cam_frame()
	var finishing := simulator.is_settled() or resolve_elapsed >= BilliardsSimulator.MAX_SHOT_TIME or settings_fast_resolve
	# Ending early must never leave balls rolling: run the rest of the shot to rest.
	if finishing and not simulator.is_settled():
		events.append_array(simulator.fast_forward())
	shot_events.append_array(events)
	_process_shot_events(events)
	if finishing:
		if house_shooting:
			_finish_house_shot()
		else:
			_finish_shot()
	queue_redraw()

func _process_shot_events(events: Array[Dictionary]) -> void:
	# Contact sounds are throttled per step. A break sends a dozen collisions
	# through one frame, and a dozen identical clicks is noise; the two hardest
	# hits survive and carry the impact speed as volume.
	var clicks := 0
	var rails := 0
	for event in events:
		if event.type == "first_contact":
			continue
		if event.type == "collision":
			var impact := float(event.get("speed", 240.0))
			if clicks < 2 and impact > 70.0:
				clicks += 1
				_sfx("ball_click", lerpf(-16.0, 0.0, clampf(impact / 720.0, 0.0, 1.0)))
			continue
		if event.type == "rail":
			if rails < 2:
				rails += 1
				_sfx("rail", -4.0)
		if event.type != "pocket":
			continue
		var ball := simulator.get_ball(event.ball_id)
		var pocket_index := int(event.get("pocket", -1))
		if pocket_index >= 0 and pocket_index < simulator.pockets.size():
			pocket_flashes.append({"pos": simulator.pockets[pocket_index], "life": 0.65, "color": RED if event.ball_id == simulator.cue_ball_id else GOLD})
		if not ball.is_empty() and ball.target:
			_burst(ball.position, Color("#f2bd58"), 12)
			_sfx("pocket")
			# Screen shake had a setting but no source; a pocket is the moment
			# the table should react. Later pockets in one shot hit harder.
			_add_trauma(0.16 + 0.05 * float(resolve_pockets))
			if house_shooting:
				# The House's captures are not contract progress: its ball is
				# spotted back and only the lost pocket matters.
				continue
			pocketed_count += 1
			resolve_pockets += 1
			# Two balls in one shot is the payoff moment the whole build chases;
			# sell it with a short step freeze while the balls are still moving.
			if resolve_pockets == 2:
				_hit_stop(0.10)
			if event.get("ice_touched", false):
				lane_pockets += 1
			if resolve_pockets == 1:
				_hit_stop(0.04)
		if event.ball_id == simulator.cue_ball_id:
			_burst(ball.position if not ball.is_empty() else Vector2(640, 360), RED, 14)
			_add_trauma(0.34)
			_hit_stop(0.09)

func _toggle_pause() -> void:
	if screen != "encounter":
		return
	paused = not paused
	if paused:
		portal.gameplay_stop()
		_show_pause_overlay()
	else:
		portal.gameplay_start()
		_hide_pause_overlay()
		_refresh_hud()

func _toggle_mute() -> void:
	settings_volume = 0.0 if settings_volume > 0.0 else 0.8
	portal.set_portal_muted(settings_volume <= 0.0)
	_save_settings()
	if screen == "settings":
		_show_settings()
	elif screen == "encounter":
		if paused:
			_show_pause_overlay()
		else:
			_refresh_hud()

func _show_pause_overlay() -> void:
	_hide_pause_overlay()
	pause_overlay = Control.new()
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_root.add_child(pause_overlay)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.72)
	pause_overlay.add_child(dim)
	var card := _panel(pause_overlay, Vector2(440, 210), Vector2(400, 300), PANEL)
	_add_label(card, Vector2(30, 22), Vector2(340, 42), "PAUSED", 36, GOLD, HORIZONTAL_ALIGNMENT_CENTER, true)
	_add_label(card, Vector2(30, 72), Vector2(340, 40), "The table waits. No shot is lost while paused.", 13, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var resume_btn := _add_button(card, Vector2(70, 124), Vector2(260, 48), "RESUME", _toggle_pause, true)
	resume_btn.grab_focus()
	_add_button(card, Vector2(70, 186), Vector2(122, 40), "SOUND  " + ("OFF" if settings_volume <= 0.0 else "ON"), _toggle_mute)
	var exit_label := "QUIT TO MAP"
	if gauntlet_active:
		exit_label = "END RUN"
	elif duel_active:
		# Leaving a duel is a concession: it ends the streak, so the button says
		# so before the click instead of surprising the player on the result card.
		# A local match has no streak to break, so it says what it does.
		exit_label = "END MATCH" if duel_local else "FORFEIT"
	_add_button(card, Vector2(208, 186), Vector2(122, 40), exit_label, _resume_to_map)
	var pause_note := "P resumes  •  M mutes  •  click RESUME on touch"
	if table_wager > 0:
		# Leaving a live rack is not a free look at the layout: the House keeps
		# the stake, so the pause card has to say it before the click.
		pause_note = "QUITTING FORFEITS THE %d CASH STAKE  ·  P resumes" % table_wager
	_add_label(card, Vector2(30, 238), Vector2(340, 40), pause_note, 11, MUTED, HORIZONTAL_ALIGNMENT_CENTER)

func _hide_pause_overlay() -> void:
	if is_instance_valid(pause_overlay):
		screen_root.remove_child(pause_overlay)
		pause_overlay.queue_free()
	pause_overlay = null

func _resume_to_map() -> void:
	paused = false
	_hide_pause_overlay()
	if duel_active:
		# A duel lives on the title, not the route, and quitting must cost the
		# streak or the ladder record could be farmed by closing the tab.
		_finish_duel(false, true)
		return
	if gauntlet_active:
		_show_run_summary(false)
		return
	_show_map()

func _dock_exit() -> void:
	if gauntlet_active or duel_active:
		# Ending a score chase or a duel must be deliberate: open the pause card
		# first instead of silently discarding the match.
		_toggle_pause()
	else:
		_show_map()

func _input(event: InputEvent) -> void:
	# Screen-jump keys are a development tool. Shipped builds must not let a
	# player press 9 for a free victory. A focused text field owns its keys:
	# challenge codes contain digits and B, and the debug shortcuts used to eat
	# them before the LineEdit could see the code.
	var editing_text := get_viewport().gui_get_focus_owner() is LineEdit
	if OS.is_debug_build() and not editing_text and event is InputEventKey and event.pressed and not event.echo and event.keycode >= KEY_0 and event.keycode <= KEY_9:
		_debug_screen(event.keycode - KEY_0)
		return
	# Debug-only shortcut to the House's table, one shot into phase two. There
	# is no digit left for it and this is the only screen that needs live QA.
	if OS.is_debug_build() and not editing_text and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B:
		if run_stage <= 1 and collection.is_empty():
			_start_new_run()
		current_node = 11
		_start_encounter(true)
		score = int(scenario.target) / 2
		_check_boss_phase()
		_refresh_hud()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F and screen == "encounter" and not paused and not duel_active:
		_arm_house_call()
		return
	# Escape opens the pause card at the table, the same way every portal game
	# treats it. The old binding only backed out of menus, so a keyboard player
	# had no way to leave a bad rack without finding the 56px dock button.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and screen == "encounter":
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return
	# Escape backs out of a menu exactly like its BACK button. Portals expect
	# the key, and a player who opened SETTINGS mid-route should not have to
	# hunt for a 40px button to return.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and screen != "encounter":
		match screen:
			"howto", "settings", "vault", "cue_case", "trophies", "build", "grind":
				if menu_return_screen == "map":
					_show_map()
				elif menu_return_screen in ["victory", "defeat"]:
					_show_run_summary(menu_return_screen == "victory", false)
				else:
					_show_title()
			"contract", "duel_result", "local_setup", "challenge":
				# Every menu backs out with Escape, including the two front doors'
				# intermediate cards. A player should not have to find BACK with a
				# mouse after a keyboard-only session.
				_show_title()
			"map":
				# First Escape drops a previewed node; a second one leaves for the
				# title, where the run is saved and can be continued.
				if pending_node >= 0:
					_show_map()
				else:
					_show_title()
		return
	if event is InputEventJoypadMotion and screen == "encounter" and not resolving and not paused:
		# Aim is a table gesture, so the stick points the cue ball at a target
		# rather than moving a cursor. The left stick is the primary aim; the
		# right stick works too for players who expect twin-stick controls.
		var stick := Vector2(Input.get_joy_axis(event.device, JOY_AXIS_LEFT_X), Input.get_joy_axis(event.device, JOY_AXIS_LEFT_Y))
		if stick.length() < 0.25:
			stick = Vector2(Input.get_joy_axis(event.device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(event.device, JOY_AXIS_RIGHT_Y))
		if _aim_with_stick(stick):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_A:
				if screen == "encounter" and not paused:
					_take_shot()
					get_viewport().set_input_as_handled()
					return
			JOY_BUTTON_START:
				if screen == "encounter":
					_toggle_pause()
					get_viewport().set_input_as_handled()
					return
			JOY_BUTTON_X:
				_adjust_power(0.10)
				return
			JOY_BUTTON_Y:
				_adjust_power(-0.10)
				return
			JOY_BUTTON_B:
				_adjust_spin(-current_spin)
				return
	if event is InputEventScreenTouch and screen == "encounter" and not resolving and not paused:
		if event.pressed and SPIN_PAD_RECT.has_point(event.position):
			_set_spin_from_pointer(event.position)
			return
		# A tap on the power bar sets power; without this it fell through to the
		# aim code and swung the cue sideways instead.
		if event.pressed and POWER_METER_RECT.has_point(event.position):
			_set_power_from_pointer(event.position.x)
			return
		# Taps on FIRE / MAP / pause / the brief are HUD input, not aim input.
		if _pointer_on_hud(event.position):
			return
		var cue := simulator.get_ball(simulator.cue_ball_id)
		if not cue.is_empty() and event.pressed:
			var direction: Vector2 = event.position - cue.position
			if direction.length() > 4.0:
				last_aim = direction.normalized()
				_coach_mark("aim")
				queue_redraw()
		return
	if event is InputEventScreenDrag and screen == "encounter" and not resolving and not paused:
		if SPIN_PAD_RECT.has_point(event.position):
			_set_spin_from_pointer(event.position)
			return
		if POWER_METER_RECT.has_point(event.position):
			_set_power_from_pointer(event.position.x)
			return
		if _pointer_on_hud(event.position):
			return
		var drag_cue := simulator.get_ball(simulator.cue_ball_id)
		if not drag_cue.is_empty():
			var drag_dir: Vector2 = event.position - drag_cue.position
			if drag_dir.length() > 4.0:
				last_aim = drag_dir.normalized()
				_coach_mark("aim")
				queue_redraw()
		return
	if screen != "encounter":
		return
	if paused:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
			_toggle_pause()
		return
	if event is InputEventMouseMotion and not resolving:
		# Meter and spin drags set their value only — never swing the aim.
		if SPIN_PAD_RECT.has_point(event.position):
			if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
				_set_spin_from_pointer(event.position)
			return
		if POWER_METER_RECT.has_point(event.position):
			if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
				_set_power_from_pointer(event.position.x)
			return
		# Aiming is a table gesture. The pointer crossing the dock or the brief
		# on its way to FIRE must not re-aim the shot at a button.
		if _pointer_on_hud(event.position):
			return
		var cue := simulator.get_ball(simulator.cue_ball_id)
		if not cue.is_empty():
			# event.position is already in 1280x720 game space; the global mouse
			# position needed a shake correction this path does not.
			var direction: Vector2 = event.position - cue.position
			if direction.length() > 4.0:
				last_aim = direction.normalized()
				_coach_mark("aim")
				queue_redraw()
	if event is InputEventMouseButton and event.pressed and not resolving:
		if event.button_index == MOUSE_BUTTON_LEFT and SPIN_PAD_RECT.has_point(event.position):
			_set_spin_from_pointer(event.position)
			return
		if event.button_index == MOUSE_BUTTON_LEFT and POWER_METER_RECT.has_point(event.position):
			_set_power_from_pointer(event.position.x)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_adjust_power(0.05)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_adjust_power(-0.05)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				# Practice has no map node; retrying it must reopen practice, not
				# silently become a scored tour table. The Grind is a score chase:
				# a free rerack would let a player farm one rack forever.
				if gauntlet_active:
					return
				if current_node < 0:
					_show_practice()
				else:
					_start_encounter(str(map_nodes[current_node].type) == "boss")
			KEY_ESCAPE:
				if gauntlet_active:
					_toggle_pause()
				else:
					_show_map()
			KEY_SPACE, KEY_ENTER:
				# A focused dock control owns the confirm key. Without this, Enter on
				# HOUSE HEAT or MAP fired the shot instead of pressing the button,
				# so no dock control outside FIRE could be used from a keyboard.
				var focused := get_viewport().gui_get_focus_owner()
				if focused is Button and focused != hud_fire_button:
					return
				# FIRE is enabled while resolving (it becomes SPEED UP), so the key
				# must be consumed here. Otherwise the focused button also receives
				# Enter and a second press skips the shot the first press just fired.
				_take_shot()
				get_viewport().set_input_as_handled()
			KEY_W, KEY_UP:
				_adjust_power(0.10)
			KEY_S, KEY_DOWN:
				_adjust_power(-0.10)
			KEY_A, KEY_LEFT:
				_adjust_spin(Vector2(-0.25, 0))
			KEY_D, KEY_RIGHT:
				_adjust_spin(Vector2(0.25, 0))
			KEY_Q:
				_adjust_spin(Vector2(0, 0.25))
			KEY_E:
				_adjust_spin(Vector2(0, -0.25))
			KEY_X:
				_adjust_spin(-current_spin)
			KEY_P:
				_toggle_pause()
			KEY_M:
				_toggle_mute()
	_refresh_hud()

func _debug_screen(index: int) -> void:
	if run_stage <= 1 and collection.is_empty():
		_start_new_run()
	match index:
		1: _show_title()
		2: _show_map()
		3:
			current_node = 2
			_start_encounter(false)
		4: _show_settings()
		5:
			current_node = 2
			_start_encounter(false)
			_toggle_pause()
		6:
			scenario = scenario if not scenario.is_empty() else library.get_by_id("gatehouse", seed_value)
			_show_reward()
		7: _show_shop()
		8: _show_collection()
		9: _show_victory()
		0: _show_defeat()

func _build_map() -> void:
	# One run is one route through this vertical tour; nodes off the route remain untouched.
	# Middle rows shuffle scenario flavor per run seed so repeats feel different.
	map_nodes = [
		{"type": "standard", "name": "The Gatehouse", "pos": Vector2(610, 150), "done": false, "scenario_id": "gatehouse"},
		{"type": "shop", "name": "Chalk Market", "pos": Vector2(440, 255), "done": false, "scenario_id": ""},
		{"type": "standard", "name": "Frozen Lane", "pos": Vector2(610, 255), "done": false, "scenario_id": "frozen_lane"},
		{"type": "event", "name": "The Back Room", "pos": Vector2(780, 255), "done": false, "scenario_id": ""},
		{"type": "elite", "name": "Locksmith's Run", "pos": Vector2(370, 370), "done": false, "scenario_id": "locksmith"},
		{"type": "standard", "name": "The Long Rail", "pos": Vector2(550, 370), "done": false, "scenario_id": "open_water"},
		{"type": "shop", "name": "The Feltworks", "pos": Vector2(730, 370), "done": false, "scenario_id": ""},
		{"type": "elite", "name": "The Trap", "pos": Vector2(910, 370), "done": false, "scenario_id": "the_trap"},
		{"type": "event", "name": "Lucky Break", "pos": Vector2(470, 480), "done": false, "scenario_id": ""},
		{"type": "shop", "name": "Last Call", "pos": Vector2(750, 480), "done": false, "scenario_id": ""},
		{"type": "boss", "name": "The Locksmith", "pos": Vector2(610, 565), "done": false, "scenario_id": "locksmith"},
		{"type": "boss", "name": "The House", "pos": Vector2(610, 665), "done": false, "scenario_id": "prism_vault"}
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(run_seed) + 999
	# Scenario deck: Gatehouse always opens (onboarding). Other standards and
	# elites draw from shuffled tier pools so every run sees different tables
	# and no scenario hides forever. Structure/names stay stable for tests.
	var standard_pool := ["frozen_lane", "open_water", "crossfire", "prism_vault", "anchor_yard"]
	var elite_pool := ["locksmith", "the_trap", "anchor_yard", "crossfire", "pinwheel"]
	_shuffle(rng, standard_pool)
	# A run must never schedule the same table twice: elites only draw from
	# scenarios the two standard slots did not already take.
	for used_id in [standard_pool[0], standard_pool[1]]:
		elite_pool.erase(used_id)
	_shuffle(rng, elite_pool)
	map_nodes[2].scenario_id = standard_pool[0]
	map_nodes[2].name = library.get_by_id(standard_pool[0], 0).name.capitalize()
	map_nodes[5].scenario_id = standard_pool[1]
	map_nodes[5].name = library.get_by_id(standard_pool[1], 0).name.capitalize()
	map_nodes[4].scenario_id = elite_pool[0]
	map_nodes[4].name = library.get_by_id(elite_pool[0], 0).name.capitalize()
	map_nodes[7].scenario_id = elite_pool[1]
	map_nodes[7].name = library.get_by_id(elite_pool[1], 0).name.capitalize()
	map_edges = [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(1, 4), Vector2i(1, 5), Vector2i(2, 4), Vector2i(2, 5), Vector2i(2, 6), Vector2i(3, 6), Vector2i(3, 7), Vector2i(4, 8), Vector2i(5, 8), Vector2i(5, 9), Vector2i(6, 9), Vector2i(7, 9), Vector2i(8, 10), Vector2i(9, 10), Vector2i(10, 11)]
	map_unlocked = [0]

func _shuffle(rng: RandomNumberGenerator, arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

func _clear_ui() -> void:
	# Detach first, then free: queue_free alone leaves the previous screen visible
	# for a frame, and since the title builds its own root the old screen stayed
	# drawn underneath it. remove_child stops drawing immediately and keeps freeing
	# the emitting button safe during its own pressed callback.
	for child in screen_root.get_children():
		screen_root.remove_child(child)
		child.queue_free()
	node_buttons.clear()
	hud_root = null
	hud_run_label = null
	hud_shot_label = null
	hud_contract_label = null
	hud_contract_fill = null
	hud_result_label = null
	hud_cue_label = null
	hud_build_label = null
	hud_guard_label = null
	hud_mods_label = null
	hud_set_label = null
	hud_power_label = null
	hud_power_fill = null
	hud_fire_button = null
	hud_heat_label = null
	hud_heat_button = null
	hud_heat_fill = null
	pause_overlay = null
	daily_reset_label = null

func _base_screen(title: String, subtitle: String, show_run := true) -> Control:
	_clear_ui()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.modulate.a = 0.0
	screen_root.add_child(root)
	var screen_tween := root.create_tween()
	screen_tween.tween_property(root, "modulate:a", 1.0, 0.16)
	var header := ColorRect.new()
	header.position = Vector2(0, 0)
	header.size = Vector2(1280, 104)
	header.color = Color("#16232d")
	root.add_child(header)
	var rule := ColorRect.new()
	rule.position = Vector2(38, 96)
	rule.size = Vector2(54, 3)
	rule.color = GOLD
	root.add_child(rule)
	_add_label(root, Vector2(38, 14), Vector2(620, 42), title, 32, GOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
	_add_label(root, Vector2(40, 59), Vector2(820, 32), subtitle, 13, MUTED)
	if show_run:
		if gauntlet_active:
			# The ladder has its own board: a free-run best would overstate today.
			var best_stage := maxi(grind_daily_best_stage, run_tables_cleared) if grind_daily_active else maxi(gauntlet_best_stage, run_tables_cleared)
			var best_label := "TODAY'S BEST" if grind_daily_active else "BEST"
			_add_label(root, Vector2(880, 14), Vector2(360, 30), "%s  %02d" % [best_label, best_stage], 22, GOLD, HORIZONTAL_ALIGNMENT_RIGHT, true)
		else:
			_add_label(root, Vector2(880, 14), Vector2(360, 30), "CASH  %03d" % run_cash, 22, GOLD, HORIZONTAL_ALIGNMENT_RIGHT, true)
		if gauntlet_active:
			var run_line := "LADDER   SCORE %04d" if grind_daily_active else "GRIND   SCORE %04d"
			hud_run_label = _add_label(root, Vector2(880, 53), Vector2(360, 22), run_line % run_score, 13, MINT, HORIZONTAL_ALIGNMENT_RIGHT)
		else:
			# Route depth, not the table count: a shop advances the stage too.
			hud_run_label = _add_label(root, Vector2(880, 53), Vector2(360, 22), "STAGE %02d   SCORE %04d" % [run_stage, run_score], 13, MINT, HORIZONTAL_ALIGNMENT_RIGHT)
	return root

func _show_title() -> void:
	portal.gameplay_stop()
	paused = false
	# The Grind is a session mode, not a save slot. Returning to the title ends
	# the mode flag so START RUN always opens the tour terms again.
	gauntlet_active = false
	grind_daily_active = false
	duel_active = false
	duel_local = false
	duel_handoff = false
	# Roll the ladder over before the title reads it, so the readiness dot and
	# the intro card can never show yesterday's best as today's.
	_refresh_grind_daily()
	# Settle milestones before the card is built, so the trophy count on the
	# card already includes anything this visit just earned.
	_check_trophies()
	screen = "title"
	_clear_ui()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.modulate.a = 0.0
	screen_root.add_child(root)
	root.create_tween().tween_property(root, "modulate:a", 1.0, 0.18)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("#0a1218")
	root.add_child(backdrop)
	# The front door is a pool-hall poster: the wordmark sits in the dark above,
	# and a full rack under a warm lamp fills the bottom of the frame. The old
	# 220px felt strip started halfway up the menu and left the composition with
	# one foot in the table and one in a spreadsheet. This table is one edge of a
	# real table the player is about to walk up to.
	var table_art := TableArt.new()
	table_art.position = Vector2(0, 466)
	table_art.size = Vector2(1280, 254)
	table_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(table_art)
	# Brand block. The eyebrow is spaced by hand because Godot labels have no
	# letter-spacing; at this size the gaps read as a vintage playbill, not a bug.
	_add_label(root, Vector2(92, 40), Vector2(620, 16), "A  P O O L  R O G U E L I T E", 11, Color("#aac2c4"))
	_add_label(root, Vector2(88, 54), Vector2(700, 96), "RACK & RUIN", 92, GOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
	_add_label(root, Vector2(94, 156), Vector2(700, 24), "ANGLES. RISK. THE HOUSE ALWAYS COLLECTS.", 15, Color("#aac2c4"))
	var gold_rule := ColorRect.new()
	gold_rule.position = Vector2(94, 190)
	gold_rule.size = Vector2(140, 3)
	gold_rule.color = GOLD
	root.add_child(gold_rule)
	_add_label(root, Vector2(94, 208), Vector2(620, 62), "Every table is a tactical problem.\nEvery shot changes the route ahead.", 21, Color("#f4ead5"))
	var has_save := _has_run_save()
	var start_label := "START NEW RUN" if has_save else "START RUN"
	# A gold dot on THE GRIND means today's free ladder is still unplayed. It is
	# the same quiet cue the vault uses for an affordable piece: a reason to
	# click without turning the title into a wall of badges.
	var grind_ready := not _grind_daily_played_today()
	if has_save:
		_add_button(root, Vector2(94, 292), Vector2(176, 58), start_label, _show_contract_select)
		var cont_btn := _add_button(root, Vector2(280, 292), Vector2(176, 58), "CONTINUE RUN", _continue_run, true)
		cont_btn.grab_focus()
		var grind_btn := _add_button(root, Vector2(466, 292), Vector2(152, 58), "THE GRIND", _show_grind_intro)
		if grind_ready:
			_add_dot_badge(grind_btn)
		_add_button(root, Vector2(628, 292), Vector2(132, 58), "PRACTICE", _show_practice)
	else:
		var start_btn := _add_button(root, Vector2(94, 292), Vector2(196, 58), start_label, _show_contract_select, true)
		start_btn.grab_focus()
		var grind_btn := _add_button(root, Vector2(300, 292), Vector2(168, 58), "THE GRIND", _show_grind_intro)
		if grind_ready:
			_add_dot_badge(grind_btn)
		_add_button(root, Vector2(478, 292), Vector2(140, 58), "PRACTICE", _show_practice)
	# The secondary row is the house office: one flat shelf under the three ways
	# to play, so the front door reads as three choices instead of nine.
	_add_button(root, Vector2(94, 366), Vector2(120, 38), "HOW TO PLAY", _show_howto)
	_add_button(root, Vector2(222, 366), Vector2(104, 38), "SETTINGS", _show_settings)
	_add_button(root, Vector2(334, 366), Vector2(120, 38), "STAKE  %d / 2" % stake, _cycle_stake)
	# The case is the trophy shelf's visible payoff: a finish earned there changes
	# the stick on every table. It sits beside the vault so both earned sinks are
	# one click from the front door.
	_add_button(root, Vector2(462, 366), Vector2(108, 38), "CUE CASE", _show_cue_case)
	# The vault is the reason reputation exists; a dot marks an affordable piece
	# so a returning player sees there is something waiting without reading menus.
	var next_cost := _next_vault_cost()
	var vault_btn := _add_button(root, Vector2(578, 366), Vector2(112, 38), "THE VAULT", _show_vault)
	if next_cost >= 0 and reputation >= next_cost:
		_add_dot_badge(vault_btn)
	_add_button(root, Vector2(698, 366), Vector2(112, 38), "TROPHIES", _show_trophies)
	var stake_notes: Array[String] = ["Full shot budget on every table.", "One fewer shot per table, +1 reputation on a win.", "One fewer shot, +15 contract target, +2 reputation on a win."]
	var stake_note: String = stake_notes[stake]
	# A returning player should see both endless chases without opening a card.
	if gauntlet_best_stage > 0:
		stake_note += "   ·   GRIND BEST %02d" % gauntlet_best_stage
	if _grind_daily_played_today():
		stake_note += "   ·   GRIND LADDER BEST %02d" % grind_daily_best_stage
	else:
		stake_note += "   ·   GRIND LADDER READY"
	_add_label(root, Vector2(94, 404), Vector2(680, 22), stake_note, 12, Color("#9fb6b4"))
	# The social door belongs under the shelf, not in the ledger: a friend's
	# code is a way to start a route, and it should be readable before the
	# table art begins. It stays quiet because no first-time player needs it.
	_add_button(root, Vector2(94, 430), Vector2(150, 34), "PLAY A CODE", _show_challenge_entry)
	_add_label(root, Vector2(256, 438), Vector2(380, 16), "A friend's seed, terms and stake.", 10, Color("#5e7478"))
	# Right column: one ledger, not three floating cards. The House keeps the
	# player's record, the day's challenge and its own challenge in the same
	# book; the single frame also removes the old overlap where the duel card cut
	# through the table's rail and a pocket.
	var start_cue := "HOUSE CUE"
	var start_note := "Reliable. No bonus, no risk."
	if _has_unlock("cue_rack"):
		start_cue = "THE SURVEYOR"
		start_note = "+10 bank. Longer rail preview."
	var start_cash := 60
	if _has_unlock("house_credit"):
		start_cash = 80
	var ledger := _panel(root, Vector2(812, 84), Vector2(420, 616), PANEL)
	_add_label(ledger, Vector2(26, 16), Vector2(240, 16), "THE HOUSE'S LEDGER", 11, GOLD)
	_add_label(ledger, Vector2(26, 16), Vector2(368, 16), "HOUSE OPEN", 10, RED, HORIZONTAL_ALIGNMENT_RIGHT)
	var ledger_top := ColorRect.new()
	ledger_top.position = Vector2(26, 38)
	ledger_top.size = Vector2(368, 1)
	ledger_top.color = Color("#33505a")
	ledger.add_child(ledger_top)
	# Section 1: what the player is about to sit down with.
	_add_label(ledger, Vector2(26, 50), Vector2(368, 16), "STARTING LOADOUT", 10, GOLD)
	_add_label(ledger, Vector2(26, 68), Vector2(368, 30), start_cue, 23, Color("#f1f6f1"), HORIZONTAL_ALIGNMENT_LEFT, true)
	_add_label(ledger, Vector2(26, 96), Vector2(368, 20), start_note, 12, MUTED)
	var card_rule := ColorRect.new()
	card_rule.position = Vector2(26, 122)
	card_rule.size = Vector2(368, 1)
	card_rule.color = Color("#33505a")
	ledger.add_child(card_rule)
	_add_label(ledger, Vector2(26, 132), Vector2(368, 42), "%03d CASH to start — about one shop piece.\nClear tables to earn build pieces." % start_cash, 12, Color("#cfe0dc"))
	var card_rule_two := ColorRect.new()
	card_rule_two.position = Vector2(26, 180)
	card_rule_two.size = Vector2(368, 1)
	card_rule_two.color = Color("#33505a")
	ledger.add_child(card_rule_two)
	# THE HOUSE REMEMBERS: the pending read belongs on the front door, beside
	# the loadout, because it changes which build is worth taking into the
	# finale. Without a read the ledger keeps its one line of house copy.
	if house_grudge != "":
		_add_label(ledger, Vector2(26, 190), Vector2(368, 14), "IT REMEMBERS YOU", 9, RED)
		_add_label(ledger, Vector2(26, 206), Vector2(368, 34), "%s  ·  %s" % [str(_grudge().name), _grudge_rule()], 10, Color("#d8cbb8"))
	else:
		_add_label(ledger, Vector2(26, 190), Vector2(368, 34), "Every clear pays cash and one piece.\nEvery route ends at The House.", 11, MUTED)
	# Section 2: the daily challenge. Same seed and twist for every player today,
	# a streak that survives sessions, today's best.
	var daily_rule := ColorRect.new()
	daily_rule.position = Vector2(26, 248)
	daily_rule.size = Vector2(368, 1)
	daily_rule.color = Color("#33505a")
	ledger.add_child(daily_rule)
	var today := _today_key()
	var played_today := daily_best_key == today
	var twist := _daily_twist(today)
	_add_label(ledger, Vector2(26, 258), Vector2(240, 16), "DAILY CHALLENGE  ·  %s" % _pretty_date(today), 10, GOLD)
	daily_reset_label = _add_label(ledger, Vector2(266, 258), Vector2(128, 16), _daily_reset_label(), 9, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	daily_label_timer = 1.0
	_add_label(ledger, Vector2(26, 276), Vector2(368, 18), "%s  ·  %s" % [str(twist.name), str(twist.body)], 12, MINT)
	var daily_note := "Same tour for every player, no unlocks."
	if played_today:
		daily_note = "Played today · best %04d · streak x%d" % [daily_best, daily_streak]
	elif daily_streak > 0:
		daily_note = "Keep a %d-day streak alive." % daily_streak
	_add_label(ledger, Vector2(26, 296), Vector2(368, 18), daily_note, 10, MUTED)
	var daily_label := "PLAY AGAIN" if played_today else "PLAY DAILY"
	_add_button(ledger, Vector2(26, 318), Vector2(368, 34), daily_label, _start_daily, false, GOLD)
	# Section 3: THE HOUSE DUEL, the second front door. No route, no build, no
	# contract. One rack, one rival, five pockets. A player who bounces off the
	# roguelite still has a reason to sit down, and the form ladder gives the
	# mode a chase independent of every other saved record.
	var duel_rule := ColorRect.new()
	duel_rule.position = Vector2(26, 370)
	duel_rule.size = Vector2(368, 1)
	duel_rule.color = Color("#33505a")
	ledger.add_child(duel_rule)
	var next_form := clampi(duel_best_form, 0, DUEL_FORMS.size() - 1)
	var form: Dictionary = DUEL_FORMS[next_form]
	_add_label(ledger, Vector2(26, 380), Vector2(240, 16), "THE HOUSE DUEL", 10, RED)
	_add_label(ledger, Vector2(26, 380), Vector2(368, 16), "WINS %02d" % duel_wins, 10, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	_add_label(ledger, Vector2(26, 396), Vector2(368, 28), "FORM %s  ·  %s" % [_duel_roman(next_form), str(form.name)], 19, GOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
	_add_label(ledger, Vector2(26, 426), Vector2(368, 30), str(form.tag), 11, Color("#c6d7d5"))
	var duel_record := "Race to five pockets. Miss, and it takes the cue."
	if duel_best_streak > 0:
		duel_record = "STREAK %d  ·  BEST %d  ·  Race to five." % [duel_streak, duel_best_streak]
	_add_label(ledger, Vector2(26, 456), Vector2(368, 18), duel_record, 10, MUTED)
	_add_button(ledger, Vector2(26, 478), Vector2(182, 36), "DUEL THE HOUSE", _start_duel, false, GOLD)
	# The second seat is the point: a portal visitor can hand the cue to a friend
	# without an account, a second device or a server.
	_add_button(ledger, Vector2(216, 478), Vector2(178, 36), "PASS & PLAY", _show_local_setup)
	var couch_note := "Two players, one keyboard. Same race, no House."
	if duel_couch_p1 + duel_couch_p2 > 0:
		couch_note = "COUCH RECORD   P1 %d — %d P2" % [duel_couch_p1, duel_couch_p2]
	_add_label(ledger, Vector2(26, 520), Vector2(368, 18), couch_note, 10, MUTED)
	# Footer: the long record, on the same book it belongs to.
	var foot_rule := ColorRect.new()
	foot_rule.position = Vector2(26, 556)
	foot_rule.size = Vector2(368, 1)
	foot_rule.color = Color("#33505a")
	ledger.add_child(foot_rule)
	_add_label(ledger, Vector2(26, 566), Vector2(368, 16), "BEST %04d    RUNS %d    TROPHIES %d/%d" % [best_score, total_runs, trophies.size(), TROPHIES.size()], 10, MUTED)
	_add_label(ledger, Vector2(26, 586), Vector2(368, 16), "SEED  %d" % last_seed, 10, Color("#5e7478"), HORIZONTAL_ALIGNMENT_LEFT)
	_add_label(ledger, Vector2(26, 586), Vector2(368, 16), "REP  %d" % reputation, 10, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)

func _duel_roman(index: int) -> String:
	return ["I", "II", "III", "IV"][clampi(index, 0, 3)]

# --- THE CUE CASE ---------------------------------------------------------
# A finish is a cosmetic memory of a milestone. Nothing here touches physics,
# scoring or the run save: the stick the player sees is the same stick either way.
func _cue_finish_index(finish_id: String) -> int:
	for i in CUE_FINISHES.size():
		if str(CUE_FINISHES[i].id) == finish_id:
			return i
	return -1

func _cue_finish_data(finish_id := "") -> Dictionary:
	var wanted := cue_finish if finish_id == "" else finish_id
	var index := _cue_finish_index(wanted)
	if index < 0:
		index = 0
	return CUE_FINISHES[index]

func _cue_unlocked(finish_id: String) -> bool:
	var index := _cue_finish_index(finish_id)
	if index < 0:
		return false
	var trophy := str(CUE_FINISHES[index].trophy)
	return trophy == "" or trophies.has(trophy)

func _equip_cue_finish(finish_id: String) -> void:
	if not _cue_unlocked(finish_id) or cue_finish == finish_id:
		return
	cue_finish = finish_id
	_save_meta()
	_sfx("click")
	if screen == "cue_case":
		_show_cue_case()

func _cue_palette(finish_id := "") -> Dictionary:
	var finish := _cue_finish_data(finish_id)
	return {
		"butt": Color(str(finish.butt)),
		"wrap": Color(str(finish.wrap)),
		"shaft": Color(str(finish.shaft)),
		"accent": Color(str(finish.accent)),
	}

# The locked card states the exact trophy it is waiting on and its live count,
# so the case is a to-do list instead of a wall of grey.
func _cue_finish_progress(finish: Dictionary) -> String:
	var trophy_id := str(finish.trophy)
	if trophy_id == "":
		return "ALWAYS IN THE BAG"
	for trophy in TROPHIES:
		if str(trophy.id) != trophy_id:
			continue
		var have := mini(_trophy_stat(str(trophy.stat)), _trophy_target(trophy))
		return "%d / %d  ·  %s" % [have, _trophy_target(trophy), str(trophy.name)]
	return "LOCKED"

func _show_howto() -> void:
	screen = "howto"
	var back_target := _show_map if menu_return_screen == "map" else _show_title
	var root := _base_screen("HOW TO PLAY", "Three things to learn, then the table teaches the rest.", false)
	_add_button(root, Vector2(32, 116), Vector2(120, 40), "BACK", back_target)
	var steps := [
		["1 · AIM + FIRE", "Aim with the pointer or a controller stick. The dotted line is the cue path; the green ghost is the first ball it will hit. Space, Enter, A or FIRE SHOT commits — table clicks never fire."],
		["2 · POWER + SPIN", "Drag the power bar, wheel, W/S or X/Y. Drag the SPIN pad (up follow, down draw); B clears it. Soft shots travel far, hard shots break anchors."],
		["3 · CONTRACTS + HEAT", "Read the brief and beat the contract before the shots run out. Banks pay extra, combos multiply, fouls and scratches cost shots — double in elites and bosses. Pots fill HOUSE HEAT."],
	]
	for i in steps.size():
		var card := _panel(root, Vector2(70 + i * 380, 168), Vector2(360, 244), PANEL_ALT)
		_add_label(card, Vector2(20, 16), Vector2(320, 20), str(steps[i][0]), 11, GOLD)
		_add_label(card, Vector2(20, 42), Vector2(320, 108), str(steps[i][1]), 13, Color("#d6e5e1"))
		var art := HowtoArt.new()
		art.mode = i
		art.position = Vector2(20, 158)
		art.size = Vector2(320, 68)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(art)
	var tip := _panel(root, Vector2(70, 428), Vector2(1140, 76), PANEL)
	_add_label(tip, Vector2(22, 12), Vector2(1096, 18), "FIRST RUN ADVICE", 10, GOLD)
	_add_label(tip, Vector2(22, 34), Vector2(1096, 40), "Start on Stake 0, bank around red barriers, and spend your first 50 cash in the shop. Practice has no stakes and no shot limit. The brass ring is the House's Spot: pot a ball and leave the cue on it for score and a shot back.", 13, Color("#d6e5e1"))
	var pb := _add_button(root, Vector2(70, 524), Vector2(280, 52), "TRY PRACTICE TABLE", _show_practice, true)
	pb.grab_focus()
	_add_button(root, Vector2(366, 524), Vector2(240, 52), "START RUN", _start_new_run)
	_add_label(root, Vector2(70, 588), Vector2(1140, 20), "HOUSE HEAT: pots fill the meter in the dock. At 100%, press F or CALL HOUSE — that shot scores double and a scratch costs no shot.", 11, MUTED)
	_add_label(root, Vector2(70, 610), Vector2(1140, 20), "THE HOUSE DUEL: the title's second front door. One rack, first to five pockets, no build and no shot budget. A pot keeps the cue; a miss hands it over.", 11, Color("#9fb6b4"))
	_add_label(root, Vector2(70, 632), Vector2(1140, 20), "PASS & PLAY: the duel's second seat. Two players on one keyboard, first to five. FIRE becomes PLAYER n READY on a handoff, and the winner breaks the next rack.", 11, Color("#9fb6b4"))

func _cycle_stake() -> void:
	stake = (stake + 1) % 3
	_sfx("click")
	_show_title()

# --- THE HOUSE'S CHALLENGE ------------------------------------------------
# A run's share text already carried a seed, but there was no way to use one:
# sharing was a dead end. The code packs the seed, signed term and stake into
# one token the title can consume. It is a route challenge, not a replay: the
# recipient builds their own run, so no server, account or ghost state is
# needed to turn a shared result into content.
func _challenge_code() -> String:
	return "RR1-%d-%s-%d" % [run_seed, run_contract.to_upper(), stake]

func _parse_challenge_code(raw: String) -> Dictionary:
	var regex := RegEx.new()
	if regex.compile("RR1-([0-9]{1,6})-([A-Z]+)-([0-9]+)") != OK:
		return {}
	var found := regex.search(raw.strip_edges().to_upper())
	if found == null:
		return {}
	var code_seed := int(found.get_string(1))
	var code_term := found.get_string(2).to_lower()
	var code_stake := int(found.get_string(3))
	if code_seed < 1 or code_seed > 999999 or code_stake > 2:
		return {}
	var known_term := false
	for contract in RUN_CONTRACTS:
		if str(contract.id) == code_term:
			known_term = true
			break
	if not known_term:
		return {}
	return {"seed": code_seed, "contract": code_term, "stake": code_stake}

func _enter_challenge_code(raw: String) -> bool:
	var parsed := _parse_challenge_code(raw)
	if parsed.is_empty():
		return false
	_start_challenge_run(parsed)
	return true

func _start_challenge_run(parsed: Dictionary) -> void:
	# A challenge is a normal tour with a friend's opening state; it is not a
	# ladder, so vault perks and a saved grudge still belong to the player. The
	# code fixes the route, term and stake, which are the parts a comparison
	# needs to be fair.
	daily_active = false
	daily_key = ""
	gauntlet_active = false
	grind_daily_active = false
	stake = int(parsed.stake)
	last_signed_contract = str(parsed.contract)
	run_contract = last_signed_contract
	run_seed = int(parsed.seed)
	last_seed = run_seed
	seed_value = run_seed
	_save_meta()
	_sfx("click")
	_start_run_with_seed()

func _show_challenge_entry() -> void:
	screen = "challenge"
	portal.gameplay_stop()
	var root := _base_screen("THE HOUSE'S CHALLENGE", "A friend's route, terms and stake in one code.", false)
	_add_button(root, Vector2(32, 116), Vector2(120, 40), "BACK", _show_title)
	var card := _panel(root, Vector2(180, 190), Vector2(920, 310), PANEL_ALT)
	_add_label(card, Vector2(40, 26), Vector2(840, 20), "PASTE A CHALLENGE CODE", 11, GOLD)
	_add_label(card, Vector2(40, 54), Vector2(840, 42), "Every normal result ends with a code like RR1-620122-MARK-0. It names the seed, the signed term and the stake. Your build and your table are still your own.", 13, Color("#d6e5e1"))
	challenge_input = LineEdit.new()
	challenge_input.position = Vector2(40, 112)
	challenge_input.size = Vector2(840, 56)
	challenge_input.placeholder_text = "RR1-620122-MARK-0"
	challenge_input.max_length = 40
	challenge_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	challenge_input.add_theme_font_size_override("font_size", 24)
	challenge_input.add_theme_color_override("font_color", Color("#f4ead5"))
	challenge_input.add_theme_color_override("font_placeholder_color", Color("#5e7478"))
	var input_style := _box(Color("#12232a"), Color("#4a6870"), 6)
	input_style.content_margin_left = 18
	input_style.content_margin_right = 18
	challenge_input.add_theme_stylebox_override("normal", input_style)
	var focus_style := _box(Color("#12232a"), GOLD, 6)
	focus_style.content_margin_left = 18
	focus_style.content_margin_right = 18
	challenge_input.add_theme_stylebox_override("focus", focus_style)
	card.add_child(challenge_input)
	challenge_input.text_submitted.connect(_on_challenge_submitted)
	challenge_input.grab_focus()
	challenge_error = _add_label(card, Vector2(40, 178), Vector2(840, 28), "", 12, RED)
	_add_button(card, Vector2(40, 220), Vector2(240, 44), "PLAY CHALLENGE", _submit_challenge, true)
	# A paste button makes the desktop flow one click; on a portal that blocks
	# clipboard reads it reports the failure instead of swallowing it, and the
	# field still accepts Ctrl+V.
	_add_button(card, Vector2(296, 220), Vector2(160, 44), "PASTE", _paste_challenge)
	_add_label(root, Vector2(180, 520), Vector2(920, 20), "A challenge starts a normal tour. Your build, vault and House record come with you.", 11, MUTED)
	if _has_run_save():
		_add_label(root, Vector2(180, 548), Vector2(920, 20), "A TOUR IS PARKED — STARTING THE CHALLENGE WILL REPLACE IT.", 10, GOLD)

func _submit_challenge() -> void:
	if not is_instance_valid(challenge_input):
		return
	if _enter_challenge_code(challenge_input.text):
		return
	challenge_error.text = "That code is not valid. It should look like RR1-620122-MARK-0."
	challenge_input.grab_focus()
	_sfx("foul")

func _on_challenge_submitted(_text: String) -> void:
	_submit_challenge()

func _paste_challenge() -> void:
	if not is_instance_valid(challenge_input):
		return
	var pasted := DisplayServer.clipboard_get().strip_edges()
	if pasted == "":
		challenge_error.text = "Clipboard is empty or blocked. Paste with Ctrl+V instead."
		challenge_input.grab_focus()
		return
	challenge_input.text = pasted
	challenge_error.text = ""
	challenge_input.grab_focus()

func _contract() -> Dictionary:
	for contract in RUN_CONTRACTS:
		if str(contract.id) == run_contract:
			return contract
	return RUN_CONTRACTS[0]

func _contract_index() -> int:
	for i in RUN_CONTRACTS.size():
		if str(RUN_CONTRACTS[i].id) == last_signed_contract:
			return i
	return 0

# A run starts with a signature, not a settings menu. The four terms are
# distinct playstyles: straight pool, banks, multi-ball clusters, and a cash
# rush bought with a shorter budget. The last term is focused, so a returning
# player can press Enter twice and be on the table without reading again.
func _show_contract_select() -> void:
	gauntlet_active = false
	grind_daily_active = false
	screen = "contract"
	portal.gameplay_stop()
	paused = false
	var root := _base_screen("THE HOUSE'S TERMS", "Choose the contract you will play under. One run, one identity.", false)
	_add_button(root, Vector2(32, 116), Vector2(120, 40), "BACK", _show_title)
	_add_label(root, Vector2(180, 120), Vector2(1068, 24), "THE TABLE IS THE SAME. WHAT IT PAYS IS NOT.", 11, MINT, HORIZONTAL_ALIGNMENT_RIGHT)
	for i in RUN_CONTRACTS.size():
		var contract: Dictionary = RUN_CONTRACTS[i]
		var chosen := i == _contract_index()
		var card := _panel(root, Vector2(60.0 + float(i) * 300.0, 166), Vector2(270, 408), PANEL_ALT)
		if chosen:
			var edge := ColorRect.new()
			edge.position = Vector2(2, 16)
			edge.size = Vector2(3, 376)
			edge.color = GOLD
			edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(edge)
		_add_label(card, Vector2(20, 16), Vector2(120, 18), "TERM %d OF 4" % (i + 1), 10, GOLD if chosen else MUTED)
		if total_runs <= 1 and i == 0:
			_add_label(card, Vector2(140, 16), Vector2(110, 18), "START HERE", 9, MINT, HORIZONTAL_ALIGNMENT_RIGHT)
		_add_label(card, Vector2(20, 40), Vector2(230, 40), str(contract.name), 26, GOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
		_add_label(card, Vector2(20, 82), Vector2(230, 34), str(contract.tagline), 12, Color("#d6e5e1"))
		var art := ContractArt.new()
		art.mode = i
		art.position = Vector2(20, 120)
		art.size = Vector2(230, 74)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(art)
		_add_label(card, Vector2(20, 208), Vector2(230, 16), "THE EDGE", 9, MINT)
		_add_label(card, Vector2(20, 226), Vector2(230, 54), str(contract.edge), 12, Color("#eef7f2"))
		_add_label(card, Vector2(20, 288), Vector2(230, 16), "THE CUT", 9, RED)
		_add_label(card, Vector2(20, 306), Vector2(230, 46), str(contract.cost), 12, Color("#d8cbb8"))
		var sign := _add_button(card, Vector2(20, 356), Vector2(230, 40), "SIGN THESE TERMS", _sign_contract.bind(str(contract.id)), chosen)
		if chosen:
			sign.grab_focus()
	var note := _panel(root, Vector2(60, 590), Vector2(1160, 62), PANEL)
	_add_label(note, Vector2(20, 10), Vector2(1120, 18), "THE TABLE REMEMBERS", 9, GOLD)
	_add_label(note, Vector2(20, 28), Vector2(1120, 28), "Banked pots need a cushion before the pocket. Multi-ball pots need two targets in one shot. Both terms pay for the setup with one fewer shot per table; the Mark and the Grifter keep every point they earn.", 11, Color("#c6d7d5"))
	_add_label(root, Vector2(60, 664), Vector2(1160, 20), "DAILY CHALLENGES ALWAYS PLAY UNDER THE MARK, so today's shared board stays fair. Your choice is saved with the run.", 10, MUTED)

# --- The House Duel -------------------------------------------------------
# A session mode beside the tour: one rack, alternating turns, first to five
# pockets. It shares the physics, the table and the House's shot planner with
# the boss fight, but none of the run economy, so a duel can never touch a
# parked run, its build or its cash.

# The second seat gets a real front door: race length, the all-time couch
# record, and one press to start. The house race (five) is the default.
func _show_local_setup() -> void:
	gauntlet_active = false
	grind_daily_active = false
	screen = "local_setup"
	portal.gameplay_stop()
	paused = false
	var root := _base_screen("PASS & PLAY", "Two players, one keyboard, one table. No account, no server.", false)
	_add_button(root, Vector2(32, 116), Vector2(120, 40), "BACK", _show_title)

	var rules := _panel(root, Vector2(60, 166), Vector2(470, 430), PANEL)
	_add_label(rules, Vector2(26, 20), Vector2(418, 18), "THE MATCH", 10, GOLD)
	_add_label(rules, Vector2(26, 42), Vector2(418, 40), "FIRST TO %d POCKETS" % duel_race, 30, Color("#f4ead5"), HORIZONTAL_ALIGNMENT_LEFT, true)
	_add_label(rules, Vector2(26, 92), Vector2(418, 80), "Player 1 breaks. A pot keeps the cue; a dry shot or a scratch passes it. The winner breaks the next rack, and a handoff card stops a shared keyboard from firing out of turn.", 13, Color("#d6e5e1"))
	var divider := ColorRect.new()
	divider.position = Vector2(26, 184)
	divider.size = Vector2(418, 1)
	divider.color = Color("#33505a")
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rules.add_child(divider)
	_add_label(rules, Vector2(26, 202), Vector2(418, 18), "RACE LENGTH", 10, GOLD)
	_add_label(rules, Vector2(26, 222), Vector2(418, 18), "Three is a coffee break. Five is the house race. Seven is a grudge.", 10, MUTED)
	for i in DUEL_RACES.size():
		var length: int = DUEL_RACES[i]
		var chosen := length == duel_race
		var race_button := _add_button(rules, Vector2(26 + float(i) * 142.0, 250), Vector2(130, 46), "TO %d" % length, _choose_duel_race.bind(length), chosen, GOLD if chosen else Color(0, 0, 0, 0))
		race_button.add_theme_font_size_override("font_size", 16)
	_add_label(rules, Vector2(26, 310), Vector2(418, 18), "NO SHOT BUDGET   ·   NO BUILD   ·   NO LADDER WRITES", 9, MUTED)
	var start := _add_button(rules, Vector2(26, 344), Vector2(418, 56), "START MATCH", _start_local_match, true)
	start.grab_focus()

	var record := _panel(root, Vector2(550, 166), Vector2(670, 430), PANEL_ALT)
	_add_label(record, Vector2(26, 20), Vector2(618, 18), "THE COUCH RECORD", 10, GOLD)
	_add_label(record, Vector2(26, 40), Vector2(618, 20), "Every local match is a rivalry. Wins survive sessions.", 11, MUTED)
	for i in 2:
		var is_p1 := i == 0
		var accent := MINT if is_p1 else GOLD
		var seat := _panel(record, Vector2(26 + float(i) * 318.0, 74), Vector2(300, 190), PANEL)
		var edge := ColorRect.new()
		edge.position = Vector2(0, 12)
		edge.size = Vector2(4, 166)
		edge.color = accent
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		seat.add_child(edge)
		_add_label(seat, Vector2(22, 14), Vector2(240, 18), "PLAYER %d" % (i + 1), 11, accent)
		_add_label(seat, Vector2(22, 34), Vector2(240, 84), str(duel_couch_p1 if is_p1 else duel_couch_p2), 64, Color("#f4ead5"), HORIZONTAL_ALIGNMENT_LEFT, true)
		_add_label(seat, Vector2(22, 122), Vector2(240, 18), "MATCHES WON", 9, MUTED)
	var record_total := duel_couch_p1 + duel_couch_p2
	if record_total == 0:
		_add_label(record, Vector2(26, 280), Vector2(618, 24), "No matches yet. The first winner takes the first line.", 12, Color("#d6e5e1"))
	else:
		var leader := "LEVEL SERIES"
		if duel_couch_p1 > duel_couch_p2:
			leader = "PLAYER 1 LEADS"
		elif duel_couch_p2 > duel_couch_p1:
			leader = "PLAYER 2 LEADS"
		_add_label(record, Vector2(26, 276), Vector2(618, 26), leader, 18, GOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
	_add_label(record, Vector2(26, 316), Vector2(618, 18), "WINNER BREAKS THE NEXT RACK", 11, MINT)
	_add_label(record, Vector2(26, 340), Vector2(618, 60), "A local match never touches your tour, your House ladder or your reputation. It only settles the couch.", 11, MUTED)

	var footer := _panel(root, Vector2(60, 620), Vector2(1160, 62), PANEL)
	_add_label(footer, Vector2(22, 10), Vector2(1116, 16), "HOW A TURN ENDS", 9, GOLD)
	_add_label(footer, Vector2(22, 28), Vector2(1116, 30), "A pot keeps the shooter at the table. A dry shot or a scratch passes the cue. First to %d takes the rack." % duel_race, 12, Color("#d6e5e1"))

func _choose_duel_race(length: int) -> void:
	duel_race = clampi(length, 2, 9)
	_sfx("click")
	_show_local_setup()

func _start_local_match() -> void:
	_start_duel(0, 0, true)

func _start_duel(form := -1, rack_seed := 0, local := false, keep_series := false) -> void:
	var target_form := int(form)
	if target_form < 0:
		target_form = clampi(duel_best_form, 0, DUEL_FORMS.size() - 1)
	target_form = clampi(target_form, 0, DUEL_FORMS.size() - 1)
	duel_local = local
	# The setup card owns the local race length; the ladder always plays five.
	duel_target = clampi(duel_race, 2, 9) if duel_local else DUEL_TARGET
	duel_winner = 1
	# A fresh entry from the title opens a new series; a rematch keeps it and
	# lets the previous winner break.
	if duel_local and not keep_series:
		duel_series_p1 = 0
		duel_series_p2 = 0
		duel_breaker = 0
	duel_active = true
	gauntlet_active = false
	grind_daily_active = false
	daily_active = false
	# A duel is a pocket race and has its own pocket rules; the position spot
	# would add a second scoreboard to a mode that deliberately has none.
	house_spot = Vector2.ZERO
	paused = false
	portal.gameplay_start()
	screen = "encounter"
	duel_form = target_form
	duel_seed = rack_seed if rack_seed != 0 else absi(randi()) + 1
	library.build_duel_rack(simulator, duel_seed)
	if duel_local:
		house_aim_error = 0.035
		scenario = {
			"id": "duel",
			"name": "PASS & PLAY",
			"subtitle": "Two players, one rack. First to %d pockets. A pot keeps the cue." % duel_target,
			"hint": "A pot keeps your turn; a dry shot or a scratch hands the cue to the other player. No build, no budget.",
			"contract": "First to %d pockets." % duel_target,
			"contract_type": "duel",
			"target": duel_target,
			"shots": 99,
		}
	else:
		var form_data: Dictionary = DUEL_FORMS[duel_form]
		house_aim_error = float(form_data.error)
		scenario = {
			"id": "duel",
			"name": "THE HOUSE DUEL",
			"subtitle": "Race The House to five pockets. A pot keeps the cue. A miss hands it over.",
			"hint": "First to five pockets takes the table. A pot keeps your turn; a dry shot or a scratch gives it to The House.",
			"contract": "First to five pockets.",
			"contract_type": "duel",
			"target": duel_target,
			"shots": 99,
		}
	current_node = -1
	encounter_is_boss = false
	encounter_is_elite = false
	boss_phase = 0
	duel_player = 0
	duel_house = 0
	duel_turn_house = duel_local and duel_breaker == 1
	duel_handoff = false
	duel_forfeited = false
	shots_remaining = 99
	table_par = 0
	score = 0
	shot_number = 0
	pocketed_count = 0
	bank_count = 0
	combo_shots = 0
	scratches = 0
	fouls = 0
	combo_streak = 0
	best_streak = 0
	lane_pockets = 0
	current_power = 0.48
	current_spin = Vector2.ZERO
	last_aim = Vector2.RIGHT
	resolving = false
	house_pending = 0.0
	house_shooting = false
	house_aim = Vector2.RIGHT
	house_place_from = Vector2.ZERO
	house_power = 0.5
	house_turns = 0
	heat = 0.0
	house_call_armed = false
	coach_active = false
	coach_aimed = false
	coach_powered = false
	last_result = "YOUR BREAK — take the table."
	if duel_local:
		last_result = "PLAYER %d BREAKS — take the table." % (duel_breaker + 1)
	result_color = MINT
	shot_events.clear()
	ball_trails.clear()
	pocket_flashes.clear()
	_render_encounter()
	queue_redraw()

# The House's shot planner seeds its jitter from run_seed so a boss fight is
# deterministic. A duel owns its own seed: borrowing the tour seed would make
# the same duel replay differently after a run and would leak one mode into
# another's determinism.
func _house_roll_seed() -> int:
	var base := absi(duel_seed) if duel_active else absi(run_seed)
	return base + (current_node + 2) * 7919 + house_turns * 104729 + simulator.closed_pockets.size() * 31

func _duel_resolve_player_shot(pocketed: int, scratched: bool, legal_contact: bool) -> void:
	if not duel_active:
		return
	if scratched:
		_recover_cue()
	# In a local match this same call resolves whichever human just shot. The pot
	# belongs to that seat, and a miss must pass the cue to the other human —
	# never to the House's AI turn timer.
	var seat_house := duel_local and duel_turn_house
	var shooter := "PLAYER 2" if seat_house else ("PLAYER 1" if duel_local else "YOU")
	var rival := "PLAYER 1" if seat_house else ("PLAYER 2" if duel_local else "THE HOUSE")
	if seat_house:
		duel_house += pocketed
	else:
		duel_player += pocketed
	var keeps_turn := pocketed > 0 and not scratched
	if scratched:
		# A pot on a scratch still counts in the race; saying only "scratch"
		# would make the score jump with no explanation.
		if pocketed > 0:
			last_result = "%s POTS %d AND SCRATCHES — %s takes the cue." % [shooter, pocketed, rival] if duel_local else "YOU POT %d AND SCRATCH — The House takes the cue." % pocketed
		else:
			last_result = "%s SCRATCHES — %s takes the cue." % [shooter, rival] if duel_local else "SCRATCH — The House takes the cue."
		result_color = RED
		_sfx("scratch")
	elif pocketed > 0:
		last_result = "%s POTS %d — keeps the cue." % [shooter, pocketed] if duel_local else "YOU POT %d — keep the table." % pocketed
		result_color = GOLD if seat_house else MINT
		_sfx("pocket")
	elif not legal_contact:
		last_result = "NO LEGAL CONTACT — %s takes the cue." % rival
		result_color = RED
		_sfx("foul")
	else:
		last_result = "DRY SHOT — %s takes the cue." % rival
		result_color = Color("#b9c9c8")
		_sfx("click")
	_refresh_hud()
	queue_redraw()
	if _duel_check_end():
		return
	if keeps_turn:
		duel_turn_house = seat_house
		_refocus_fire()
		return
	if duel_local:
		duel_turn_house = not seat_house
		# The next human has to take the table deliberately. Without this beat a
		# shared keyboard fires the other player's shot by muscle memory.
		duel_handoff = true
		house_pending = 0.0
		_refresh_hud()
		return
	duel_turn_house = true
	house_pending = 1.15
	_refresh_hud()

# The handoff is the only confirmation in a local match: FIRE first takes the
# cue, then fires. It is short enough not to slow a match and long enough to
# stop the other player from shooting out of turn.
func _duel_confirm_handoff() -> void:
	if not duel_local or not duel_handoff:
		return
	duel_handoff = false
	_sfx("click")
	last_result = "%s TO SHOOT — pot and keep the cue." % ("PLAYER 2" if duel_turn_house else "PLAYER 1")
	result_color = GOLD if duel_turn_house else MINT
	_refresh_hud()
	_refocus_fire()

func _duel_finish_house_shot() -> void:
	var cue_scratched := false
	var potted := 0
	var potted_pocket := -1
	for event in shot_events:
		if event.type != "pocket":
			continue
		var ball := simulator.get_ball(int(event.ball_id))
		if ball.is_empty():
			continue
		if int(event.ball_id) == simulator.cue_ball_id:
			cue_scratched = true
			continue
		if bool(ball.get("target", false)):
			potted += 1
			if potted_pocket < 0:
				potted_pocket = int(event.get("pocket", -1))
	if cue_scratched:
		_recover_cue()
	duel_house += potted
	# The higher forms claim the table itself: each House pot bolts a pocket
	# until the form's cap. The ball is not spotted back — the pot is a point in
	# the race, and what shrinks is the player's geometry for the next one.
	var shutdown_limit := int(DUEL_FORMS[duel_form].get("shut", 0))
	var shut_note := ""
	if potted > 0 and simulator.closed_pockets.size() < shutdown_limit:
		var shut_index := potted_pocket
		if shut_index < 0 or simulator.closed_pockets.has(shut_index):
			for index in simulator.pockets.size():
				if not simulator.closed_pockets.has(index):
					shut_index = index
					break
		if shut_index >= 0:
			simulator.close_pocket(shut_index)
			shut_note = " A POCKET BOLTS SHUT."
			_add_trauma(0.5)
			_sfx("boss")
	if cue_scratched:
		last_result = "THE HOUSE SCRATCHES — the cue is yours." if potted == 0 else "THE HOUSE POTS %d AND SCRATCHES — the cue is yours.%s" % [potted, shut_note]
		result_color = MINT
		_sfx("scratch")
	elif potted > 0:
		last_result = "THE HOUSE POTS %d — it keeps the table.%s" % [potted, shut_note]
		result_color = RED
		_add_trauma(0.4)
		_floater(Vector2(795, 320), "HOUSE +%d" % potted, RED)
		_sfx("pocket")
	else:
		last_result = "THE HOUSE MISSES — the cue is yours."
		result_color = Color("#b9c9c8")
		_sfx("click")
	_refresh_hud()
	queue_redraw()
	if _duel_check_end():
		return
	if potted > 0 and not cue_scratched:
		duel_turn_house = true
		house_pending = 0.95
		_refresh_hud()
	else:
		# Refreshing after the hand-back is mandatory: the HUD was drawn while
		# the House still held the cue, and a disabled FIRE button on the player's
		# turn softlocks the match with no other way to shoot.
		duel_turn_house = false
		_refresh_hud()
		_refocus_fire()

func _duel_check_end() -> bool:
	if not duel_active:
		return false
	if duel_player >= duel_target:
		_finish_duel(true)
		return true
	if duel_house >= duel_target:
		_finish_duel(false)
		return true
	# With nine targets a race to five always resolves before the rack empties,
	# but a future rack change must not be able to leave the table unendable.
	if simulator.active_target_count() <= 0:
		_finish_duel(duel_player > duel_house)
		return true
	return false

func _finish_duel(won: bool, forfeited := false) -> void:
	if not duel_active:
		return
	duel_forfeited = forfeited
	duel_active = false
	duel_turn_house = false
	paused = false
	_hide_pause_overlay()
	house_pending = 0.0
	house_shooting = false
	resolving = false
	duel_handoff = false
	# A local match is a couch game, not ladder progress: no wins, no streak,
	# no reputation and no House form are written. Only the session series
	# moves, and the winner keeps the break for the next rack.
	if duel_local:
		duel_winner = 0
		if not forfeited:
			duel_winner = 1 if won else 2
			if won:
				duel_series_p1 += 1
				duel_couch_p1 += 1
				duel_breaker = 0
			else:
				duel_series_p2 += 1
				duel_couch_p2 += 1
				duel_breaker = 1
			# Only the couch record persists; the House ladder is untouched.
			_save_meta()
		portal.gameplay_stop()
		_show_local_duel_result()
		return
	portal.gameplay_stop()
	var form_index := duel_form
	var unlocked := false
	if won:
		duel_wins += 1
		duel_streak += 1
		duel_best_streak = maxi(duel_best_streak, duel_streak)
		# Beating the hardest form you have reached unlocks the next one. The
		# counter is also the trophy stat, so "forms beaten" and the ladder can
		# never disagree.
		if form_index >= duel_best_form and duel_best_form < DUEL_FORMS.size():
			duel_best_form += 1
			unlocked = duel_best_form < DUEL_FORMS.size()
		reputation += 1
		_sfx("victory")
	else:
		duel_streak = 0
		_sfx("defeat")
	_save_meta()
	_show_duel_result(won, form_index, unlocked)
	_check_trophies()

func _show_duel_result(won: bool, form_index: int, unlocked: bool) -> void:
	screen = "duel_result"
	var form: Dictionary = DUEL_FORMS[form_index]
	var subtitle := "The House keeps its table."
	if won:
		subtitle = "You take the table from Form %s." % _duel_roman(form_index)
	elif duel_forfeited:
		subtitle = "You leave the table. The House keeps it."
	var root := _base_screen("THE HOUSE DUEL", subtitle, false)
	_add_label(root, Vector2(60, 148), Vector2(1160, 76), "THE TABLE IS YOURS" if won else "THE HOUSE COLLECTS", 64, GOLD if won else RED, HORIZONTAL_ALIGNMENT_CENTER, true)
	var score_line := "YOU  %d   ·   %d  THE HOUSE" % [duel_player, duel_house]
	if duel_forfeited and not won:
		score_line = "FORFEIT   ·   YOU  %d   ·   %d  THE HOUSE" % [duel_player, duel_house]
	_add_label(root, Vector2(60, 226), Vector2(1160, 30), score_line, 22, Color("#eef7f2"), HORIZONTAL_ALIGNMENT_CENTER)
	var card := _panel(root, Vector2(330, 276), Vector2(620, 86), PANEL)
	_add_label(card, Vector2(24, 12), Vector2(260, 16), "FORM %s  ·  %s" % [_duel_roman(form_index), str(form.name)], 10, GOLD)
	# One body label, chosen once. Adding the unlock text over the form tag left
	# both strings stacked in the same rectangle on every win that unlocked a form.
	var card_body := str(form.tag)
	var card_color := Color("#d6e5e1")
	if unlocked:
		var next: Dictionary = DUEL_FORMS[duel_best_form]
		card_body = "FORM %s UNLOCKED — %s.\n%s" % [_duel_roman(duel_best_form), str(next.name), str(next.tag)]
		card_color = GOLD
	elif won and duel_best_form >= DUEL_FORMS.size():
		card_body = "You have beaten The House at its true form. Nothing is left to unlock — only the streak."
		card_color = GOLD
	_add_label(card, Vector2(24, 32), Vector2(572, 44), card_body, 13, card_color)
	# The ladder is the mode's long arc, so the result names every step, not
	# just the one just played.
	for i in DUEL_FORMS.size():
		var chip := _panel(root, Vector2(330 + float(i) * 160.0, 380), Vector2(140, 58), PANEL_ALT if i == form_index else PANEL)
		var beaten := i < duel_best_form
		var state := "BEATEN" if beaten else ("NEXT" if i == duel_best_form else "LOCKED")
		_add_label(chip, Vector2(12, 8), Vector2(116, 14), "FORM %s" % _duel_roman(i), 9, MUTED)
		_add_label(chip, Vector2(12, 24), Vector2(116, 20), str(DUEL_FORMS[i].name), 12, Color("#eef7f2"))
		_add_label(chip, Vector2(12, 42), Vector2(116, 12), state, 9, GOLD if state == "NEXT" else (MINT if beaten else MUTED))
	_add_label(root, Vector2(330, 454), Vector2(620, 20), "WINS %02d   ·   STREAK %02d   ·   BEST STREAK %02d   ·   %s" % [duel_wins, duel_streak, duel_best_streak, "+1 REPUTATION" if won else "STREAK BROKEN"], 12, GOLD if won else MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var rematch := _add_button(root, Vector2(330, 496), Vector2(196, 52), "REMATCH", _start_duel.bind(form_index, duel_seed), true)
	rematch.grab_focus()
	if unlocked:
		_add_button(root, Vector2(542, 496), Vector2(196, 52), "FACE FORM %s" % _duel_roman(duel_best_form), _start_duel.bind(duel_best_form, 0), false, GOLD)
	else:
		_add_button(root, Vector2(542, 496), Vector2(196, 52), "NEW RACK", _start_duel.bind(form_index, 0), false, GOLD)
	_add_button(root, Vector2(754, 496), Vector2(196, 52), "TITLE", _show_title)
	_add_label(root, Vector2(330, 560), Vector2(620, 20), "A pot keeps the cue. A dry shot or a scratch hands it to The House.", 11, MUTED, HORIZONTAL_ALIGNMENT_CENTER)

# A local result is a rematch screen, not a ladder report: it never mentions
# reputation, forms or streaks, and the series is the only record it keeps.
func _show_local_duel_result() -> void:
	screen = "duel_result"
	var abandoned := duel_winner == 0
	var p1_won := duel_winner == 1
	var subtitle := "Two players. One table. One winner."
	if abandoned:
		subtitle = "The match ended before the fifth pot. Nothing was recorded."
	var root := _base_screen("PASS & PLAY", subtitle, false)
	var headline := "MATCH ABANDONED"
	var head_color := Color("#9fb6b4")
	if not abandoned:
		headline = "PLAYER 1 WINS" if p1_won else "PLAYER 2 WINS"
		head_color = GOLD
	_add_label(root, Vector2(60, 142), Vector2(1160, 76), headline, 64, head_color, HORIZONTAL_ALIGNMENT_CENTER, true)
	for i in 2:
		var is_p1 := i == 0
		var score := duel_player if is_p1 else duel_house
		var accent := MINT if is_p1 else GOLD
		var won_this := not abandoned and duel_winner == i + 1
		var card := _panel(root, Vector2(250.0 if is_p1 else 650.0, 236), Vector2(380, 146), PANEL_ALT if won_this else PANEL)
		var edge := ColorRect.new()
		edge.position = Vector2(0, 12)
		edge.size = Vector2(4, 122)
		edge.color = accent
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(edge)
		_add_label(card, Vector2(26, 14), Vector2(220, 18), "PLAYER %d" % (i + 1), 11, accent)
		_add_label(card, Vector2(250, 14), Vector2(104, 18), "POCKETS", 9, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
		_add_label(card, Vector2(26, 30), Vector2(160, 80), str(score), 62, Color("#f4ead5"), HORIZONTAL_ALIGNMENT_LEFT, true)
		var state := "SERIES %d" % (duel_series_p1 if is_p1 else duel_series_p2)
		if not abandoned:
			state += "   ·   " + ("TAKES THE RACK" if won_this else "RUNNER-UP")
		_add_label(card, Vector2(26, 112), Vector2(328, 20), state, 10, MUTED)
	var result_note := "NO RESULT RECORDED" if abandoned else "WINNER BREAKS THE NEXT RACK"
	_add_label(root, Vector2(60, 396), Vector2(1160, 22), "ALL-TIME   P1 %d — %d P2   ·   %s" % [duel_couch_p1, duel_couch_p2, result_note], 11, MUTED if abandoned else GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	var rematch := _add_button(root, Vector2(330, 430), Vector2(196, 52), "REMATCH", _start_duel.bind(0, duel_seed, true, true), true)
	rematch.grab_focus()
	_add_button(root, Vector2(542, 430), Vector2(196, 52), "NEW RACK", _start_duel.bind(0, 0, true, true), false, GOLD)
	_add_button(root, Vector2(754, 430), Vector2(196, 52), "TITLE", _show_title)
	_add_label(root, Vector2(330, 496), Vector2(620, 20), "A pot keeps the cue. A dry shot or a scratch passes it.", 11, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_sfx("victory" if not abandoned else "click")

func _show_grind_intro() -> void:
	gauntlet_active = false
	grind_daily_active = false
	_refresh_grind_daily()
	screen = "grind"
	portal.gameplay_stop()
	paused = false
	menu_return_screen = "title"
	var root := _base_screen("THE GRIND", "No map. No favors. One rack after another until the House closes the table.", false)
	_add_button(root, Vector2(32, 116), Vector2(120, 40), "BACK", _show_title)
	_add_label(root, Vector2(180, 136), Vector2(600, 54), "HOW DEEP CAN YOU GO?", 42, GOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
	_add_label(root, Vector2(180, 194), Vector2(600, 64), "Every rack is procedural and every clear buys one piece. The asks climb, the shot budgets tighten, and every fifth table is a gate. No map, no favor, no second table.", 14, Color("#d6e5e1"))
	var record := _panel(root, Vector2(820, 136), Vector2(360, 152), PANEL)
	_add_label(record, Vector2(24, 16), Vector2(312, 18), "YOUR DEEPEST RUN", 10, GOLD)
	if gauntlet_best_stage > 0:
		_add_label(record, Vector2(24, 38), Vector2(312, 40), "TABLE %02d" % gauntlet_best_stage, 30, Color("#eef7f2"), HORIZONTAL_ALIGNMENT_LEFT, true)
		_add_label(record, Vector2(24, 84), Vector2(312, 22), "HIGH SCORE  %04d" % gauntlet_best_score, 13, MINT)
	else:
		_add_label(record, Vector2(24, 42), Vector2(312, 30), "NO RUN YET", 26, MUTED, HORIZONTAL_ALIGNMENT_LEFT, true)
		_add_label(record, Vector2(24, 84), Vector2(312, 22), "The first rack is the easy one.", 12, MUTED)
	var ladder_note := "TODAY'S LADDER  ·  NOT PLAYED"
	if _grind_daily_played_today():
		ladder_note = "TODAY'S LADDER  ·  BEST %02d  ·  HIGH %04d" % [grind_daily_best_stage, grind_daily_best_score]
	_add_label(record, Vector2(24, 110), Vector2(312, 18), ladder_note, 9, MINT if _grind_daily_played_today() else GOLD)
	var session_note := "ONE SESSION  ·  NO CONTINUE"
	var ladder_streak := _grind_daily_streak_now()
	if ladder_streak > 0:
		session_note = "%d-DAY LADDER STREAK  ·  NO CONTINUE" % ladder_streak
	elif not grind_pace_splits.is_empty():
		session_note = "PACE %d TABLES  ·  NO CONTINUE" % grind_pace_splits.size()
	_add_label(record, Vector2(24, 130), Vector2(312, 16), session_note, 9, MUTED)
	var rules := [
		["01 · CLEAR THE RACK", "Pocket the target before the budget runs out. Beat par to bank one extra shot for the next rack."],
		["02 · TAKE ONE PIECE", "Every clear opens the reward room. Your build carries through the whole run; two of a kind unlock a set rule."],
		["03 · EVERY FIFTH IS A GATE", "A score gate with double foul cost. Break it to keep the line alive."],
	]
	for i in rules.size():
		var card := _panel(root, Vector2(140 + i * 330, 300), Vector2(300, 158), PANEL_ALT)
		_add_label(card, Vector2(20, 18), Vector2(260, 20), str(rules[i][0]), 10, GOLD)
		_add_label(card, Vector2(20, 46), Vector2(260, 92), str(rules[i][1]), 13, Color("#d6e5e1"))
	var note := _panel(root, Vector2(140, 482), Vector2(1040, 62), PANEL)
	_add_label(note, Vector2(20, 10), Vector2(1000, 18), "THE GRIND'S RULES", 9, GOLD)
	_add_label(note, Vector2(20, 28), Vector2(1000, 24), "House Heat still charges, but resets on every rack. Fouls cost shots. The favor is not offered here.", 12, Color("#c6d7d5"))
	var enter := _add_button(root, Vector2(140, 578), Vector2(260, 56), "TODAY'S LADDER", _start_grind_daily, true)
	enter.grab_focus()
	_add_button(root, Vector2(414, 578), Vector2(190, 56), "FREE GRIND", _start_gauntlet)
	_add_button(root, Vector2(618, 578), Vector2(170, 56), "BACK TO TITLE", _show_title)
	_add_label(root, Vector2(140, 640), Vector2(1040, 18), "The ladder is today's fixed racks with base rules. The free grind is endless practice for your own record.", 11, MUTED)
	_add_label(root, Vector2(140, 668), Vector2(1040, 22), "THE HOUSE DOES NOT CLOSE. YOU DO.", 12, MUTED, HORIZONTAL_ALIGNMENT_CENTER)

func _start_gauntlet() -> void:
	_sfx("click")
	gauntlet_active = true
	grind_daily_active = false
	daily_active = false
	daily_key = ""
	# The Grind is the same rack for everyone: no signed term tilts the score.
	run_contract = "mark"
	menu_return_screen = "title"
	# Keep a parked tour alive: the Grind has no save slot, so it must not wipe
	# the route a player left at the map.
	_start_run_with_seed(true)

func _build_grind_map() -> void:
	# One reusable node keeps every encounter/map invariant intact while the
	# table number lives in run_stage. The map screen is never shown in a run.
	map_nodes = [{"type": "standard", "name": "The Grind", "pos": Vector2(610, 150), "done": false, "scenario_id": ""}]
	map_edges = []
	map_unlocked = [0]
	map_position = 0
	current_node = 0

func _start_grind_table() -> void:
	if not gauntlet_active:
		return
	var gate := run_stage % 5 == 0
	map_nodes[0].type = "elite" if gate else "standard"
	map_nodes[0].done = false
	current_node = 0
	_start_encounter(false)

# Endless rules land after the rack is built so the target is capped against
# the balls actually on the felt, and before the shot budget is computed.
func _apply_grind_rules() -> void:
	var table_no := maxi(run_stage, 1)
	var gate := table_no % 5 == 0
	if gate:
		# Cap the gate against the rack's live value: an authored rack can hold
		# as little as 80 points, and a gate that asks for more than the felt can
		# pay without a multiplier is not a test, it is a wall.
		var rack_value := 0
		for ball in simulator.balls:
			if bool(ball.get("target", false)):
				rack_value += int(ball.get("value", 0))
		scenario.contract_type = "score"
		scenario.target = mini(80 + table_no * 5, maxi(72, int(float(rack_value) * 1.1)))
		scenario.shots = 8
		scenario.name = ("DAILY LADDER  //  GATE %02d" if grind_daily_active else "THE GRIND  //  GATE %02d") % table_no
		scenario.contract = "GATE %02d: Score %d before the shots run out. Fouls cost an extra shot." % [table_no, int(scenario.target)]
		scenario.hint = "A gate rack. Play for clusters; one big shot beats four small ones."
	else:
		var targets := mini(simulator.active_target_count(), 3 + int((table_no - 1) / 2))
		scenario.contract_type = "clear"
		scenario.target = targets
		scenario.shots = maxi(6, 10 - int(table_no / 3))
		scenario.name = ("DAILY LADDER  //  TABLE %02d" if grind_daily_active else "THE GRIND  //  TABLE %02d") % table_no
		scenario.contract = "TABLE %02d: Clear %d targets before the shots run out." % [table_no, targets]
		scenario.hint = "Every clear buys a piece. Play the rack, not the highlight."
	if grind_daily_active:
		scenario.subtitle = "Today's ladder, rack %d. Same racks for every player." % table_no
	else:
		scenario.subtitle = "Endless rack %d. The House does not offer a favor here." % table_no

func _sign_contract(contract_id: String) -> void:
	run_contract = contract_id
	last_signed_contract = contract_id
	_save_meta()
	_sfx("click")
	_start_new_run()

func _show_practice() -> void:
	# Zero-stakes table that teaches without consuming a run.
	gauntlet_active = false
	grind_daily_active = false
	portal.gameplay_start()
	current_node = -1
	seed_value += 31
	# A barrier and a zone on the practice table, so a new player learns both.
	scenario = library.get_by_id("gatehouse", seed_value)
	scenario.name = "PRACTICE // GATEHOUSE"
	scenario.contract = "No stakes. Learn banks and zones."
	scenario.subtitle = ""
	scenario.contract_type = "clear"
	scenario.target = 4
	scenario.shots = 99
	screen = "encounter"
	encounter_is_elite = false
	encounter_is_boss = false
	library.build_scenario(simulator, scenario)
	score = 0
	shot_number = 0
	pocketed_count = 0
	bank_count = 0
	combo_shots = 0
	scratches = 0
	fouls = 0
	combo_streak = 0
	shots_remaining = 99
	_apply_set_table_start()
	current_power = 0.48
	current_spin = Vector2.ZERO
	last_aim = Vector2.RIGHT
	resolving = false
	heat = 0.0
	house_call_armed = false
	house_spot_table_hits = 0
	house_spot_paid_shot = false
	house_spot_flash = 0.0
	house_spot_boost = 0
	_place_house_spot()
	last_result = "Practice: no stakes. Try a bank, then a combo."
	result_color = MINT
	ball_trails.clear()
	pocket_flashes.clear()
	_start_coach_if_new(false)
	_render_encounter()

func _retry_seed() -> void:
	grind_daily_active = false
	run_seed = last_seed
	seed_value = run_seed
	# A daily retry replays the same day's tour and must stay a daily run.
	_start_run_with_seed(daily_active)

func _start_new_run() -> void:
	grind_daily_active = false
	run_contract = last_signed_contract
	run_seed = randi() % 900000 + 1000
	last_seed = run_seed
	seed_value = run_seed
	_start_run_with_seed()

func _continue_run() -> void:
	if not _load_run():
		_start_new_run()

func _start_run_with_seed(preserve_save := false) -> void:
	if daily_active:
		# A daily is the one shared table: no personal terms can tilt it.
		run_contract = "mark"
	if not preserve_save:
		_clear_run_save()
		daily_active = false
		daily_key = ""
		grind_daily_active = false
	menu_return_screen = "title"
	run_best_streak = 0
	run_best_shot = 0
	favor_available = true
	active_cue = "House Cue"
	active_cue_id = "house"
	run_score = 0
	run_cash = 60
	pending_wager = 0
	table_wager = 0
	last_wager_stake = 0
	last_wager_payout = 0
	run_stage = 1
	run_tables_cleared = 0
	map_position = 0
	current_node = -1
	map_unlocked = [0]
	collection.clear()
	codex_seen.clear()
	run_bosses_beaten = 0
	bank_bonus = 0
	combo_bonus = 0
	rail_bonus = 0
	streak_guard = 0
	scratch_guard = 0
	side_pocket_bonus = 0
	house_spot_boost = 0
	next_shot_modifier = 0
	permanent_shot_bonus = 0
	grind_par_shots = 0
	run_pace_splits.clear()
	run_pace_target.clear()
	# THE HOUSE REMEMBERS: only a normal tour carries the saved read. Dailies and
	# the endless modes are exhibition tables where two players must face the
	# same racks, so a personal grudge there would break the shared board.
	grudge_active = not daily_active and not gauntlet_active and house_grudge != ""
	run_banks = 0
	run_scratches = 0
	run_combo_shots = 0
	summary_grudge_settled = false
	summary_grudge_name = ""
	if gauntlet_active:
		var pace_source := grind_daily_pace_splits if grind_daily_active else grind_pace_splits
		for split in pace_source:
			run_pace_target.append(int(split))
	# Vault unlocks apply to normal tours only. A daily is the shared table, so
	# a long-time player and a first-timer get the same contract there. Instead
	# the daily carries one date-picked twist, which is what makes today's tour
	# read as an event rather than a normal run with a fixed seed.
	if daily_active:
		var twist := _daily_twist(daily_key)
		run_cash += int(twist.get("cash", 0))
		bank_bonus += int(twist.get("bank", 0))
		rail_bonus += int(twist.get("rail", 0))
		side_pocket_bonus += int(twist.get("side", 0))
		permanent_shot_bonus = int(twist.get("shots", 0))
	elif not grind_daily_active:
		# The daily ladder is a shared, date-seeded test: vault perks would make
		# two players' identical racks play differently, so they stay home.
		if _has_unlock("house_credit"):
			run_cash = 80
		if _has_unlock("allowance"):
			permanent_shot_bonus = 1
		if _has_unlock("cue_rack"):
			active_cue = "The Surveyor"
			active_cue_id = "surveyor"
			bank_bonus += 10
			rail_bonus += 2
		# The signed terms bake into the run now, beside vault perks, so a
		# continued run keeps the identity it began with. The Mark is all zeros.
		var terms := _contract()
		run_cash += int(terms.cash)
		permanent_shot_bonus += int(terms.shots)
		bank_bonus += int(terms.bank)
		combo_bonus += int(terms.combo)
		rail_bonus += int(terms.rail)
	# A Grind or ladder session is not a tour start; counting it would make the
	# title's run count climb every time a player chased a free record.
	if not gauntlet_active:
		total_runs += 1
	_save_meta()
	_build_map()
	if gauntlet_active:
		_build_grind_map()
		_start_grind_table()
		return
	_show_map()

func _node_danger(index: int) -> String:
	match str(map_nodes[index].type):
		"boss":
			return "LETHAL"
		"elite":
			return "RISKY"
		"event":
			return "GAMBLE"
		"shop":
			return "SAFE"
	return "FAIR"

func _node_preview(index: int) -> String:
	# The rule, not the payout: the rail has a PAYS line for the numbers, and the
	# two used to say the same thing twice.
	match str(map_nodes[index].type):
		"shop":
			return "Named pieces at fixed prices. Reroll to see a different three."
		"event":
			return "A back-room offer: cash now for a tighter next table, or walk away."
		"boss":
			return "A gate, not a table. Its signature rule is shown before you commit."
		"elite":
			return "A harder contract than a standard rack, for a stronger piece."
	return "Procedural rack: blocks cut the direct lines.\nBank around them or find the open channel."

# Right-hand rail: the selected table's contract, always in the same place.
# As a floating card next to the node it covered the two tables below it, and
# the map's right third sat empty.
func _show_contract_rail(root: Control) -> void:
	var selected := pending_node >= 0 and pending_node < map_nodes.size()
	var wagerable := selected and _wager_node(pending_node)
	# The wager controls need a taller card. Leaving the card at 340 pushed the
	# enter button under the stake note, so only scored route tables get 470.
	var rail := _panel(root, Vector2(1000, 122), Vector2(248, 470 if (not selected or wagerable) else 340), PANEL)
	if not selected:
		_add_label(rail, Vector2(18, 16), Vector2(212, 18), "NO TABLE SELECTED", 10, MUTED)
		_add_label(rail, Vector2(18, 42), Vector2(212, 62), "Select a highlighted table to read its contract. Select it a second time to play it.", 12, Color("#c6d7d5"))
		_add_label(rail, Vector2(18, 116), Vector2(212, 18), "NODE TYPES", 10, GOLD)
		var legend := [
			["standard", "TABLE", "Standard rack. +20 cash and a build piece."],
			["shop", "SHOP", "Buy one piece, or reroll the stock."],
			["event", "EVENT", "Back-room deal: cash now, shots later."],
			["elite", "ELITE", "Harder contract. +35 cash, stronger piece."],
			["boss", "BOSS", "Gate. Read the rule before you enter."],
		]
		for i in legend.size():
			var y := 142.0 + float(i) * 56.0
			var dot := ColorRect.new()
			dot.position = Vector2(18, y + 2)
			dot.size = Vector2(8, 8)
			dot.color = _node_color(str(legend[i][0]))
			rail.add_child(dot)
			_add_label(rail, Vector2(34, y - 2), Vector2(196, 16), str(legend[i][1]), 11, Color("#e2ece9"))
			_add_label(rail, Vector2(34, y + 14), Vector2(196, 34), str(legend[i][2]), 11, MUTED)
		_add_label(rail, Vector2(18, 430), Vector2(212, 40), "Solid gold: cleared route. Dashed gold: the choice this table opens.", 10, GOLD)
		return
	var n: Dictionary = map_nodes[pending_node]
	var node_type := str(n.type)
	_add_label(rail, Vector2(18, 14), Vector2(212, 16), "%s  //  %s" % [_node_danger(pending_node), _node_symbol(node_type)], 10, MINT)
	_add_label(rail, Vector2(18, 30), Vector2(212, 56), str(n.name).to_upper(), 26, GOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
	_add_label(rail, Vector2(18, 92), Vector2(212, 120), _node_preview(pending_node), 13, Color("#d6e5e1"))
	_add_label(rail, Vector2(18, 218), Vector2(212, 18), "PAYS", 10, MUTED)
	_add_label(rail, Vector2(18, 234), Vector2(212, 20), _node_payout(pending_node), 13, MINT)
	# "ENTER TABLE" on a shop or an event was a lie the player only discovered
	# after the screen changed. The button now names the room it opens.
	var enter_text := "ENTER TABLE"
	match node_type:
		"shop": enter_text = "ENTER SHOP"
		"event": enter_text = "TAKE A SEAT"
		"boss": enter_text = "FACE THE GATE"
	var enter_y := 258.0
	var note_y := 312.0
	if wagerable:
		# Stakes are chosen before the commit, not hidden behind the enter button.
		_add_label(rail, Vector2(18, 258), Vector2(212, 16), "THE HOUSE'S WAGER", 9, GOLD)
		for i in WAGER_STAKES.size():
			var amount: int = WAGER_STAKES[i]
			var wager_label := "OFF" if amount == 0 else str(amount)
			var wager_button := _add_button(rail, Vector2(18.0 + float(i) * 72.0, 276.0), Vector2(68, 34), wager_label, _set_wager.bind(amount), false, GOLD if amount == pending_wager else Color(0, 0, 0, 0))
			if amount > run_cash:
				wager_button.disabled = true
		var wager_note := "NO STAKE. THE TABLE PAYS ITS CONTRACT."
		if pending_wager > 0:
			wager_note = "CLEAR RETURNS %d CASH  ·  A LOSS FORFEITS THE STAKE." % (pending_wager * _wager_odds(pending_node))
		_add_label(rail, Vector2(18, 316), Vector2(212, 26), wager_note, 9, MUTED)
		enter_y = 348.0
		note_y = 404.0
	_add_button(rail, Vector2(18, enter_y), Vector2(212, 48), enter_text, _select_node.bind(pending_node), true)
	if node_type == "boss" and grudge_active and house_grudge != "":
		# The finale's rule belongs on the card the player reads before walking
		# in, not only on the intro one click later.
		_add_label(rail, Vector2(18, note_y), Vector2(212, 20), "IT REMEMBERS  ·  " + _grudge_tag(), 10, RED)
	else:
		_add_label(rail, Vector2(18, note_y), Vector2(212, 20), "Or select it a second time.", 10, MUTED)

func _node_payout(index: int) -> String:
	match str(map_nodes[index].type):
		"shop":
			return "3 pieces, 50–70 cash each"
		"event":
			return "25–80 cash, or a shot back"
		"boss":
			return "+50 cash, the run on the line"
		"elite":
			return "+35 cash, stronger piece"
	return "+20 cash, one build piece"

# The wager is a route decision, not a table rule. Dailies and endless modes
# disable it because their boards are shared or record-chasing, and a cash bet
# would make two players' identical racks play differently.
func _wager_enabled() -> bool:
	return not daily_active and not gauntlet_active and not grind_daily_active

func _wager_node(index: int) -> bool:
	if not _wager_enabled() or index < 0 or index >= map_nodes.size():
		return false
	return str(map_nodes[index].type) in ["standard", "elite", "boss"]

# Standard racks pay even money on top of the stake; a gate or an elite pays
# 3x because the House gives worse odds where it expects to win.
func _wager_odds(index: int) -> int:
	if index >= 0 and index < map_nodes.size() and str(map_nodes[index].type) in ["elite", "boss"]:
		return 3
	return 2

func _set_wager(amount: int) -> void:
	if not _wager_node(pending_node) or not WAGER_STAKES.has(amount):
		return
	if amount > run_cash:
		return
	pending_wager = amount
	_sfx("click")
	_show_map(true)

# The House is named on the title card and in the tagline, so the tour map
# gives it a voice. Lines react to run state where they can, because a rotating
# quote that ignores the player reads as set dressing.
const HOUSE_TABLE_LINES := [
	"The rail takes the cue. The House takes its time.",
	"A dry shot. The House did not need your permission.",
	"You missed. It noticed.",
	"The House rolls the cue back to you. Almost gently.",
]

const HOUSE_TAUNTS := [
	"Felt is a mirror. It shows every angle you ignored.",
	"Every table you take is one I let you take.",
	"Cash buys pieces. It does not buy the line.",
	"Nobody remembers the safe shot.",
	"The pockets are honest. You are the variable.",
	"Take your time. The rail is patient.",
]

func _house_taunt() -> String:
	# A held grudge outranks the small talk: the map should be where the player
	# learns the finale is personal, before the boss gate.
	if grudge_active and house_grudge != "":
		return str(HOUSE_GRUDGES[house_grudge].bark)
	if scratches > 0:
		return "You handed me a scratch. I will keep it."
	if run_best_streak >= 3:
		return "Three in a row buys attention, not mercy."
	if run_cash >= 120:
		return "Deep pockets. Shallow angles."
	if run_stage <= 1:
		return "You have not taken a table yet. I am still being polite."
	return HOUSE_TAUNTS[posmod(run_seed + run_stage * 13 + run_score, HOUSE_TAUNTS.size())]

# The read is taken from a finished winning tour, never from a single lucky
# table. Each tell must be clearly above its threshold; the strongest ratio
# wins, and a route with no dominant habit returns "" so the House stays
# unread. That is the counterplay: a varied build is a safe build.
func _read_house_grudge() -> String:
	var reads := {
		"rails": float(run_banks) / 4.0,
		"streak": float(run_best_streak) / 4.0,
		"chain": float(run_combo_shots) / 2.0,
		"scratch": float(run_scratches) / 4.0,
	}
	var best := ""
	var strongest := 1.0
	for id in ["rails", "streak", "chain", "scratch"]:
		if float(reads[id]) >= strongest:
			strongest = float(reads[id])
			best = str(id)
	return best

func _grudge() -> Dictionary:
	if not HOUSE_GRUDGES.has(house_grudge):
		return {}
	return HOUSE_GRUDGES[house_grudge]

func _grudge_rule() -> String:
	return str(_grudge().get("rule", ""))

func _grudge_tag() -> String:
	return str(_grudge().get("tag", ""))

# Only two habits change a shot's value. The other two change the boss rack or
# its phase gate; keeping them out of the scoring path means this function is
# the single place a scored shot has to ask about a grudge.
func _grudge_multiplier(pocketed: int, banked: bool) -> float:
	if not _grudge_table_active():
		return 1.0
	if house_grudge == "rails" and banked:
		return 0.5
	if house_grudge == "chain" and pocketed > 1:
		return 0.6
	return 1.0

# The grudge is a rule on the final House table, never a tax on the whole
# route: the player has a whole tour to build around it, and the Locksmith is
# its own fight. One predicate keeps scoring, the HUD and the intro agreeing.
func _grudge_table_active() -> bool:
	if not grudge_active or not encounter_is_boss or current_node < 0:
		return false
	return str(map_nodes[current_node].name).to_upper() == "THE HOUSE"

func _show_map(keep_pending := false) -> void:
	if screen == "encounter":
		portal.gameplay_stop()
		# Walking out of a live rack keeps the House's stake. The table is not
		# finished, so a player cannot bet, see a bad layout, and back out free.
		table_wager = 0
	if screen == "encounter" and resolving:
		_cancel_active_shot()
	paused = false
	_hide_pause_overlay()
	if not keep_pending:
		pending_node = -1
		pending_wager = 0
		# When the route offers no choice yet, preselect the only node: the
		# player sees its contract immediately and one click enters the table,
		# instead of a silent map asking them to find the one lit button.
		if map_unlocked.size() == 1:
			pending_node = map_unlocked[0]
	if run_stage > 1 or current_node >= 0:
		_save_run()
	# Practice has no map.
	if screen == "encounter" and current_node == -1 and shots_remaining >= 90:
		_show_title()
		return
	screen = "map"
	var map_subtitle := "Pick the next table. Read its contract, then commit to it."
	if daily_active:
		var twist := _daily_twist(daily_key)
		map_subtitle = "DAILY TOUR  ·  %s — %s: %s. Same route for everyone." % [_pretty_date(daily_key), str(twist.name), str(twist.body).to_lower()]
	var root := _base_screen("THE TOUR", map_subtitle)
	_add_button(root, Vector2(32, 116), Vector2(120, 40), "SETTINGS", _open_settings_from_map)
	# The map needs an exit. A portal session that has to be closed cannot reach
	# the title any other way, so the run had no pause point at all.
	_add_button(root, Vector2(164, 116), Vector2(100, 40), "TITLE", _show_title)
	for i in map_nodes.size():
		node_buttons.append(_add_map_node(root, i))
	# Build identity in plain language. The old "+B4 +C5% +R3" strip told the
	# player nothing about what their run had become.
	var counts := _archetype_counts()
	var rows: Array[String] = []
	for discipline in ["BANK", "COMBO", "RAIL", "CONTROL", "TEMPO"]:
		if int(counts.get(discipline, 0)) > 0:
			rows.append("%s  x%d" % [discipline, int(counts[discipline])])
	var build_body := "No pieces yet.\nClear a table to start a build." if rows.is_empty() else "\n".join(rows)
	# Height follows the list: an empty build should not sit in a tall empty box.
	var body_height := maxf(44.0, float(rows.size()) * 22.0)
	var sheet_y := 74.0 + body_height + 14.0
	var build := _panel(root, Vector2(32, 176), Vector2(262, sheet_y + 62.0), PANEL)
	_add_label(build, Vector2(18, 14), Vector2(140, 20), "YOUR BUILD", 11, GOLD)
	var seed_tag := ("DAILY  ·  %s" % _pretty_date(daily_key)) if daily_active else ("SEED %d" % run_seed)
	_add_label(build, Vector2(18, 13), Vector2(226, 20), seed_tag, 10, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	_add_label(build, Vector2(18, 38), Vector2(226, 28), active_cue, 20, Color("#dce9e6"), HORIZONTAL_ALIGNMENT_LEFT, true)
	_add_label(build, Vector2(18, 74), Vector2(226, body_height), build_body, 13, MINT)
	_add_button(build, Vector2(18, sheet_y), Vector2(226, 32), "FULL SHEET", _open_collection_from_map)
	_add_label(build, Vector2(18, sheet_y + 38.0), Vector2(226, 16), "TERMS  " + _contract().name, 9, GOLD)
	# The left column used to end in empty felt once the build sheet was short.
	# The House's line fills it and gives the route an antagonist that speaks.
	var house_card := _panel(root, Vector2(32, 176.0 + sheet_y + 66.0), Vector2(262, 86), PANEL)
	_add_label(house_card, Vector2(18, 12), Vector2(226, 16), "THE HOUSE", 10, RED)
	_add_label(house_card, Vector2(18, 30), Vector2(226, 46), _house_taunt(), 12, Color("#d8cbb8"))
	# A legend turns the board from coloured rectangles into a route a first-time
	# player can read. It also uses the empty lower-left felt that used to sit
	# under the House card doing nothing.
	var legend_y := 176.0 + sheet_y + 66.0 + 104.0
	var legend := _panel(root, Vector2(32, legend_y), Vector2(262, 138), PANEL)
	_add_label(legend, Vector2(18, 10), Vector2(226, 16), "ROUTE LEGEND", 10, GOLD)
	var legend_rows := [
		["TABLE", "standard contract", MINT],
		["SHOP", "spend cash on a piece", _node_color("shop")],
		["? EVENT", "a deal with the House", _node_color("event")],
		["ELITE", "harder table, better pay", _node_color("elite")],
		["BOSS", "a gate you must pass", _node_color("boss")],
	]
	for row in legend_rows.size():
		var row_y := 30.0 + float(row) * 16.0
		var dot := ColorRect.new()
		dot.position = Vector2(18, row_y + 3.0)
		dot.size = Vector2(6, 6)
		dot.color = legend_rows[row][2]
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		legend.add_child(dot)
		_add_label(legend, Vector2(32, row_y), Vector2(74, 14), str(legend_rows[row][0]), 9, Color(legend_rows[row][2]))
		_add_label(legend, Vector2(108, row_y), Vector2(148, 14), str(legend_rows[row][1]), 9, MUTED)
	_add_label(legend, Vector2(18, 116), Vector2(226, 16), "TAP ONCE TO PREVIEW  ·  TAP AGAIN TO ENTER", 8, Color("#8aa3a6"))
	_show_contract_rail(root)
	# Focus the table the player can actually enter. With no focus, Enter and
	# the gamepad A button did nothing on the map at all.
	if pending_node >= 0 and pending_node < node_buttons.size():
		node_buttons[pending_node].grab_focus()
	else:
		var node_focused := false
		for index in map_unlocked:
			if index >= 0 and index < node_buttons.size() and not map_nodes[index].done:
				node_buttons[index].grab_focus()
				node_focused = true
				break
		if not node_focused:
			_focus_first_button(root)
	_check_trophies()

func _node_color(kind: String) -> Color:
	match kind:
		"shop":
			return Color("#79c7d6")
		"event":
			return Color("#c8a2ef")
		"elite":
			return Color("#f0a25e")
		"boss":
			return RED
	return MINT

func _add_map_node(parent: Control, index: int) -> Button:
	var node: Dictionary = map_nodes[index]
	var kind := str(node.type)
	var unlocked: bool = map_unlocked.has(index) and not node.done
	var accent := _node_color(kind)
	var button := _add_button(parent, node.pos - Vector2(62, 28), Vector2(124, 56), "", _select_node.bind(index), false, accent)
	button.disabled = not unlocked
	button.tooltip_text = "%s // %s" % [_node_danger(index), _node_preview(index)]
	var tag_color := MINT if node.done else accent
	var title_color := Color("#e8f2ee") if unlocked else Color("#7d9499")
	if node.done:
		title_color = Color("#8fb0a8")
	var tag := _add_label(button, Vector2(4, 7), Vector2(116, 14), "CLEARED" if node.done else _node_symbol(kind), 9, tag_color, HORIZONTAL_ALIGNMENT_CENTER)
	var title := _add_label(button, Vector2(4, 26), Vector2(116, 22), str(node.name), 15, title_color, HORIZONTAL_ALIGNMENT_CENTER, true)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.clip_text = true
	return button

func _node_symbol(kind: String) -> String:
	match kind:
		"shop":
			return "SHOP"
		"event":
			return "? EVENT"
		"elite":
			return "ELITE"
		"boss":
			return "BOSS"
	return "TABLE"

func _select_node(index: int) -> void:
	if not map_unlocked.has(index) or map_nodes[index].done:
		return
	_sfx("click")
	# Two-tap entry: first tap previews (touch users can't hover tooltips),
	# second tap commits. Desktop players just double-click.
	if pending_node != index:
		pending_node = index
		# A stake belongs to one preview. Switching tables must not silently
		# carry the previous bet into a different rack.
		pending_wager = 0
		_show_map(true)
		return
	pending_node = -1
	current_node = index
	var node: Dictionary = map_nodes[index]
	match node.type:
		"shop": _show_shop()
		"event": _show_event()
		"boss": _show_boss_intro()
		_: _start_encounter(false)

func _show_boss_intro() -> void:
	screen = "boss_intro"
	_sfx("boss")
	var root := _base_screen("BOSS APPROACHING", "This is a gate, not another ordinary table. Read the rule before committing.")
	var boss_name := str(map_nodes[current_node].name).to_upper()
	var is_house := boss_name == "THE HOUSE"
	var boss_rule := "BANKS PAY DOUBLE" if not is_house else "THE HOUSE TAKES THE TABLE"
	var boss_hint := "A banked pot pays its value again — triple past half. Plan the rail before the pocket." if not is_house else "Fouls and scratches cost an extra shot. At half score The House shoots after every miss and bolts a pocket for each ball it pots."
	# The intro must quote the stake-adjusted budget, not the base one: a Stake 2
	# player used to read 130 in 10 shots and then face 145 in 9.
	var phase_target := 165 if is_house else 130
	var phase_shots := 11 if is_house else 10
	if stake == 1:
		phase_shots = maxi(5, phase_shots - 1)
	elif stake == 2:
		phase_shots = maxi(5, phase_shots - 1)
		phase_target += 15
	var phase := ""
	if is_house:
		phase = "PHASE 1: %d score in %d shots. PHASE 2 (at half): the House plays; a dry shot gives it the cue." % [phase_target, phase_shots]
	else:
		phase = "PHASE 1: %d score in %d shots. Banked pots pay double, then triple past half." % [phase_target, phase_shots]
	_add_label(root, Vector2(120, 138), Vector2(1040, 68), boss_name, 54, RED, HORIZONTAL_ALIGNMENT_CENTER, true)
	var rule_card := _panel(root, Vector2(250, 235), Vector2(780, 260), PANEL_ALT)
	_add_label(rule_card, Vector2(30, 25), Vector2(680, 32), "SIGNATURE RULE", 16, GOLD)
	_add_label(rule_card, Vector2(30, 66), Vector2(680, 46), boss_rule, 32, Color("#f4ead5"), HORIZONTAL_ALIGNMENT_LEFT, true)
	_add_label(rule_card, Vector2(30, 125), Vector2(680, 55), boss_hint, 15, Color("#d3e0de"))
	_add_label(rule_card, Vector2(30, 182), Vector2(680, 45), phase, 13, MUTED)
	# A grudge is announced here, before the player commits: the counter-build
	# is the whole point, and a tax revealed after the break is just a bad beat.
	if grudge_active and is_house and house_grudge != "":
		_add_label(rule_card, Vector2(30, 220), Vector2(680, 20), "IT REMEMBERS  ·  %s" % _grudge_rule().to_upper(), 11, RED)
	else:
		_add_label(rule_card, Vector2(30, 220), Vector2(680, 20), "CLEAR PAYS  +50 CASH", 11, MINT)
	var enter_btn := _add_button(root, Vector2(390, 530), Vector2(240, 52), "ENTER BOSS TABLE", _begin_boss, true)
	enter_btn.grab_focus()
	_add_button(root, Vector2(650, 530), Vector2(240, 52), "RETURN TO MAP", _show_map)

func _begin_boss() -> void:
	_start_encounter(true)

func _resolve_node_scenario_id() -> String:
	if current_node >= 0:
		var sid := str(map_nodes[current_node].get("scenario_id", ""))
		if sid != "":
			return sid
	return ""

func _start_encounter(is_boss: bool) -> void:
	portal.gameplay_start()
	paused = false
	# A tour table never inherits a duel's opponent or its difficulty. Without
	# this reset, playing a duel made the next boss House shoot at Form IV's
	# accuracy while the run believed it was on its normal rack.
	duel_active = false
	duel_local = false
	duel_handoff = false
	# The stake joins the table when the rack actually starts. Opening a boss
	# card or previewing a route costs nothing; backing out of a card must not
	# forfeit cash before a ball has moved.
	last_wager_stake = 0
	last_wager_payout = 0
	if current_node >= 0 and table_wager == 0 and pending_wager > 0:
		var wager_charge := mini(pending_wager, run_cash)
		if wager_charge > 0:
			run_cash -= wager_charge
			table_wager = wager_charge
		pending_wager = 0
	house_aim_error = 0.035
	screen = "encounter"
	# Derive the table seed instead of advancing a counter. R is labelled
	# RETRY TABLE, and the old `seed_value += 7919` dealt a fresh rack every
	# press, letting a player fish for an easy board and breaking the promise
	# that a seed replays the same tables.
	seed_value = run_seed + (run_stage - 1) * 7919 + (current_node + 2) * 104729
	encounter_is_boss = is_boss
	var sid := _resolve_node_scenario_id()
	if sid != "" and not is_boss:
		scenario = library.get_by_id(sid, seed_value)
		scenario["seed"] = seed_value
	else:
		scenario = library.get_for_seed(seed_value)
	encounter_is_elite = current_node >= 0 and map_nodes[current_node].type == "elite"
	if is_boss:
		var boss_name := str(map_nodes[current_node].name).to_upper() if current_node >= 0 else "THE HOUSE"
		var is_house := boss_name == "THE HOUSE"
		scenario.name = boss_name
		if is_house:
			scenario.contract = "BOSS CONTRACT: Score 165 before shots run out. At half score The House takes the table: every miss gives it a shot, and every pot lets it bolt a pocket shut."
			scenario.target = 165
			scenario.shots = 11
		else:
			# Both boss racks hold 110 base value before the gate's anchor, so a
			# target above that can only be met by playing the advertised bank
			# rule. 130 asks for one clean bank without requiring a bank build.
			scenario.contract = "BOSS CONTRACT: Score 130. Banks count double. Fouls cost two shots."
			scenario.target = 130
			scenario.shots = 10
		scenario.contract_type = "score"
		scenario.subtitle = "The table takes interest on every mistake."
	elif encounter_is_elite:
		scenario.name = "ELITE // " + str(scenario.name)
		# An elite always asks for the same kind of thing: a real score. Adding
		# 35 to whatever the rack's authored target was produced "score 37" for
		# clear/bank tables and "score 155" for Crossfire — one free win, one
		# wall, from the same node type.
		var elite_target := clampi(60 + run_stage * 10, 80, 110)
		scenario.contract = "ELITE CONTRACT: Score %d before the line closes. Fouls cost an extra shot." % elite_target
		scenario.contract_type = "score"
		scenario.target = elite_target
		scenario.shots = maxi(7, int(scenario.shots) - 1)
		# The foul tax is already the elite contract line; repeating it in the
		# brief pushed the hint into a fifth line and out of its card.
	# Stake pressure.
	if stake == 1:
		scenario.shots = maxi(5, int(scenario.shots) - 1)
	elif stake == 2:
		scenario.shots = maxi(5, int(scenario.shots) - 1)
		scenario.target = int(scenario.target) + 15
	if is_boss:
		# Boss tables pick from the shape pool by seed; each boss keeps its contract.
		library.build_boss_shape(simulator, int(absi(seed_value) / 7) + int(absi(run_seed)))
	elif current_node >= 0 and str(map_nodes[current_node].type) == "standard":
		# Normal nodes are procedurally generated from the seed. The authored
		# hint describes a hand-built layout, so it would name zones that are not
		# on this table; replace it with a brief that matches what is drawn.
		library.build_procedural(simulator, seed_value, run_stage)
		# An ice-lane contract needs a zone and a procedural rack has none, so
		# that table could never be completed. Fall back to clearing pockets.
		if str(scenario.contract_type) == "ice_lane":
			scenario.contract_type = "clear"
		# Early procedural racks teach pocketing before they demand a rule
		# trick. Table two used to be able to ask for four pockets with no
		# scratch on a five-ball rack, which ended most first sessions.
		if run_stage <= 1:
			scenario.contract_type = "clear"
			scenario.target = mini(3, simulator.active_target_count())
			scenario.shots = maxi(int(scenario.shots), 8) + 2
		elif run_stage <= 3:
			scenario.contract_type = "clear"
			scenario.target = mini(3 + (run_stage - 2), simulator.active_target_count())
			scenario.shots = maxi(int(scenario.shots), 9)
		if str(scenario.contract_type) in ["clear", "no_scratch"]:
			scenario.target = mini(int(scenario.target), simulator.active_target_count())
		# A score ask authored for a hand-built rack is too tall on a smaller
		# procedural one; cap it against what this rack can actually pay.
		if str(scenario.contract_type) in ["score", "combo"]:
			var rack_value := 0
			for ball in simulator.balls:
				if bool(ball.get("target", false)):
					rack_value += int(ball.get("value", 0))
			scenario.target = mini(int(scenario.target), maxi(45, int(float(rack_value) * 0.7)))
		# Authored contract text can name geometry the procedural rack does not
		# have (an anchor, a prism, a lane). Restate it from the live rule.
		scenario.contract = _procedural_contract_text()
		scenario.hint = "Procedural rack: solid blocks cut the direct lines. Bank around them or find the open channel."
		scenario.subtitle = "Every run deals a different rack."
		if run_stage <= 1:
			scenario.subtitle = "A small rack to learn the line. Pocket three."
			scenario.hint = "Aim with the pointer, set power, then FIRE SHOT. Three pockets open the route."
	else:
		library.build_scenario(simulator, scenario)
	if gauntlet_active:
		_apply_grind_rules()
	# The daily table rule lands after the rack is built and never on a boss:
	# boss shapes are their identity. The brief states the rule because the rack
	# alone cannot explain closed pockets or a livelier felt.
	if not is_boss:
		var table_rule := _daily_table_rule()
		if table_rule != "":
			_apply_table_rule(table_rule)
			scenario.hint = str(_daily_twist(daily_key).get("table_hint", scenario.hint))
	# The opening table is the only one that needs to teach the brass ring: the
	# spot is visible on every table, but a new player has to be told what it
	# pays before it can become a habit. Later tables never repeat the rule.
	if current_node == 0 and run_stage <= 1:
		scenario.hint = str(scenario.hint) + "  Brass ring: pot a ball, leave the cue on it for +10 and a shot back."
	if not codex_seen.has(str(scenario.id)):
		codex_seen.append(str(scenario.id))
	# Scouting is per-browser, not per-run: the trophy shelf counts the tables a
	# player has actually met, so revisiting one does not inflate it.
	if not scouted.has(str(scenario.id)):
		scouted.append(str(scenario.id))
	var encounter_shot_modifier := next_shot_modifier
	var grind_shot_bonus := grind_par_shots if gauntlet_active else 0
	shots_remaining = maxi(3, int(scenario.shots) + encounter_shot_modifier + permanent_shot_bonus + grind_shot_bonus)
	if gauntlet_active:
		grind_par_shots = 0
	# The opening table is a promise, not a difficulty test: a Banker or
	# Collector term must not turn the first lesson into a nine-shot table.
	if current_node == 0 and run_stage <= 1:
		shots_remaining = maxi(shots_remaining, 10)
	# House Set rules land after the base budget and the opening-table floor,
	# so a focused build changes the table it is about to play.
	_apply_set_table_start()
	table_par = _table_par()
	next_shot_modifier = 0
	if is_boss:
		_run_boss_setup()
	score = 0
	shot_number = 0
	pocketed_count = 0
	bank_count = 0
	combo_shots = 0
	scratches = 0
	fouls = 0
	combo_streak = 0
	best_streak = 0
	lane_pockets = 0
	current_power = 0.48
	current_spin = Vector2.ZERO
	last_aim = Vector2.RIGHT
	resolving = false
	boss_phase = 0
	house_pending = 0.0
	house_shooting = false
	house_aim = Vector2.RIGHT
	house_place_from = Vector2.ZERO
	house_power = 0.5
	house_turns = 0
	# Heat belongs to one rack. Carrying it across a route would let a patient
	# player bank a call and skip the table that earned it.
	heat = 0.0
	house_call_armed = false
	# The spot is one position target per table; its once-per-rack shot refund
	# must not carry into the next table either.
	house_spot_table_hits = 0
	house_spot_paid_shot = false
	house_spot_flash = 0.0
	_place_house_spot()
	last_result = "Read the contract, choose a line, and commit."
	result_color = Color("#d5e2e2")
	shot_events.clear()
	ball_trails.clear()
	pocket_flashes.clear()
	_start_coach_if_new(is_boss)
	_render_encounter()
	queue_redraw()

# A first table is where a portal player decides to stay. The coach names one
# action at a time and disappears the moment they fire; bosses, elites and
# later tables never show it. Dailies do show it: it is local UI, so it cannot
# make the shared table unfair.
func _start_coach_if_new(is_boss: bool) -> void:
	coach_active = false
	coach_aimed = false
	coach_powered = false
	if tutorial_seen or is_boss or encounter_is_elite:
		return
	if current_node >= 0 and run_stage > 1:
		return
	coach_active = true

func _coach_step() -> int:
	if not coach_aimed:
		return 0
	if not coach_powered:
		return 1
	return 2

func _coach_mark(kind: String) -> void:
	if not coach_active:
		return
	if kind == "aim" and not coach_aimed:
		coach_aimed = true
		_sync_coach_label()
		queue_redraw()
	elif kind == "power" and not coach_powered:
		coach_powered = true
		_sync_coach_label()
		queue_redraw()

# The coach is one action at a time; the label also carries the step number so
# a player can see the whole lesson shrink from three beats to none.
func _sync_coach_label() -> void:
	if not is_instance_valid(hud_coach_label):
		return
	var rows: Array[String] = [
		"MOVE THE POINTER TO AIM",
		"DRAG THE POWER BAR OR PRESS W/S",
		"SPACE OR FIRE SHOT TO COMMIT",
	]
	var step := _coach_step()
	if is_instance_valid(hud_coach_step):
		hud_coach_step.text = "FIRST SHOT  ·  %d OF 3" % (step + 1)
	hud_coach_label.text = rows[step]

func _coach_finish() -> void:
	if not coach_active:
		return
	coach_active = false
	if is_instance_valid(hud_coach_label):
		hud_coach_label.visible = false
		hud_coach_step.visible = false
	if is_instance_valid(hud_build_label):
		hud_build_label.visible = true
		hud_guard_label.visible = true
		hud_mods_label.visible = true
		hud_set_label.visible = true
	if not tutorial_seen:
		tutorial_seen = true
		_save_meta()
	_refresh_hud()
	queue_redraw()

func _procedural_contract_text() -> String:
	match str(scenario.contract_type):
		"score":
			return "RACK CONTRACT: Score %d before the shots run out." % int(scenario.target)
		"combo":
			return "RACK CONTRACT: Score %d and pocket two balls in one shot." % int(scenario.target)
		"bank_count":
			return "RACK CONTRACT: %d banks, and 4 balls pocketed." % int(scenario.target)
		"no_scratch":
			return "RACK CONTRACT: Pocket %d balls without scratching." % int(scenario.target)
	return "RACK CONTRACT: Pocket %d targets. Blocks cut the direct lines." % int(scenario.target)

func _run_boss_setup() -> void:
	simulator.add_barrier(Rect2(610, 260, 80, 200))
	simulator.add_ball(Vector2(900, 360), 30, "anchor", true, Color("#e85b4f"))
	# THE HOUSE REMEMBERS (streak): it watched you run the rack, so the finale
	# opens with one corner already bolted. The plate is on the felt from the
	# break, which makes the grudge a thing the player can see, not a stat.
	if grudge_active and house_grudge == "streak" and current_node >= 0 and str(map_nodes[current_node].name).to_upper() == "THE HOUSE":
		simulator.close_pocket(int(posmod(absi(seed_value) / 13, 4)))

func _render_encounter() -> void:
	# The contract itself lives in the left panel, where progress sits next to
	# it. Repeating the rule here made the header a second copy of the brief.
	var subtitle := str(scenario.get("subtitle", ""))
	if subtitle == "":
		subtitle = "Read the table, choose a line, and commit."
	# A duel has no cash, stage or score: showing the tour header would print a
	# parked run's numbers over an unrelated table.
	var root := _base_screen(scenario.name, subtitle, not duel_active)
	if duel_active:
		if duel_local:
			_add_label(root, Vector2(880, 14), Vector2(360, 30), "FIRST TO %d" % duel_target, 22, GOLD, HORIZONTAL_ALIGNMENT_RIGHT, true)
			var series_line := "RACE TO %d   ·   PLAYER %d BREAKS" % [duel_target, duel_breaker + 1]
			if duel_series_p1 + duel_series_p2 > 0:
				series_line = "SERIES   P1 %d — %d P2" % [duel_series_p1, duel_series_p2]
			_add_label(root, Vector2(880, 53), Vector2(360, 22), series_line, 13, MINT, HORIZONTAL_ALIGNMENT_RIGHT)
		else:
			_add_label(root, Vector2(880, 14), Vector2(360, 30), "FORM %s" % _duel_roman(duel_form), 22, RED, HORIZONTAL_ALIGNMENT_RIGHT, true)
			_add_label(root, Vector2(880, 53), Vector2(360, 22), "RACE TO %d   ·   WINS %02d   ·   STREAK %02d" % [duel_target, duel_wins, duel_streak], 13, MINT, HORIZONTAL_ALIGNMENT_RIGHT)
	_build_encounter_ui(root)
	_refresh_hud()

func _build_encounter_ui(root: Control) -> void:
	hud_root = root

	# Left column: shot budget, what this table wants, how far along the
	# contract is, and what the run has built — in the order a player needs it.
	# The full control tip is onboarding copy: first table of the first run only.
	var show_tip := not duel_active and total_runs <= 1 and run_stage <= 1
	var brief := _panel(root, Vector2(18, 140), Vector2(322, 402), PANEL)
	hud_shot_label = _add_label(brief, Vector2(20, 12), Vector2(282, 36), "", 11, MINT)
	_add_label(brief, Vector2(20, 58), Vector2(282, 18), "THE MATCH" if duel_active else "TABLE BRIEF", 10, GOLD)
	# The brief needs room for four full lines: a variant rule pushes the hint
	# past 64px, and the old layout let the last line run into CONTRACT.
	_add_label(brief, Vector2(20, 78), Vector2(282, 80), str(scenario.hint), 13, Color("#c6d7d5"))
	_add_label(brief, Vector2(20, 162), Vector2(282, 18), "THE RACE" if duel_active else "CONTRACT", 10, MUTED)
	# Par shares the small header row: it belongs next to the contract, and no
	# contract line is long enough to reach the right edge of a 10px row.
	hud_par_label = _add_label(brief, Vector2(20, 162), Vector2(282, 18), "", 10, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	hud_contract_label = _add_label(brief, Vector2(20, 180), Vector2(282, 24), "", 16, Color("#eef7f2"))
	var progress_back := ColorRect.new()
	progress_back.position = Vector2(20, 208)
	progress_back.size = Vector2(282, 8)
	progress_back.color = Color("#0b171b")
	brief.add_child(progress_back)
	hud_contract_fill = ColorRect.new()
	hud_contract_fill.position = Vector2(20, 208)
	hud_contract_fill.size = Vector2(0.0, 8)
	hud_contract_fill.color = MINT
	brief.add_child(hud_contract_fill)
	hud_result_label = _add_label(brief, Vector2(20, 224), Vector2(282, 56), "", 13, Color("#d5e2e2"))
	var divider := ColorRect.new()
	divider.position = Vector2(20, 286)
	divider.size = Vector2(282, 1)
	divider.color = Color("#33505a")
	brief.add_child(divider)
	hud_cue_label = _add_label(brief, Vector2(20, 296), Vector2(282, 22), "", 12, Color("#e4efeb"))
	hud_build_label = _add_label(brief, Vector2(20, 318), Vector2(282, 32), "", 12, MINT)
	hud_guard_label = _add_label(brief, Vector2(20, 352), Vector2(282, 16), "", 10, MUTED)
	# Why a shot paid what it paid: the active bonuses sit next to the result
	# instead of being buried in a tooltip or a collection screen.
	hud_mods_label = _add_label(brief, Vector2(20, 370), Vector2(282, 16), "", 10, MINT)
	hud_set_label = _add_label(brief, Vector2(20, 386), Vector2(282, 14), "", 9, GOLD)
	# The first-shot coach lives in the brief column, not over the felt: a strip
	# on the lower rail covered the bottom side pocket at exactly the table
	# that has to teach a new player where the pockets are. This space is empty
	# on a first table anyway (no pieces, no guards), and a coach step reads
	# beside the contract instead of competing with the shot line.
	var coach_here := coach_active and screen == "encounter"
	if show_tip or coach_here:
		hud_build_label.visible = false
		hud_guard_label.visible = false
		hud_mods_label.visible = false
		hud_set_label.visible = false
		hud_coach_step = _add_label(brief, Vector2(20, 310), Vector2(282, 16), "", 10, GOLD)
		hud_coach_label = _add_label(brief, Vector2(20, 328), Vector2(282, 56), "", 12, Color("#eef7f2"))
		hud_coach_step.visible = coach_here
		hud_coach_label.visible = coach_here
		if show_tip and not coach_here:
			_add_label(brief, Vector2(20, 318), Vector2(282, 56), "Aim with the pointer. FIRE commits the shot — table clicks never do.", 11, MUTED)
		else:
			_sync_coach_label()

	# Dock: three labelled clusters, one baseline per cluster.
	var dock := _panel(root, Vector2(300, 578), Vector2(930, 130), PANEL)
	_add_label(dock, Vector2(20, 10), Vector2(300, 16), "POWER", 10, MUTED)
	hud_power_label = _add_label(dock, Vector2(20, 22), Vector2(300, 34), "", 28, Color("#e6f0ec"), HORIZONTAL_ALIGNMENT_LEFT, true)
	var power_back := ColorRect.new()
	power_back.position = Vector2(20, 64)
	power_back.size = Vector2(320, 14)
	power_back.color = Color("#0b171b")
	dock.add_child(power_back)
	hud_power_fill = ColorRect.new()
	hud_power_fill.position = Vector2(20, 64)
	hud_power_fill.size = Vector2(0.0, 14)
	hud_power_fill.color = GOLD
	dock.add_child(hud_power_fill)
	_add_label(dock, Vector2(20, 86), Vector2(320, 18), "Drag the bar  •  W/S  •  mouse wheel", 10, MUTED)

	_add_label(dock, Vector2(370, 10), Vector2(160, 16), "ACTION", 10, MUTED)
	hud_fire_button = _add_button(dock, Vector2(370, 30), Vector2(160, 56), "FIRE SHOT", _take_shot, true)
	hud_fire_button.add_theme_font_size_override("font_size", 16)
	hud_fire_button.grab_focus()
	# Utilities sit at the far edge; the spin pad stays next to FIRE, where the
	# shot is set up. Pinning it right left a 190px hole in the middle of the dock.
	# HOUSE HEAT sits between the spin pad and MAP: the one in-table power play
	# stays inside thumb reach and never moves between tables.
	hud_heat_label = _add_label(dock, Vector2(652, 6), Vector2(104, 14), "HOUSE HEAT", 9, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	hud_heat_button = _add_button(dock, Vector2(652, 26), Vector2(104, 56), "HEAT 0%", _arm_house_call)
	# Heat is a run-scoped comeback meter; a duel has no table to save. The same
	# footprint becomes a live race tile so the dock never grows a dead gap.
	if duel_active:
		hud_heat_label.text = "THE RACE"
		hud_heat_button.disabled = true
		hud_heat_button.add_theme_font_size_override("font_size", 19)
		# The tile is a readout, not a disabled control; keep it at full legibility.
		hud_heat_button.add_theme_color_override("font_disabled_color", Color("#eef7f2"))
	else:
		hud_heat_button.add_theme_font_size_override("font_size", 12)
	hud_heat_fill = ColorRect.new()
	hud_heat_fill.position = Vector2(3, 3)
	hud_heat_fill.size = Vector2(0.0, 50.0)
	hud_heat_fill.color = Color(0.98, 0.74, 0.34, 0.3)
	hud_heat_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_heat_button.add_child(hud_heat_fill)
	var dock_exit_label := "MAP"
	if gauntlet_active:
		dock_exit_label = "MENU"
	elif duel_active:
		dock_exit_label = "LEAVE"
	_add_button(dock, Vector2(768, 38), Vector2(76, 40), dock_exit_label, _dock_exit)
	_add_button(dock, Vector2(856, 38), Vector2(56, 40), "II", _toggle_pause)

	_add_label(dock, Vector2(546, 6), Vector2(100, 16), "SPIN", 10, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	spin_pad = SpinPad.new()
	spin_pad.position = SPIN_PAD_RECT.position - dock.position
	spin_pad.size = SPIN_PAD_RECT.size
	spin_pad.spin = current_spin
	spin_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.add_child(spin_pad)
	_add_label(dock, Vector2(528, 102), Vector2(136, 16), "FOLLOW / DRAW", 9, MUTED, HORIZONTAL_ALIGNMENT_CENTER)

func _refresh_hud() -> void:
	if not is_instance_valid(hud_root) or screen != "encounter":
		return
	if duel_active:
		_refresh_duel_hud()
		return
	var house_busy := house_pending > 0.0 or house_shooting
	var house_table := encounter_is_boss and boss_phase >= 1 and current_node >= 0 and str(map_nodes[current_node].name).to_upper() == "THE HOUSE"
	var phase_tag := ""
	if encounter_is_boss and boss_phase >= 1:
		phase_tag = "   ITS TURN" if house_busy else "   PHASE 2"
	# Shot 1 of the table reads as SHOT 01, not SHOT 00, before the first fire.
	var wager_tag := "   ·   WAGER %d" % table_wager if table_wager > 0 else ""
	hud_shot_label.text = "SHOT %02d   LEFT %02d%s\nFOULS %02d   STREAK x%d%s" % [shot_number + 1, shots_remaining, phase_tag, fouls, combo_streak, wager_tag]
	hud_contract_label.text = _contract_line()
	if is_instance_valid(hud_par_label):
		var par_beaten := table_par > 0 and score >= table_par
		if par_beaten:
			hud_par_label.text = "PAR %d  BEATEN" % table_par
			if gauntlet_active:
				hud_par_label.text = "PAR %d  BEATEN  ·  +1 NEXT" % table_par
		elif table_par > 0:
			# The Grind pays one extra shot next rack for a par beat.
			if gauntlet_active:
				hud_par_label.text = "PAR %d  ·  +1 NEXT" % table_par
			else:
				hud_par_label.text = "PAR %d  ·  +15" % table_par
		else:
			hud_par_label.text = ""
		hud_par_label.add_theme_color_override("font_color", MINT if par_beaten else GOLD)
	hud_contract_fill.size.x = maxf(282.0 * _contract_progress(), 4.0)
	hud_result_label.text = last_result
	hud_result_label.add_theme_color_override("font_color", result_color if not settings_high_contrast else Color.WHITE)
	var mode_label := str(_contract().name)
	if gauntlet_active:
		mode_label = "TODAY'S LADDER" if grind_daily_active else "THE GRIND"
	hud_cue_label.text = "CUE  %s   ·   %s" % [active_cue, mode_label]
	hud_build_label.text = _build_line()
	if house_table:
		var shut_count := simulator.closed_pockets.size()
		hud_guard_label.text = "THE HOUSE PLAYS  ·  %d POCKET%s SHUT" % [shut_count, "" if shut_count == 1 else "S"]
		hud_guard_label.add_theme_color_override("font_color", RED)
	elif _grudge_table_active() and house_grudge != "":
		# The rule is repeated on the live brief, not only on the intro card, so
		# it is still readable three shots into the rack that it taxes.
		hud_guard_label.text = "IT REMEMBERS  ·  " + _grudge_tag()
		hud_guard_label.add_theme_color_override("font_color", RED)
	else:
		hud_guard_label.text = _guard_line()
		hud_guard_label.add_theme_color_override("font_color", MUTED)
	hud_mods_label.text = _mods_line()
	if is_instance_valid(hud_set_label):
		var set_text := _sets_line()
		# The favor is a one-per-tour resource, not a per-table readout. Once it
		# is spent, the brief keeps the warning; until then the set line uses
		# the space because it changes play.
		if not gauntlet_active and not favor_available:
			set_text += "  ·  FAVOR SPENT"
		hud_set_label.text = set_text
		hud_set_label.add_theme_color_override("font_color", GOLD if _set_active_names() != "" else Color("#5e7478"))
	if is_instance_valid(hud_heat_button):
		var ready := heat >= HEAT_FULL
		if house_call_armed:
			hud_heat_button.text = "CALLED"
		elif ready:
			hud_heat_button.text = "CALL HOUSE"
		else:
			hud_heat_button.text = "HEAT %d%%" % int(heat)
		hud_heat_button.add_theme_color_override("font_color", GOLD if (ready or house_call_armed) else Color("#c3d3d1"))
		hud_heat_fill.size.x = 98.0 * clampf(heat / HEAT_FULL, 0.0, 1.0)
		hud_heat_fill.color = Color(0.98, 0.74, 0.34, 0.3 if ready else 0.2)
	hud_power_label.text = "%02d%%" % int(current_power * 100)
	hud_power_fill.size.x = 320.0 * current_power
	# While resolving, FIRE is the speed-up control instead of a dead button.
	hud_fire_button.disabled = house_busy or (not resolving and shots_remaining <= 0)
	if house_busy:
		hud_fire_button.text = "THE HOUSE"
	elif resolving:
		hud_fire_button.text = "SPEED UP"
	else:
		hud_fire_button.text = "FIRE SHOT"
	if is_instance_valid(hud_run_label):
		if grind_daily_active:
			hud_run_label.text = "LADDER %02d   SCORE %04d" % [run_stage, run_score]
		elif gauntlet_active:
			hud_run_label.text = "GRIND %02d   SCORE %04d" % [run_stage, run_score]
		else:
			hud_run_label.text = "STAGE %02d   SCORE %04d" % [run_stage, run_score]
		if gauntlet_active:
			var pace_note := _grind_pace_label()
			if pace_note != "":
				hud_run_label.text += "   ·   " + pace_note
	_refresh_spin_pad()

# A duel has no shot budget, cash, score or build, so the tour HUD would print
# a wall of zeroes over a live match. This is the same three clusters a player
# already reads, wired to the race instead of the run.
func _refresh_duel_hud() -> void:
	if duel_local:
		_refresh_local_duel_hud()
		return
	var player_turn := not (duel_turn_house or house_pending > 0.0 or house_shooting)
	var form: Dictionary = DUEL_FORMS[duel_form]
	hud_shot_label.text = "%s\nSTREAK x%d" % ["YOUR TURN" if player_turn else "THE HOUSE'S TURN", duel_streak]
	hud_shot_label.add_theme_color_override("font_color", MINT if player_turn else RED)
	hud_contract_label.text = "YOU  %d   ·   %d  HOUSE" % [duel_player, duel_house]
	var house_match_point := duel_house == duel_target - 1
	if is_instance_valid(hud_par_label):
		hud_par_label.text = "MATCH POINT" if house_match_point or duel_player == duel_target - 1 else "FIRST TO %d" % duel_target
		hud_par_label.add_theme_color_override("font_color", RED if house_match_point else GOLD)
	hud_contract_fill.size.x = maxf(282.0 * float(duel_player) / float(duel_target), 4.0)
	hud_contract_fill.color = MINT
	hud_result_label.text = last_result
	hud_result_label.add_theme_color_override("font_color", result_color if not settings_high_contrast else Color.WHITE)
	hud_cue_label.text = "CUE  HOUSE CUE   ·   FORM %s" % _duel_roman(duel_form)
	hud_build_label.text = str(form.name)
	var guard_text := "POT AND KEEP SHOOTING"
	if not player_turn:
		guard_text = "THE HOUSE SHOOTS UNTIL IT MISSES"
	# A bolted pocket is the form's authored rule, so it has to read on the
	# brief instead of only on the felt.
	if simulator.closed_pockets.size() > 0:
		guard_text += "   ·   %d SHUT" % simulator.closed_pockets.size()
	hud_guard_label.text = guard_text
	hud_guard_label.add_theme_color_override("font_color", RED if not player_turn else MUTED)
	hud_mods_label.text = "WINS %02d   ·   STREAK %02d   ·   BEST %02d" % [duel_wins, duel_streak, duel_best_streak]
	if is_instance_valid(hud_set_label):
		# The brief is already dense with the match; the race line is in the
		# header and the score tile. Leave this slot empty rather than repeating
		# the same facts twice inside one column.
		hud_set_label.text = ""
	if is_instance_valid(hud_heat_button):
		hud_heat_label.text = "THE RACE"
		hud_heat_label.add_theme_color_override("font_color", MUTED)
		hud_heat_button.text = "%d — %d" % [duel_player, duel_house]
		hud_heat_button.add_theme_font_size_override("font_size", 19)
		hud_heat_fill.size.x = 0.0
	hud_power_label.text = "%02d%%" % int(current_power * 100)
	hud_power_fill.size.x = 320.0 * current_power
	var house_busy := duel_turn_house or house_pending > 0.0 or house_shooting
	hud_fire_button.disabled = house_busy
	if house_busy:
		hud_fire_button.text = "THE HOUSE"
	elif resolving:
		hud_fire_button.text = "SPEED UP"
	else:
		hud_fire_button.text = "FIRE SHOT"
	_refresh_spin_pad()

# PASS & PLAY shares the duel's turn state, but both seats use the same
# controls, so FIRE is only ever disabled while the balls are rolling. The
# heat slot becomes the scoreboard and the form ladder disappears.
func _refresh_local_duel_hud() -> void:
	var p2_turn := duel_turn_house
	var current := "PLAYER 2" if p2_turn else "PLAYER 1"
	var accent := GOLD if p2_turn else MINT
	# The header already states the race distance, so the brief names only the
	# seat and the one moment that changes the stakes.
	hud_shot_label.text = "%s'S TURN" % current
	hud_shot_label.add_theme_color_override("font_color", accent)
	hud_contract_label.text = "P1  %d   ·   %d  P2" % [duel_player, duel_house]
	var match_point := duel_player == duel_target - 1 or duel_house == duel_target - 1
	if is_instance_valid(hud_par_label):
		hud_par_label.text = "MATCH POINT" if match_point else ""
		# The leader's colour names who is one pot from the match without a
		# second line of text.
		hud_par_label.add_theme_color_override("font_color", accent)
	hud_contract_fill.size.x = maxf(282.0 * float(maxi(duel_player, duel_house)) / float(duel_target), 4.0)
	hud_contract_fill.color = GOLD if duel_house > duel_player else (MINT if duel_player > duel_house else Color("#7d9a98"))
	hud_result_label.text = last_result
	hud_result_label.add_theme_color_override("font_color", result_color if not settings_high_contrast else Color.WHITE)
	hud_cue_label.text = "PASS & PLAY   ·   ONE KEYBOARD"
	hud_build_label.text = "%s AT THE TABLE" % current
	hud_build_label.add_theme_color_override("font_color", accent)
	hud_guard_label.text = "POT AND KEEP SHOOTING"
	hud_guard_label.add_theme_color_override("font_color", MUTED)
	hud_mods_label.text = "NO SHOT BUDGET   ·   NO BUILD"
	if is_instance_valid(hud_set_label):
		hud_set_label.text = ""
	if is_instance_valid(hud_heat_button):
		hud_heat_label.text = "THE RACE"
		hud_heat_label.add_theme_color_override("font_color", MUTED)
		hud_heat_button.text = "%d — %d" % [duel_player, duel_house]
		hud_heat_button.add_theme_font_size_override("font_size", 19)
		hud_heat_button.add_theme_color_override("font_disabled_color", accent)
		hud_heat_fill.size.x = 0.0
	hud_power_label.text = "%02d%%" % int(current_power * 100)
	hud_power_fill.size.x = 320.0 * current_power
	# FIRE is never dead in a local match: while balls roll it is SPEED UP (the
	# sink for a rattling pocket), and on a handoff it is the ready press.
	hud_fire_button.disabled = false
	if resolving:
		hud_fire_button.text = "SPEED UP"
	elif duel_handoff:
		# The button is the handoff: the next player accepts the cue before any
		# shot can be fired with their hands already on the keys.
		hud_fire_button.text = "%s READY" % current
	else:
		hud_fire_button.text = "FIRE SHOT"
	_refresh_spin_pad()

func _contract_line() -> String:
	if scenario.is_empty():
		return ""
	var target := int(scenario.get("target", 0))
	match str(scenario.contract_type):
		"score", "combo":
			return "SCORE  %d / %d" % [score, target]
		"bank_count":
			return "BANKS  %d / %d    POCKETS  %d / 4" % [bank_count, target, pocketed_count]
		"no_scratch":
			return "POCKETS  %d / %d    SCRATCHES  %d" % [pocketed_count, target, scratches]
		"ice_lane":
			return "POCKETS  %d / %d    LANE  %d / 1" % [pocketed_count, target, lane_pockets]
		"clear":
			return "POCKETS  %d / %d" % [pocketed_count, target]
	return ""

func _build_line() -> String:
	var counts := _archetype_counts()
	var parts: Array[String] = []
	for discipline in ["BANK", "COMBO", "RAIL", "CONTROL", "TEMPO"]:
		if int(counts.get(discipline, 0)) > 0:
			parts.append("%s x%d" % [discipline, int(counts[discipline])])
	return "   ".join(parts) if not parts.is_empty() else "No pieces yet."

# Compact build readout, shared by the reward and shop screens: the choice
# there is which discipline to deepen, so the current spread has to be visible.
func _build_strip(root: Control, position: Vector2, size: Vector2) -> void:
	var strip := _panel(root, position, size, PANEL)
	_add_label(strip, Vector2(24, 10), Vector2(size.x - 48, 16), "YOUR BUILD", 10, GOLD)
	_add_label(strip, Vector2(24, 28), Vector2(size.x - 48, 26), "%s   •   %s" % [active_cue, _build_line()], 13, Color("#dce9e6"))
	_add_label(strip, Vector2(24, 56), Vector2(size.x - 48, 20), _guard_line(), 10, MUTED)
	_add_label(strip, Vector2(24, 72), Vector2(size.x - 48, 16), _sets_line(), 9, GOLD)

func _mods_line() -> String:
	var parts: Array[String] = []
	if bank_bonus > 0:
		parts.append("BANK +%d" % bank_bonus)
	if combo_bonus > 0:
		parts.append("COMBO +%d%%" % combo_bonus)
	if rail_bonus > 0:
		parts.append("RAIL +%d" % rail_bonus)
	if side_pocket_bonus > 0:
		parts.append("SIDE +%d" % side_pocket_bonus)
	if house_spot_boost > 0:
		parts.append("SPOT +%d" % (10 + house_spot_boost * 5))
	if house_spot_table_hits > 0:
		parts.append("SPOT x%d" % house_spot_table_hits)
	return "  ·  ".join(parts) if not parts.is_empty() else "NO SCORING BONUSES YET"

func _guard_line() -> String:
	var parts: Array[String] = []
	if streak_guard > 0:
		parts.append("STREAK GUARD x%d" % streak_guard)
	if scratch_guard > 0:
		parts.append("SCRATCH GUARD x%d" % scratch_guard)
	if settings_volume <= 0.0:
		parts.append("AUDIO MUTED")
	return "   ".join(parts) if not parts.is_empty() else "No protection held."


func _take_shot() -> void:
	if paused:
		return
	# The handoff card owns the first press in a local match: FIRE takes the
	# cue for the next human instead of firing their shot for them.
	if duel_local and duel_handoff and screen == "encounter":
		_duel_confirm_handoff()
		return
	# The FIRE button becomes SPEED UP while a shot resolves. Portals cannot
	# afford a 9-second wait on a rattling pocket; a second press runs the rest
	# of the physics instantly instead of forcing a settings toggle.
	if resolving and not house_shooting:
		_skip_resolution()
		return
	# A duel has no shot budget; the 99 it carries is only a guard against a
	# tournament loop, and gating FIRE on it would softlock two flailing players
	# with the table still live.
	if screen != "encounter" or resolving or house_pending > 0.0 or house_shooting or (duel_active and duel_turn_house and not duel_local) or (shots_remaining <= 0 and not duel_active) or simulator.is_settled() == false or _encounter_complete():
		return
	var cue := simulator.get_ball(simulator.cue_ball_id)
	if cue.is_empty() or current_power < 0.08:
		last_result = "Set more power before firing."
		_refresh_hud()
		return
	_sfx("fire")
	cue_strike = 0.16
	cue_strike_pos = cue.position
	cue_strike_dir = last_aim.normalized()
	_burst(cue.position - last_aim.normalized() * 12.0, Color(0.93, 0.94, 0.86), 4, 50.0)
	# A new shot owns the screen: any replay from the last one is dismissed, and
	# this shot starts its own recording from the pre-contact frame.
	house_cam_active = false
	house_cam_frames.clear()
	house_cam_marks.clear()
	house_cam_clock = 0.0
	if settings_house_cam:
		_capture_house_cam_frame()
	var result := simulator.set_shot(last_aim.angle(), current_power, current_spin)
	if not result.ok:
		return
	_coach_finish()
	resolving = true
	resolve_elapsed = 0.0
	resolve_pockets = 0
	shot_number += 1
	shots_remaining -= 1
	shot_events.clear()
	ball_trails.clear()
	pocket_flashes.clear()
	last_result = "SHOT RESOLVING..."
	_refresh_hud()

# Heat is earned by potting, never by merely surviving, and a foul drains it
# so the meter cannot be farmed with dry shots. Reaching full is announced
# once: the button turns gold at the same moment, so the cue is redundant
# after the first time a player sees it.
func _gain_heat(amount: float) -> void:
	if is_zero_approx(amount):
		return
	var was_full := heat >= HEAT_FULL
	heat = clampf(heat + amount, 0.0, HEAT_FULL)
	if not was_full and heat >= HEAT_FULL and screen == "encounter":
		# A pulse on the dock button: the call is the point of the meter, and a
		# colour change alone is easy to miss mid-rack.
		if is_instance_valid(hud_heat_button):
			var pulse := create_tween()
			pulse.tween_property(hud_heat_button, "modulate", Color(1.3, 1.2, 1.0), 0.16)
			pulse.tween_property(hud_heat_button, "modulate", Color.WHITE, 0.34)
		_floater(Vector2(704, 560), "HOUSE HEAT FULL", GOLD)
		last_result = "HOUSE HEAT FULL — press F or CALL HOUSE for a double-score shot."
		result_color = GOLD
		_sfx("streak")

func _arm_house_call() -> void:
	if screen != "encounter" or resolving or paused or house_pending > 0.0 or house_shooting:
		return
	if house_call_armed:
		last_result = "The House shot is already called — fire it."
		result_color = GOLD
		_refresh_hud()
		_refocus_fire()
		return
	if heat < HEAT_FULL:
		last_result = "House heat %d%% — pots fill it, fouls drain it." % int(heat)
		result_color = Color("#b9c9c8")
		_sfx("click")
		_refresh_hud()
		_refocus_fire()
		return
	heat = 0.0
	house_call_armed = true
	_add_trauma(0.22)
	_hit_stop(0.05)
	_sfx("cash")
	_floater(Vector2(704, 520), "HOUSE CALL", GOLD)
	last_result = "HOUSE CALL — the next shot pays double and a scratch is covered."
	result_color = GOLD
	_refresh_hud()
	_refocus_fire()
	queue_redraw()

# Calling the House is a prelude to a shot, so the confirm key belongs back on
# FIRE afterwards; otherwise a keyboard player presses Enter again and only
# re-triggers the button they just used.
func _refocus_fire() -> void:
	if is_instance_valid(hud_fire_button) and not hud_fire_button.disabled:
		hud_fire_button.grab_focus()

func _skip_resolution() -> void:
	if not resolving or house_shooting:
		return
	# fast_forward returns every pocket it rolls through, so a skipped shot
	# scores exactly like a watched one. This is presentation only.
	var events := simulator.fast_forward()
	shot_events.append_array(events)
	_process_shot_events(events)
	_finish_shot()
	queue_redraw()

func _finish_shot() -> void:
	resolving = false
	var pocketed_this_shot := 0
	var rails_this_shot := 0
	var target_rail := false
	var scratched := false
	var legal_contact := false
	var shot_value := 0
	var scored_rails := 0
	var banked_value := 0
	var side_pockets := 0
	var deepest_rail_pot := 0
	var set_heat := 0.0
	var set_notes: Array[String] = []
	for event in shot_events:
		if event.type == "first_contact":
			legal_contact = true
		if event.type == "rail":
			rails_this_shot += 1
			var rail_ball := simulator.get_ball(event.ball_id)
			if not rail_ball.is_empty() and rail_ball.target:
				target_rail = true
		if event.type == "pocket":
			var pocketed_ball := simulator.get_ball(event.ball_id)
			if not pocketed_ball.is_empty() and pocketed_ball.target:
				pocketed_this_shot += 1
				shot_value += int(pocketed_ball.value)
				# Only rails used by a ball that actually dropped may pay base
				# score. The old loop paid for every cushion the cue touched, so a
				# missed safety shot "scored 6 BANK" and score contracts could be
				# cleared without pocketing a single target.
				var target_rails := int(event.get("rails", 0))
				scored_rails += target_rails
				if target_rails > 0:
					banked_value += int(pocketed_ball.value)
				# Deep banks: a target that touched 2+ rails before its pocket earns a bonus per extra rail.
				var deep_rails := maxi(target_rails - 1, 0)
				shot_value += deep_rails * DEEP_BANK_BONUS
				deepest_rail_pot = maxi(deepest_rail_pot, target_rails)
				# HOUSE SET II/IV: the bank identity starts paying for the setup
				# itself, not just the size of the original ball.
				if target_rails > 0:
					var bank_set := _set_tier("BANK")
					if bank_set >= 2:
						shot_value += 30 if bank_set >= 4 else 15
						if not set_notes.has("BANK SET"):
							set_notes.append("BANK SET")
						if bank_set >= 4:
							set_heat += 12.0
				if str(event.get("pocket_kind", "corner")) == "side":
					side_pockets += 1
			if event.ball_id == simulator.cue_ball_id:
				scratched = true
	# A duel is a pocket race, not a scored run: it must never touch score,
	# cash, heat, the build or the saved tour. Resolve the turn and hand the
	# cue back to the table loop.
	if duel_active:
		flash_time = (0.25 if settings_reduced_flash else 0.75) if pocketed_this_shot > 0 else (0.15 if settings_reduced_flash else 0.35)
		if pocketed_this_shot > 0:
			_add_trauma(0.35 if pocketed_this_shot == 1 else 0.6)
			_floater(Vector2(795, 320), "+%d" % pocketed_this_shot, GOLD if duel_local and duel_turn_house else MINT)
		elif scratched:
			_add_trauma(0.6)
		# The race result screen, if this shot ends the match, covers the inset;
		# starting it anyway costs nothing and a non-final multi-pot deserves it.
		_maybe_start_house_cam(pocketed_this_shot, target_rail and banked_value > 0, false)
		_duel_resolve_player_shot(pocketed_this_shot, scratched, legal_contact)
		queue_redraw()
		return
	if target_rail and pocketed_this_shot > 0:
		bank_count += 1
		run_banks += 1
	# HOUSE SET II/IV: combo and rail identities are paid on the same base
	# value as a pot, before the term and streak multipliers, so they scale
	# with the build instead of sitting outside it.
	if pocketed_this_shot > 1:
		var combo_set := _set_tier("COMBO")
		if combo_set >= 2:
			var chain_pay := (pocketed_this_shot - 1) * (40 if combo_set >= 4 else 20)
			shot_value += chain_pay
			set_notes.append("CHAIN +%d" % chain_pay)
			if combo_set >= 4 and not set_combo_shot_used:
				set_combo_shot_used = true
				shots_remaining += 1
				set_heat += 10.0
				set_notes.append("SET +1 SHOT")
	if deepest_rail_pot >= 2:
		var rail_set := _set_tier("RAIL")
		if rail_set >= 2:
			var rail_pay := 35 if rail_set >= 4 else 15
			shot_value += rail_pay
			set_notes.append("RAIL SET +%d" % rail_pay)
			if rail_set >= 4:
				set_heat += 10.0
	flash_time = (0.25 if settings_reduced_flash else 0.75) if pocketed_this_shot > 0 else (0.15 if settings_reduced_flash else 0.35)
	if pocketed_this_shot > 0:
		_add_trauma(0.35 if pocketed_this_shot == 1 else 0.6)
		_floater(Vector2(795, 320), "+%d" % shot_value, MINT)
	elif scratched:
		_add_trauma(0.6)
	if scratched:
		scratches += 1
		fouls += 1
		run_scratches += 1
		if scratch_guard > 0:
			scratch_guard -= 1
			_recover_cue()
			last_result = "SCRATCH FORGIVEN — corked case absorbs it."
			result_color = MINT
		elif house_call_armed:
			# A called House shot protects the shot budget, so a bold line is
			# never punished twice: the call is spent and the streak still breaks.
			combo_streak = 0
			_recover_cue()
			last_result = "HOUSE CALL COVERS THE SCRATCH — no shot lost."
			result_color = GOLD
			_sfx("streak")
		else:
			if streak_guard > 0:
				streak_guard -= 1
			else:
				combo_streak = 0
			if shots_remaining > 0:
				shots_remaining -= 1
			if encounter_is_elite and shots_remaining > 0:
				shots_remaining -= 1
			if encounter_is_boss and shots_remaining > 0:
				shots_remaining -= 1
			if bool(_contract().get("foul_extra", false)) and shots_remaining > 0:
				shots_remaining -= 1
			_recover_cue()
			last_result = "SCRATCH — penalty shot lost. Cue ball recovered."
			result_color = RED
			_sfx("scratch")
	elif not legal_contact:
		fouls += 1
		if streak_guard > 0:
			streak_guard -= 1
		else:
			combo_streak = 0
		if shots_remaining > 0:
			shots_remaining -= 1
		if encounter_is_elite and shots_remaining > 0:
			shots_remaining -= 1
		if encounter_is_boss and shots_remaining > 0:
			shots_remaining -= 1
		if bool(_contract().get("foul_extra", false)) and shots_remaining > 0:
			shots_remaining -= 1
		last_result = "FOUL — no legal target contact. Shot penalty applied."
		result_color = RED
		_sfx("foul")
	else:
		# Base rail pay belongs to a ball that dropped, not to every cushion
		# stroke. Build pieces and the RAIL WEEK daily still pay per contact
		# through rail_bonus, so that identity remains intact.
		var shot_score := shot_value + scored_rails * 3 + rails_this_shot * rail_bonus
		var is_locksmith := encounter_is_boss and current_node >= 0 and str(map_nodes[current_node].name).to_upper() != "THE HOUSE"
		if target_rail and banked_value > 0:
			# A bank that does not drop is a miss, not a paid bank. The old
			# gate only checked target_rail, so bank builds earned their bonus
			# for grazing a cushion and missing the pocket entirely.
			shot_score += bank_bonus
			if is_locksmith:
				# Pay only the banked pot again, not the whole shot: a mixed
				# shot used to double a directly pocketed ball sitting beside it.
				shot_score += banked_value
				if boss_phase >= 1:
					shot_score += banked_value
		if scenario.contract_type == "score" and scored_rails > 0:
			shot_score += scored_rails * 4
		# A pocket the House bolted cannot capture a ball, so any side pot here
		# came through an open mouth; the side bonus is always earned.
		if side_pockets > 0:
			shot_score += side_pockets * side_pocket_bonus
		# House terms reshape what the pot is worth. A Banker is paid for
		# bringing a cushion into the line; a Collector for bringing a second
		# ball. The Mark and Grifter are neutral.
		var terms := _contract()
		if pocketed_this_shot > 0 and str(terms.id) == "banker":
			var banked_line := target_rail and banked_value > 0
			shot_score = int(float(shot_score) * (float(terms.bank_mult) if banked_line else float(terms.direct_mult)))
		elif pocketed_this_shot > 0 and str(terms.id) == "collector":
			shot_score = int(float(shot_score) * (float(terms.multi_mult) if pocketed_this_shot > 1 else float(terms.single_mult)))
		if pocketed_this_shot > 1:
			combo_shots += 1
			run_combo_shots += 1
			shot_score = int(float(shot_score) * (1.25 + combo_bonus * 0.01))
		if pocketed_this_shot > 0:
			combo_streak += 1
			best_streak = maxi(best_streak, combo_streak)
			run_best_streak = maxi(run_best_streak, best_streak)
			shot_score = int(float(shot_score) * (1.0 + minf(float(combo_streak), 5.0) * 0.05))
		else:
			if streak_guard > 0:
				streak_guard -= 1
			else:
				combo_streak = 0
		# THE HOUSE REMEMBERS: the tax lands after the build and streak have
		# paid, so the rule reads as a real cut to the line the House studied
		# rather than a rounding error on the base ball value.
		var grudge_mult := _grudge_multiplier(pocketed_this_shot, target_rail and banked_value > 0)
		if grudge_mult < 1.0:
			shot_score = int(float(shot_score) * grudge_mult)
			set_notes.append("HOUSE TAX")
		if house_call_armed and shot_score > 0:
			# Doubling lands after every build bonus and combo multiplier, so
			# the call reads as one decisive shot rather than a small add-on.
			shot_score *= 2
		if shot_score > 0:
			score += shot_score
			run_score += shot_score
			if pocketed_this_shot > 0:
				# A best-shot record must be a real pot. A RAIL PAY miss can
				# move the score, but it must never claim a single-shot trophy.
				run_best_shot = maxi(run_best_shot, shot_score)
				last_result = "+%d  %s" % [shot_score, _shot_tags(rails_this_shot, pocketed_this_shot, target_rail)]
				result_color = MINT
				if target_rail:
					_sfx("bank")
				if combo_streak >= 3:
					_sfx("streak")
			else:
				# Only a rail-pay build can reach this branch without a pocket;
				# say why the score moved instead of dressing it as a bank.
				last_result = "+%d  RAIL PAY  ·  MISS" % shot_score
				result_color = Color("#b9c9c8")
		else:
			last_result = "No pocket. Re-plan the changed table."
			result_color = Color("#b9c9c8")
	var heat_gain := minf(float(pocketed_this_shot), 2.0) * 22.0
	if pocketed_this_shot > 0 and target_rail and banked_value > 0:
		heat_gain += 10.0
	if pocketed_this_shot == 0 and legal_contact and not scratched:
		heat_gain += 6.0
	if scratched or not legal_contact:
		heat_gain -= 30.0
	else:
		heat_gain += set_heat
	_gain_heat(heat_gain)
	if pocketed_this_shot > 0 and not set_notes.is_empty() and not last_result.begins_with("SCRATCH"):
		last_result += "  ·  " + "  ·  ".join(set_notes)
	# Position is scored after the pot, so the ring cannot be farmed on a dry
	# shot. A scratch never parks: the cue is off the felt.
	if pocketed_this_shot > 0 and not scratched:
		_try_park_house_spot()
	if house_call_armed:
		# Counted only when the call is actually fired, so leaving a table with
		# a charged call cannot farm the milestone shelf.
		house_calls += 1
	house_call_armed = false
	_check_boss_phase()
	# Pick the replay after scoring: the caption belongs to what the shot did,
	# not to what the aim line promised. A table that just ended already has a
	# reward card, so it does not also need an inset behind it.
	_maybe_start_house_cam(pocketed_this_shot, target_rail and banked_value > 0, _encounter_complete() or shots_remaining <= 0)
	# Practice never ends the run.
	if current_node == -1:
		_refresh_hud()
		queue_redraw()
		return
	if _encounter_complete():
		run_tables_cleared += 1
		_complete_current_node()
	elif shots_remaining <= 0:
		# A rescue is offered before the run is recorded. The House extends one
		# marker per tour; taking it reracks this table instead of ending the run.
		# The Grind has no marker: the endless line ends where it breaks.
		if gauntlet_active:
			_show_defeat()
		elif favor_available:
			_show_last_call()
		else:
			_show_defeat()
	elif _house_should_shoot(pocketed_this_shot):
		_queue_house_turn()
	else:
		_refresh_hud()
	queue_redraw()

# The House's phase two is a real opponent, not a hidden modifier: it takes the
# cue after any shot that pots nothing, and every ball it pots lets it bolt one
# pocket. Only the last boss plays this way; the Locksmith keeps its bank tax.
func _house_should_shoot(pocketed_this_shot: int) -> bool:
	if not encounter_is_boss or boss_phase < 1 or current_node < 0:
		return false
	if str(map_nodes[current_node].name).to_upper() != "THE HOUSE":
		return false
	return pocketed_this_shot == 0

func _check_boss_phase() -> void:
	if not encounter_is_boss or current_node < 0 or boss_phase >= 1:
		return
	if scenario.is_empty():
		return
	var boss_name := str(map_nodes[current_node].name).to_upper()
	var gate := int(scenario.target) / 2
	# THE HOUSE REMEMBERS (scratches): a player who survived on the foul line
	# gets no grace period. It takes the table a third of the way in.
	if grudge_active and house_grudge == "scratch" and boss_name == "THE HOUSE":
		gate = int(float(int(scenario.target)) * 0.34)
	if score < gate:
		return
	boss_phase = 1
	_add_trauma(0.5)
	_hit_stop(0.12)
	_sfx("boss")
	if boss_name == "THE HOUSE":
		last_result = "PHASE 2 — THE HOUSE TAKES THE TABLE. Miss, and it shoots."
		_floater(Vector2(795, 280), "THE HOUSE STANDS", RED)
	else:
		last_result = "PHASE 2 — the gate weakens. Banked pots pay triple. Finish it."
		_floater(Vector2(795, 280), "PHASE 2", GOLD)
	result_color = GOLD

func _cancel_active_shot() -> void:
	resolving = false
	house_shooting = false
	house_pending = 0.0
	resolve_elapsed = 0.0
	shot_events.clear()
	ball_trails.clear()
	pocket_flashes.clear()
	for ball in simulator.balls:
		ball.velocity = Vector2.ZERO

func _queue_house_turn() -> void:
	# One visible beat, then the House shoots. The pause is not decoration: it
	# is the only warning the player gets that the cue is about to be taken.
	# The first turn teaches the rule; later turns only need a cue that the House
	# is moving. A full banner every miss would turn a boss beat into a screensaver.
	house_pending = 1.8 if house_turns == 0 else 0.9
	last_result = "THE HOUSE STEPS UP — your miss handed it the cue."
	result_color = RED
	_sfx("boss")
	_refresh_hud()
	_refocus_fire()

func _house_plan_shot() -> Dictionary:
	var cue := simulator.get_ball(simulator.cue_ball_id)
	if cue.is_empty() or bool(cue.get("pocketed", true)):
		return {}
	var radius := BilliardsSimulator.BALL_RADIUS
	var best := {}
	var best_cost := INF
	for ball in simulator.balls:
		if not bool(ball.get("target", false)) or bool(ball.get("pocketed", true)):
			continue
		for index in simulator.pockets.size():
			if simulator.closed_pockets.has(index):
				continue
			var pocket: Vector2 = simulator.pockets[index]
			var to_pocket: Vector2 = pocket - ball.position
			var pocket_dist := to_pocket.length()
			if pocket_dist < 70.0:
				continue
			var pocket_dir := to_pocket / pocket_dist
			var ghost: Vector2 = ball.position - pocket_dir * (radius * 2.0 - 2.0)
			var to_ghost: Vector2 = ghost - cue.position
			var cue_dist := to_ghost.length()
			if cue_dist < 40.0:
				continue
			var aim := to_ghost / cue_dist
			var alignment := aim.dot(pocket_dir)
			# Thin cuts are the House's tell: it will not attempt a line it
			# cannot actually hold, so a player can read where it is safe.
			if alignment < 0.3:
				continue
			if not _guide_lane_clear(cue.position, ghost, int(ball.id), true):
				continue
			if not _guide_lane_clear(ball.position, pocket, int(ball.id)):
				continue
			var cost := (1.0 - alignment) * 1100.0 + cue_dist * 0.55 + pocket_dist * 0.35
			if cost < best_cost:
				best_cost = cost
				var power := clampf(0.34 + cue_dist / 1600.0 + pocket_dist / 2600.0, 0.32, 0.9)
				best = {"aim": aim, "power": power}
			# The boss racks hide the cue behind a slab; a House that only plays
			# straight lines would never take a pocket. One-rail kicks let it go
			# around the blockage the same way the table's best players do.
			var bank := _house_bank_shot(cue, ball, ghost, pocket_dist)
			if not bank.is_empty() and float(bank.cost) < best_cost:
				best_cost = bank.cost
				best = {"aim": bank.aim, "power": bank.power}
	if best.is_empty():
		# Nothing visible from where the cue lies: the House takes ball in hand
		# and places the cue where it can see a pocket. The Croupier is the
		# teaching form and does not get this privilege, so a beginner can hide
		# the cue and actually get it back.
		var takes_hand := true
		if duel_active:
			takes_hand = bool(DUEL_FORMS[duel_form].get("hand", true))
		if takes_hand:
			var placed := _house_ball_in_hand()
			if not placed.is_empty():
				return placed
	var rng := RandomNumberGenerator.new()
	rng.seed = _house_roll_seed()
	var jitter := rng.randf_range(-house_aim_error, house_aim_error)
	if best.is_empty():
		# No clean line: the House plays a soft safety instead of pretending.
		var nearest := {}
		var nearest_dist := INF
		for ball in simulator.balls:
			if not bool(ball.get("target", false)) or bool(ball.get("pocketed", true)):
				continue
			var d: float = cue.position.distance_to(ball.position)
			if d < nearest_dist:
				nearest_dist = d
				nearest = ball
		if nearest.is_empty():
			return {}
		var safety_dir: Vector2 = (nearest.position - cue.position).normalized()
		return {"aim": safety_dir.rotated(jitter * 3.0), "power": 0.36, "safety": true}
	return {"aim": best.aim.rotated(jitter), "power": best.power, "safety": false}

# The boss's read: the House owns the cue. When no direct line exists from the
# current cue position, it places the cue where one does. The spot search uses
# the same lane test as the player's aim guide, so it can never cheat through
# a block or a ball.
func _house_ball_in_hand() -> Dictionary:
	var table := simulator.table_rect
	var radius := BilliardsSimulator.BALL_RADIUS
	var rng := RandomNumberGenerator.new()
	rng.seed = _house_roll_seed() + 17
	var jitter := rng.randf_range(-house_aim_error, house_aim_error)
	var best := {}
	var best_cost := INF
	for ball in simulator.balls:
		if not bool(ball.get("target", false)) or bool(ball.get("pocketed", true)):
			continue
		for index in simulator.pockets.size():
			if simulator.closed_pockets.has(index):
				continue
			var pocket: Vector2 = simulator.pockets[index]
			var to_pocket: Vector2 = pocket - ball.position
			var pocket_dist := to_pocket.length()
			if pocket_dist < 70.0:
				continue
			var pocket_dir := to_pocket / pocket_dist
			if not _guide_lane_clear(ball.position, pocket, int(ball.id)):
				continue
			var ghost: Vector2 = ball.position - pocket_dir * (radius * 2.0 - 2.0)
			var inner := table.grow(-radius - 6.0)
			for row in 7:
				for col in 10:
					var spot := Vector2(
						inner.position.x + inner.size.x * float(col + 0.5) / 10.0,
						inner.position.y + inner.size.y * float(row + 0.5) / 7.0
					)
					var cue_dist := spot.distance_to(ghost)
					if cue_dist < 70.0:
						continue
					if not _cue_spot_clear(spot, simulator.cue_ball_id):
						continue
					if not _guide_lane_clear(spot, ghost, int(ball.id), true):
						continue
					var aim := (ghost - spot).normalized()
					var alignment := aim.dot(pocket_dir)
					if alignment < 0.35:
						continue
					var cost := (1.0 - alignment) * 900.0 + cue_dist * 0.4 + pocket_dist * 0.2
					if cost < best_cost:
						best_cost = cost
						best = {"aim": aim.rotated(jitter), "power": clampf(0.34 + cue_dist / 1500.0 + pocket_dist / 2400.0, 0.32, 0.9), "place": spot, "safety": false}
	return best

# One-rail kick: mirror the ghost point across each cushion, then aim at the
# mirror. The reflected path is checked segment by segment, so a kick that
# would rattle through a block or another ball is never chosen.
func _house_bank_shot(cue: Dictionary, ball: Dictionary, ghost: Vector2, pocket_dist: float) -> Dictionary:
	var table := simulator.table_rect
	var radius := BilliardsSimulator.BALL_RADIUS
	var best := {}
	var best_cost := INF
	var rails := [
		{"axis": "y", "line": table.position.y + radius, "min": table.position.x + 80.0, "max": table.end.x - 80.0},
		{"axis": "y", "line": table.end.y - radius, "min": table.position.x + 80.0, "max": table.end.x - 80.0},
		{"axis": "x", "line": table.position.x + radius, "min": table.position.y + 80.0, "max": table.end.y - 80.0},
		{"axis": "x", "line": table.end.x - radius, "min": table.position.y + 80.0, "max": table.end.y - 80.0},
	]
	for rail in rails:
		var line := float(rail.line)
		var mirrored := Vector2(ghost.x, line * 2.0 - ghost.y) if rail.axis == "y" else Vector2(line * 2.0 - ghost.x, ghost.y)
		var denom: float = mirrored.y - cue.position.y if rail.axis == "y" else mirrored.x - cue.position.x
		if absf(denom) < 0.001:
			continue
		var t: float = (line - cue.position.y) / denom if rail.axis == "y" else (line - cue.position.x) / denom
		if t <= 0.02 or t >= 0.98:
			continue
		var hit: Vector2 = cue.position.lerp(mirrored, t)
		var along := hit.x if rail.axis == "y" else hit.y
		if along < float(rail.min) or along > float(rail.max):
			continue
		var near_pocket := false
		for p in simulator.pockets:
			if hit.distance_to(p) < 74.0:
				near_pocket = true
				break
		if near_pocket:
			continue
		if not _guide_lane_clear(cue.position, hit, int(ball.id), true):
			continue
		if not _guide_lane_clear(hit, ghost, int(ball.id)):
			continue
		var total: float = cue.position.distance_to(hit) + hit.distance_to(ghost)
		var cost: float = total * 0.55 + pocket_dist * 0.35 + 360.0
		if cost < best_cost:
			best_cost = cost
			best = {
				"aim": (mirrored - cue.position).normalized(),
				"power": clampf(0.36 + total / 1200.0, 0.36, 0.95),
				"cost": cost,
			}
	return best

func _house_take_shot() -> void:
	if screen != "encounter" or resolving or house_shooting:
		return
	house_place_from = Vector2.ZERO
	var cue := simulator.get_ball(simulator.cue_ball_id)
	if cue.is_empty() or bool(cue.get("pocketed", true)):
		_recover_cue()
	var plan := _house_plan_shot()
	if plan.is_empty():
		# Nothing to aim at: the rack has already resolved, or a duel's House
		# found no line. Hand the cue back rather than freezing the table on an
		# impossible button state.
		house_pending = 0.0
		if duel_active:
			duel_turn_house = false
			last_result = "THE HOUSE HAS NO SHOT — the table is yours."
			result_color = MINT
			_sfx("streak")
			_refresh_hud()
			_refocus_fire()
			return
		last_result = "The House has nothing left to take. Play it out."
		result_color = Color("#b9c9c8")
		_refresh_hud()
		return
	house_aim = plan.aim
	house_power = plan.power
	if plan.has("place"):
		var placed_cue: Dictionary = simulator.get_ball(simulator.cue_ball_id)
		house_place_from = placed_cue.position
		placed_cue.position = plan.place
		placed_cue.velocity = Vector2.ZERO
		placed_cue.spin = Vector2.ZERO
		_floater(plan.place, "BALL IN HAND", GOLD)
		last_result = "THE HOUSE TAKES BALL IN HAND."
		result_color = RED
	var result := simulator.set_shot(house_aim.angle(), house_power, Vector2.ZERO)
	if not result.ok:
		house_pending = 0.0
		if duel_active:
			duel_turn_house = false
			last_result = "THE HOUSE PASSES — the table is yours."
			result_color = MINT
			_refocus_fire()
			_refresh_hud()
			return
		_refresh_hud()
		return
	house_turns += 1
	house_shooting = true
	resolving = true
	resolve_elapsed = 0.0
	resolve_pockets = 0
	shot_events.clear()
	last_result = "THE HOUSE SHOOTS…"
	result_color = RED
	_sfx("fire")
	_refresh_hud()
	queue_redraw()

func _finish_house_shot() -> void:
	resolving = false
	house_shooting = false
	house_pending = 0.0
	if duel_active:
		_duel_finish_house_shot()
		return
	var cue_scratched := false
	var potted: Array[Dictionary] = []
	var shut_index := -1
	for event in shot_events:
		if event.type != "pocket":
			continue
		var ball := simulator.get_ball(int(event.ball_id))
		if ball.is_empty():
			continue
		if int(event.ball_id) == simulator.cue_ball_id:
			cue_scratched = true
			continue
		if not bool(ball.get("target", false)):
			continue
		potted.append(ball)
		if shut_index < 0 and simulator.closed_pockets.size() < HOUSE_POCKET_CAP:
			shut_index = int(event.get("pocket", -1))
	if cue_scratched:
		_recover_cue()
	# Spot the House's captures back on the felt. Its pot is not a score: it is
	# a claim on the pocket, and removing the ball would quietly lower the
	# contract's ceiling below what the rack can pay.
	for ball in potted:
		_respot_target(ball)
	if shut_index >= 0:
		var pocket_name := _house_pocket_name(shut_index)
		simulator.close_pocket(shut_index)
		last_result = "THE HOUSE BOLTS THE %s POCKET — %d still open. Your ball is spotted." % [pocket_name, simulator.open_pocket_count()]
		result_color = RED
		_floater(simulator.pockets[shut_index] + Vector2(-52, -28), "POCKET SHUT", RED)
		_add_trauma(0.55)
		_hit_stop(0.1)
		_sfx("boss")
	elif not potted.is_empty():
		last_result = "The House pots your %d, then spots it back. Every pocket it can shut is already bolted." % int(potted[0].value)
		result_color = GOLD
		_sfx("scratch")
	elif cue_scratched:
		last_result = "THE HOUSE SCRATCHES. It hands the cue back without a word."
		result_color = MINT
		_sfx("streak")
	else:
		last_result = _house_table_line()
		result_color = Color("#b9c9c8")
		_sfx("click")
	_refresh_hud()
	queue_redraw()
	_refocus_fire()

func _respot_target(ball: Dictionary) -> void:
	ball.pocketed = false
	ball.position = _respot_spot()
	ball.velocity = Vector2.ZERO
	ball.spin = Vector2.ZERO
	ball.first_contact = false
	ball.first_contact_target_id = -1
	ball.ice_touched = false
	ball.rails_touched = 0
	ball.barriers_touched = 0

func _house_pocket_name(index: int) -> String:
	if index < 0 or index >= simulator.pockets.size():
		return "POCKET"
	if str(simulator.pocket_kinds[index]) == "side":
		return "SIDE"
	var pocket: Vector2 = simulator.pockets[index]
	var center := simulator.table_rect.get_center()
	var side := "LEFT" if pocket.x < center.x else "RIGHT"
	var end := "TOP" if pocket.y < center.y else "BOTTOM"
	return "%s-%s" % [end, side]

func _house_table_line() -> String:
	return HOUSE_TABLE_LINES[posmod(house_turns + run_stage, HOUSE_TABLE_LINES.size())]

func _recover_cue() -> void:
	var cue := simulator.get_ball(simulator.cue_ball_id)
	if cue.is_empty():
		return
	# A scratch used to drop the cue on the table centre even when a target
	# already rested there (or a block covered it), spawning two balls inside
	# each other and handing the player a broken-looking table. Find the
	# nearest open spot instead.
	cue.pocketed = false
	cue.position = _cue_recovery_spot()
	cue.velocity = Vector2.ZERO
	cue.spin = Vector2.ZERO

# Closest legal drop for a recovered cue: clear of every live ball, every
# block and every pocket mouth, searched outward from the centre so the
# restart is predictable instead of random.
func _cue_recovery_spot() -> Vector2:
	return _open_spot_near(simulator.table_rect.get_center(), simulator.cue_ball_id)

# The House spots its captures at the foot side of the table, which is where a
# real rack would put a returned ball. Every live ball (including the cue)
# blocks the spot, so two res pots can never land inside each other.
func _respot_spot() -> Vector2:
	var table := simulator.table_rect
	var anchor := table.position + Vector2(table.size.x * 0.72, table.size.y * 0.5)
	return _open_spot_near(anchor, -1)

func _open_spot_near(anchor: Vector2, ignore_ball_id: int) -> Vector2:
	var radius := BilliardsSimulator.BALL_RADIUS
	var inner := simulator.table_rect.grow(-radius - 4.0)
	var spots: Array[Vector2] = []
	var step := 64.0
	var cols := int(inner.size.x / step)
	var rows := int(inner.size.y / step)
	for row in rows + 1:
		for col in cols + 1:
			spots.append(Vector2(
				minf(inner.position.x + col * step, inner.end.x),
				minf(inner.position.y + row * step, inner.end.y)
			))
	spots.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return a.distance_squared_to(anchor) < b.distance_squared_to(anchor))
	for spot in spots:
		if _cue_spot_clear(spot, ignore_ball_id):
			return spot
	return anchor

func _cue_spot_clear(point: Vector2, ignore_ball_id: int) -> bool:
	var radius := BilliardsSimulator.BALL_RADIUS
	for ball in simulator.balls:
		if bool(ball.pocketed) or int(ball.id) == ignore_ball_id:
			continue
		if point.distance_to(ball.position) < radius * 2.0 + 6.0:
			return false
	for barrier in simulator.barriers:
		if barrier.grow(radius + 4.0).has_point(point):
			return false
	for pocket in simulator.pockets:
		if point.distance_to(pocket) < 52.0:
			return false
	return true

# --- THE HOUSE'S SPOT ------------------------------------------------------
# Placement is deliberate, not random: the ring must be a real target a player
# could reach after a pot. It sits near the live targets but clear of every
# ball, rail, pocket and block, so it never asks for an impossible leave.
func _place_house_spot() -> void:
	house_spot = Vector2.ZERO
	if duel_active:
		return
	var table := simulator.table_rect
	if table.size.x < 200.0:
		return
	var target_centroid := Vector2.ZERO
	var target_count := 0
	for ball in simulator.balls:
		if bool(ball.get("target", false)) and not bool(ball.get("pocketed", false)):
			target_centroid += ball.position
			target_count += 1
	if target_count == 0:
		return
	target_centroid /= float(target_count)
	var inner := table.grow(-62.0)
	var best := Vector2.ZERO
	var best_score := -INF
	for row in 5:
		for col in 9:
			var point := inner.position + Vector2(inner.size.x * float(col) / 8.0, inner.size.y * float(row) / 4.0)
			if not _house_spot_clear(point):
				continue
			var nearest_ball := 9999.0
			for ball in simulator.balls:
				if bool(ball.get("pocketed", false)):
					continue
				nearest_ball = minf(nearest_ball, point.distance_to(ball.position))
			# Two pulls: stay near the action (so a leave there is plausible)
			# and stay in open felt (so the ring is readable).
			var score := minf(nearest_ball, 220.0) * 1.35 - point.distance_to(target_centroid) * 0.45
			if score > best_score:
				best_score = score
				best = point
	if best_score > -INF:
		house_spot = best
	else:
		# A crowded rack can leave no fully clear grid point. Never draw a ring
		# that a ball is sitting on: a spot the player cannot read is worse than
		# no spot at all.
		var fallback := _open_spot_near(target_centroid, -1)
		house_spot = fallback if _house_spot_clear(fallback) else Vector2.ZERO

func _house_spot_clear(point: Vector2) -> bool:
	for ball in simulator.balls:
		if bool(ball.get("pocketed", false)):
			continue
		if point.distance_to(ball.position) < 58.0:
			return false
	for barrier in simulator.barriers:
		if barrier.grow(48.0).has_point(point):
			return false
	for pocket in simulator.pockets:
		if point.distance_to(pocket) < 74.0:
			return false
	return simulator.table_rect.grow(-60.0).has_point(point)

# The only payout in the game that asks where the cue stopped. A table pays the
# first park once with a shot back, so a great leave can rescue a tight rack;
# every park still pays score and heat, which makes position play a score line
# rather than a cosmetic ring.
func _try_park_house_spot() -> bool:
	if duel_active or house_spot == Vector2.ZERO:
		return false
	var cue := simulator.get_ball(simulator.cue_ball_id)
	if cue.is_empty() or bool(cue.get("pocketed", false)):
		return false
	if cue.position.distance_to(house_spot) > HOUSE_SPOT_RADIUS:
		return false
	house_spot_hits += 1
	house_spot_table_hits += 1
	house_spot_flash = 0.9
	var gain := 10 + house_spot_boost * 5
	var notes: Array[String] = ["SPOT +%d" % gain]
	score += gain
	run_score += gain
	_gain_heat(16.0)
	if not house_spot_paid_shot or house_spot_boost > 0:
		house_spot_paid_shot = true
		shots_remaining += 1
		notes.append("+1 SHOT")
	last_result += "  ·  " + "  ".join(notes)
	_floater(house_spot + Vector2(0, -42), "ON THE SPOT", GOLD)
	_burst(house_spot, GOLD, 20, 190.0)
	_sfx("streak", -2.0)
	_place_house_spot()
	return true

func _encounter_complete() -> bool:
	if scenario.is_empty():
		return false
	if scenario.contract_type == "score":
		return score >= scenario.target
	if scenario.contract_type == "ice_lane":
		return pocketed_count >= scenario.target and lane_pockets >= 1
	if scenario.contract_type == "bank_count":
		return bank_count >= scenario.target and pocketed_count >= 4
	if scenario.contract_type == "no_scratch":
		return pocketed_count >= scenario.target and scratches == 0
	if scenario.contract_type == "clear":
		return pocketed_count >= scenario.target
	if scenario.contract_type == "combo":
		return score >= scenario.target and combo_shots >= 1
	return false

# A build piece's discipline is derived from what it actually rewards, so the
# classification can never drift from the piece's numbers.
func _archetype(item: Dictionary) -> String:
	var bank := int(item.get("bank", 0)) + int(item.get("side", 0))
	var combo := int(item.get("combo", 0))
	var rail := int(item.get("rail", 0))
	var control := int(item.get("guard", 0)) + int(item.get("scratch", 0)) + int(item.get("spot", 0))
	var tempo := int(item.get("shots", 0)) * 3 + int(item.get("cash", 0)) / 20
	var best := "BANK"
	var best_value := bank
	for pair in [["COMBO", combo], ["RAIL", rail], ["CONTROL", control], ["TEMPO", tempo]]:
		if int(pair[1]) > best_value:
			best = str(pair[0])
			best_value = int(pair[1])
	return best

# Discipline counts for the current run, derived from the pieces already taken.
func _archetype_color(discipline: String) -> Color:
	match discipline:
		"BANK":
			return GOLD
		"COMBO":
			return Color("#f28bb0")
		"RAIL":
			return MINT
		"CONTROL":
			return Color("#84c7f2")
		"TEMPO":
			return Color("#f0a25e")
	return MINT

# The shop assumes the player knows what a discipline does. One line per
# category makes the three offers a strategy choice instead of three prices.
func _discipline_role(discipline: String) -> String:
	match discipline:
		"BANK":
			return "Rewards banked pots and side pockets."
		"COMBO":
			return "Rewards multi-ball shots and streaks."
		"RAIL":
			return "Pays for every cushion the cue touches."
		"CONTROL":
			return "Protects a streak, forgives a scratch, or pays position."
		"TEMPO":
			return "Buys shots and cash for the route."
	return ""

func _archetype_counts() -> Dictionary:
	var counts := {}
	for taken in collection:
		for item in reward_catalog:
			if str(item.name) == str(taken):
				var discipline := _archetype(item)
				counts[discipline] = int(counts.get(discipline, 0)) + 1
				break
	return counts

# --- House Sets -----------------------------------------------------------
# The piece count is the only source of truth. Two pieces wake the first set
# rule, four replace it with the stronger one. Nothing is stored separately, so
# a load, a sale, or a run retry can never leave a stale set active.
func _set_tier(discipline: String) -> int:
	var owned := int(_archetype_counts().get(discipline, 0))
	if owned >= 4:
		return 4
	if owned >= 2:
		return 2
	return 0

func _set_bonus(discipline: String, tier: int) -> Dictionary:
	var table: Array = SET_BONUSES.get(discipline, [])
	for bonus in table:
		if int(bonus.tier) == tier:
			return bonus
	return {}

func _set_roman(tier: int) -> String:
	return {2: "II", 4: "IV"}.get(tier, "")

# One compact line for the table HUD and build strip. Five active sets would
# overflow a 282px brief, so the readout names the first three and counts the
# rest; the collection screen carries the full sheet.
func _sets_line() -> String:
	var parts: Array[String] = []
	for discipline in DISCIPLINES:
		var tier := _set_tier(discipline)
		if tier >= 2:
			parts.append("%s %s" % [discipline, _set_roman(tier)])
	if parts.is_empty():
		return "SETS  ·  2 OF A KIND UNLOCK A BONUS"
	if parts.size() > 3:
		var extra := parts.size() - 3
		parts = parts.slice(0, 3)
		parts.append("+%d" % extra)
	return "SETS  " + "  ·  ".join(parts)

func _set_active_names() -> String:
	var names: Array[String] = []
	for discipline in DISCIPLINES:
		var tier := _set_tier(discipline)
		if tier >= 2:
			names.append(str(_set_bonus(discipline, tier).name))
	return "  ·  ".join(names)

# What the next piece of this discipline buys. The reward and shop cards use
# this line to turn "+8 bank" into a visible step toward a new rule.
func _set_reward_note(discipline: String, owned: int) -> String:
	if owned >= 4:
		return "SET IV ACTIVE  ·  %s" % str(_set_bonus(discipline, 4).name)
	if owned == 3:
		return "NEXT PIECE  ·  SET IV  %s" % str(_set_bonus(discipline, 4).name)
	if owned == 2:
		return "SET II ACTIVE  ·  2 MORE FOR SET IV"
	if owned == 1:
		return "NEXT PIECE  ·  SET II  %s" % str(_set_bonus(discipline, 2).name)
	return "TAKE 2 MORE FOR SET II"

# The collection sheet lists the count in all five disciplines plus the rules
# currently live, so a player never has to remember a card from three tables
# ago. Three compact rows fit the existing card.
func _set_sheet() -> String:
	var counts := _archetype_counts()
	var first_line: Array[String] = []
	var second_line: Array[String] = []
	for i in DISCIPLINES.size():
		var discipline: String = DISCIPLINES[i]
		var entry := "%s %d/4" % [discipline, int(counts.get(discipline, 0))]
		if i < 3:
			first_line.append(entry)
		else:
			second_line.append(entry)
	var active := _set_active_names()
	if active == "":
		active = "No set bonus yet. Two of a kind wakes one."
	return "%s\n%s\n%s" % ["   ·   ".join(first_line), "   ·   ".join(second_line), active]

func _apply_set_table_start() -> void:
	set_combo_shot_used = false
	var tempo := _set_tier("TEMPO")
	if tempo >= 4:
		shots_remaining += 2
	elif tempo >= 2:
		shots_remaining += 1
	# "Start every table with" means at least one, never an ever-growing pile
	# of guards for a patient player who never spends them.
	if _set_tier("CONTROL") >= 2:
		streak_guard = maxi(streak_guard, 1)
	if _set_tier("CONTROL") >= 4:
		scratch_guard = maxi(scratch_guard, 1)

func _reward_pool() -> Array[Dictionary]:
	# Elites and late run bias to tier 2. A corner-only daily closes the side
	# pockets, so side-pocket pieces would be dead offers on that day.
	var sides_open := _daily_table_rule() != "corner"
	var pool: Array[Dictionary] = []
	for item in reward_catalog:
		if int(item.tier) == 0:
			continue
		if not sides_open and int(item.get("side", 0)) > 0:
			continue
		if encounter_is_elite or encounter_is_boss or run_stage >= 4:
			pool.append(item)
		elif int(item.tier) == 1:
			pool.append(item)
	if pool.size() < 3:
		pool = reward_catalog.filter(func(r: Dictionary) -> bool: return int(r.tier) > 0 and (sides_open or int(r.get("side", 0)) == 0))
	return pool

# Three offers from three different disciplines, so every reward screen is a
# strategic fork (more banking? more control?) rather than three dice rolls.
func _reward_offer_set() -> Array[Dictionary]:
	var pool := _reward_pool()
	var by_discipline := {}
	for item in pool:
		var discipline := _archetype(item)
		if not by_discipline.has(discipline):
			by_discipline[discipline] = []
		by_discipline[discipline].append(item)
	var keys: Array = by_discipline.keys()
	keys.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(run_seed) + run_stage * 977 + int(scenario.get("variant", 0)) * 13
	for i in range(keys.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = keys[i]
		keys[i] = keys[j]
		keys[j] = tmp
	var offers: Array[Dictionary] = []
	for discipline in keys:
		if offers.size() >= 3:
			break
		var bag: Array = by_discipline[discipline]
		offers.append(bag[rng.randi_range(0, bag.size() - 1)])
	# A small pool may not reach three disciplines; fill from what is left.
	var guard := 0
	while offers.size() < 3 and guard < 40:
		guard += 1
		var candidate: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
		var duplicate := false
		for offer in offers:
			if str(offer.id) == str(candidate.id):
				duplicate = true
				break
		if not duplicate:
			offers.append(candidate)
	return offers

func _show_reward() -> void:
	screen = "reward"
	_sfx("reward")
	reward_offers = _reward_offer_set()
	var root := _base_screen("REWARD ROOM", "One build piece, chosen from three. The other two are gone.")
	var terms_cash := int(_contract().get("clear", 0))
	var cleared_line := "%s CLEARED    +%d SCORE" % [str(scenario.name).to_upper(), score]
	if terms_cash > 0:
		cleared_line += "    +%d GRIFTER" % terms_cash
	_add_label(root, Vector2(95, 142), Vector2(1090, 40), cleared_line, 28, MINT, HORIZONTAL_ALIGNMENT_LEFT, true)
	# The par verdict sits on the right of the same band like a scoreboard: the
	# colour, not the words, tells a beat from a miss at a glance.
	if table_par > 0:
		var par_beaten := score >= table_par
		var verdict := "PAR %d  MISSED" % table_par
		if par_beaten:
			verdict = "PAR %d  BEATEN" % table_par
			verdict += "  ·  +1 SHOT NEXT" if gauntlet_active else "  ·  +15 CASH"
		_add_label(root, Vector2(95, 150), Vector2(1090, 24), verdict, 16, MINT if par_beaten else MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	if last_wager_payout > 0:
		# The reward room is where the risk resolves: the stake left the wallet
		# at the break, and this line is the only place the payout is visible as
		# a number rather than a quietly larger cash total.
		_add_label(root, Vector2(95, 168), Vector2(560, 18), "HOUSE WAGER %d WON  ·  +%d CASH" % [last_wager_stake, last_wager_payout], 10, GOLD)
	_add_label(root, Vector2(95, 190), Vector2(1090, 22), "Each offer belongs to a different discipline. Two of a kind unlock a House Set rule.", 12, MUTED)
	var counts := _archetype_counts()
	for i in reward_offers.size():
		var offer: Dictionary = reward_offers[i]
		var discipline := _archetype(offer)
		var owned := int(counts.get(discipline, 0))
		var card := _panel(root, Vector2(105 + i * 370, 232), Vector2(330, 244), PANEL_ALT)
		# Discipline colour is the card's identity: the three offers should read
		# as three different plans before the player parses a word of copy.
		var accent := ColorRect.new()
		accent.position = Vector2(2, 12)
		accent.size = Vector2(3, 220)
		accent.color = _archetype_color(discipline)
		accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(accent)
		# A piece that reaches a set threshold is labelled as one: the choice
		# between a third BANK piece and a first TEMPO piece is the whole point.
		var set_piece := owned == 1 or owned == 3
		_add_label(card, Vector2(20, 18), Vector2(196, 18), "%s  •  %s  •  TIER %d" % [discipline, str(offer.type), int(offer.tier)], 10, _archetype_color(discipline))
		_add_label(card, Vector2(216, 18), Vector2(94, 18), "SET PIECE" if set_piece else ("x%d OWNED" % owned if owned > 0 else "NEW"), 9, GOLD if set_piece else MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
		_add_label(card, Vector2(20, 40), Vector2(290, 40), str(offer.name), 24, GOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
		_add_label(card, Vector2(20, 96), Vector2(290, 44), str(offer.body), 13, Color("#d3e0de"))
		# One line of discipline language teaches the build vocabulary the shop
		# assumes; the next line names the set the piece moves toward.
		_add_label(card, Vector2(20, 144), Vector2(290, 26), _discipline_role(discipline), 11, Color("#9fb6b4"))
		_add_label(card, Vector2(20, 172), Vector2(290, 16), _set_reward_note(discipline, owned), 10, _archetype_color(discipline))
		_add_button(card, Vector2(20, 194), Vector2(290, 34), "TAKE THIS", _choose_reward.bind(i))
	_build_strip(root, Vector2(105, 500), Vector2(1070, 90))
	if gauntlet_active:
		# The reward room is the Grind's heartbeat: show the next gate and the
		# record it is chasing, so the next rack is a decision, not a formality.
		var next_gate := int(ceil(float(run_stage) / 5.0)) * 5
		var grind_strip := _panel(root, Vector2(105, 606), Vector2(1070, 54), PANEL)
		_add_label(grind_strip, Vector2(20, 8), Vector2(400, 16), "TODAY'S LADDER" if grind_daily_active else "THE GRIND", 9, GOLD)
		var gate_note := "NEXT TABLE IS A GATE" if run_stage % 5 == 0 else "NEXT GATE  TABLE %02d" % next_gate
		_add_label(grind_strip, Vector2(20, 26), Vector2(400, 20), gate_note, 12, MINT)
		var best_stage := maxi(grind_daily_best_stage if grind_daily_active else gauntlet_best_stage, run_tables_cleared)
		var best_score := maxi(grind_daily_best_score if grind_daily_active else gauntlet_best_score, run_score)
		var best_note := "TODAY BEST %02d   ·   HIGH %04d" if grind_daily_active else "BEST TABLE %02d   ·   HIGH SCORE %04d"
		var best_text: String = best_note % [best_stage, best_score]
		var pace_note := _grind_pace_label()
		if pace_note != "":
			best_text += "   ·   " + pace_note
		_add_label(grind_strip, Vector2(430, 26), Vector2(620, 20), best_text, 12, Color("#d6e5e1"), HORIZONTAL_ALIGNMENT_RIGHT)
	_focus_first_button(root)

func _choose_reward(choice: int) -> void:
	if choice < 0 or choice >= reward_offers.size():
		return
	_apply_reward(reward_offers[choice])
	if gauntlet_active:
		_start_grind_table()
		return
	_show_map()

func _reward_by_id(reward_id: String) -> Dictionary:
	for item in reward_catalog:
		if str(item.id) == reward_id:
			return item
	return reward_catalog[1]

func _apply_reward(reward: Dictionary) -> void:
	var tiers_before := {}
	for discipline in DISCIPLINES:
		tiers_before[discipline] = _set_tier(discipline)
	bank_bonus += int(reward.get("bank", 0))
	combo_bonus += int(reward.get("combo", 0))
	rail_bonus += int(reward.get("rail", 0))
	streak_guard += int(reward.get("guard", 0))
	scratch_guard += int(reward.get("scratch", 0))
	side_pocket_bonus += int(reward.get("side", 0))
	house_spot_boost += int(reward.get("spot", 0))
	next_shot_modifier += int(reward.get("shots", 0))
	run_cash += int(reward.get("cash", 0))
	if str(reward.type) == "CUE":
		active_cue = str(reward.name)
		active_cue_id = str(reward.id)
	# Every piece belongs to the build, not just cues. Keeping this inside the
	# CUE branch meant chalks and relics changed the numbers while the identity,
	# collection sheet and set counts never saw them.
	collection.append(str(reward.name))
	# Crossing a set threshold is the payoff moment for a focused build. The
	# toast outlives the screen change, so the next table opens with the rule
	# still on screen and the reward already in effect.
	for discipline in DISCIPLINES:
		var tier := _set_tier(discipline)
		if tier > int(tiers_before[discipline]):
			var bonus := _set_bonus(discipline, tier)
			_toast("HOUSE SET  //  %s %s" % [discipline, _set_roman(tier)], "%s IS ACTIVE" % str(bonus.name), _archetype_color(discipline))
			_sfx("reward")

func _reward_price(item: Dictionary) -> int:
	return 70 if int(item.tier) >= 2 else 50

func _roll_shop_offers(roll_seed: int) -> Array[Dictionary]:
	var pool := _reward_pool()
	var rng := RandomNumberGenerator.new()
	rng.seed = roll_seed
	var offers: Array[Dictionary] = []
	var guard := 0
	while offers.size() < 3 and guard < 60:
		guard += 1
		var pick: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
		var dup := false
		for o in offers:
			if str(o.id) == str(pick.id):
				dup = true
				break
		if not dup:
			offers.append(pick)
	return offers

func _show_shop() -> void:
	screen = "shop"
	# Seeded variety: every shop stocks different named pieces, late shops
	# bias to tier 2. Prices follow tier so players can read value at a glance.
	shop_offers = _roll_shop_offers(absi(run_seed) + run_stage * 101 + current_node * 17 + 7)
	shop_prices.clear()
	for o in shop_offers:
		shop_prices.append(_reward_price(o))
	shop_rerolls = 0
	_draw_shop()

func _shop_title() -> String:
	if current_node >= 0 and current_node < map_nodes.size():
		return str(map_nodes[current_node].name).to_upper()
	return "CHALK MARKET"

func _draw_shop() -> void:
	var root := _base_screen(_shop_title(), "Spend cash on one named build piece. Leaving ends the visit.")
	var counts := _archetype_counts()
	for i in shop_offers.size():
		var offer: Dictionary = shop_offers[i]
		var discipline := _archetype(offer)
		var owned := int(counts.get(discipline, 0))
		var price := int(shop_prices[i])
		var affordable := run_cash >= price
		var card := _panel(root, Vector2(105 + i * 370, 188), Vector2(310, 262), PANEL_ALT)
		var accent := ColorRect.new()
		accent.position = Vector2(2, 12)
		accent.size = Vector2(3, 238)
		accent.color = _archetype_color(discipline)
		accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(accent)
		var set_piece := owned == 1 or owned == 3
		_add_label(card, Vector2(20, 16), Vector2(196, 18), "%s  •  %s  •  TIER %d" % [discipline, str(offer.type), int(offer.tier)], 10, _archetype_color(discipline))
		_add_label(card, Vector2(206, 16), Vector2(84, 18), "SET PIECE" if set_piece else ("x%d · %d/4" % [owned, owned] if owned > 0 else "NEW"), 9, GOLD if set_piece else MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
		_add_label(card, Vector2(20, 38), Vector2(270, 40), str(offer.name), 22, GOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
		_add_label(card, Vector2(20, 84), Vector2(270, 48), str(offer.body), 13, Color("#d3e0de"))
		_add_label(card, Vector2(20, 132), Vector2(270, 30), _discipline_role(discipline), 11, Color("#9fb6b4"))
		_add_label(card, Vector2(20, 164), Vector2(270, 28), "%d CASH" % price, 20, GOLD if affordable else MUTED, HORIZONTAL_ALIGNMENT_LEFT, true)
		# A disabled BUY with no reason reads as a broken button; name the gap.
		var button := _add_button(card, Vector2(20, 200), Vector2(270, 38), "BUY" if affordable else "NEED %d MORE" % (price - run_cash), _buy_shop.bind(offer, price))
		button.disabled = not affordable
	_build_strip(root, Vector2(105, 472), Vector2(1070, 90))
	var reroll_cost := 15 + shop_rerolls * 10
	var reroll := _add_button(root, Vector2(320, 580), Vector2(300, 46), "REROLL  %d CASH" % reroll_cost, _reroll_shop.bind(reroll_cost))
	reroll.disabled = run_cash < reroll_cost
	_add_button(root, Vector2(640, 580), Vector2(300, 46), "LEAVE SHOP", _advance_after_stop)
	_add_label(root, Vector2(320, 638), Vector2(620, 20), "Tier 1 costs 50, tier 2 costs 70. Two of a kind unlock a House Set rule.", 11, MUTED)
	_focus_first_button(root)

func _reroll_shop(cost: int) -> void:
	if run_cash < cost:
		return
	run_cash -= cost
	shop_rerolls += 1
	shop_offers = _roll_shop_offers(run_seed + shop_rerolls * 131 + run_stage)
	shop_prices.clear()
	for o in shop_offers:
		shop_prices.append(_reward_price(o))
	_draw_shop()

# Headless-bot helper (not wired to any button): buy the cheapest affordable
# piece so economy playthroughs stay representative; leave empty-handed shops.
func _buy_cheapest_affordable_or_leave() -> void:
	var best := -1
	for i in shop_offers.size():
		if int(shop_prices[i]) <= run_cash and (best < 0 or int(shop_prices[i]) < int(shop_prices[best])):
			best = i
	if best < 0:
		_advance_after_stop()
		return
	_buy_shop(shop_offers[best], shop_prices[best])

func _buy_shop(reward: Dictionary, price: int) -> void:
	if run_cash < price:
		return
	run_cash -= price
	_apply_reward(reward)
	_advance_after_stop()

func _table_par() -> int:
	# Score contracts already state a number, so par sits just above their own
	# ask: beating par means overachieving, not merely clearing. Count contracts
	# have no score ask, so par follows the stage and the danger of the table.
	var target := int(scenario.get("target", 0))
	var par := 0
	if str(scenario.contract_type) in ["score", "combo"]:
		# ceil, not truncation: 1.15 x 100 lands on 114.999… in binary and would
		# post a par below the printed contract.
		par = int(ceil(float(target) * 1.15))
	else:
		par = 42 + run_stage * 9
	if encounter_is_elite:
		par += 12
	if encounter_is_boss:
		par += 25
	return par

func _complete_current_node() -> void:
	if current_node < 0:
		return
	portal.gameplay_stop()
	if gauntlet_active:
		# A Grind clear never touches the map. Bank the record immediately so a
		# portal session that closes mid-run still keeps its deepest table. The
		# daily ladder has its own board and its own same-day payout guard.
		gauntlet_best_stage = maxi(gauntlet_best_stage, run_tables_cleared)
		gauntlet_best_score = maxi(gauntlet_best_score, run_score)
		if table_par > 0 and score >= table_par:
			grind_par_shots += 1
		run_pace_splits.append(run_score)
		_update_grind_pace()
		if grind_daily_active:
			_record_grind_daily_clear()
		_save_meta()
		_sfx("cash")
		run_stage += 1
		_show_reward()
		return
	var par_met := table_par > 0 and score >= table_par
	run_cash += 20 + (15 if encounter_is_elite else 0) + (30 if encounter_is_boss else 0)
	# The Grifter's clear money is part of the table payout, not a separate
	# screen, so it reads beside the par bonus on the reward header.
	run_cash += int(_contract().get("clear", 0))
	# A cleared wager returns the stake at the table's odds. The stake already
	# left run_cash at the break, so this line is the whole payout, not a bonus.
	if table_wager > 0:
		last_wager_stake = table_wager
		last_wager_payout = table_wager * _wager_odds(current_node)
		run_cash += last_wager_payout
		table_wager = 0
	if par_met:
		run_cash += 15
		_toast("THE HOUSE PAYS 15", "PAR %d BEATEN  ·  %d SCORE" % [table_par, score], MINT)
	_sfx("cash")
	if encounter_is_boss:
		bosses_beaten += 1
		run_bosses_beaten += 1
	map_nodes[current_node].done = true
	run_stage += 1
	map_position = current_node
	map_unlocked.clear()
	for edge in map_edges:
		if edge.x == current_node:
			map_unlocked.append(edge.y)
	if current_node == map_nodes.size() - 1:
		_show_victory()
	else:
		_show_reward()

func _advance_after_stop() -> void:
	_complete_current_node()

func _route_summary() -> String:
	var route: Array[String] = []
	for node in map_nodes:
		if node.done:
			route.append(str(node.name))
	return "  →  ".join(route) if not route.is_empty() else "No tables cleared"

func _record_run_end(won: bool) -> void:
	var pays_rep := true
	if daily_active:
		# Only a completed daily counts toward the streak and the day's best;
		# the save slot belongs to the normal run, so leave it alone.
		pays_rep = daily_rep_key != daily_key
		daily_rep_key = daily_key
		_record_daily_result(daily_key, run_score)
	else:
		# The Grind never owned the tour save, so ending it must leave a parked
		# route intact for CONTINUE.
		if not gauntlet_active:
			_clear_run_save()
	if gauntlet_active:
		gauntlet_best_stage = maxi(gauntlet_best_stage, run_tables_cleared)
		gauntlet_best_score = maxi(gauntlet_best_score, run_score)
	else:
		best_score = maxi(best_score, run_score)
	if grind_daily_active:
		_record_grind_daily_end()
		# One positive payout per day: a short attempt does not burn the day's
		# chance, and once a run pays, replaying the same racks cannot farm rep.
		var ladder_payout := mini(int(run_tables_cleared / 3), 5)
		pays_rep = grind_daily_rep_key != grind_daily_key and ladder_payout > 0
		if pays_rep:
			grind_daily_rep_key = grind_daily_key
	# Trophy counters settle with the run. Best-value fields take the max so a
	# poor tour can never lower a milestone already reached. OPENING NIGHT is a
	# tour milestone, so an endless session must not unlock it.
	if not gauntlet_active:
		runs_finished += 1
	# Settling a grudge is worth reputation on top of the win. Declared out
	# here because the payout is added after `last_rep_gain` is computed below.
	var grudge_rep := 0
	if won:
		wins += 1
		if stake == 2:
			stake2_wins += 1
		# A clean House kill: it never bolted a pocket in the final rack.
		if current_node == map_nodes.size() - 1 and simulator.closed_pockets.is_empty():
			house_shutouts += 1
		# THE HOUSE REMEMBERS: a normal tour teaches it one habit. Beating a
		# held grudge settles it for +2 REP and clears the slate; a win without
		# one gives it the next read. Dailies and endless modes are exhibition
		# play and never write the House's book.
		if not daily_active and not gauntlet_active:
			if grudge_active and house_grudge != "":
				summary_grudge_settled = true
				summary_grudge_name = str(_grudge().get("name", ""))
				grudges_settled += 1
				house_grudge = ""
				grudge_rep = 2
			else:
				var read := _read_house_grudge()
				if read != "":
					house_grudge = read
					summary_grudge_name = str(HOUSE_GRUDGES[read].name)
	tables_cleared += maxi(run_tables_cleared, 0)
	# Route trophies measure a tour, so a deep endless run must not unlock them.
	if not gauntlet_active:
		best_tables = maxi(best_tables, run_tables_cleared)
	best_shot_ever = maxi(best_shot_ever, run_best_shot)
	best_streak_ever = maxi(best_streak_ever, run_best_streak)
	best_build = maxi(best_build, collection.size())
	# Set milestones are settled from the run's final build, so a set that was
	# broken by leaving mid-rack never claims a career milestone.
	var run_set_tier := 0
	var run_set_count := 0
	for discipline in DISCIPLINES:
		var tier := _set_tier(discipline)
		run_set_tier = maxi(run_set_tier, tier)
		if tier >= 2:
			run_set_count += 1
	best_set_tier = maxi(best_set_tier, run_set_tier)
	best_sets_in_run = maxi(best_sets_in_run, run_set_count)
	best_bosses_in_run = maxi(best_bosses_in_run, run_bosses_beaten)
	best_daily_streak = maxi(best_daily_streak, daily_streak)
	if daily_active:
		dailies_played += 1
	last_rep_gain = 0
	if pays_rep:
		if gauntlet_active:
			# Endless runs pay for depth, capped and never for an instant quit, so
			# restarting the mode cannot become the fastest reputation farm.
			last_rep_gain = mini(int(run_tables_cleared / 3), 5)
		else:
			last_rep_gain = (2 + stake) if won else 1
		last_rep_gain += grudge_rep
		reputation += last_rep_gain
	var run_mode := "tour"
	if grind_daily_active:
		run_mode = "daily_grind"
	elif gauntlet_active:
		run_mode = "grind"
	run_log.append({"seed": run_seed, "score": run_score, "tables": run_tables_cleared, "won": won, "stake": stake, "mode": run_mode})
	while run_log.size() > 8:
		run_log.pop_front()
	_save_meta()

func _show_defeat() -> void:
	# A lost table keeps the House's stake. Carry that loss onto the summary so
	# the missing cash has a named cause instead of reading like a bug.
	last_wager_payout = 0
	last_wager_stake = table_wager
	table_wager = 0
	_show_run_summary(false)

# The one decision that decides whether a portal session survives a bad table.
# Nothing is recorded here: the run is only lost when the player ends it.
func _show_last_call() -> void:
	screen = "last_call"
	portal.gameplay_stop()
	_sfx("boss")
	var root := _base_screen("LAST CALL", "The House always collects. Tonight it will take a marker instead.", false)
	var table_name := "THIS TABLE"
	if not scenario.is_empty():
		table_name = str(scenario.get("name", table_name)).to_upper()
	_add_label(root, Vector2(140, 132), Vector2(1000, 54), "ONE FAVOR LEFT", 46, GOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
	var card := _panel(root, Vector2(140, 206), Vector2(1000, 252), PANEL_ALT)
	_add_label(card, Vector2(30, 22), Vector2(940, 18), "SHOTS EXHAUSTED  ·  %s" % table_name, 11, RED)
	_add_label(card, Vector2(30, 48), Vector2(940, 64), "Call in the favor and this rack is reset from its opening ball with the full shot budget. Score from this attempt is lost; the tour continues.", 15, Color("#e4efeb"))
	_add_label(card, Vector2(30, 122), Vector2(940, 20), "ONE PER TOUR  ·  NEVER RETURNS  ·  THE HOUSE DOES NOT NEGOTIATE TWICE", 11, GOLD)
	_add_label(card, Vector2(30, 160), Vector2(940, 44), "If you walk away, this run is over. Reputation already earned still banks, but the route and its build are gone.", 13, MUTED)
	var use := _add_button(card, Vector2(30, 202), Vector2(300, 40), "CALL IN THE FAVOR", _call_in_favor, true)
	use.grab_focus()
	_add_button(card, Vector2(346, 202), Vector2(240, 40), "END THE RUN", _show_defeat)
	_add_label(root, Vector2(140, 512), Vector2(1000, 22), "The favor is offered on any lost table, including a boss. A win still needs the contract.", 11, MUTED)

func _call_in_favor() -> void:
	if not favor_available:
		return
	favor_available = false
	_sfx("reward")
	_toast("FAVOR CALLED", "The rack is reset. Spend it well.", GOLD)
	var is_boss := current_node >= 0 and current_node < map_nodes.size() and str(map_nodes[current_node].type) == "boss"
	_start_encounter(is_boss)

func _show_event() -> void:
	screen = "event"
	var deal_cash := 25 + (10 if run_stage >= 4 else 0)
	var double_cash := 60 + (20 if run_stage >= 4 else 0)
	var deck := posmod(absi(run_seed + current_node * 37 + run_stage * 11), 3)
	if deck == 0:
		event_choices = [
			{"title": "TAKE THE DEAL", "body": "+%d cash, -1 shot next table." % deal_cash, "cash": deal_cash, "shots": -1, "tag": "Back Room Debt"},
			{"title": "DOUBLE OR NOTHING", "body": "+%d cash, -2 shots next table." % double_cash, "cash": double_cash, "shots": -2, "tag": "Double Debt"},
			{"title": "WALK AWAY", "body": "No deal. +1 shot next table.", "cash": 0, "shots": 1, "tag": "Clean Conscience"},
		]
	elif deck == 1:
		event_choices = [
			{"title": "HOUSE CUT", "body": "+%d cash now, streak resets next table." % (deal_cash + 10), "cash": deal_cash + 10, "shots": 0, "tag": "House Cut"},
			{"title": "STAKED FELT", "body": "+%d cash, -1 shot next table." % (deal_cash + 15), "cash": deal_cash + 15, "shots": -1, "tag": "Staked Felt"},
			{"title": "STEADY OUT", "body": "No cash. +1 shot and a clean slate next table.", "cash": 0, "shots": 1, "tag": "Steady Out"},
		]
	else:
		event_choices = [
			{"title": "SIDE BET", "body": "+%d cash, side pockets pay less next table." % (deal_cash + 5), "cash": deal_cash + 5, "shots": 0, "tag": "Side Bet"},
			{"title": "ALL IN", "body": "+%d cash, -2 shots next table." % (double_cash + 10), "cash": double_cash + 10, "shots": -2, "tag": "All In"},
			{"title": "FOLD", "body": "No deal. +1 shot next table.", "cash": 0, "shots": 1, "tag": "Folded Clean"},
		]
	var event_title := "THE BACK ROOM"
	if current_node >= 0 and current_node < map_nodes.size():
		event_title = str(map_nodes[current_node].name).to_upper()
	var root := _base_screen(event_title, "A quiet table, a dangerous offer, and no perfect answer.")
	for i in event_choices.size():
		var c: Dictionary = event_choices[i]
		var card := _panel(root, Vector2(105 + i * 370, 220), Vector2(320, 210), PANEL_ALT)
		_add_label(card, Vector2(20, 18), Vector2(280, 40), str(c.title), 22, GOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
		_add_label(card, Vector2(20, 74), Vector2(280, 55), str(c.body), 14, Color("#c5d6d3"))
		_add_button(card, Vector2(20, 148), Vector2(280, 40), "CHOOSE", _take_event_deal.bind(i))
	_add_label(root, Vector2(105, 452), Vector2(1070, 40), "Cash is immediate. The shot penalty lands on your next table.", 13, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_build_strip(root, Vector2(105, 500), Vector2(1070, 90))
	_focus_first_button(root)

func _take_event_deal(choice: int) -> void:
	if choice < 0 or choice >= event_choices.size():
		return
	var c: Dictionary = event_choices[choice]
	run_cash += int(c.cash)
	next_shot_modifier += int(c.shots)
	collection.append(str(c.tag))
	_advance_after_stop()

func _open_collection_from_map() -> void:
	menu_return_screen = "map"
	_show_collection()

func _open_settings_from_map() -> void:
	menu_return_screen = "map"
	_show_settings()

func _show_collection() -> void:
	# From victory/defeat, BACK should return to the summary, not the map.
	if screen == "victory" or screen == "defeat":
		menu_return_screen = screen
	screen = "collection"
	var back_target: Callable = _show_map if menu_return_screen == "map" else _show_title
	if menu_return_screen == "victory":
		back_target = func() -> void: _show_run_summary(true, false)
	elif menu_return_screen == "defeat":
		back_target = func() -> void: _show_run_summary(false, false)
	var root := _base_screen("RUN BUILD", "What this route has earned, and where it has been.", false)
	_add_button(root, Vector2(32, 116), Vector2(120, 40), "BACK", back_target)
	var counts := _archetype_counts()
	var disciplines: Array[String] = []
	for discipline in ["BANK", "COMBO", "RAIL", "CONTROL", "TEMPO"]:
		if int(counts.get(discipline, 0)) > 0:
			disciplines.append("%s x%d" % [discipline, int(counts[discipline])])
	var cards := [
		{"title": "ACTIVE CUE", "body": "%s\n%s" % [active_cue, _reward_by_id(active_cue_id).body]},
		{"title": "DISCIPLINES  ·  HOUSE SETS", "body": _set_sheet() if not collection.is_empty() else "No pieces yet.\nClear a table to earn one.\nTwo of a kind unlock a set bonus."},
		{"title": "PROTECTION", "body": _guard_line()},
	]
	for i in cards.size():
		var card := _panel(root, Vector2(70 + i * 390, 168), Vector2(350, 116), PANEL_ALT)
		_add_label(card, Vector2(20, 14), Vector2(310, 18), str(cards[i].title), 10, GOLD)
		_add_label(card, Vector2(20, 38), Vector2(310, 68), str(cards[i].body), 13, Color("#d6e5e1"))
	var route_card := _panel(root, Vector2(70, 300), Vector2(1110, 80), PANEL)
	_add_label(route_card, Vector2(22, 12), Vector2(1060, 18), "ROUTE", 10, GOLD)
	_add_label(route_card, Vector2(22, 36), Vector2(1060, 34), _route_summary(), 13, Color("#d6e5e1"))
	var item_card := _panel(root, Vector2(70, 396), Vector2(1110, 110), PANEL)
	_add_label(item_card, Vector2(22, 12), Vector2(1060, 18), "ACQUIRED THIS RUN", 10, GOLD)
	_add_label(item_card, Vector2(22, 38), Vector2(1060, 62), ", ".join(collection) if not collection.is_empty() else "Nothing yet — rewards, shop pieces and event tags collect here.", 13, Color("#d6e5e1"))
	_add_label(root, Vector2(70, 524), Vector2(1110, 24), "CASH  %03d    •    TABLES CLEARED  %d    •    SCORE  %04d    •    CODEX  %d/%d tables scouted" % [run_cash, run_tables_cleared, run_score, codex_seen.size(), library.scenarios.size()], 12, MINT)
	_add_label(root, Vector2(70, 556), Vector2(1110, 18), "PAST RUNS", 10, GOLD)
	if run_log.is_empty():
		_add_label(root, Vector2(70, 578), Vector2(1110, 20), "No past runs yet.", 12, MUTED)
	else:
		# Newest first, four per row: a wrapped sentence of eight runs was unreadable.
		# Result and score are separate labels so the score column stays aligned
		# whether the run reads WIN or LOSS.
		for i in run_log.size():
			var r: Dictionary = run_log[run_log.size() - 1 - i]
			var cell := Vector2(70.0 + float(i % 4) * 270.0, 578.0 + float(i / 4) * 40.0)
			var won := bool(r.get("won", false))
			var mode := str(r.get("mode", "tour"))
			var grind := mode in ["grind", "daily_grind"]
			var ladder := mode == "daily_grind"
			var tone: Color = MINT if won else (GOLD if grind else RED)
			var result := "LOSS"
			if won:
				result = "WIN"
			elif ladder:
				result = "LADDER"
			elif grind:
				result = "GRIND"
			_add_label(root, cell, Vector2(56, 16), result, 12, tone)
			_add_label(root, cell + Vector2(58, 0), Vector2(120, 16), "%04d" % int(r.get("score", 0)), 12, Color("#e6f0ec"))
			var detail := "%d tables   •   stake %d" % [int(r.get("tables", 0)), int(r.get("stake", 0))]
			if ladder:
				detail = "%d tables   •   daily" % int(r.get("tables", 0))
			elif grind:
				detail = "%d tables   •   endless" % int(r.get("tables", 0))
			_add_label(root, cell + Vector2(0, 16), Vector2(250, 16), detail, 10, MUTED)
	_focus_first_button(root)

func _show_run_summary(won: bool, record := true) -> void:
	var trophy_rep := 0
	if record:
		_record_run_end(won)
		portal.gameplay_stop()
		_sfx("victory" if won else "defeat")
		if won:
			portal.happy_time()
		# Trophy reputation is earned by this tour, so the summary's reputation
		# cell has to include it instead of revealing it later on another screen.
		trophy_rep = _check_trophies()
	screen = "victory" if won else "defeat"
	menu_return_screen = screen
	var headline := "A CLEAN BREAK" if won else "THE HOUSE WINS THIS TOUR"
	var subtitle := "The House is beaten. Here is what this route built." if won else "The route closes here. Learn the table, then build a better line."
	if gauntlet_active:
		var depth := maxi(run_tables_cleared, 0)
		var grind_name := "TODAY'S LADDER" if grind_daily_active else "THE GRIND"
		if depth > 0:
			headline = "%s  ·  %02d TABLES DEEP" % [grind_name, depth]
		else:
			headline = "%s  ·  NO TABLES CLEARED" % grind_name
		subtitle = "The House keeps the table. Take a better line back into the racks."
		if grind_daily_active:
			subtitle = "Same racks for everyone today. Your best is on the board."
	var root := _base_screen("RUN SUMMARY", subtitle, false)
	_add_label(root, Vector2(140, 128), Vector2(1000, 54), headline, 44, GOLD if won else RED, HORIZONTAL_ALIGNMENT_LEFT, true)
	var rep_gain := last_rep_gain + trophy_rep
	var stats := _panel(root, Vector2(140, 196), Vector2(1000, 172), PANEL)
	_stat_cell(stats, 26.0, 18.0, "RUN SCORE", "%04d" % run_score)
	_stat_cell(stats, 348.0, 18.0, "TABLES CLEARED", "%d" % run_tables_cleared)
	_stat_cell(stats, 670.0, 18.0, "BEST STREAK", "x%d" % run_best_streak)
	_stat_cell(stats, 26.0, 92.0, "BEST SHOT", "%d" % run_best_shot)
	# Leftover cash does not persist; calling it "banked" promised a payout the
	# next run never paid. It is spending money for the current route only. The
	# Grind has no shops, so its cell shows the record instead.
	if gauntlet_active:
		var best_table := maxi(grind_daily_best_stage if grind_daily_active else gauntlet_best_stage, run_tables_cleared)
		_stat_cell(stats, 348.0, 92.0, "TODAY'S BEST" if grind_daily_active else "BEST TABLE", "%02d" % best_table)
	else:
		_stat_cell(stats, 348.0, 92.0, "CASH LEFT", "%03d" % run_cash)
	# "+0" rather than an em dash: the display font has no dash glyph, and a
	# same-day daily replay honestly paid nothing.
	_stat_cell(stats, 670.0, 92.0, "REPUTATION", "+%d" % rep_gain)
	var route_card := _panel(root, Vector2(140, 388), Vector2(1000, 116), PANEL)
	var route_label := "ROUTE"
	if grind_daily_active:
		route_label = "TODAY'S LADDER"
	elif gauntlet_active:
		route_label = "THE GRIND"
	_add_label(route_card, Vector2(24, 16), Vector2(950, 18), route_label, 10, GOLD)
	if gauntlet_active:
		var best_stage := maxi(grind_daily_best_stage if grind_daily_active else gauntlet_best_stage, run_tables_cleared)
		var best_score := maxi(grind_daily_best_score if grind_daily_active else gauntlet_best_score, run_score)
		var best_prefix := "TODAY BEST" if grind_daily_active else "BEST TABLE"
		_add_label(route_card, Vector2(24, 40), Vector2(950, 44), "%s %02d   ·   HIGH SCORE %04d   ·   EVERY FIFTH RACK A GATE" % [best_prefix, best_stage, best_score], 14, Color("#d6e5e1"))
	else:
		_add_label(route_card, Vector2(24, 40), Vector2(950, 44), _route_summary(), 14, Color("#d6e5e1"))
	var footer_line := "SEED %d  —  replay it to learn the same tables." % run_seed
	if gauntlet_active:
		footer_line = "ENDLESS RACKS  ·  NO FAVOR  ·  ONE PIECE PER CLEAR  ·  SEED %d" % run_seed
	if grind_daily_active:
		var ladder_streak := _grind_daily_streak_now()
		var streak_note := "NO LADDER CLEAR YET"
		if ladder_streak > 0:
			streak_note = "%d-DAY STREAK" % ladder_streak
		elif run_tables_cleared > 0:
			streak_note = "STREAK STARTS TODAY"
		footer_line = "DAILY LADDER %s  ·  %s  ·  ONE PAYOUT PER DAY" % [_pretty_date(grind_daily_key), streak_note]
	if daily_active:
		var twist := _daily_twist(daily_key)
		footer_line = "DAILY %s  ·  %s  ·  %d-DAY STREAK  ·  TODAY'S BEST %04d" % [_pretty_date(daily_key), str(twist.name), daily_streak, daily_best]
	if gauntlet_active:
		var pace_note := _grind_pace_label()
		if pace_note != "":
			footer_line += "  ·  " + pace_note
	if not favor_available and not gauntlet_active:
		footer_line += "  ·  FAVOR SPENT"
	if last_wager_payout > 0:
		footer_line += "  ·  WAGER %d WON  ·  +%d CASH" % [last_wager_stake, last_wager_payout]
	elif last_wager_stake > 0:
		footer_line += "  ·  WAGER %d LOST" % last_wager_stake
	# The finale's result is the run's story. Name it once, on the line that
	# already carries the seed and the tour's other loose ends.
	if summary_grudge_settled:
		footer_line += "  ·  GRUDGE SETTLED  ·  +2 REP"
	elif won and summary_grudge_name != "":
		footer_line += "  ·  IT HAS YOUR NUMBER  ·  " + summary_grudge_name
	_add_label(route_card, Vector2(24, 88), Vector2(950, 18), footer_line, 11, MUTED)
	if gauntlet_active:
		if grind_daily_active:
			_add_button(root, Vector2(140, 534), Vector2(230, 54), "LADDER AGAIN", _start_grind_daily, true)
			_add_button(root, Vector2(384, 534), Vector2(190, 54), "FREE GRIND", _start_gauntlet)
			_add_button(root, Vector2(588, 534), Vector2(190, 54), "COPY RESULT", _copy_run_result)
			_add_button(root, Vector2(792, 534), Vector2(140, 54), "TITLE", _show_title)
		else:
			_add_button(root, Vector2(140, 534), Vector2(240, 54), "GRIND AGAIN", _start_gauntlet, true)
			_add_button(root, Vector2(394, 534), Vector2(190, 54), "TODAY'S LADDER", _start_grind_daily)
			_add_button(root, Vector2(598, 534), Vector2(190, 54), "COPY RESULT", _copy_run_result)
			_add_button(root, Vector2(802, 534), Vector2(140, 54), "TITLE", _show_title)
	else:
		var primary := "START NEW RUN" if won else "TRY NEW ROUTE"
		_add_button(root, Vector2(140, 534), Vector2(240, 54), primary, _show_contract_select, true)
		_add_button(root, Vector2(394, 534), Vector2(190, 54), "RETRY SEED", _retry_seed)
		_add_button(root, Vector2(598, 534), Vector2(190, 54), "VIEW RUN BUILD", _show_collection)
		_add_button(root, Vector2(802, 534), Vector2(180, 54), "COPY RESULT", _copy_run_result)
		_add_button(root, Vector2(996, 534), Vector2(140, 54), "TITLE", _show_title)
	# Reputation just changed; point the player at the only thing it buys.
	var next_cost := _next_vault_cost()
	if next_cost < 0:
		_add_label(root, Vector2(140, 602), Vector2(1000, 22), "VAULT COMPLETE  ·  EVERY PERMANENT UPGRADE OWNED", 12, MINT)
	elif reputation >= next_cost:
		_add_button(root, Vector2(140, 596), Vector2(300, 36), "SPEND REP IN THE VAULT", _show_vault, false, GOLD)
	else:
		_add_label(root, Vector2(140, 602), Vector2(1000, 22), "NEXT VAULT PIECE  %d REP  ·  YOU HAVE %d" % [next_cost, reputation], 12, MUTED)
	# The post-run screen is where a portal session either ends or starts again.
	# Name the nearest unearned milestone so the next run has a purpose.
	var goal := _next_trophy()
	var goal_card := _panel(root, Vector2(140, 642), Vector2(1000, 54), PANEL_ALT)
	_add_label(goal_card, Vector2(20, 8), Vector2(300, 16), "NEXT MILESTONE", 9, GOLD)
	if goal.is_empty():
		_add_label(goal_card, Vector2(20, 25), Vector2(960, 20), "SHELF COMPLETE — every milestone earned. The rest is mastery.", 12, MINT)
	else:
		var goal_target := _trophy_target(goal)
		var goal_have := mini(_trophy_stat(str(goal.stat)), goal_target)
		_add_label(goal_card, Vector2(20, 25), Vector2(720, 20), "%s  ·  %s" % [str(goal.name), str(goal.body)], 12, Color("#e4efeb"))
		_add_label(goal_card, Vector2(760, 25), Vector2(220, 20), "%d / %d" % [goal_have, goal_target], 12, MINT, HORIZONTAL_ALIGNMENT_RIGHT)
	_focus_first_button(root)

func _run_share_text() -> String:
	var tables := maxi(run_tables_cleared, 0)
	if grind_daily_active:
		return "RACK & RUIN · %s DAILY LADDER — %d score, %d tables deep. Same racks for everyone." % [_pretty_date(grind_daily_key), run_score, tables]
	if gauntlet_active:
		return "RACK & RUIN · THE GRIND — %d score, %d tables deep. Best table %d." % [run_score, tables, maxi(gauntlet_best_stage, tables)]
	if daily_active:
		return "RACK & RUIN · %s DAILY — %d score, %d tables, %d-day streak. Same tour for everyone." % [_pretty_date(daily_key), run_score, tables, daily_streak]
	var line := "RACK & RUIN · seed %d — %d score, %d tables, best streak x%d." % [run_seed, run_score, tables, run_best_streak]
	if screen == "victory":
		line += " The House fell."
	# The code is the part a friend can act on. Keeping it at the end means a
	# pasted result reads as a story first and a challenge second.
	line += "  ·  CODE " + _challenge_code()
	return line

func _copy_run_result() -> void:
	if portal.copy_text(_run_share_text()):
		_sfx("click")
		_toast("RESULT COPIED", "The code at the end opens this route on the title.", MINT)
	else:
		_toast("COPY UNAVAILABLE", "This page blocks clipboard access.", RED)

func _stat_cell(card: Control, x: float, y: float, label: String, value: String) -> void:
	# Label above value: the old side-by-side cells put one row's number right
	# against the next row's label, so "0000 BEST SHOT" read as a single stat.
	_add_label(card, Vector2(x, y), Vector2(300, 18), label, 10, MUTED)
	_add_label(card, Vector2(x, y + 16), Vector2(300, 34), value, 30, Color("#eef7f2"), HORIZONTAL_ALIGNMENT_LEFT, true)

func _show_settings() -> void:
	screen = "settings"
	var root := _base_screen("SETTINGS", "Presentation options only. None of them change the physics.", false)
	var back_target := _show_map if menu_return_screen == "map" else _show_title
	_add_button(root, Vector2(32, 116), Vector2(120, 40), "BACK", back_target)

	var access := _panel(root, Vector2(70, 176), Vector2(560, 300), PANEL)
	_add_label(access, Vector2(26, 20), Vector2(500, 20), "ACCESSIBILITY", 11, GOLD)
	_setting_row(access, 54.0, "High contrast text", "ON" if settings_high_contrast else "OFF", _toggle_contrast)
	_setting_row(access, 106.0, "Reduced flash", "ON" if settings_reduced_flash else "OFF", _toggle_flash)
	_setting_row(access, 158.0, "Screen shake", "OFF" if settings_no_shake else "ON", _toggle_shake)
	_setting_row(access, 210.0, "Aim guide", "LONG" if settings_guide > 0.9 else "SHORT", _toggle_guide)
	_add_label(access, Vector2(26, 262), Vector2(500, 22), "Shake, flash and guide length are presentation only.", 10, MUTED)

	var feel := _panel(root, Vector2(660, 176), Vector2(560, 300), PANEL)
	_add_label(feel, Vector2(26, 20), Vector2(500, 20), "PACE & SOUND", 11, GOLD)
	_setting_row(feel, 50.0, "Fast resolution", "ON" if settings_fast_resolve else "OFF", _toggle_fast)
	_setting_row(feel, 96.0, "House cam replays", "ON" if settings_house_cam else "OFF", _toggle_house_cam)
	_setting_row(feel, 142.0, "Volume", "%d%%" % int(settings_volume * 100), _cycle_volume)
	# The card had a third of its height empty; the local record is the most
	# useful thing to put there, and it rewards a returning player with proof
	# that the last session moved something.
	var record_rule := ColorRect.new()
	record_rule.position = Vector2(26, 184)
	record_rule.size = Vector2(508, 1)
	record_rule.color = Color("#33505a")
	feel.add_child(record_rule)
	_add_label(feel, Vector2(26, 194), Vector2(500, 18), "YOUR RECORD", 10, GOLD)
	_add_label(feel, Vector2(26, 216), Vector2(500, 20), "BEST %04d    RUNS %d    REP %d" % [best_score, total_runs, reputation], 12, Color("#e4efeb"))
	var daily_record := "DAILY  no streak yet"
	if daily_streak > 0:
		daily_record = "DAILY  streak x%d" % daily_streak
		if daily_best_key == _today_key():
			daily_record += "    today %04d" % daily_best
	_add_label(feel, Vector2(26, 238), Vector2(500, 20), daily_record, 12, MINT)
	_add_label(feel, Vector2(26, 268), Vector2(508, 22), "Fast resolve settles balls instantly. House cam is presentation only.", 10, MUTED)

	var controls := _panel(root, Vector2(70, 488), Vector2(1110, 190), PANEL)
	_add_label(controls, Vector2(26, 16), Vector2(1050, 18), "CONTROLS", 10, GOLD)
	var entries := [
		["AIM", "Pointer, drag, or stick"],
		["POWER", "Drag · W/S · wheel · pad X/Y"],
		["SPIN", "Spin pad · A/D · Q/E · pad B"],
		["FIRE", "Space · Enter · pad A · FIRE"],
		["HOUSE CALL", "F · HEAT button when full"],
		["PAUSE", "P · Start · II"],
		["RETRY TABLE", "R"],
		["SOUND", "M"],
		["LEAVE TABLE", "Esc"],
	]
	for i in entries.size():
		var x := 26.0 + float(i % 3) * 358.0
		var y := 46.0 + float(i / 3) * 48.0
		_add_label(controls, Vector2(x, y), Vector2(250, 14), str(entries[i][0]), 9, MUTED)
		_add_label(controls, Vector2(x, y + 17), Vector2(250, 32), str(entries[i][1]), 12, Color("#d6e5e1"))
	_focus_first_button(root)

# --- THE VAULT -------------------------------------------------------------
# Reputation is the only currency that survives a run, so it buys permanence.
# Unlocks live in the meta file and are applied when a normal run starts; a
# daily tour ignores them so the shared table stays fair.

func _has_unlock(unlock_id: String) -> bool:
	return unlocks.has(unlock_id)

func _vault_item(unlock_id: String) -> Dictionary:
	for item in vault_items:
		if str(item.id) == unlock_id:
			return item
	return {}

func _next_vault_cost() -> int:
	# Cheapest unowned piece, or -1 when the vault is complete.
	var cheapest := -1
	for item in vault_items:
		if _has_unlock(str(item.id)):
			continue
		var cost := int(item.cost)
		if cheapest < 0 or cost < cheapest:
			cheapest = cost
	return cheapest

func _buy_unlock(unlock_id: String) -> void:
	var item := _vault_item(unlock_id)
	if item.is_empty() or _has_unlock(unlock_id) or reputation < int(item.cost):
		return
	reputation -= int(item.cost)
	unlocks.append(unlock_id)
	_save_meta()
	_sfx("reward")
	_show_vault()

func _show_vault() -> void:
	# Remember where the vault was opened from, so leaving after a purchase
	# returns to the run summary instead of dumping the player on the title.
	if screen != "vault":
		vault_return = screen
	screen = "vault"
	var back_target: Callable = _show_title
	if vault_return == "map":
		back_target = _show_map
	elif vault_return == "victory":
		back_target = func() -> void: _show_run_summary(true, false)
	elif vault_return == "defeat":
		back_target = func() -> void: _show_run_summary(false, false)
	var root := _base_screen("THE VAULT", "Reputation buys upgrades that last. They apply to every new tour, never to dailies.", false)
	var back_btn := _add_button(root, Vector2(32, 116), Vector2(120, 40), "BACK", back_target)
	_add_label(root, Vector2(600, 112), Vector2(580, 40), "%d REPUTATION" % reputation, 28, GOLD, HORIZONTAL_ALIGNMENT_RIGHT, true)
	var focus_button: Button = null
	for i in vault_items.size():
		var item: Dictionary = vault_items[i]
		var owned := _has_unlock(str(item.id))
		var cost := int(item.cost)
		var affordable := reputation >= cost
		var card := _panel(root, Vector2(70 + i * 390, 190), Vector2(350, 254), PANEL_ALT)
		_add_label(card, Vector2(24, 18), Vector2(302, 18), "PERMANENT UPGRADE  ·  TIER %d" % (i + 1), 10, GOLD)
		_add_label(card, Vector2(24, 42), Vector2(302, 30), str(item.name), 20, Color("#f1f6f1"), HORIZONTAL_ALIGNMENT_LEFT, true)
		_add_label(card, Vector2(24, 82), Vector2(302, 84), str(item.body), 13, Color("#d6e5e1"))
		var status := "%d REP" % cost
		var status_tone := GOLD if affordable else MUTED
		if owned:
			status = "INSTALLED"
			status_tone = MINT
		_add_label(card, Vector2(24, 172), Vector2(302, 24), status, 15, status_tone, HORIZONTAL_ALIGNMENT_LEFT, true)
		if owned:
			var owned_btn := _add_button(card, Vector2(24, 202), Vector2(302, 40), "OWNED", func() -> void: pass)
			owned_btn.disabled = true
		elif affordable:
			var unlock_btn := _add_button(card, Vector2(24, 202), Vector2(302, 40), "UNLOCK", _buy_unlock.bind(str(item.id)), true)
			if focus_button == null:
				focus_button = unlock_btn
		else:
			var locked_btn := _add_button(card, Vector2(24, 202), Vector2(302, 40), "NEED %d REP" % (cost - reputation), func() -> void: pass)
			locked_btn.disabled = true
	# Progress toward the cheapest unowned piece: the reason to play one more
	# tour, stated before the player leaves the screen.
	var next_cost := _next_vault_cost()
	var next_name := ""
	for item in vault_items:
		if not _has_unlock(str(item.id)) and int(item.cost) == next_cost:
			next_name = str(item.name)
			break
	var progress := _panel(root, Vector2(70, 460), Vector2(1140, 66), PANEL)
	if next_cost < 0:
		_add_label(progress, Vector2(24, 12), Vector2(700, 18), "VAULT COMPLETE", 10, GOLD)
		_add_label(progress, Vector2(24, 32), Vector2(800, 22), "Every permanent upgrade is installed on this browser.", 13, MINT)
	else:
		_add_label(progress, Vector2(24, 12), Vector2(700, 18), "NEXT PIECE", 10, GOLD)
		_add_label(progress, Vector2(24, 32), Vector2(700, 22), next_name, 15, Color("#f1f6f1"), HORIZONTAL_ALIGNMENT_LEFT, true)
		_add_label(progress, Vector2(760, 12), Vector2(356, 18), "%d / %d REP" % [mini(reputation, next_cost), next_cost], 11, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
		var track := ColorRect.new()
		track.position = Vector2(760, 38)
		track.size = Vector2(356, 8)
		track.color = Color("#2c4752")
		progress.add_child(track)
		var fill := ColorRect.new()
		fill.position = Vector2(760, 38)
		fill.size = Vector2(356.0 * clampf(float(reputation) / float(next_cost), 0.0, 1.0), 8)
		fill.color = GOLD
		progress.add_child(fill)
	var foot := _panel(root, Vector2(70, 540), Vector2(1140, 110), PANEL)
	_add_label(foot, Vector2(24, 12), Vector2(1092, 18), "HOW REPUTATION WORKS", 10, GOLD)
	_add_label(foot, Vector2(24, 34), Vector2(1092, 40), "Every finished tour pays +1 REP — +2 on a win, +1 more at Stake 1 and Stake 2. Dailies pay reputation too, but upgrades never apply inside a daily: everyone plays the same table there.", 13, Color("#d6e5e1"))
	_add_label(foot, Vector2(24, 78), Vector2(1092, 24), "Unlocks are read when a new run starts. An in-progress run keeps the loadout it began with.", 11, MUTED)
	if focus_button != null:
		focus_button.grab_focus()
	else:
		back_btn.grab_focus()

# --- THE CUE CASE ---------------------------------------------------------
# A trophy is a number on a shelf; a finish is the same trophy in your hands on
# every shot. The case is deliberately not a shop: nothing here can be bought,
# so no player can buy an advantage and no save can be stranded by a price.
func _show_cue_case() -> void:
	screen = "cue_case"
	var root := _base_screen("THE CUE CASE", "Six sticks, six stories. Finishes are earned by trophies — the table is never tilted.", false)
	var back_btn := _add_button(root, Vector2(32, 116), Vector2(120, 40), "BACK", _show_title)
	var owned_count := 0
	for finish in CUE_FINISHES:
		if _cue_unlocked(str(finish.id)):
			owned_count += 1
	_add_label(root, Vector2(720, 114), Vector2(460, 30), "%d / %d IN THE CASE" % [owned_count, CUE_FINISHES.size()], 16, GOLD, HORIZONTAL_ALIGNMENT_RIGHT, true)
	var focus_button: Button = null
	for i in CUE_FINISHES.size():
		var finish: Dictionary = CUE_FINISHES[i]
		var finish_id := str(finish.id)
		var owned := _cue_unlocked(finish_id)
		var equipped := cue_finish == finish_id
		var col := i % 3
		var row := i / 3
		var card := _panel(root, Vector2(70 + col * 390, 164 + row * 214), Vector2(350, 196), PANEL_ALT if equipped else PANEL)
		if equipped:
			var edge := ColorRect.new()
			edge.position = Vector2(2, 14)
			edge.size = Vector2(3, 168)
			edge.color = GOLD
			edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(edge)
		var art := CueArt.new()
		art.finish = finish
		art.position = Vector2(24, 10)
		art.size = Vector2(302, 48)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(art)
		_add_label(card, Vector2(24, 62), Vector2(302, 26), str(finish.name), 18, Color("#f1f6f1") if owned else Color("#94a9ab"), HORIZONTAL_ALIGNMENT_LEFT, true)
		_add_label(card, Vector2(24, 90), Vector2(302, 20), str(finish.note), 11, MUTED)
		var status := ""
		var tone := MUTED
		if equipped:
			status = "IN HAND"
			tone = GOLD
		elif owned:
			status = "UNLOCKED"
			tone = MINT
		else:
			status = _cue_finish_progress(finish)
			tone = Color("#c8a2ef")
		_add_label(card, Vector2(24, 116), Vector2(302, 16), status, 10, tone)
		if equipped:
			var equipped_btn := _add_button(card, Vector2(24, 142), Vector2(302, 36), "EQUIPPED", func() -> void: pass)
			equipped_btn.disabled = true
		elif owned:
			var equip_btn := _add_button(card, Vector2(24, 142), Vector2(302, 36), "TAKE THE CUE", _equip_cue_finish.bind(finish_id), true)
			if focus_button == null:
				focus_button = equip_btn
		else:
			var locked_btn := _add_button(card, Vector2(24, 142), Vector2(302, 36), "LOCKED", func() -> void: pass)
			locked_btn.disabled = true
	var foot := _panel(root, Vector2(70, 604), Vector2(1110, 62), PANEL)
	_add_label(foot, Vector2(22, 10), Vector2(760, 18), "HOW FINISHES WORK", 9, GOLD)
	_add_label(foot, Vector2(22, 28), Vector2(760, 26), "Each finish is a trophy in your hands. No purchase, no stat — only the look of the stick changes.", 11, Color("#d6e5e1"))
	_add_button(foot, Vector2(836, 12), Vector2(252, 38), "OPEN THE TROPHY SHELF", _show_trophies)
	if focus_button != null:
		focus_button.grab_focus()
	else:
		back_btn.grab_focus()

# --- TROPHIES -------------------------------------------------------------

func _trophy_target(trophy: Dictionary) -> int:
	if str(trophy.stat) == "unlocks":
		return vault_items.size()
	return int(trophy.target)

func _trophy_stat(stat: String) -> int:
	match stat:
		"tables_cleared":
			return tables_cleared
		"runs_finished":
			return runs_finished
		"wins":
			return wins
		"bosses_beaten":
			return bosses_beaten
		"best_bosses_in_run":
			return best_bosses_in_run
		"best_tables":
			return best_tables
		"best_shot_ever":
			return best_shot_ever
		"best_streak_ever":
			return best_streak_ever
		"scouted":
			return scouted.size()
		"dailies_played":
			return dailies_played
		"best_daily_streak":
			return best_daily_streak
		"unlocks":
			return unlocks.size()
		"best_build":
			return best_build
		"best_set_tier":
			return best_set_tier
		"best_sets_in_run":
			return best_sets_in_run
		"house_spot_hits":
			return house_spot_hits
		"stake2_wins":
			return stake2_wins
		"house_calls":
			return house_calls
		"house_shutouts":
			return house_shutouts
		"grudges_settled":
			return grudges_settled
		"duel_wins":
			return duel_wins
		"duel_best_streak":
			return duel_best_streak
		"duel_best_form":
			return duel_best_form
		"best_grind_stage":
			return gauntlet_best_stage
	return 0

# Settles every milestone against the saved counters. Checked on menu screens
# rather than inside a purchase, so a trophy can never quietly change the price
# of the thing the player is looking at. Returns the reputation it paid.
func _check_trophies() -> int:
	var paid := 0
	var names: Array[String] = []
	var new_ids: Array[String] = []
	for trophy in TROPHIES:
		var trophy_id := str(trophy.id)
		if trophies.has(trophy_id):
			continue
		if _trophy_stat(str(trophy.stat)) < _trophy_target(trophy):
			continue
		trophies.append(trophy_id)
		paid += int(trophy.rep)
		names.append(str(trophy.name))
		new_ids.append(trophy_id)
	if names.is_empty():
		return 0
	reputation += paid
	_save_meta()
	_sfx("reward")
	var headline := "TROPHY  //  %s" % names[0]
	if names.size() > 1:
		headline += "   +%d MORE" % (names.size() - 1)
	# A trophy that unlocks a stick is worth saying out loud: otherwise the new
	# finish sits one screen away and the player never learns the case changed.
	var new_finish := ""
	for finish in CUE_FINISHES:
		if new_ids.has(str(finish.trophy)):
			new_finish = str(finish.name)
	var detail := "+%d REPUTATION" % paid
	if new_finish != "":
		detail += "   ·   %s IN THE CUE CASE" % new_finish
	_toast(headline, detail, GOLD)
	return paid

func _earned_trophy_rep() -> int:
	var total := 0
	for trophy in TROPHIES:
		if trophies.has(str(trophy.id)):
			total += int(trophy.rep)
	return total

# The closest unearned milestone, measured by completion ratio and then by the
# fewest steps left. The run summary names it so a finished tour always ends on
# a concrete next thing to chase instead of a dead end.
func _next_trophy() -> Dictionary:
	var best: Dictionary = {}
	var best_ratio := -1.0
	var best_remaining := 1 << 30
	for trophy in TROPHIES:
		if trophies.has(str(trophy.id)):
			continue
		var target := maxi(_trophy_target(trophy), 1)
		var have := mini(_trophy_stat(str(trophy.stat)), target)
		var ratio := float(have) / float(target)
		var remaining := target - have
		if ratio > best_ratio + 0.0001 or (absf(ratio - best_ratio) <= 0.0001 and remaining < best_remaining):
			best = trophy
			best_ratio = ratio
			best_remaining = remaining
	return best

# One toast at a time, on its own canvas layer so it can never be counted as a
# screen child or block a button underneath it.
func _toast(title: String, detail: String, tone := GOLD) -> void:
	if not is_instance_valid(toast_root):
		return
	for old in toast_root.get_children():
		toast_root.remove_child(old)
		old.queue_free()
	var chip := _panel(toast_root, Vector2(430, 16), Vector2(420, 56), PANEL_ALT)
	var accent := ColorRect.new()
	accent.position = Vector2(0, 0)
	accent.size = Vector2(4, 56)
	accent.color = tone
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(accent)
	var title_label := _add_label(chip, Vector2(18, 8), Vector2(384, 22), title, 17, tone, HORIZONTAL_ALIGNMENT_LEFT, true)
	var detail_label := _add_label(chip, Vector2(18, 30), Vector2(384, 18), detail, 10, MUTED)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.modulate.a = 0.0
	var tween := chip.create_tween()
	tween.tween_property(chip, "modulate:a", 1.0, 0.16)
	tween.tween_interval(4.0)
	tween.tween_property(chip, "modulate:a", 0.0, 0.35)
	tween.tween_callback(chip.queue_free)

func _show_trophies() -> void:
	screen = "trophies"
	var root := _base_screen("TROPHIES", "Milestones across tours, dailies and the vault. Each one pays reputation once.", false)
	var back_btn := _add_button(root, Vector2(32, 116), Vector2(120, 40), "BACK", _show_title)
	_add_label(root, Vector2(660, 118), Vector2(520, 20), "%d / %d EARNED    ·    %d REP COLLECTED" % [trophies.size(), TROPHIES.size(), _earned_trophy_rep()], 11, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	# Four columns keep every rule legible and — more importantly — fit the
	# whole shelf. The row height is deliberately tight: 29 milestones have to
	# fit above the footer, and a card that runs off the bottom is a milestone
	# the player cannot read.
	for i in TROPHIES.size():
		var trophy: Dictionary = TROPHIES[i]
		var earned := trophies.has(str(trophy.id))
		var col := i % 4
		var row := i / 4
		var card := _panel(root, Vector2(60 + col * 292, 156 + row * 62), Vector2(276, 58), PANEL_ALT if earned else PANEL)
		var accent := ColorRect.new()
		accent.position = Vector2(0, 0)
		accent.size = Vector2(4, 58)
		accent.color = GOLD if earned else Color("#2c4752")
		accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(accent)
		_add_label(card, Vector2(14, 3), Vector2(188, 18), str(trophy.name), 13, Color("#f1f6f1") if earned else Color("#93a9ab"), HORIZONTAL_ALIGNMENT_LEFT, true)
		_add_label(card, Vector2(192, 5), Vector2(70, 16), "EARNED" if earned else "+%d REP" % int(trophy.rep), 8, GOLD if earned else MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
		_add_label(card, Vector2(14, 21), Vector2(248, 20), str(trophy.body), 9, Color("#c8d8d5") if earned else MUTED)
		if earned:
			_add_label(card, Vector2(14, 44), Vector2(248, 12), "COLLECTED  ·  +%d REP" % int(trophy.rep), 8, MINT)
		else:
			var have := mini(_trophy_stat(str(trophy.stat)), _trophy_target(trophy))
			_add_label(card, Vector2(14, 44), Vector2(248, 12), "PROGRESS  %d / %d" % [have, _trophy_target(trophy)], 8, MUTED)
	_add_label(root, Vector2(70, 668), Vector2(1110, 20), "Trophies never change physics or scoring. They are stored in this browser.", 10, MUTED)
	back_btn.grab_focus()

func _setting_row(card: Control, y: float, label: String, value: String, callback: Callable) -> void:
	var button := _add_button(card, Vector2(26, y), Vector2(508, 42), "", callback)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var name_label := _add_label(button, Vector2(16, 10), Vector2(350, 22), label, 13, Color("#e4efeb"))
	var value_label := _add_label(button, Vector2(370, 10), Vector2(122, 22), value, 13, MINT, HORIZONTAL_ALIGNMENT_RIGHT)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _toggle_contrast() -> void:
	settings_high_contrast = not settings_high_contrast
	_save_settings()
	_show_settings()

func _toggle_fast() -> void:
	settings_fast_resolve = not settings_fast_resolve
	_save_settings()
	_show_settings()

func _toggle_house_cam() -> void:
	settings_house_cam = not settings_house_cam
	_save_settings()
	_show_settings()

func _toggle_flash() -> void:
	settings_reduced_flash = not settings_reduced_flash
	_save_settings()
	_show_settings()

func _toggle_shake() -> void:
	settings_no_shake = not settings_no_shake
	_save_settings()
	_show_settings()

func _toggle_guide() -> void:
	settings_guide = 0.55 if settings_guide > 0.9 else 1.0
	_save_settings()
	_show_settings()

func _cycle_volume() -> void:
	settings_volume = 0.0 if settings_volume > 0.9 else (0.4 if settings_volume < 0.1 else (0.8 if settings_volume < 0.6 else 1.0))
	portal.set_portal_muted(settings_volume <= 0.0)
	_save_settings()
	_show_settings()

func _show_victory() -> void:
	_show_run_summary(true)

func _adjust_power(amount: float) -> void:
	if resolving or paused:
		return
	current_power = clampf(current_power + amount, 0.08, 1.0)
	_sfx("click")
	_coach_mark("power")
	_refresh_hud()

# Gamepad aiming: stick direction is the shot direction. Shared by the input
# path and tests so the dead zone lives in one place.
func _aim_with_stick(stick: Vector2) -> bool:
	if stick.length() < 0.25:
		return false
	last_aim = stick.normalized()
	_coach_mark("aim")
	queue_redraw()
	return true

func _adjust_spin(amount: Vector2) -> void:
	if resolving or paused:
		return
	current_spin = (current_spin + amount).clamp(Vector2(-1, -1), Vector2(1, 1))
	_refresh_spin_pad()
	queue_redraw()

func _set_spin_from_pointer(pointer: Vector2) -> void:
	if resolving or paused:
		return
	var offset := pointer - SPIN_PAD_RECT.get_center()
	# Up is follow, so the vertical axis is inverted against screen space.
	current_spin = (Vector2(offset.x, -offset.y) / (SPIN_PAD_RECT.size.x * 0.5 - 6.0)).clamp(Vector2(-1, -1), Vector2(1, 1))
	_refresh_spin_pad()
	queue_redraw()

func _refresh_spin_pad() -> void:
	if is_instance_valid(spin_pad):
		spin_pad.spin = current_spin
		spin_pad.queue_redraw()

func _pointer_on_hud(point: Vector2) -> bool:
	return HUD_BRIEF_RECT.has_point(point) or HUD_DOCK_RECT.has_point(point)

func _set_power_from_pointer(pointer_x: float) -> void:
	if resolving or paused:
		return
	# Matches the visual bar: screen x320 = empty, x640 = full.
	current_power = clampf((pointer_x - 320.0) / 320.0, 0.08, 1.0)
	_coach_mark("power")
	_refresh_hud()

func _contract_progress() -> float:
	if scenario.is_empty():
		return 0.0
	match scenario.contract_type:
		"score":
			return clampf(float(score) / float(scenario.target), 0.0, 1.0)
		"ice_lane":
			return clampf(float(pocketed_count) / float(scenario.target), 0.0, 1.0)
		"bank_count":
			return clampf(minf(float(bank_count) / float(scenario.target), float(pocketed_count) / 4.0), 0.0, 1.0)
		"no_scratch":
			return clampf(float(pocketed_count) / float(scenario.target), 0.0, 1.0)
		"clear":
			return clampf(float(pocketed_count) / float(scenario.target), 0.0, 1.0)
		"combo":
			return clampf(float(score) / float(scenario.target), 0.0, 1.0)
	return 0.0

func _shot_tags(rails: int, pockets: int, target_rail: bool) -> String:
	# A tag describes the shot that happened. Rails touched by a cue that
	# missed every target are not a bank; calling that "BANK" taught the wrong
	# lesson and made a score-contract miss look like progress.
	if pockets <= 0:
		return "MISS"
	var tags: Array[String] = []
	if target_rail:
		tags.append("DEEP BANK" if rails >= 2 else "BANK")
	elif rails > 0:
		tags.append("KICK")
	elif pockets == 1:
		tags.append("CLEAN")
	if pockets > 1:
		tags.append("COMBO")
	return " / ".join(tags) if not tags.is_empty() else "POCKET"

# Draggable cue-ball strike point: x = english, y = follow (up) / draw (down).
class SpinPad extends Control:
	var spin := Vector2.ZERO

	func _draw() -> void:
		var center := size * 0.5
		var radius := size.x * 0.5 - 1.0
		draw_circle(center, radius, Color("#0b171b"))
		draw_circle(center, radius, Color("#5b7276"), false, 2.0)
		draw_line(center - Vector2(radius - 9.0, 0), center + Vector2(radius - 9.0, 0), Color(1, 1, 1, 0.10))
		draw_line(center - Vector2(0, radius - 9.0), center + Vector2(0, radius - 9.0), Color(1, 1, 1, 0.10))
		var dot := center + Vector2(spin.x, -spin.y) * (radius - 11.0)
		draw_circle(dot, 9.0, Color(0.95, 0.75, 0.30, 0.18), false, 1.5)
		draw_circle(dot, 5.0, Color("#f2bd58") if spin.length() > 0.05 else Color(1, 1, 1, 0.38))

# Title-screen table: rail, cushion, felt, a racked set and a cue. Drawn as a
# Control so it sits under the labels but above the backdrop.
# Title-screen table band: a real rail with three pockets on it, a woven felt
# and a racked set. Drawn in the same visual language as the encounter table so
# the first screen already teaches what the game looks like.
# Mini diagrams for the How to Play cards: a previewed shot, a power meter with
# a spin pad, and a contract bar. They show the shape of the interaction faster
# than the copy can describe it.
class HowtoArt extends Control:
	var mode := 0

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#101f24"))
		draw_rect(Rect2(Vector2.ZERO, size), Color("#33505a"), false, 1.0)
		match mode:
			0:
				var from := Vector2(18, size.y - 20)
				var contact := Vector2(size.x - 84, size.y * 0.5)
				_dashes(from, contact)
				draw_circle(contact, 6.0, Color("#8fe1bd"))
				var ghost := Vector2(size.x - 58, size.y * 0.5 - 10)
				draw_circle(ghost, 13.0, Color(0.56, 0.88, 0.74, 0.75), false, 2.0)
				draw_line(ghost, ghost + Vector2(26, -14), Color(0.56, 0.88, 0.74, 0.9), 2.0)
			1:
				var bar := Rect2(18, size.y * 0.5 - 7, 190, 14)
				draw_rect(bar, Color("#0b171b"))
				draw_rect(Rect2(bar.position, Vector2(bar.size.x * 0.64, bar.size.y)), GOLD)
				var pad := Vector2(size.x - 46, size.y * 0.5)
				draw_circle(pad, 21.0, Color("#0b171b"))
				draw_circle(pad, 21.0, Color("#5b7276"), false, 1.5)
				draw_circle(pad + Vector2(0, -8), 5.0, GOLD)
			2:
				draw_rect(Rect2(18, 16, size.x - 36, 10), Color("#0b171b"))
				draw_rect(Rect2(18, 16, (size.x - 36) * 0.66, 10), MINT)
				for chip_index in 3:
					var chip := Rect2(18 + chip_index * 62, 40, 52, 16)
					draw_rect(chip, Color("#31505a"))
					draw_rect(chip, MINT if chip_index == 0 else Color("#4a6870"), false, 1.0)

	func _dashes(from: Vector2, to: Vector2) -> void:
		var distance := from.distance_to(to)
		if distance < 1.0:
			return
		var direction := (to - from) / distance
		var cursor := 0.0
		while cursor < distance:
			draw_line(from + direction * cursor, from + direction * minf(cursor + 10.0, distance), Color(0.92, 0.96, 0.78, 0.9), 2.0)
			cursor += 18.0

# A four-card diagram strip: straight line, bank line, cluster line, cash.
# They are deliberately diagrams, not UI mockups: a player reads the shape of
# the term before the copy.
class ContractArt extends Control:
	var mode := 0

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#0b171b"))
		draw_rect(Rect2(Vector2.ZERO, size), Color("#33505a"), false, 1.0)
		var felt := Rect2(8, 8, size.x - 16.0, size.y - 16.0)
		draw_rect(felt, Color("#16483c"))
		var pockets := [felt.position, Vector2(felt.end.x, felt.position.y), Vector2(felt.position.x, felt.end.y), felt.end, Vector2(felt.get_center().x, felt.position.y), Vector2(felt.get_center().x, felt.end.y)]
		for pocket in pockets:
			draw_circle(pocket, 4.0, Color("#04080a"))
		match mode:
			0:
				var cue := Vector2(28, felt.end.y - 24.0)
				var target := Vector2(96, felt.position.y + 28.0)
				var pocket := felt.end
				draw_circle(cue, 6.0, Color("#f4f1e6"))
				draw_circle(target, 7.0, Color("#e85b4f"))
				_dash(cue, target, Color(0.92, 0.96, 0.78, 0.8))
				_dash(target, pocket, Color(0.95, 0.75, 0.30, 0.9))
				draw_circle(pocket, 8.0, Color(0.95, 0.75, 0.30, 0.5), false, 1.5)
			1:
				var cue := Vector2(26, felt.end.y - 22.0)
				var rail := Vector2(80, felt.position.y + 4.0)
				var target := Vector2(154, felt.position.y + 36.0)
				var pocket := felt.end
				draw_circle(cue, 6.0, Color("#f4f1e6"))
				draw_circle(target, 7.0, Color("#f2bd58"))
				_dash(cue, rail, Color(0.92, 0.96, 0.78, 0.8))
				_dash(rail, target, Color(0.95, 0.75, 0.30, 0.9))
				draw_circle(rail, 3.5, GOLD)
				_dash(target, pocket, Color(0.95, 0.75, 0.30, 0.9))
			2:
				var cue := Vector2(26, felt.get_center().y + 18.0)
				var one := Vector2(96, felt.get_center().y - 16.0)
				var two := Vector2(112, felt.get_center().y + 14.0)
				var pocket := Vector2(felt.end.x, felt.get_center().y)
				draw_circle(cue, 6.0, Color("#f4f1e6"))
				draw_circle(one, 7.0, Color("#8fe1bd"))
				draw_circle(two, 7.0, Color("#6fa8d8"))
				_dash(cue, one, Color(0.92, 0.96, 0.78, 0.8))
				_dash(one, pocket, Color(0.95, 0.75, 0.30, 0.9))
				_dash(two, pocket, Color(0.95, 0.75, 0.30, 0.9))
				draw_circle(pocket, 8.0, Color(0.95, 0.75, 0.30, 0.5), false, 1.5)
			3:
				var base := Vector2(felt.get_center().x - 28.0, felt.get_center().y + 20.0)
				for i in 3:
					var chip := base + Vector2(i * 14.0, -i * 12.0)
					draw_circle(chip + Vector2(2, 3), 11.0, Color(0, 0, 0, 0.3))
					draw_circle(chip, 11.0, GOLD)
					draw_circle(chip, 7.0, Color(0.55, 0.38, 0.16))
				draw_circle(Vector2(38, felt.end.y - 24.0), 6.0, Color("#f4f1e6"))
				_dash(Vector2(44, felt.end.y - 20.0), Vector2(felt.end.x - 8.0, felt.position.y + 12.0), Color(0.95, 0.75, 0.30, 0.55))

	func _dash(from: Vector2, to: Vector2, color: Color) -> void:
		var distance := from.distance_to(to)
		if distance < 1.0:
			return
		var direction := (to - from) / distance
		var cursor := 0.0
		while cursor < distance:
			draw_line(from + direction * cursor, from + direction * minf(cursor + 7.0, distance), color, 1.5)
			cursor += 12.0

class CueArt extends Control:
	var finish: Dictionary = {}

	func _draw() -> void:
		if finish.is_empty():
			return
		var butt := Color(str(finish.butt))
		var wrap := Color(str(finish.wrap))
		var shaft := Color(str(finish.shaft))
		var accent := Color(str(finish.accent))
		var y := size.y * 0.5
		var left := 6.0
		var right := size.x - 4.0
		draw_line(Vector2(left, y + 3.0), Vector2(right, y + 3.0), Color(0, 0, 0, 0.32), 9.0)
		# Shaft from the joint to the ferrule, tapering toward the tip.
		var joint := right - 148.0
		var ferrule := right - 16.0
		for i in 3:
			var a := joint + (ferrule - joint) * float(i) / 3.0
			var b := joint + (ferrule - joint) * float(i + 1) / 3.0
			draw_line(Vector2(a, y), Vector2(b, y), shaft, 5.8 - float(i) * 0.5)
		var wrap_start := joint - 74.0
		draw_line(Vector2(wrap_start, y), Vector2(joint, y), wrap, 8.4)
		for i in 9:
			var wx := wrap_start + (joint - wrap_start) * (float(i) + 0.5) / 9.0
			draw_line(Vector2(wx, y - 3.4), Vector2(wx, y + 3.4), Color(0, 0, 0, 0.20), 1.2)
		draw_line(Vector2(left + 9.0, y), Vector2(wrap_start, y), butt, 9.6)
		draw_line(Vector2(left + 5.0, y), Vector2(left + 1.0, y), accent, 9.2)
		draw_line(Vector2(wrap_start + 2.0, y), Vector2(wrap_start - 2.0, y), accent, 9.4)
		draw_line(Vector2(ferrule, y), Vector2(ferrule + 6.0, y), Color(0.96, 0.94, 0.86), 4.4)
		draw_line(Vector2(ferrule + 6.0, y), Vector2(right, y), Color(0.44, 0.70, 0.84), 4.2)
		draw_line(Vector2(left + 10.0, y - 2.2), Vector2(right - 2.0, y - 1.0), Color(1, 1, 1, 0.18), 1.2)

class TableArt extends Control:
	# The title table is a real broadcast frame, not a green band: one far rail,
	# a warm lamp pool, a full fifteen-ball rack and the player's cue waiting in
	# the near corner. Everything is drawn in the same language as the encounter
	# table, so the front door already teaches the felt.
	func _draw() -> void:
		var rail := 26.0
		draw_rect(Rect2(0, 0, size.x, rail), Color("#7d4f27"))
		draw_rect(Rect2(0, 0, size.x, 4.0), Color("#a9713a"))
		draw_rect(Rect2(0, rail - 6.0, size.x, 6.0), Color("#52321a"))
		# Rail grain: long, low-contrast streaks following the wood, so the rail
		# is a material instead of a brown band. Four passes is enough at 720p.
		for grain in 4:
			var grain_y := 8.0 + float(grain) * 3.6
			var grain_alpha := 0.06 + float(grain) * 0.012
			var grain_x := 0.0
			while grain_x < size.x:
				var run := 90.0 + float((grain * 47 + int(grain_x)) % 160)
				draw_line(Vector2(grain_x, grain_y), Vector2(grain_x + run, grain_y + sin(grain_x * 0.01) * 0.8), Color(0.10, 0.04, 0.01, grain_alpha), 1.0)
				grain_x += run + 24.0
		# Felt first, then rail and pockets on top of it.
		draw_rect(Rect2(0, rail, size.x, size.y - rail), Color("#12453a"))
		# A single warm lamp above the rack: concentric wide ellipses stand in for
		# a light pool without a gradient texture or a shader.
		var lamp_center := Vector2(size.x * 0.38, rail + 130.0)
		draw_set_transform(lamp_center, 0.0, Vector2(1.0, 0.52))
		for glow_index in 24:
			draw_circle(Vector2.ZERO, 372.0 - float(glow_index) * 13.0, Color(1.0, 0.84, 0.52, 0.010 + float(glow_index) * 0.0012))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var weave := Color(1, 1, 1, 0.024)
		var weave_x := -size.y
		while weave_x < size.x:
			draw_line(Vector2(weave_x, size.y), Vector2(weave_x + size.y, rail), weave, 3.0)
			weave_x += 30.0
		# Edge shadow: the table gets darker away from the lamp, which makes the
		# rack read as the lit centre of a room instead of a flat swatch.
		for side_index in 10:
			var edge := float(side_index) * 10.0
			draw_rect(Rect2(edge, rail, 10.0, size.y - rail), Color(0.01, 0.03, 0.04, 0.05), true)
			draw_rect(Rect2(size.x - edge - 10.0, rail, 10.0, size.y - rail), Color(0.01, 0.03, 0.04, 0.05), true)
		for bottom_index in 8:
			draw_rect(Rect2(0, size.y - float(bottom_index) * 10.0 - 10.0, size.x, 10.0), Color(0.01, 0.03, 0.04, 0.04), true)
		# Cushion lip, then three pockets on the far rail. Only three are visible
		# because the camera is standing at the near end of the table.
		draw_rect(Rect2(0, rail, size.x, 8.0), Color("#0d352d"))
		for grain_index in 5:
			draw_line(Vector2(0, 6.0 + float(grain_index) * 4.0), Vector2(size.x, 5.0 + float(grain_index) * 4.0), Color(0, 0, 0, 0.10), 1.0)
		for pocket_x in [size.x * 0.18, size.x * 0.5, size.x * 0.82]:
			var mouth := Vector2(pocket_x, rail)
			draw_circle(mouth, 34.0, Color("#1d130c"))
			draw_circle(mouth, 31.0, Color("#5b3a1e"))
			draw_circle(mouth, 28.5, Color("#b5823f"))
			draw_circle(mouth, 27.0, Color("#7a5326"))
			draw_circle(mouth, 24.0, Color(0.015, 0.025, 0.03, 0.99))
			draw_arc(mouth, 28.5, 0.0, TAU, 30, Color("#f0c67a", 0.85), 1.4)
			draw_arc(mouth, 24.4, PI * 0.10, PI * 0.90, 12, Color(0, 0, 0, 0.55), 2.0)
			draw_circle(mouth + Vector2(-22.5, 0.0), 1.7, Color("#e2c082"))
			draw_circle(mouth + Vector2(22.5, 0.0), 1.7, Color("#e2c082"))
		# A full rack, five rows, apex pointing at the cue ball. The triangle is
		# a real rack (tight spacing, wood frame) and 9-15 wear stripes: fifteen
		# solids read as a toy set, not a pool table, at a glance.
		var radius := 14.0
		var rack_apex := Vector2(size.x * 0.40, rail + 112.0)
		var cue_ball := rack_apex + Vector2(-176.0, 0.0)
		var row_gap := radius * 1.732
		var col_gap := radius * 2.0
		# A wooden rack frame drawn as a triangle around the cluster. A filled
		# triangle disappears under the balls; the outline is what a player
		# recognises as a racked set from across the room.
		var frame := Color("#684323")
		var frame_pad := 18.0
		var frame_left := rack_apex + Vector2(-radius - frame_pad, 0.0)
		var frame_butt := row_gap * 4.0 + radius + frame_pad
		var frame_top := rack_apex + Vector2(frame_butt, -col_gap * 2.0 - radius - frame_pad)
		var frame_bottom := rack_apex + Vector2(frame_butt, col_gap * 2.0 + radius + frame_pad)
		draw_line(frame_left, frame_top, frame, 7.0)
		draw_line(frame_left, frame_bottom, frame, 7.0)
		draw_line(frame_top, frame_bottom, frame, 7.0)
		draw_line(frame_left + Vector2(-1, -2), frame_top + Vector2(-1, -2), Color("#9a6634"), 2.0)
		draw_line(frame_left + Vector2(1, 2), frame_bottom + Vector2(1, 2), Color("#3c2512"), 2.0)
		draw_line(frame_top + Vector2(1, 0), frame_bottom + Vector2(1, 0), Color("#9a6634"), 1.5)
		var palette := [
			Color("#d8a521"), Color("#2e5c99"), Color("#a9332c"), Color("#5f3b8c"),
			Color("#bd6f22"), Color("#236345"), Color("#782b2b"), Color("#121619"),
			Color("#d8a521"), Color("#2e5c99"), Color("#a9332c"), Color("#5f3b8c"),
			Color("#bd6f22"), Color("#236345"), Color("#782b2b"),
		]
		# A real rack order: 8 in the middle, one solid and one stripe in the
		# back corners. The layout is fixed while the positions are geometric.
		var rack_order := [1, 9, 2, 10, 8, 3, 11, 4, 12, 5, 13, 6, 14, 7, 15]
		for row in 5:
			for column in row + 1:
				var ball_number: int = rack_order[(row * (row + 1)) / 2 + column]
				var pos := rack_apex + Vector2(float(row) * row_gap, (float(column) - float(row) * 0.5) * col_gap)
				_draw_title_ball(pos, radius, palette[ball_number - 1], ball_number)
		# The cue ball is the brightest object in the frame; the stick enters from
		# the near corner and points the eye straight at the rack.
		_draw_title_ball(cue_ball, radius, Color("#efe9d8"), 0, true)
		var cue_from := Vector2(cue_ball.x - 258.0, size.y - 14.0)
		var aim := (cue_ball - cue_from).normalized()
		var perp := Vector2(-aim.y, aim.x)
		var cue_to := cue_ball - aim * 24.0
		# A cue tapers from the butt to the ferrule. Drawing it as three parallel
		# lines made it a straw; a polygon is what makes it a stick someone made.
		var taper := PackedVector2Array([
			cue_from + perp * 5.0, cue_to + perp * 1.6,
			cue_to - perp * 1.6, cue_from - perp * 5.0,
		])
		var shadow_taper := PackedVector2Array()
		for point in taper:
			shadow_taper.append(point + Vector2(2.0, 3.0))
		draw_colored_polygon(shadow_taper, Color(0, 0, 0, 0.26))
		draw_colored_polygon(taper, Color("#8a5a2e"))
		draw_line(cue_from - perp * 2.0, cue_to - perp * 0.6, Color("#c79a5c", 0.85), 1.6)
		# Butt wrap and joint rings: the two details a player's eye checks first.
		var wrap_from := cue_from.lerp(cue_to, 0.18)
		var wrap_to := cue_from.lerp(cue_to, 0.46)
		draw_line(wrap_from + perp * 4.2, wrap_to + perp * 3.0, Color("#24160e"), 4.0)
		draw_line(wrap_from - perp * 4.2, wrap_to - perp * 3.0, Color("#24160e"), 4.0)
		draw_line(wrap_from, wrap_from - perp * 4.0, Color("#d9b46c"), 1.4)
		draw_line(wrap_to, wrap_to - perp * 3.2, Color("#d9b46c"), 1.4)
		# Ferrule, tip and a chalk-blue cap.
		draw_line(cue_to, cue_to + aim * 9.0, Color("#e9e4d5"), 4.2)
		draw_line(cue_to + aim * 9.0, cue_to + aim * 12.0, Color("#6fa8d8"), 3.4)
		draw_circle(cue_from, 4.6, Color("#3a2412"))
		draw_circle(cue_from - aim * 0.5, 3.0, Color("#5a3a1d"))
		# Rail diamonds at the standard stations. They are the one piece of
		# furniture every pool player reads without thinking, and they make the
		# felt feel measured rather than empty.
		for station in [1, 2, 3, 4, 5, 6, 7]:
			if station == 4:
				continue
			var dx := size.x * float(station) / 8.0
			var diamond := PackedVector2Array([
				Vector2(dx, rail * 0.5 - 3.0), Vector2(dx + 3.0, rail * 0.5),
				Vector2(dx, rail * 0.5 + 3.0), Vector2(dx - 3.0, rail * 0.5),
			])
			draw_colored_polygon(diamond, Color("#e9dcc0", 0.85))
		# A chalk cube on the rail is the small object that makes the scene a
		# place someone plays in, not a diagram.
		draw_rect(Rect2(size.x * 0.13, 8.0, 16.0, 11.0), Color("#2e6f8a"))
		draw_rect(Rect2(size.x * 0.13, 8.0, 16.0, 4.0), Color("#54a9c4"))
		draw_rect(Rect2(size.x * 0.13 + 2.0, 9.0, 12.0, 2.0), Color("#8fd4e6"))

	# One billiard ball, drawn in the same language as the felt: shadow, rim,
	# sphere, optional stripe, number disc, one tight specular. Solids and
	# stripes are the thing a real rack has that a row of coloured dots does not.
	func _draw_title_ball(pos: Vector2, radius: float, color: Color, number: int, cue := false) -> void:
		draw_circle(pos + Vector2(2.0, 3.4), radius - 0.6, Color(0, 0, 0, 0.30))
		draw_circle(pos, radius, color.darkened(0.28))
		draw_circle(pos - Vector2(0.8, 1.2), radius - 1.6, color)
		if not cue and number >= 9:
			# The stripe is a band around the equator, so it is drawn as the
			# spherical lens between two chords rather than a rectangle: a
			# rectangle's corners would spill outside the ball.
			var half := radius * 0.30
			var arc := asin(clampf(half / radius, 0.0, 1.0))
			var band := PackedVector2Array()
			for i in 13:
				var a := -arc + 2.0 * arc * float(i) / 12.0
				band.append(pos + Vector2(cos(a), sin(a)) * (radius - 1.4))
			for i in 13:
				var a := arc - 2.0 * arc * float(i) / 12.0
				band.append(pos + Vector2(-cos(a), sin(a)) * (radius - 1.4))
			draw_colored_polygon(band, Color("#e4dcc6"))
		# A thin contact shadow under the equator keeps the sphere from
		# flattening into a sticker at this size.
		draw_arc(pos + Vector2(0, 1.0), radius - 2.2, PI * 0.18, PI * 0.82, 12, Color(0, 0, 0, 0.18), 2.4)
		draw_arc(pos, radius - 0.5, 0.0, TAU, 24, Color(0, 0, 0, 0.46), 1.4)
		if not cue:
			draw_circle(pos, radius * 0.40, Color("#f2ebd6"))
			draw_circle(pos, radius * 0.43, Color(0, 0, 0, 0.10), false, 1.0)
			var label := str(number)
			var label_width := ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 9).x
			draw_string(ThemeDB.fallback_font, pos + Vector2(-label_width * 0.5, 3.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#11181d"))
		draw_circle(pos - Vector2(radius * 0.36, radius * 0.42), radius * 0.30, Color(1, 1, 1, 0.14))
		draw_circle(pos - Vector2(radius * 0.40, radius * 0.46), radius * 0.15, Color(1, 1, 1, 0.70))

func _panel(parent: Control, position: Vector2, size: Vector2, color: Color) -> Control:
	var panel := Panel.new()
	panel.position = position
	panel.size = size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _box(color, Color("#4a6870"), 9)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _add_label(parent: Control, position: Vector2, size: Vector2, text: String, font_size: int, color: Color, alignment := HORIZONTAL_ALIGNMENT_LEFT, display := false) -> Label:
	var label := Label.new()
	label.position = position
	label.size = size
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = alignment
	if display:
		label.add_theme_font_override("font", DISPLAY_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color if not settings_high_contrast else Color.WHITE)
	parent.add_child(label)
	return label

func _box(bg: Color, border: Color, radius: int, border_width := 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style

func _add_button(parent: Control, position: Vector2, size: Vector2, text: String, callback: Callable, primary := false, accent := Color(0, 0, 0, 0)) -> Button:
	var button := Button.new()
	button.position = position
	button.size = size
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", DISPLAY_FONT)
	button.add_theme_font_size_override("font_size", 18)
	var border := accent if accent.a > 0.0 else Color("#5e8587")
	var bg := GOLD if primary else Color("#31505a")
	var ink := INK if primary else Color("#e4efeb")
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_focus_color", ink)
	button.add_theme_color_override("font_hover_color", INK if primary else Color("#fff4d2"))
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_disabled_color", Color("#6f858a"))
	button.add_theme_stylebox_override("normal", _box(bg, border, 6))
	button.add_theme_stylebox_override("hover", _box(Color("#ffd275") if primary else Color("#426b70"), GOLD, 6))
	button.add_theme_stylebox_override("pressed", _box(Color("#d9a23f") if primary else GOLD, GOLD, 6))
	button.add_theme_stylebox_override("disabled", _box(Color("#1a292e"), Color("#33464b"), 6))
	button.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), Color("#fff4d2"), 6))
	parent.add_child(button)
	button.pressed.connect(callback)
	return button

# A small gold dot in the button's top-right corner. Text suffixes read like
# stray punctuation next to the display font; a real badge reads as a status.
func _add_dot_badge(button: Button) -> void:
	var dot := Panel.new()
	dot.position = Vector2(button.size.x - 13.0, 6.0)
	dot.size = Vector2(7, 7)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = GOLD
	style.set_corner_radius_all(4)
	dot.add_theme_stylebox_override("panel", style)
	button.add_child(dot)

# Every screen needs one focused control. The encounter autofocuses FIRE, but
# the map, reward and shop doors landed on nothing, so a keyboard or controller
# player could open a reward screen and have no way to take a piece. Depth-first
# finds the first enabled button in reading order.
func _focus_first_button(node: Node) -> void:
	for child in node.get_children():
		if child is Button and child.focus_mode != Control.FOCUS_NONE and not child.disabled:
			child.grab_focus()
			return
		_focus_first_button(child)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), BG)
	if screen == "map":
		# The route is a strategy board on green baize, not a graph floating in
		# the dark. The felt and its weave sit under the paths, and a brass rule
		# frames the board the same way the rails frame a table.
		# The board has to contain the widest node (the right column ends at x=972)
		# and the bottom House node (y=706), or the route reads as falling off its
		# own table. 14px of margin on each side keeps it deliberate.
		var board := Rect2(298, 112, 688, 602)
		draw_rect(board, Color("#0e1c21"), true)
		draw_rect(Rect2(board.position, Vector2(board.size.x, 8.0)), Color("#12352f"), true)
		var board_weave := Color(1, 1, 1, 0.012)
		var board_weave_x := board.position.x - board.size.y
		while board_weave_x < board.end.x:
			draw_line(Vector2(board_weave_x, board.end.y), Vector2(board_weave_x + board.size.y, board.position.y), board_weave, 2.0)
			board_weave_x += 34.0
		draw_rect(board, Color("#2b464c"), false, 2.0)
		draw_rect(Rect2(board.position + Vector2(6, 6), board.size - Vector2(12, 12)), Color(0.55, 0.72, 0.70, 0.10), false, 1.0)
		for edge in map_edges:
			var map_a: Vector2 = map_nodes[edge.x].pos + shake_offset * 0.2
			var map_b: Vector2 = map_nodes[edge.y].pos + shake_offset * 0.2
			# Three route states: travelled (both ends cleared), open next (the
			# table you can play now leads here), and locked. Gold on a locked
			# branch promised a choice the player did not have yet.
			var travelled: bool = map_nodes[edge.x].done and map_nodes[edge.y].done
			var leads_on: bool = map_unlocked.has(edge.x) and not map_nodes[edge.x].done
			if travelled:
				draw_line(map_a, map_b, Color("#f2bd58", 0.30), 7.0)
				draw_line(map_a, map_b, GOLD, 2.0)
			elif leads_on:
				draw_line(map_a, map_b, Color("#f2bd58", 0.16), 7.0)
				for dash in range(0, 12, 2):
					var t0 := float(dash) / 12.0
					var t1 := float(dash + 1) / 12.0
					draw_line(map_a.lerp(map_b, t0), map_a.lerp(map_b, t1), Color(0.95, 0.74, 0.35, 0.75), 2.0)
			else:
				draw_line(map_a, map_b, Color("#536b72", 0.55), 3.0)
		# Buttons carry the node itself; a halo behind them is the only route
		# emphasis that survives the opaque button fill. They belong to the map
		# branch: left at function scope they painted a stray gold box over the
		# title and every other screen at a map node's coordinates.
		for i in map_nodes.size():
			if map_nodes[i].done:
				continue
			var node_rect := Rect2(map_nodes[i].pos - Vector2(62, 28), Vector2(124, 56))
			if i == pending_node:
				draw_style_box(halo_pending, node_rect.grow(5))
			elif map_unlocked.has(i):
				draw_style_box(halo_ready, node_rect.grow(4.0 + sin(animation_time * 3.0 + i) * 1.5))
		# A held grudge is a red wax seal on the final node: the route should show
		# that the House is waiting for this player specifically, not just print it
		# in the left column.
		if grudge_active and house_grudge != "":
			for i in map_nodes.size():
				if str(map_nodes[i].type) == "boss" and str(map_nodes[i].name).to_upper() == "THE HOUSE":
					var seal: Vector2 = map_nodes[i].pos
					var seal_pulse := 0.5 + 0.5 * sin(animation_time * 3.0)
					draw_arc(seal, 40.0 + seal_pulse * 2.0, 0.0, TAU, 36, Color(0.94, 0.42, 0.39, 0.50 + seal_pulse * 0.20), 2.0)
					draw_string(DISPLAY_FONT, seal + Vector2(-70, -36), "IT REMEMBERS", HORIZONTAL_ALIGNMENT_CENTER, 140, 11, Color("#ef6b64"))
		_draw_particles()
		return
	if screen != "encounter":
		_draw_particles()
		return
	var table := simulator.table_rect
	draw_rect(Rect2(0, 104, 1280, 552), FRAME_DARK)
	draw_rect(Rect2(300, 578, 930, 130), FRAME, true)
	draw_rect(Rect2(300, 578, 930, 130), Color("#53666a"), false, 2.0)
	draw_rect(Rect2(18, 122, 322, 450), FRAME, true)
	draw_rect(Rect2(350, 122, 900, 450), FRAME, true)
	draw_rect(Rect2(18, 122, 322, 450), Color("#53666a"), false, 3.0)
	draw_rect(Rect2(350, 122, 900, 450), Color("#53666a"), false, 3.0)
	draw_rect(Rect2(360, 132, 880, 420), Color("#0d151a"), true)
	var origin_shift := shake_offset
	draw_set_transform(origin_shift, 0.0, Vector2.ONE)
	draw_rect(table.grow(24), Color(0.01, 0.015, 0.02, 0.85), true)
	draw_rect(table, Color("#174f41"), true)
	# Wooden rail: four solid bands outside the felt plus corner caps, so the
	# table reads as a built object instead of a green rectangle with an outline.
	var rail := 20.0
	var wood := Color("#7d4f27")
	var wood_hi := Color("#a9713a")
	var wood_dark := Color("#52321a")
	draw_rect(Rect2(table.position.x - rail, table.position.y - rail, table.size.x + rail * 2.0, rail), wood)
	draw_rect(Rect2(table.position.x - rail, table.end.y, table.size.x + rail * 2.0, rail), wood)
	draw_rect(Rect2(table.position.x - rail, table.position.y, rail, table.size.y), wood)
	draw_rect(Rect2(table.end.x, table.position.y, rail, table.size.y), wood)
	draw_rect(Rect2(table.position.x - rail, table.position.y - rail, table.size.x + rail * 2.0, 3.0), wood_hi)
	draw_rect(Rect2(table.position.x - rail, table.end.y + rail - 3.0, table.size.x + rail * 2.0, 3.0), wood_dark)
	draw_rect(Rect2(table.position.x - rail, table.position.y - rail, 3.0, table.size.y + rail * 2.0), wood_hi)
	draw_rect(Rect2(table.end.x + rail - 3.0, table.position.y - rail, 3.0, table.size.y + rail * 2.0), wood_dark)
	# Rail grain and a cushion shadow. The rail is the largest brown area on
	# screen; a flat fill made the whole table read as a diagram with a green
	# rectangle in it.
	for grain in 3:
		var grain_y := table.position.y - rail + 7.0 + float(grain) * 5.0
		draw_line(Vector2(table.position.x - rail, grain_y), Vector2(table.end.x + rail, grain_y + 0.6), Color(0.12, 0.05, 0.02, 0.20), 1.0)
	draw_rect(Rect2(table.position.x - rail, table.position.y - 5.0, table.size.x + rail * 2.0, 5.0), Color(0, 0, 0, 0.22), true)
	draw_rect(Rect2(table.position.x - rail, table.end.y, table.size.x + rail * 2.0, 3.0), Color(0, 0, 0, 0.30), true)
	for corner in [table.position, Vector2(table.end.x, table.position.y), Vector2(table.position.x, table.end.y), table.end]:
		var cap_pos: Vector2 = corner - Vector2(rail, rail)
		draw_rect(Rect2(cap_pos, Vector2(rail * 2.0, rail * 2.0)), wood_dark)
		draw_rect(Rect2(cap_pos + Vector2(3, 3), Vector2(rail * 2.0 - 6.0, rail * 2.0 - 6.0)), wood)
		draw_rect(Rect2(cap_pos + Vector2(6, 6), Vector2(rail * 2.0 - 12.0, rail * 2.0 - 12.0)), wood_hi)
	# Rail sights at the standard eighth stations. They are the aiming language
	# of a real table and give the long rail a readable rhythm.
	var sight := Color("#f0e6cf")
	var sight_alpha := 0.72 if not settings_high_contrast else 0.95
	for i in range(1, 8):
		if i == 4:
			continue
		var sight_x := table.position.x + table.size.x * float(i) / 8.0
		_draw_rail_sight(Vector2(sight_x, table.position.y - rail * 0.5), Color(sight, sight_alpha))
		_draw_rail_sight(Vector2(sight_x, table.end.y + rail * 0.5), Color(sight, sight_alpha))
	for i in range(1, 4):
		var sight_y := table.position.y + table.size.y * float(i) / 4.0
		_draw_rail_sight(Vector2(table.position.x - rail * 0.5, sight_y), Color(sight, sight_alpha))
		_draw_rail_sight(Vector2(table.end.x + rail * 0.5, sight_y), Color(sight, sight_alpha))
	# Felt depth: a soft inward vignette plus a diagonal weave, both cheap and
	# static so the cloth reads as fabric rather than flat fill.
	for step_index in 6:
		draw_rect(table.grow(-float(step_index) * 8.0), Color(0, 0, 0, 0.045), false, 8.0)
	var weave := Color(1, 1, 1, 0.022)
	var weave_x := table.position.x - table.size.y
	while weave_x < table.end.x:
		draw_line(Vector2(weave_x, table.end.y), Vector2(weave_x + table.size.y, table.position.y), weave, 2.0)
		weave_x += 26.0
	# Warm room light on the cloth: a wide, soft ellipse centered over the rack
	# area. Without it the felt is evenly lit and the table reads as a flat
	# rectangle; with it the action has a place to happen.
	var felt_center := table.get_center() + Vector2(-30, -16)
	draw_set_transform(felt_center, 0.0, Vector2(1.0, 0.56))
	for light_index in 18:
		draw_circle(Vector2.ZERO, 470.0 - float(light_index) * 25.0, Color(1.0, 0.88, 0.60, 0.011))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# A brass nameplate on the near rail. It is the detail that makes the felt
	# a table in a room instead of a playfield in a panel.
	var plate := Rect2(table.position.x + 140.0, table.end.y + 3.0, 122.0, 14.0)
	draw_rect(plate, Color("#6b4e22"), true)
	draw_rect(plate.grow(-1.0), Color("#c9a55e"), true)
	draw_rect(plate.grow(-3.0), Color("#8d6a2e"), false, 1.0)
	draw_circle(plate.position + Vector2(5.0, 7.0), 1.6, Color("#5d4118"))
	draw_circle(Vector2(plate.end.x - 5.0, plate.get_center().y), 1.6, Color("#5d4118"))
	draw_string(DISPLAY_FONT, plate.position + Vector2(0, 11.0), "RACK & RUIN", HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, 9, Color("#2a1c0d"))
	# Cushion lip: the bed meets the rubber in a hard shadow, not a neon frame.
	# The old pulsing green outline read as a trampoline and competed with the
	# aim line for attention.
	draw_rect(table.grow(-3.0), Color("#1d5c4c"), false, 7.0)
	draw_rect(table.grow(-7.0), Color(0.01, 0.07, 0.055, 0.55), false, 3.0)
	draw_rect(table.grow(-1.0), Color(0.60, 0.86, 0.72, 0.28), false, 1.0)
	for zone in simulator.zones:
		draw_rect(zone.rect, zone.color, true)
		draw_rect(zone.rect, Color(zone.color.r + 0.25, zone.color.g + 0.18, zone.color.b + 0.10, 0.6), false, 1.5)
		var zone_label := str(zone.kind).to_upper()
		var label_pos: Vector2 = zone.rect.position + Vector2(10, 18)
		draw_rect(Rect2(label_pos + Vector2(-6, -13), Vector2(ThemeDB.fallback_font.get_string_size(zone_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 12, 17)), Color(0, 0, 0, 0.45), true)
		draw_string(ThemeDB.fallback_font, label_pos, zone_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#e6fbf7"))
	for barrier in simulator.barriers:
		# Cushioned block: shadow, dark base, bright bevel on top and left edges.
		draw_rect(Rect2(barrier.position + Vector2(3, 4), barrier.size), Color(0, 0, 0, 0.35), true)
		draw_rect(barrier, Color("#4a1a1d"), true)
		draw_rect(Rect2(barrier.position, Vector2(barrier.size.x, 4.0)), Color("#f08a6c"), true)
		draw_rect(Rect2(barrier.position, Vector2(4.0, barrier.size.y)), Color("#d9694f"), true)
		draw_rect(barrier, Color("#ee6b4f"), false, 2.0)
	_draw_house_spot()
	# The capture radius is 26-36px, so the mouth is drawn at 28: a smaller hole
	# made balls vanish from open felt, a larger one ate the rail.
	# Pockets sit ON the rail: a brass rim, a leather ring, then the hole. The
	# mouth is 26px, matching the capture radius, so a ball never vanishes from
	# open felt and never looks swallowed by the wood.
	for index in simulator.pockets.size():
		var pocket: Vector2 = simulator.pockets[index]
		if simulator.closed_pockets.has(index):
			# A bolted pocket is furniture now: brass plate, four screws and a
			# red bar. It has to read as shut from across the table.
			draw_circle(pocket, 32.0, Color("#2a1c12"))
			draw_circle(pocket, 28.0, Color("#6b4a28"))
			draw_circle(pocket, 23.0, Color("#242d31"))
			draw_circle(pocket, 23.0, Color("#9b784a"), false, 2.0)
			for screw in 4:
				draw_circle(pocket + Vector2.RIGHT.rotated(TAU * float(screw) / 4.0 + PI * 0.25) * 18.0, 2.0, Color("#d8b478"))
			draw_line(pocket + Vector2(-11, -11), pocket + Vector2(11, 11), Color("#ef6b64"), 4.0)
			draw_line(pocket + Vector2(11, -11), pocket + Vector2(-11, 11), Color("#ef6b64"), 4.0)
			continue
		# A pocket is a mouth cut into the rail: a leather collar, a brass plate
		# and the dark below it, with the plate catching the room light. The old
		# single black disc looked like a hole punched through cardboard.
		draw_circle(pocket, 36.0, Color("#1d130c"))
		draw_circle(pocket, 33.0, Color("#5b3a1e"))
		draw_circle(pocket, 30.5, Color("#b5823f"))
		draw_circle(pocket, 29.0, Color("#7a5326"))
		draw_circle(pocket, 27.0, Color(0.015, 0.025, 0.03, 0.99))
		draw_arc(pocket, 30.5, 0.0, TAU, 32, Color("#f0c67a", 0.85), 1.4)
		draw_arc(pocket, 27.4, PI * 0.10, PI * 0.90, 12, Color(0, 0, 0, 0.55), 2.0)
		draw_circle(pocket + Vector2(-24.0, 0.0), 1.8, Color("#e2c082"))
		draw_circle(pocket + Vector2(24.0, 0.0), 1.8, Color("#e2c082"))
	for flash in pocket_flashes:
		var flash_t: float = clampf(float(flash.life) / 0.65, 0.0, 1.0)
		var flash_color: Color = flash.color
		draw_circle(flash.pos, 30.0 + (1.0 - flash_t) * 36.0, Color(flash_color, flash_t * 0.10))
		draw_circle(flash.pos, 28.0 + (1.0 - flash_t) * 42.0, Color(flash_color, flash_t * 0.68), false, 3.0)
	# Aim-guide chips are collected here and drawn after the balls: CONTACT and
	# CUE STOPS sit next to the ball they describe, so drawing them first put
	# the target ball on top of its own label.
	_draw_cue_strike()
	var guide_tags := _draw_aim_guide()
	# Trails sit on the felt under every ball, oldest point faintest. Drawing a
	# dot at each sample keeps the effect cheap and readable at 60fps.
	for ball in simulator.balls:
		var trail: Array = ball_trails.get(ball.id, [])
		for i in trail.size():
			var trail_t := float(i + 1) / float(trail.size())
			draw_circle(trail[i] + Vector2(0, 1), 2.0 + trail_t * 5.0, Color(ball.color, trail_t * 0.18))
	for ball in simulator.balls:
		if ball.pocketed:
			continue
		draw_circle(ball.position + Vector2(3, 4), ball.radius, Color(0.01, 0.02, 0.025, 0.4))
		# Layer A (artist): plain base per ball type, no numbers baked in.
		# Sphere shading: dark rim, slightly lifted core, one tight specular and
		# a low crescent. Flat discs read as tokens, not billiard balls.
		draw_circle(ball.position, ball.radius, ball.color.darkened(0.18))
		draw_circle(ball.position - Vector2(1.5, 1.5), ball.radius - 2.0, ball.color)
		draw_circle(ball.position - Vector2(6, 7), 5.0, Color(1, 1, 1, 0.12))
		draw_circle(ball.position - Vector2(6.5, 7.5), 2.6, Color(1, 1, 1, 0.62))
		draw_arc(ball.position + Vector2(0, 1.5), ball.radius - 3.0, PI * 0.18, PI * 0.82, 14, Color(0, 0, 0, 0.16), 3.0)
		draw_arc(ball.position, ball.radius - 0.5, 0, TAU, 24, Color(0, 0, 0, 0.32), 1.5)
		# Layer B (code): value drawn on top so art stays number-free.
		if ball.target and int(ball.value) > 0:
			# A real pool ball carries its number on a cream disc. Drawing the
			# value straight onto the colour read as a coin; the disc makes every
			# ball a billiard ball while keeping the score legible at a glance.
			draw_circle(ball.position, ball.radius * 0.52, Color("#f2ebd8"))
			draw_circle(ball.position, ball.radius * 0.52, Color(0, 0, 0, 0.14), false, 1.0)
			var label := str(int(ball.value))
			var w := ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 13).x
			draw_string(ThemeDB.fallback_font, ball.position + Vector2(-w * 0.5, 4.5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#101a1e"))
			# The disc is opaque, so the gloss has to land on top of it: one tight
			# highlight at the upper-left keeps the ball reading as glass, not card.
			draw_circle(ball.position - Vector2(ball.radius * 0.36, ball.radius * 0.42), 2.4, Color(1, 1, 1, 0.62))
		if ball.kind == "anchor":
			draw_arc(ball.position, ball.radius + 5, 0, TAU, 20, RED, 3)
		if ball.kind == "heavy":
			draw_arc(ball.position, ball.radius - 5, 0, TAU, 16, Color(0, 0, 0, 0.4), 3.0)
	# A live streak is the table's temperature. Three pots in a row puts a
	# breathing ring around the cue ball; five makes it gold. The HUD already
	# prints the number, so this is the felt's version of the same fact.
	if combo_streak >= 3 and not duel_active and not resolving:
		var streak_cue := simulator.get_ball(simulator.cue_ball_id)
		if not streak_cue.is_empty() and not bool(streak_cue.get("pocketed", false)):
			var streak_color: Color = GOLD if combo_streak >= 5 else MINT
			var streak_pulse := 0.5 + 0.5 * sin(animation_time * 4.2)
			draw_arc(streak_cue.position, BilliardsSimulator.BALL_RADIUS + 7.0, 0.0, TAU, 30, Color(streak_color, 0.45 + streak_pulse * 0.25), 2.0)
			draw_arc(streak_cue.position, BilliardsSimulator.BALL_RADIUS + 12.0, 0.0, TAU, 30, Color(streak_color, 0.16 + streak_pulse * 0.12), 1.0)
	for tag in guide_tags:
		_draw_table_tag(tag.position, tag.text, tag.color)
	# The House's cue is a dark, red-wrapped stick, deliberately not the player's
	# pale one, so whose turn it is can be read from the felt alone.
	if house_shooting:
		var house_cue := simulator.get_ball(simulator.cue_ball_id)
		if not house_cue.is_empty() and not bool(house_cue.pocketed):
			if house_place_from != Vector2.ZERO and house_place_from.distance_to(house_cue.position) > 8.0:
				# A dashed trace makes the ball-in-hand placement read as a move,
				# not as a rendering glitch.
				_draw_dashed_line(house_place_from, house_cue.position, Color(0.94, 0.62, 0.38, 0.5), 2.0)
				draw_circle(house_place_from, BilliardsSimulator.BALL_RADIUS + 3.0, Color(0.94, 0.62, 0.38, 0.3), false, 2.0)
			var direction := house_aim.normalized()
			var pull := 20.0 + house_power * 34.0
			draw_line(house_cue.position - direction * (pull + 12.0), house_cue.position - direction * 8.0, Color("#2b1714"), 7.0)
			draw_line(house_cue.position - direction * (pull + 10.0), house_cue.position - direction * 9.0, Color("#9c4a3c"), 4.0)
			draw_circle(house_cue.position - direction * (pull + 12.0), 4.5, Color("#d9b46c"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_particles()
	_draw_floaters()
	_draw_house_turn()
	_draw_local_handoff()
	_draw_house_cam()
	if flash_time > 0.0:
		draw_rect(Rect2(0, 0, 1280, 720), Color(1, 0.9, 0.5, flash_time * 0.2), true)

# The handoff belongs on the felt, not in the dock: the next player has to
# look away from the keys and see whose turn it is before touching anything.
# A cue that vanished on the same frame as the hit made every shot feel fired
# by the UI. The strike keeps the stick on screen for a beat, pushed through
# the contact point, with a chalk flash at the tip.
func _draw_cue_strike() -> void:
	if cue_strike <= 0.0 or screen != "encounter":
		return
	var t := clampf(cue_strike / 0.16, 0.0, 1.0)
	_draw_player_cue(cue_strike_pos, cue_strike_dir, -2.0, t * 0.85)
	var tip := cue_strike_pos - cue_strike_dir * 4.0
	draw_circle(tip, 2.5 + (1.0 - t) * 5.0, Color(1.0, 0.96, 0.82, t * 0.45))

# The replay is an inset, not a screen: live play keeps running underneath,
# so a highlight is celebrated without ever taking the table away. It is drawn
# in the top-right corner of the felt, where the HUD has no controls.
func _house_cam_map(point: Vector2, fit: float, offset: Vector2) -> Vector2:
	return point * fit + offset

func _draw_house_cam() -> void:
	if not house_cam_active or screen != "encounter" or house_cam_frames.size() < 2:
		return
	var t := 1.0 - clampf(house_cam_time / maxf(house_cam_duration, 0.01), 0.0, 1.0)
	# Fade hard at both ends so the inset appears as a broadcast cut, not a card
	# that slides in from nowhere and vanishes mid-ball.
	var fade := clampf(minf(t * 8.0, (1.0 - t) * 6.0), 0.0, 1.0)
	var inset := Rect2(906, 148, 322, 198)
	var header_h := 22.0
	var frame_rect := Rect2(inset.position + Vector2(6, header_h + 6), inset.size - Vector2(12, header_h + 13))
	draw_rect(Rect2(inset.position + Vector2(3, 5), inset.size), Color(0, 0, 0, 0.40 * fade), true)
	draw_rect(inset, Color(0.035, 0.065, 0.075, 0.96 * fade), true)
	draw_rect(Rect2(inset.position, Vector2(inset.size.x, header_h)), Color(0.08, 0.13, 0.15, fade), true)
	draw_rect(inset, Color(0.95, 0.75, 0.34, 0.72 * fade), false, 1.5)
	draw_rect(frame_rect, Color(0.07, 0.23, 0.19, fade), true)
	for step_index in 3:
		draw_rect(frame_rect.grow(-float(step_index) * 7.0), Color(0, 0, 0, 0.07 * fade), false, 7.0)
	# Camera: fit the action's back half into the inset with a little air.
	var fit := minf(frame_rect.size.x / maxf(house_cam_bbox.size.x, 1.0), frame_rect.size.y / maxf(house_cam_bbox.size.y, 1.0))
	var offset := frame_rect.get_center() - house_cam_bbox.get_center() * fit
	var last := house_cam_frames.size() - 1
	var frame_pos := t * float(last)
	var i0 := clampi(int(floor(frame_pos)), 0, last)
	var i1 := mini(i0 + 1, last)
	var blend := frame_pos - float(i0)
	var frame_a: Dictionary = house_cam_frames[i0]
	var frame_b: Dictionary = house_cam_frames[i1]
	var pos_a: PackedVector2Array = frame_a.pos
	var pos_b: PackedVector2Array = frame_b.pos
	var alive_a: PackedByteArray = frame_a.alive
	var alive_b: PackedByteArray = frame_b.alive
	# Motion streaks sit under the balls and use older samples, so the inset
	# reads as movement even when the ball is only a few pixels across.
	for back in [3, 2, 1]:
		var trail_frame := maxi(i0 - back, 0)
		var trail_data: Dictionary = house_cam_frames[trail_frame]
		var trail_pos: PackedVector2Array = trail_data.pos
		var trail_alive: PackedByteArray = trail_data.alive
		var trail_alpha := fade * (0.07 + 0.05 * float(3 - back))
		for i in trail_pos.size():
			if trail_alive[i] == 0:
				continue
			var tp := _house_cam_map(trail_pos[i], fit, offset)
			if frame_rect.grow(-1.0).has_point(tp):
				draw_circle(tp, 2.0, Color(0.95, 0.88, 0.68, trail_alpha))
	for mark in house_cam_marks:
		var mp := _house_cam_map(mark, fit, offset)
		if not frame_rect.has_point(mp):
			continue
		var pulse := 0.5 + 0.5 * sin(animation_time * 6.0)
		draw_circle(mp, 7.0 + pulse * 3.0, Color(0.98, 0.82, 0.38, 0.16 * fade), false, 2.0)
		draw_circle(mp, 4.0, Color(0.98, 0.82, 0.38, 0.55 * fade))
	for i in pos_a.size():
		if alive_a[i] == 0 and alive_b[i] == 0:
			continue
		var point: Vector2
		var shrink := 1.0
		if alive_a[i] == 0:
			point = pos_b[i]
		elif alive_b[i] == 0:
			# Dropped between frames: shrink into the pocket instead of popping.
			point = pos_a[i]
			shrink = 1.0 - blend
		else:
			point = pos_a[i].lerp(pos_b[i], blend)
		var screen_point := _house_cam_map(point, fit, offset)
		if not frame_rect.has_point(screen_point):
			continue
		var ball: Dictionary = simulator.balls[i]
		var radius := clampf(BilliardsSimulator.BALL_RADIUS * fit, 3.0, 13.0) * shrink
		if radius < 0.8:
			continue
		draw_circle(screen_point + Vector2(1, 2), radius, Color(0, 0, 0, 0.35 * fade))
		draw_circle(screen_point, radius, Color(ball.color, fade))
		draw_circle(screen_point - Vector2(radius * 0.3, radius * 0.35), maxf(radius * 0.3, 1.0), Color(1, 1, 1, 0.55 * fade))
		draw_arc(screen_point, radius, 0, TAU, 16, Color(0, 0, 0, 0.30 * fade), 1.2)
		if ball.target and int(ball.value) > 0 and radius > 7.0:
			var label := str(int(ball.value))
			var label_w := ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
			draw_string(ThemeDB.fallback_font, screen_point + Vector2(-label_w * 0.5, 3.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.06, 0.08, 0.10, fade))
	# Header + caption: a tiny broadcast package around the replay itself.
	draw_string(DISPLAY_FONT, Vector2(inset.position.x + 9, inset.position.y + 17), "HOUSE CAM", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(GOLD, fade))
	var rec_x := inset.end.x - 138.0
	draw_circle(Vector2(rec_x, inset.position.y + 11), 3.0, Color(0.94, 0.32, 0.28, fade))
	draw_string(ThemeDB.fallback_font, Vector2(rec_x + 8, inset.position.y + 15), "SLOW MOTION", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.62, 0.72, 0.72, fade))
	var strip := Rect2(frame_rect.position.x, frame_rect.end.y - 23.0, frame_rect.size.x, 23.0)
	draw_rect(strip, Color(0, 0, 0, 0.55 * fade), true)
	draw_string(DISPLAY_FONT, Vector2(strip.position.x + 8, strip.position.y + 17), house_cam_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#f4ead5", fade))
	draw_string(ThemeDB.fallback_font, Vector2(strip.end.x - 62, strip.position.y + 15), "REPLAY", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.62, 0.72, 0.72, fade))

func _draw_local_handoff() -> void:
	if screen != "encounter" or not duel_local or not duel_handoff:
		return
	var accent := GOLD if duel_turn_house else MINT
	var seat := "PLAYER 2" if duel_turn_house else "PLAYER 1"
	var box := Rect2(430, 244, 420, 106)
	draw_rect(Rect2(box.position + Vector2(0, 6), box.size), Color(0.0, 0.0, 0.0, 0.45), true)
	draw_rect(box, Color(0.04, 0.09, 0.1, 0.96), true)
	draw_rect(box, accent, false, 2.0)
	draw_rect(Rect2(box.position, Vector2(5, box.size.y)), accent, true)
	draw_string(ThemeDB.fallback_font, Vector2(box.position.x, box.position.y + 30), "PASS THE CUE", HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 12, Color("#9fb6b4"))
	draw_string(ThemeDB.fallback_font, Vector2(box.position.x, box.position.y + 66), seat, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 30, accent)
	draw_string(ThemeDB.fallback_font, Vector2(box.position.x, box.position.y + 90), "PRESS FIRE OR SPACE TO TAKE THE TABLE", HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 11, Color("#d6e5e1"))

# The House's turn gets a named banner and a red rail pulse. Without it a
# portal player would think the game had taken their shot away by accident.
func _draw_house_turn() -> void:
	if screen != "encounter" or duel_local:
		return
	if house_pending <= 0.0 and not house_shooting:
		return
	var table := simulator.table_rect
	var pulse := 0.5 + 0.5 * sin(animation_time * 4.0)
	draw_rect(table.grow(-4.0), Color(0.86, 0.27, 0.22, 0.22 + pulse * 0.16), false, 3.0)
	if house_pending <= 0.0:
		draw_rect(Rect2(534, 128, 212, 26), Color(0.35, 0.08, 0.07, 0.9), true)
		draw_rect(Rect2(534, 128, 212, 26), Color(0.95, 0.45, 0.36, 0.85), false, 1.5)
		draw_string(ThemeDB.fallback_font, Vector2(534, 146), "THE HOUSE SHOOTS", HORIZONTAL_ALIGNMENT_CENTER, 212, 13, Color("#f6d7c8"))
		return
	# A duel's House does not bolt pockets or take ball in hand on Form I, so the
	# boss phase-two lecture would promise rules the match is not using. Keep the
	# short pill; the full card belongs only to the boss fight.
	if duel_active:
		draw_rect(Rect2(518, 128, 244, 26), Color(0.35, 0.08, 0.07, 0.9), true)
		draw_rect(Rect2(518, 128, 244, 26), Color(0.95, 0.45, 0.36, 0.85), false, 1.5)
		draw_string(ThemeDB.fallback_font, Vector2(518, 146), "THE HOUSE TAKES THE CUE", HORIZONTAL_ALIGNMENT_CENTER, 244, 13, Color("#f6d7c8"))
		return
	if house_turns > 0:
		draw_rect(Rect2(518, 128, 244, 26), Color(0.35, 0.08, 0.07, 0.9), true)
		draw_rect(Rect2(518, 128, 244, 26), Color(0.95, 0.45, 0.36, 0.85), false, 1.5)
		draw_string(ThemeDB.fallback_font, Vector2(518, 146), "THE HOUSE STEPS UP", HORIZONTAL_ALIGNMENT_CENTER, 244, 13, Color("#f6d7c8"))
		return
	var box := Rect2(430, 252, 420, 92)
	draw_rect(box.grow(3.0), Color(0.02, 0.02, 0.03, 0.6), true)
	draw_rect(box, Color(0.07, 0.035, 0.035, 0.96), true)
	draw_rect(box, Color(0.94, 0.42, 0.34, 0.9), false, 2.0)
	draw_rect(Rect2(box.position, Vector2(5, box.size.y)), RED, true)
	draw_string(DISPLAY_FONT, box.position + Vector2(20, 34), "THE HOUSE TAKES THE TABLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#f6d7c8"))
	draw_string(ThemeDB.fallback_font, box.position + Vector2(20, 56), "Every miss gives it the cue — and the cue goes where it likes.", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#e7b6a6"))
	draw_string(ThemeDB.fallback_font, box.position + Vector2(20, 74), "Every ball it pots bolts one pocket shut.", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#e7b6a6"))

func _draw_particles() -> void:
	for p in particles:
		draw_circle(p.pos + shake_offset, 3.0, p.color)

func _draw_floaters() -> void:
	for f in floaters:
		draw_string(ThemeDB.fallback_font, f.pos, str(f.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, f.color)

func _draw_aim_guide() -> Array:
	var tags: Array[Dictionary] = []
	if resolving or house_pending > 0.0 or house_shooting:
		return tags
	var cue := simulator.get_ball(simulator.cue_ball_id)
	if cue.is_empty() or cue.pocketed:
		return tags
	var max_dist := lerpf(260.0, 1050.0, current_power) * settings_guide
	var prediction := simulator.predict_shot(cue.position, last_aim.angle(), max_dist, current_spin)
	var points: Array = prediction.points
	for i in range(points.size() - 1):
		_draw_dashed_line(points[i], points[i + 1], Color(0.92, 0.96, 0.78, 0.88), 3.0)
	var bounces: Array = prediction.bounces
	for b in bounces.size():
		var endpoint: Vector2 = bounces[b]
		draw_circle(endpoint, 7.0, Color("#f2bd58"))
		draw_circle(endpoint, 12.0, Color(0.95, 0.75, 0.30, 0.30), false, 2.0)
		# A bounce that lands on a pocket mouth already reads as a pocket; the
		# chip used to sit on top of the hole and its ball. Only name bounces on
		# open felt, and only the first two.
		if b >= 2:
			continue
		var near_pocket := false
		for pocket in simulator.pockets:
			if endpoint.distance_to(pocket) < 62.0:
				near_pocket = true
				break
		if not near_pocket:
			tags.append({"position": endpoint + Vector2(12, -6), "text": "BOUNCE %d" % (b + 1), "color": Color("#f2bd58")})
	if bool(prediction.hit):
		var contact: Vector2 = prediction.contact
		var hit_ball: Dictionary = prediction.hit_ball
		draw_circle(contact, 8.0, Color("#8fe1bd"))
		draw_circle(hit_ball.position, BilliardsSimulator.BALL_RADIUS + 6.0, Color(0.56, 0.88, 0.74, 0.7), false, 2.5)
		draw_line(hit_ball.position, prediction.ghost_end, Color(0.56, 0.88, 0.74, 0.9), 3.0)
		draw_circle(prediction.ghost_end, 5.0, Color(0.56, 0.88, 0.74, 0.9))
		# Pocket preview: when the ghost line sends this target straight into a
		# pocket, draw the whole line and ring the pocket. A 56px direction hint
		# was not enough for a portal player to learn cut angles by themselves.
		var target_dir: Vector2 = prediction.ghost_end - hit_ball.position
		var target_pocket := _pocket_line_target(hit_ball, target_dir)
		if not target_pocket.is_empty():
			var pocket: Vector2 = target_pocket.pocket
			_draw_dashed_line(hit_ball.position, pocket, Color(0.98, 0.82, 0.38, 0.55), 2.0)
			var pulse := 0.5 + 0.5 * sin(animation_time * 5.0)
			draw_circle(pocket, 34.0 + pulse * 3.0, Color(0.98, 0.82, 0.38, 0.16 + pulse * 0.10), false, 4.0)
			draw_circle(pocket, 31.0, Color(0.98, 0.82, 0.38, 0.9), false, 2.0)
		# Onboarding label only: after the first table the ring and ghost line
		# carry the meaning, and the word collides with neighbouring balls.
		if total_runs <= 1 and run_stage <= 1:
			var contact_w := ThemeDB.fallback_font.get_string_size("CONTACT", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			tags.append({"position": hit_ball.position + Vector2(-contact_w * 0.5, -BilliardsSimulator.BALL_RADIUS - 10.0), "text": "CONTACT", "color": MINT})
		# Where the cue ball goes after contact — this is the position play the
		# guide was missing, and it is the same tangent line the physics produces.
		var cue_dir: Vector2 = prediction.cue_dir
		if cue_dir.length() > 0.1:
			# A direction, not a destination: the analytic preview stops at contact,
			# so a long line would imply a resting place it has not calculated —
			# it can run straight through a block.
			var cue_end := contact + cue_dir * 56.0
			_draw_dashed_line(contact, cue_end, Color(0.78, 0.90, 1.0, 0.9), 2.5)
			draw_circle(cue_end, 4.0, Color(0.78, 0.90, 1.0, 0.95))
		else:
			tags.append({"position": contact + Vector2(10, 12), "text": "CUE STOPS", "color": Color(0.78, 0.90, 1.0)})
	else:
		var end: Vector2 = points[points.size() - 1]
		if bool(prediction.get("blocked", false)):
			draw_line(end + Vector2(-7, -7), end + Vector2(7, 7), RED, 2.5)
			draw_line(end + Vector2(7, -7), end + Vector2(-7, 7), RED, 2.5)
			tags.append({"position": end + Vector2(12, -6), "text": "BLOCKED", "color": RED})
		else:
			draw_circle(end, 6.0, GOLD)
			draw_circle(end, 13.0, Color(0.95, 0.75, 0.30, 0.28), false, 2.0)
	# The stick, not a hairline. Pullback follows power and the tip slides to
	# the english side, so address and spin are legible before the shot.
	var direction := last_aim.normalized()
	_draw_player_cue(cue.position, direction, 10.0 + current_power * 34.0)
	return tags

# The player's own cue. It is drawn from the tip backwards so the butt can run
# off the felt and be covered by the HUD panels, exactly like a real stick held
# past the rail. The finish comes from THE CUE CASE.
func _draw_player_cue(origin: Vector2, direction: Vector2, pull: float, alpha := 1.0) -> void:
	var dir := direction.normalized()
	if dir.length_squared() < 0.5:
		return
	var palette := _cue_palette()
	var perp := Vector2(-dir.y, dir.x)
	var english := perp * (current_spin.x * 4.0)
	var tip := origin - dir * (6.0 + maxf(pull, -2.0)) + english
	# A real cue is roughly half the table long. The old 314px stick read as a
	# wand floating over the felt; this length lets the butt run off the table
	# (and under the HUD) the way a held cue does.
	var shaft_len := 268.0
	var wrap_len := 92.0
	var butt_len := 74.0
	var end := tip - dir * (shaft_len + wrap_len + butt_len + 6.0)
	var butt := Color(palette.butt, alpha)
	var wrap := Color(palette.wrap, alpha)
	var shaft := Color(palette.shaft, alpha)
	var accent := Color(palette.accent, alpha)
	# Soft drop shadow, then four tapered shaft bands. Flat one-width lines read
	# as a pool cue only from directly above; the taper sells the object.
	draw_line(end + Vector2(3, 4), tip + Vector2(3, 4), Color(0, 0, 0, 0.34 * alpha), 8.0)
	for i in 4:
		var a := tip - dir * (shaft_len * float(i) / 4.0)
		var b := tip - dir * (shaft_len * float(i + 1) / 4.0)
		draw_line(a, b, shaft, 4.1 + float(i) * 0.7)
	# Ferrule + chalked tip. The blue cue tip is the small authenticity cue
	# that says "pool" before any label does.
	draw_line(tip, tip - dir * 8.0, Color(0.96, 0.94, 0.86, alpha), 4.6)
	draw_line(tip, tip - dir * 5.0, Color(0.44, 0.70, 0.84, alpha), 4.4)
	# Joint collar, linen wrap, butt sleeve, butt cap and a gold ring at the end.
	var wrap_start := tip - dir * (shaft_len + 4.0)
	draw_line(wrap_start + dir * 3.0, wrap_start - dir * 3.0, accent, 6.2)
	var wrap_end := wrap_start - dir * wrap_len
	draw_line(wrap_start, wrap_end, wrap, 8.6)
	for i in 9:
		var p := wrap_start.lerp(wrap_end, (float(i) + 0.5) / 9.0)
		draw_line(p - perp * 3.4, p + perp * 3.4, Color(0, 0, 0, 0.22 * alpha), 1.4)
	var butt_start := wrap_end
	var butt_end := butt_start - dir * butt_len
	draw_line(butt_start, butt_end, butt, 10.0)
	draw_line(butt_start + dir * 2.0, butt_start - dir * 2.0, accent, 10.2)
	draw_line(butt_end + dir * 5.0, butt_end, accent, 9.4)
	# One long sheen along the lit edge keeps the stick from reading as a slab.
	draw_line(end + perp * 2.0, tip + perp * 1.3, Color(1, 1, 1, 0.16 * alpha), 1.4)

# Returns the pocket this target is genuinely aimed at, or {} when the line
# is not aligned or something is in the way. The threshold follows the mouth
# width with distance, so the preview never promises a pot that would miss.
func _pocket_line_target(hit_ball: Dictionary, target_dir: Vector2) -> Dictionary:
	if target_dir.length_squared() < 0.25:
		return {}
	var direction := target_dir.normalized()
	var best := {}
	var best_alignment := 0.0
	var target_position: Vector2 = hit_ball.position
	for index in simulator.pockets.size():
		if simulator.closed_pockets.has(index):
			continue
		var pocket: Vector2 = simulator.pockets[index]
		var to_pocket: Vector2 = pocket - target_position
		var distance: float = to_pocket.length()
		if distance < 48.0:
			continue
		var pocket_dir: Vector2 = to_pocket / distance
		# A 36px capture mouth minus the ball's own radius leaves a small
		# window; require the projected centre to arrive inside 22px of it.
		var required: float = distance / sqrt(distance * distance + 22.0 * 22.0)
		var alignment: float = direction.dot(pocket_dir)
		if alignment < required or alignment <= best_alignment:
			continue
		if not _guide_lane_clear(target_position, pocket, int(hit_ball.id)):
			continue
		best_alignment = alignment
		best = {"pocket": pocket, "index": index}
	return best

func _guide_lane_clear(from: Vector2, to: Vector2, skip_id: int, skip_cue := false) -> bool:
	var distance := from.distance_to(to)
	if distance < 1.0:
		return false
	var steps := maxi(10, int(distance / 16.0))
	var radius := BilliardsSimulator.BALL_RADIUS
	for step_index in range(1, steps):
		var point := from.lerp(to, float(step_index) / float(steps))
		for barrier in simulator.barriers:
			if barrier.grow(radius * 0.75).has_point(point):
				return false
		for ball in simulator.balls:
			if bool(ball.get("pocketed", true)) or int(ball.get("id", -1)) == skip_id:
				continue
			# A cue path starts ON the cue ball; without this the ball blocks
			# its own first step and every route tests as obstructed.
			if skip_cue and int(ball.get("id", -1)) == simulator.cue_ball_id:
				continue
			if point.distance_to(ball.position) < radius * 1.9:
				return false
	return true

# The brass ring is the position target. It is deliberately brighter than any
# zone and quieter than a ball: it must read at a glance without competing with
# the rack. Ticks are compass points, not decoration — they give the ring a
# centre a soft shot can be lined up against.
func _draw_house_spot() -> void:
	if duel_active or house_spot == Vector2.ZERO:
		return
	var cue := simulator.get_ball(simulator.cue_ball_id)
	var cue_near: bool = not cue.is_empty() and not bool(cue.get("pocketed", false)) and cue.position.distance_to(house_spot) < 92.0
	var pulse := (sin(animation_time * 2.4) + 1.0) * 0.5
	var brass := Color("#f2bd58") if not settings_high_contrast else Color.WHITE
	draw_circle(house_spot, 44.0, Color(0.95, 0.74, 0.35, 0.035 + pulse * 0.02))
	draw_circle(house_spot, HOUSE_SPOT_RADIUS + 4.0, Color(0.02, 0.05, 0.06, 0.45))
	draw_arc(house_spot, HOUSE_SPOT_RADIUS, 0.0, TAU, 48, Color(brass, 0.9), 3.0)
	draw_arc(house_spot, HOUSE_SPOT_RADIUS + 7.0, 0.0, TAU, 48, Color(brass, 0.20 + pulse * 0.16), 1.5)
	# Four brass compass ticks outside the ring.
	for tick in 4:
		var direction := Vector2.RIGHT.rotated(TAU * float(tick) / 4.0)
		draw_line(house_spot + direction * (HOUSE_SPOT_RADIUS + 3.0), house_spot + direction * (HOUSE_SPOT_RADIUS + 11.0), Color(brass, 0.85), 2.0)
	# Centre mark: a tiny diamond cross, never a filled dot (a dot reads as a ball).
	var mark := PackedVector2Array([
		house_spot + Vector2(0, -7),
		house_spot + Vector2(7, 0),
		house_spot + Vector2(0, 7),
		house_spot + Vector2(-7, 0),
	])
	draw_colored_polygon(mark, Color(brass, 0.85 if cue_near else 0.45))
	if cue_near:
		# A warm halo is the "you could park here" read, and it makes the ring
		# the brightest thing on the felt at the moment it matters.
		draw_arc(house_spot, HOUSE_SPOT_RADIUS - 5.0, 0.0, TAU, 40, Color(brass, 0.32 + pulse * 0.16), 2.0)
	if house_spot_flash > 0.0:
		var t := clampf(house_spot_flash / 0.9, 0.0, 1.0)
		draw_arc(house_spot, HOUSE_SPOT_RADIUS + (1.0 - t) * 46.0, 0.0, TAU, 42, Color(brass, t * 0.65), 3.0)
		_draw_table_tag(house_spot + Vector2(0, -52), "ON THE SPOT", brass)
	elif cue_near:
		# The close label is the invitation; the quiet one is the reminder. A
		# ring with no name reads as a decal to a first-time player.
		_draw_table_tag(house_spot + Vector2(0, -52), "PARK IT", brass)
	else:
		_draw_table_tag(house_spot + Vector2(0, -52), "SPOT", Color(brass, 0.62))

# Table labels get a dark chip: CONTACT and BLOCKED can land on a barrier or a
# ball, and bare red-on-dark-red was unreadable there.
func _draw_rail_sight(center: Vector2, color: Color) -> void:
	var r := 3.4
	var points := PackedVector2Array([
		center + Vector2(0, -r),
		center + Vector2(r, 0),
		center + Vector2(0, r),
		center + Vector2(-r, 0),
	])
	draw_colored_polygon(points, Color(0, 0, 0, 0.35))
	var inner := PackedVector2Array([
		center + Vector2(0, -r + 1.0),
		center + Vector2(r - 1.0, 0),
		center + Vector2(0, r - 1.0),
		center + Vector2(-r + 1.0, 0),
	])
	draw_colored_polygon(inner, color)

func _draw_table_tag(position: Vector2, text: String, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_rect(Rect2(position + Vector2(-5, -12), Vector2(width + 10, 17)), Color(0.02, 0.03, 0.04, 0.72), true)
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)

func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var distance := from.distance_to(to)
	if distance < 1.0:
		return
	var direction := (to - from).normalized()
	var cursor := 0.0
	while cursor < distance:
		var dash_start := from + direction * cursor
		var dash_end := from + direction * minf(cursor + 14.0, distance)
		draw_line(dash_start, dash_end, color, width)
		cursor += 24.0
