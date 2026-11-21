class_name ScenarioLibrary
extends RefCounted

const TABLE := Rect2(370.0, 148.0, 850.0, 398.0)

var scenarios: Array[Dictionary] = [
	{
		"id": "gatehouse",
		"name": "THE GATEHOUSE",
		"subtitle": "Open the center before the valuable line disappears.",
		"contract": "Score 95 points. Bank shots are worth extra.",
		"contract_type": "score",
		"target": 95,
		"shots": 8,
		"theme": "barrier",
		"difficulty": 1,
		"hint": "A bank around the red barrier is safe. The blue lane rewards a ball that crosses it.",
	},
	{
		"id": "frozen_lane",
		"name": "THE FROZEN LANE",
		"subtitle": "Speed survives in the blue. Control your power.",
		"contract": "Pocket 3 balls, including one through the Ice Lane.",
		"contract_type": "ice_lane",
		"target": 3,
		"shots": 9,
		"theme": "ice",
		"difficulty": 1,
		"hint": "Soft contact inside the blue lane travels farther than expected.",
	},
	{
		"id": "locksmith",
		# The boss gate below shares the family name, so the open table keeps the
		# old route name; two cards called THE LOCKSMITH read as one table twice.
		"name": "LOCKSMITH'S RUN",
		"subtitle": "Three pockets. Three keys. One clean route.",
		"contract": "Make 2 bank shots and pocket 4 balls.",
		"contract_type": "bank_count",
		"target": 2,
		"shots": 10,
		"theme": "sequence",
		"difficulty": 2,
		"hint": "Banks count as keys even when position breaks down. Plan the rail first.",
	},
	{
		"id": "the_trap",
		"name": "THE TRAP",
		"subtitle": "The cue ball is boxed in. Find the kick.",
		"contract": "Pocket 4 balls without scratching.",
		"contract_type": "no_scratch",
		"target": 4,
		"shots": 9,
		"theme": "island",
		"difficulty": 2,
		"hint": "Use the upper rail to kick around the island. Do not rush the first contact.",
	},
	{
		"id": "open_water",
		"name": "OPEN WATER",
		"subtitle": "A clean rack for build expression.",
		"contract": "Pocket 4 balls. No trick rule.",
		"contract_type": "clear",
		"target": 4,
		"shots": 8,
		"theme": "open",
		"difficulty": 1,
		"hint": "Recovery table. Cash in combo bonuses and protect your streak here.",
	},
	{
		"id": "crossfire",
		"name": "CROSSFIRE",
		"subtitle": "Clustered values reward multi-ball shots.",
		"contract": "Score 120 with at least one combo.",
		"contract_type": "combo",
		"target": 120,
		"shots": 8,
		"theme": "cluster",
		"difficulty": 2,
		"hint": "Aim through the cluster, not at it. Combos multiply the whole shot.",
	},
	{
		"id": "anchor_yard",
		"name": "ANCHOR YARD",
		"subtitle": "The red anchor resists soft shots.",
		"contract": "Pocket 4 balls. The anchor needs pace.",
		"contract_type": "clear",
		"target": 4,
		"shots": 9,
		"theme": "anchor",
		"difficulty": 3,
		"hint": "Hit the anchor hard or move it with a carom. Soft shots will die on it.",
	},
	{
		"id": "prism_vault",
		"name": "PRISM VAULT",
		"subtitle": "Light balls glide. Heavy balls punish greed.",
		"contract": "Score 140. Mixed weights change every line.",
		"contract_type": "score",
		"target": 140,
		"shots": 9,
		"theme": "vault",
		"difficulty": 3,
		"hint": "Feather the lights, drive the heavies. One power setting will not solve this.",
	},
	{
		"id": "pinwheel",
		"name": "THE PINWHEEL",
		"subtitle": "Two diagonal arms spin the rack. Every channel is a choice.",
		"contract": "Pocket 4 balls. The arms make every line a bank.",
		"contract_type": "clear",
		"target": 4,
		"shots": 9,
		"theme": "pinwheel",
		"difficulty": 2,
		"hint": "Each arm leaves a clear channel. Find the one that banks into a pocket.",
	},
	{
		"id": "split_channel",
		"name": "SPLIT CHANNEL",
		"subtitle": "One island, two open lanes. Pick a side and commit.",
		"contract": "Pocket 4 balls. Both lanes stay open.",
		"contract_type": "clear",
		"target": 4,
		"shots": 9,
		"theme": "split",
		"difficulty": 2,
		"hint": "The island blocks the middle only. Low-power lanes on either side hold position.",
	},
	{
		"id": "drift_gate",
		"name": "DRIFT GATE",
		"subtitle": "A violet field bends everything right. Aim left of the line.",
		"contract": "Score 120. Drift balls count double when they cross the field.",
		"contract_type": "score",
		"target": 120,
		"shots": 9,
		"theme": "drift",
		"difficulty": 2,
		"hint": "Play the left channel and let the drift carry the ball home. Hard shots over-bend.",
	},
	{
		"id": "dead_pocket",
		"name": "DEAD POCKET",
		"subtitle": "Mud swallows pace. Bring extra power or go around.",
		"contract": "Pocket 4 balls. The mud takes the soft option off the table.",
		"contract_type": "clear",
		"target": 4,
		"shots": 9,
		"theme": "mud",
		"difficulty": 2,
		"hint": "Drive through the mud with pace, or bank the long way around it.",
	},
	{
		"id": "spring_board",
		"name": "SPRING BOARD",
		"subtitle": "A live rail in the middle. Banks come back fast.",
		"contract": "Score 130 with at least one bank.",
		"contract_type": "bank_count",
		"target": 1,
		"shots": 9,
		"theme": "spring",
		"difficulty": 2,
		"hint": "Use the teal band as a second rail. Medium power keeps the rebound readable.",
	},
]

func get_for_seed(seed: int, completed: Array[String] = []) -> Dictionary:
	var available: Array[Dictionary] = []
	for scenario in scenarios:
		if not completed.has(scenario.id):
			available.append(scenario)
	if available.is_empty():
		available = scenarios.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(seed) * 100003 + 17
	var index := absi(rng.randi()) % available.size()
	var selected: Dictionary = available[index].duplicate(true)
	selected["seed"] = seed
	# Deterministic difficulty nudge: every 4th seed is slightly harder.
	if posmod(absi(seed), 4) == 3:
		selected["target"] = int(selected["target"]) + 10
		selected["shots"] = maxi(6, int(selected["shots"]) - 1)
		selected["hint"] = str(selected["hint"]) + " Tight rack: fewer shots, higher demand."
	return selected

func get_by_id(scenario_id: String, seed: int) -> Dictionary:
	for scenario in scenarios:
		if scenario.id == scenario_id:
			var copy: Dictionary = scenario.duplicate(true)
			copy["seed"] = seed
			return copy
	var fallback: Dictionary = scenarios[0].duplicate(true)
	fallback["seed"] = seed
	return fallback

func build_scenario(sim: BilliardsSimulator, scenario: Dictionary) -> void:
	sim.configure_table(TABLE)
	sim.reset()
	sim.layout_variant = posmod(absi(int(scenario.get("seed", 0))), 4)
	scenario["variant"] = sim.layout_variant
	match scenario.theme:
		"barrier":
			_build_gatehouse(sim)
		"ice":
			_build_frozen_lane(sim)
		"sequence":
			_build_locksmith(sim)
		"island":
			_build_trap(sim)
		"open":
			_build_open(sim, scenario)
		"cluster":
			_build_crossfire(sim, scenario)
		"anchor":
			_build_anchor(sim, scenario)
		"vault":
			_build_vault(sim, scenario)
		"pinwheel":
			_build_pinwheel(sim, scenario)
		"split":
			_build_split(sim, scenario)
		"drift":
			_build_drift(sim, scenario)
		"mud":
			_build_mud(sim, scenario)
		"spring":
			_build_spring(sim, scenario)
		_:
			_build_gatehouse(sim)
	_apply_variant(sim, scenario)
	_apply_seed_jitter(sim, scenario)

func _apply_variant(sim: BilliardsSimulator, scenario: Dictionary) -> void:
	var variant: int = int(scenario.get("variant", 0))
	if variant == 0:
		return
	if variant == 1:
		sim.add_zone(Rect2(720.0, 180.0, 120.0, 280.0), "drift", Color(0.52, 0.34, 0.78, 0.16))
		scenario.hint = str(scenario.hint) + " Variant rule: the violet drift field nudges balls right."
	elif variant == 2:
		sim.add_zone(Rect2(720.0, 180.0, 140.0, 280.0), "mud", Color(0.72, 0.45, 0.22, 0.16))
		scenario.hint = str(scenario.hint) + " Variant rule: the amber dead zone steals speed."
	else:
		sim.add_zone(Rect2(480.0, 200.0, 320.0, 160.0), "elastic", Color(0.18, 0.62, 0.75, 0.18))
		scenario.hint = str(scenario.hint) + " Variant rule: the teal band adds spring off the middle."

func _apply_seed_jitter(sim: BilliardsSimulator, scenario: Dictionary) -> void:
	# Small deterministic offsets so same scenario id plays differently per seed,
	# but identical seeds stay identical. Keeps balls inside the table.
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(int(scenario.get("seed", 1))) * 7919 + 31
	for ball in sim.balls:
		if ball.kind == "cue":
			continue
		var jx := rng.randf_range(-14.0, 14.0)
		var jy := rng.randf_range(-12.0, 12.0)
		var p: Vector2 = ball.position + Vector2(jx, jy)
		var inner := sim.table_rect.grow(-ball.radius - 6.0)
		p.x = clampf(p.x, inner.position.x, inner.end.x)
		p.y = clampf(p.y, inner.position.y, inner.end.y)
		ball.position = p

# The opening table has one job: let a first-time player pot a ball before
# the game asks them to read a cut. The authored gimme sits on the cue-to-
# bottom-right-pocket line, so a straight aim and any sane power drops it.
func _build_opening(sim: BilliardsSimulator) -> void:
	sim.configure_table(TABLE)
	sim.reset()
	sim.add_ball(Vector2(260.0, 360.0), 0, "cue", false, Color(0.94, 0.94, 0.91))
	# Authored positions map onto the live table; the cue and the bottom-right
	# pocket are collinear with the 20, giving the first shot a clean line.
	sim.add_ball(Vector2(620.0, 460.0), 20, "standard", true, Color(0.95, 0.76, 0.12))
	sim.add_ball(Vector2(500.0, 230.0), 15, "light", true, Color(0.22, 0.78, 0.42))
	sim.add_ball(Vector2(850.0, 200.0), 25, "standard", true, Color(0.95, 0.30, 0.58))
	sim.add_ball(Vector2(900.0, 400.0), 20, "standard", true, Color(0.18, 0.62, 0.93))
	sim.add_ball(Vector2(700.0, 545.0), 15, "standard", true, Color(0.68, 0.28, 0.84))
	sim.add_barrier(Rect2(950.0, 250.0, 55.0, 70.0))

# Procedural normal table: seeded barriers and balls, identical for identical seeds.
# Barriers are kept off the cue lane and shallow enough that a gap always exists.
func build_procedural(sim: BilliardsSimulator, seed: int, stage := 99) -> void:
	if stage <= 1:
		_build_opening(sim)
		return
	sim.configure_table(TABLE)
	sim.reset()
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(seed) * 6131 + 77
	sim.add_ball(Vector2(260.0, 360.0), 0, "cue", false, Color(0.94, 0.94, 0.91))
	# Opening tables stay readable for new players: at most one small block so
	# a direct line almost always exists. Later stages keep 1-3 full blocks.
	var barrier_count := rng.randi_range(1, 3)
	var max_block := 90.0
	if stage <= 2:
		barrier_count = 1
		max_block = 64.0
	var obstacles: Array[Rect2] = []
	for i in barrier_count:
		var rect := Rect2(rng.randf_range(520.0, 880.0), rng.randf_range(200.0, 520.0), rng.randf_range(40.0, max_block), rng.randf_range(40.0, max_block))
		obstacles.append(rect)
		sim.add_barrier(rect)
	var palette := [Color(0.95, 0.76, 0.12), Color(0.94, 0.25, 0.18), Color(0.18, 0.62, 0.93), Color(0.68, 0.28, 0.84), Color(0.22, 0.78, 0.42), Color(0.95, 0.30, 0.58)]
	var placed: Array[Vector2] = [Vector2(260.0, 360.0)]
	for i in 6:
		var value := rng.randi_range(15, 30)
		var kind := "light" if value <= 15 else "standard"
		var spot := _clear_spot(rng, obstacles, placed)
		if spot == Vector2.ZERO:
			continue
		placed.append(spot)
		sim.add_ball(spot, value, kind, true, palette[i % palette.size()])

# The House's private table: a clean nine-ball spread with one small seeded
# block. It has no ice lanes, anchors or shut pockets, because a duel asks a
# single question (can you hold the table?) and every extra rule would blur it.
# Nine targets make a race to five possible without ever running dry: 5 + 4 is
# the worst split, so the last ball always settles the match.
func build_duel_rack(sim: BilliardsSimulator, seed: int) -> void:
	sim.configure_table(TABLE)
	sim.reset()
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(seed) * 7717 + 313
	sim.add_ball(Vector2(260.0, 360.0), 0, "cue", false, Color(0.94, 0.94, 0.91))
	# The block is picked from hand-checked slots that never touch a ball or the
	# cue's opening line, so no seed can deal a rack with an enclosed pocket.
	var blocks := [
		Rect2(745.0, 452.0, 100.0, 38.0),
		Rect2(552.0, 182.0, 82.0, 38.0),
		Rect2(1022.0, 330.0, 38.0, 118.0),
	]
	sim.add_barrier(blocks[rng.randi_range(0, blocks.size() - 1)])
	var palette := [Color(0.95, 0.76, 0.12), Color(0.94, 0.25, 0.18), Color(0.18, 0.62, 0.93), Color(0.68, 0.28, 0.84), Color(0.22, 0.78, 0.42), Color(0.95, 0.30, 0.58)]
	var spots: Array[Vector2] = [
		Vector2(620.0, 250.0), Vector2(700.0, 330.0), Vector2(620.0, 410.0),
		Vector2(790.0, 250.0), Vector2(870.0, 330.0), Vector2(790.0, 410.0),
		Vector2(960.0, 290.0), Vector2(960.0, 420.0), Vector2(860.0, 500.0),
	]
	for i in spots.size():
		var spot: Vector2 = spots[i]
		# A few pixels of seeded drift keeps rematches from feeling stamped,
		# while staying far inside the no-overlap margin above.
		spot += Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-8.0, 8.0))
		var value := 20 if i % 2 == 0 else 15
		sim.add_ball(spot, value, "light" if value == 15 else "standard", true, palette[i % palette.size()])

# Finds a spawn point clear of every barrier and every already-placed ball, so a
# target can never start inside a block (unplayable) or overlapping another ball.
func _clear_spot(rng: RandomNumberGenerator, obstacles: Array[Rect2], placed: Array[Vector2]) -> Vector2:
	var margin := 26.0
	for _attempt in 80:
		var p := Vector2(rng.randf_range(560.0, 1080.0), rng.randf_range(200.0, 520.0))
		var blocked := false
		for rect in obstacles:
			if rect.grow(margin).has_point(p):
				blocked = true
				break
		if blocked:
			continue
		for other in placed:
			if p.distance_to(other) < 54.0:
				blocked = true
				break
		if not blocked:
			return p
	return Vector2.ZERO

# Boss tables draw from a large pool of distinct authored shapes, so each boss feels different.
func build_boss_shape(sim: BilliardsSimulator, index: int) -> void:
	sim.configure_table(TABLE)
	sim.reset()
	sim.add_ball(Vector2(260.0, 360.0), 0, "cue", false, Color(0.94, 0.94, 0.91))
	var shape := posmod(index, 4)
	match shape:
		0:
			sim.add_barrier(Rect2(560.0, 180.0, 40.0, 120.0))
			sim.add_barrier(Rect2(560.0, 420.0, 40.0, 120.0))
		1:
			sim.add_barrier(Rect2(640.0, 250.0, 200.0, 40.0))
		2:
			sim.add_barrier(Rect2(480.0, 200.0, 40.0, 320.0))
			sim.add_barrier(Rect2(760.0, 200.0, 40.0, 320.0))
		_:
			sim.add_barrier(Rect2(600.0, 300.0, 120.0, 40.0))
	sim.add_ball(Vector2(820.0, 300.0), 30, "heavy", true, Color(0.85, 0.60, 0.10))
	sim.add_ball(Vector2(900.0, 420.0), 25, "standard", true, Color(0.25, 0.60, 0.90))
	sim.add_ball(Vector2(960.0, 260.0), 25, "standard", true, Color(0.60, 0.30, 0.85))

func _build_gatehouse(sim: BilliardsSimulator) -> void:
	sim.add_barrier(Rect2(585.0, 255.0, 110.0, 190.0))
	sim.add_zone(Rect2(220.0, 285.0, 820.0, 90.0), "elastic", Color(0.18, 0.62, 0.75, 0.24))
	sim.add_ball(Vector2(260.0, 360.0), 0, "cue", false, Color(0.94, 0.94, 0.91))
	sim.add_ball(Vector2(780.0, 300.0), 20, "standard", true, Color(0.85, 0.18, 0.16))
	sim.add_ball(Vector2(880.0, 360.0), 25, "heavy", true, Color(0.95, 0.64, 0.12))
	sim.add_ball(Vector2(795.0, 420.0), 15, "standard", true, Color(0.22, 0.65, 0.90))
	sim.add_ball(Vector2(950.0, 245.0), 20, "standard", true, Color(0.57, 0.25, 0.82))
	sim.add_ball(Vector2(950.0, 475.0), 20, "standard", true, Color(0.95, 0.35, 0.60))

func _build_frozen_lane(sim: BilliardsSimulator) -> void:
	sim.add_zone(Rect2(480.0, 140.0, 170.0, 440.0), "ice", Color(0.32, 0.75, 0.95, 0.25))
	sim.add_zone(Rect2(485.0, 145.0, 160.0, 430.0), "drift", Color(0.35, 0.80, 0.98, 0.12))
	sim.add_ball(Vector2(260.0, 360.0), 0, "cue", false, Color(0.94, 0.94, 0.91))
	sim.add_ball(Vector2(545.0, 210.0), 20, "light", true, Color(0.95, 0.30, 0.16))
	sim.add_ball(Vector2(545.0, 300.0), 20, "standard", true, Color(0.94, 0.80, 0.18))
	sim.add_ball(Vector2(545.0, 420.0), 20, "standard", true, Color(0.22, 0.68, 0.92))
	sim.add_ball(Vector2(545.0, 510.0), 20, "heavy", true, Color(0.64, 0.28, 0.82))
	sim.add_ball(Vector2(900.0, 230.0), 20, "standard", true, Color(0.95, 0.35, 0.61))
	sim.add_ball(Vector2(920.0, 480.0), 20, "standard", true, Color(0.21, 0.78, 0.43))

func _build_locksmith(sim: BilliardsSimulator) -> void:
	sim.add_barrier(Rect2(515.0, 285.0, 250.0, 35.0))
	sim.add_barrier(Rect2(515.0, 400.0, 250.0, 35.0))
	sim.add_ball(Vector2(260.0, 360.0), 0, "cue", false, Color(0.94, 0.94, 0.91))
	sim.add_ball(Vector2(430.0, 360.0), 25, "standard", true, Color(0.95, 0.76, 0.12))
	sim.add_ball(Vector2(830.0, 210.0), 25, "standard", true, Color(0.94, 0.25, 0.18))
	sim.add_ball(Vector2(830.0, 510.0), 25, "standard", true, Color(0.18, 0.62, 0.93))
	sim.add_ball(Vector2(930.0, 360.0), 20, "standard", true, Color(0.68, 0.28, 0.84))
	sim.add_ball(Vector2(1030.0, 250.0), 15, "light", true, Color(0.22, 0.78, 0.42))
	sim.add_ball(Vector2(1030.0, 470.0), 15, "light", true, Color(0.95, 0.30, 0.58))

func _build_trap(sim: BilliardsSimulator) -> void:
	sim.add_barrier(Rect2(430.0, 245.0, 260.0, 230.0))
	sim.add_zone(Rect2(750.0, 180.0, 210.0, 360.0), "mud", Color(0.72, 0.45, 0.22, 0.22))
	sim.add_ball(Vector2(275.0, 360.0), 0, "cue", false, Color(0.94, 0.94, 0.91))
	sim.add_ball(Vector2(760.0, 270.0), 25, "anchor", true, Color(0.95, 0.23, 0.15))
	sim.add_ball(Vector2(850.0, 360.0), 20, "standard", true, Color(0.95, 0.76, 0.12))
	sim.add_ball(Vector2(760.0, 450.0), 20, "standard", true, Color(0.20, 0.65, 0.92))
	sim.add_ball(Vector2(1000.0, 220.0), 15, "standard", true, Color(0.67, 0.28, 0.84))
	sim.add_ball(Vector2(1000.0, 500.0), 15, "standard", true, Color(0.22, 0.78, 0.43))

func _build_open(sim: BilliardsSimulator, _scenario: Dictionary) -> void:
	sim.add_ball(Vector2(280.0, 360.0), 0, "cue", false, Color(0.94, 0.94, 0.91))
	sim.add_ball(Vector2(700.0, 280.0), 20, "standard", true, Color(0.90, 0.30, 0.20))
	sim.add_ball(Vector2(780.0, 360.0), 20, "standard", true, Color(0.95, 0.76, 0.12))
	sim.add_ball(Vector2(700.0, 440.0), 20, "standard", true, Color(0.20, 0.60, 0.90))
	sim.add_ball(Vector2(900.0, 300.0), 25, "standard", true, Color(0.30, 0.75, 0.45))
	sim.add_ball(Vector2(920.0, 430.0), 15, "light", true, Color(0.70, 0.35, 0.85))

func _build_crossfire(sim: BilliardsSimulator, _scenario: Dictionary) -> void:
	sim.add_barrier(Rect2(640.0, 150.0, 30.0, 120.0))
	sim.add_ball(Vector2(280.0, 360.0), 0, "cue", false, Color(0.94, 0.94, 0.91))
	sim.add_ball(Vector2(720.0, 330.0), 20, "standard", true, Color(0.95, 0.50, 0.12))
	sim.add_ball(Vector2(760.0, 370.0), 20, "standard", true, Color(0.95, 0.30, 0.30))
	sim.add_ball(Vector2(800.0, 340.0), 25, "heavy", true, Color(0.55, 0.30, 0.85))
	sim.add_ball(Vector2(840.0, 390.0), 15, "light", true, Color(0.25, 0.75, 0.80))
	sim.add_ball(Vector2(950.0, 300.0), 20, "standard", true, Color(0.30, 0.70, 0.40))

func _build_anchor(sim: BilliardsSimulator, _scenario: Dictionary) -> void:
	sim.add_barrier(Rect2(560.0, 180.0, 40.0, 360.0))
	sim.add_ball(Vector2(280.0, 360.0), 0, "cue", false, Color(0.94, 0.94, 0.91))
	sim.add_ball(Vector2(720.0, 280.0), 30, "anchor", true, Color(0.90, 0.25, 0.18))
	sim.add_ball(Vector2(830.0, 360.0), 20, "standard", true, Color(0.95, 0.76, 0.12))
	sim.add_ball(Vector2(720.0, 450.0), 20, "standard", true, Color(0.20, 0.60, 0.90))
	sim.add_ball(Vector2(950.0, 250.0), 20, "standard", true, Color(0.55, 0.35, 0.85))
	sim.add_ball(Vector2(980.0, 470.0), 15, "light", true, Color(0.25, 0.75, 0.50))

func _build_pinwheel(sim: BilliardsSimulator, _scenario: Dictionary) -> void:
	# Two diagonal arms with clear channels on both sides of the cue lane.
	sim.add_barrier(Rect2(600.0, 230.0, 130.0, 36.0))
	sim.add_barrier(Rect2(860.0, 430.0, 130.0, 36.0))
	sim.add_ball(Vector2(300.0, 360.0), 0, "cue", false, Color(0.94, 0.94, 0.91))
	sim.add_ball(Vector2(700.0, 420.0), 20, "standard", true, Color(0.95, 0.76, 0.12))
	sim.add_ball(Vector2(760.0, 300.0), 20, "standard", true, Color(0.94, 0.25, 0.18))
	sim.add_ball(Vector2(880.0, 300.0), 15, "light", true, Color(0.22, 0.78, 0.42))
	sim.add_ball(Vector2(930.0, 380.0), 25, "heavy", true, Color(0.18, 0.62, 0.93))
	sim.add_ball(Vector2(1000.0, 260.0), 20, "standard", true, Color(0.68, 0.28, 0.84))
	sim.add_ball(Vector2(820.0, 500.0), 20, "standard", true, Color(0.95, 0.35, 0.60))

func _build_split(sim: BilliardsSimulator, _scenario: Dictionary) -> void:
	sim.add_barrier(Rect2(680.0, 240.0, 90.0, 240.0))
	sim.add_ball(Vector2(280.0, 360.0), 0, "cue", false, Color(0.94, 0.94, 0.91))
	sim.add_ball(Vector2(620.0, 260.0), 20, "standard", true, Color(0.95, 0.76, 0.12))
	sim.add_ball(Vector2(620.0, 460.0), 20, "standard", true, Color(0.20, 0.60, 0.90))
	sim.add_ball(Vector2(880.0, 260.0), 25, "standard", true, Color(0.94, 0.25, 0.18))
	sim.add_ball(Vector2(880.0, 460.0), 25, "standard", true, Color(0.30, 0.75, 0.45))
	sim.add_ball(Vector2(1010.0, 360.0), 15, "light", true, Color(0.25, 0.75, 0.80))

func _build_drift(sim: BilliardsSimulator, _scenario: Dictionary) -> void:
	sim.add_barrier(Rect2(560.0, 180.0, 30.0, 140.0))
	sim.add_zone(Rect2(620.0, 180.0, 220.0, 360.0), "drift", Color(0.52, 0.34, 0.78, 0.16))
	sim.add_ball(Vector2(280.0, 360.0), 0, "cue", false, Color(0.94, 0.94, 0.91))
	sim.add_ball(Vector2(700.0, 300.0), 20, "standard", true, Color(0.95, 0.76, 0.12))
	sim.add_ball(Vector2(760.0, 420.0), 20, "standard", true, Color(0.22, 0.68, 0.92))
	sim.add_ball(Vector2(900.0, 280.0), 25, "standard", true, Color(0.94, 0.25, 0.18))
	sim.add_ball(Vector2(940.0, 460.0), 20, "standard", true, Color(0.30, 0.75, 0.45))
	sim.add_ball(Vector2(1020.0, 360.0), 15, "light", true, Color(0.68, 0.28, 0.84))

func _build_mud(sim: BilliardsSimulator, _scenario: Dictionary) -> void:
	sim.add_zone(Rect2(560.0, 200.0, 260.0, 320.0), "mud", Color(0.72, 0.45, 0.22, 0.22))
	sim.add_ball(Vector2(280.0, 360.0), 0, "cue", false, Color(0.94, 0.94, 0.91))
	sim.add_ball(Vector2(640.0, 280.0), 20, "standard", true, Color(0.95, 0.76, 0.12))
	sim.add_ball(Vector2(740.0, 450.0), 20, "standard", true, Color(0.20, 0.60, 0.90))
	sim.add_ball(Vector2(900.0, 300.0), 25, "heavy", true, Color(0.85, 0.60, 0.10))
	sim.add_ball(Vector2(950.0, 460.0), 20, "standard", true, Color(0.30, 0.75, 0.45))
	sim.add_ball(Vector2(1030.0, 360.0), 15, "light", true, Color(0.25, 0.75, 0.50))

func _build_spring(sim: BilliardsSimulator, _scenario: Dictionary) -> void:
	sim.add_zone(Rect2(620.0, 200.0, 200.0, 320.0), "elastic", Color(0.18, 0.62, 0.75, 0.18))
	sim.add_barrier(Rect2(880.0, 240.0, 36.0, 240.0))
	sim.add_ball(Vector2(280.0, 360.0), 0, "cue", false, Color(0.94, 0.94, 0.91))
	sim.add_ball(Vector2(700.0, 300.0), 20, "standard", true, Color(0.95, 0.76, 0.12))
	sim.add_ball(Vector2(760.0, 430.0), 20, "standard", true, Color(0.94, 0.25, 0.18))
	sim.add_ball(Vector2(960.0, 300.0), 25, "standard", true, Color(0.18, 0.62, 0.93))
	sim.add_ball(Vector2(1000.0, 440.0), 20, "standard", true, Color(0.30, 0.70, 0.40))
	sim.add_ball(Vector2(1080.0, 360.0), 15, "light", true, Color(0.70, 0.35, 0.85))

func _build_vault(sim: BilliardsSimulator, _scenario: Dictionary) -> void:
	sim.add_zone(Rect2(600.0, 160.0, 220.0, 400.0), "ice", Color(0.32, 0.75, 0.95, 0.18))
	sim.add_ball(Vector2(280.0, 360.0), 0, "cue", false, Color(0.94, 0.94, 0.91))
	sim.add_ball(Vector2(680.0, 260.0), 20, "light", true, Color(0.95, 0.45, 0.20))
	sim.add_ball(Vector2(760.0, 340.0), 30, "heavy", true, Color(0.85, 0.60, 0.10))
	sim.add_ball(Vector2(680.0, 450.0), 20, "standard", true, Color(0.25, 0.60, 0.90))
	sim.add_ball(Vector2(900.0, 280.0), 25, "standard", true, Color(0.60, 0.30, 0.85))
	sim.add_ball(Vector2(940.0, 460.0), 15, "light", true, Color(0.30, 0.75, 0.55))
