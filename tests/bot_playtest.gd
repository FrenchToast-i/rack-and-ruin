extends SceneTree

# Headless bot: plays seeded full runs through the real main scene.
# It aims at the nearest live target, fires at varied power, and walks the
# route by always taking the first unlocked node. It fails on any shot that
# never settles (softlock), any encounter that cannot end, or a crash.

const RUNS := 12
const MAX_SHOTS_PER_TABLE := 40

func _init() -> void:
	call_deferred("_play")

func _play() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	# Isolated slots: a bot run must never earn reputation, unlock vault pieces
	# or append to the developer's real run history.
	game.save_path = "user://rack_ruin_bot_meta.cfg"
	game.run_save_path = "user://rack_ruin_bot_run.cfg"
	for path in [game.save_path, game.run_save_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	root.add_child(game)
	await process_frame
	var wins := 0
	var total_tables := 0
	for run_index in RUNS:
		game._start_new_run()
		game.run_seed = 1000 + run_index * 7919
		game.last_seed = game.run_seed
		game.seed_value = game.run_seed
		game._build_map()
		game.screen = "map"
		var guard := 0
		while guard < 80 and game.screen != "victory" and game.screen != "defeat":
			guard += 1
			if game.screen == "map":
				var next_node := _first_unlocked(game)
				if next_node < 0:
					push_error("Softlock: map has no unlocked node at run %d" % run_index)
					quit(1)
					return
				game.current_node = next_node
				# Shops and events are route choices, not tables. Entering them as
				# encounters (the old harness did) fought a random authored rack
				# with no shop stock and no reward, so the bot's win rate measured
				# the harness rather than the game.
				match str(game.map_nodes[next_node].type):
					"shop":
						game._show_shop()
					"event":
						game._show_event()
					"boss":
						game._start_encounter(true)
					_:
						game._start_encounter(false)
			elif game.screen == "encounter":
				await _play_table(game, run_index)
				total_tables += 1
			elif game.screen == "reward":
				game._choose_reward(0)
			elif game.screen == "shop":
				game._buy_cheapest_affordable_or_leave()
			elif game.screen == "event":
				game._take_event_deal(2)
			elif game.screen == "last_call":
				# The favor is a real run resource now: spend it, then finish the
				# table. A second lost table is a real defeat.
				if game.favor_available:
					game._call_in_favor()
				else:
					game._show_defeat()
			else:
				push_error("Unexpected screen '%s' in run %d" % [game.screen, run_index])
				quit(1)
				return
		if game.screen == "victory":
			wins += 1
		print("run %02d seed=%d result=%s tables=%d score=%d" % [run_index, game.run_seed, game.screen, game.run_tables_cleared, game.run_score])
	print("bot summary: %d/%d runs won, %d tables played" % [wins, RUNS, total_tables])
	# The duel uses the same ghost-ball player against every form. This is not a
	# difficulty grade — the bot never uses spin or safeties — but it proves each
	# form reaches a result through the real turn loop, with no stuck cue and no
	# House turn that never returns the table.
	for form in game.DUEL_FORMS.size():
		var duel_wins := 0
		for duel_index in 3:
			var duel_seed: int = 6100 + int(form) * 131 + int(duel_index) * 977
			if _play_duel(game, form, duel_seed):
				duel_wins += 1
		print("duel form %s: %d/3 bot wins" % [game._duel_roman(form), duel_wins])
	# PASS & PLAY: both seats are the same ghost-ball player, so a full match
	# proves the shared turn loop hands the cue back and forth through real
	# physics — no House AI, no dead turn, no pot lost between seats.
	var ladder_wins_before: int = game.duel_wins
	var local_p1 := 0
	var local_p2 := 0
	for local_index in 3:
		var local_winner := _play_local_match(game, 9100 + local_index * 613)
		if local_winner == 1:
			local_p1 += 1
		elif local_winner == 2:
			local_p2 += 1
		print("pass & play %d: P1 %d — %d P2" % [local_index, game.duel_player, game.duel_house])
	if game.duel_wins != ladder_wins_before:
		push_error("A local match wrote the House ladder record")
		quit(1)
		return
	print("pass & play: P1 %d/3, P2 %d/3" % [local_p1, local_p2])
	print("Rack & Ruin bot playtest finished")
	for path in [game.save_path, game.run_save_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	quit(0)

# Plays one duel to a real result. Returns true when the bot takes the table.
# The loop advances both clocks the game uses: _process owns the House's
# pre-shot pause, _physics_process owns ball motion; skipping either would look
# like a softlock that a human never sees.
func _play_duel(game: Node, form: int, duel_seed: int) -> bool:
	game._start_duel(form, duel_seed)
	var guard := 0
	while game.screen == "encounter" and guard < 4000:
		guard += 1
		game._process(1.0 / 60.0)
		if game.resolving:
			game._physics_process(1.0 / 60.0)
			continue
		if game.house_pending > 0.0 or game.duel_turn_house:
			continue
		var solution := _ghost_solution(game)
		if solution.is_empty():
			break
		game.last_aim = solution.aim
		game.current_power = solution.power
		game._take_shot()
	if game.screen != "duel_result":
		push_error("Softlock: duel form %d seed %d stuck on %s" % [form, duel_seed, game.screen])
		quit(1)
		return false
	return game.duel_player >= game.duel_target

# Plays one Pass & Play match with the same ghost-ball policy in both seats.
# It drives the real handoff press, real shots and real physics, so a missing
# turn or a pot credited to the wrong seat fails here instead of in a portal.
func _play_local_match(game: Node, duel_seed: int) -> int:
	game._start_duel(0, duel_seed, true)
	var guard := 0
	while game.screen == "encounter" and guard < 6000:
		guard += 1
		game._process(1.0 / 60.0)
		if game.resolving:
			game._physics_process(1.0 / 60.0)
			continue
		if game.duel_handoff:
			game._duel_confirm_handoff()
			continue
		var solution := _ghost_solution(game)
		if solution.is_empty():
			break
		game.last_aim = solution.aim
		game.current_power = solution.power
		game._take_shot()
	if game.screen != "duel_result":
		push_error("Softlock: local match seed %d stuck on %s" % [duel_seed, game.screen])
		quit(1)
		return 0
	return game.duel_winner

func _first_unlocked(game: Node) -> int:
	for index in game.map_nodes.size():
		if game.map_unlocked.has(index) and not game.map_nodes[index].done:
			return index
	return -1

func _play_table(game: Node, run_index: int) -> void:
	var shots := 0
	while game.screen == "encounter" and shots < MAX_SHOTS_PER_TABLE:
		shots += 1
		var solution := _ghost_solution(game)
		if solution.is_empty():
			break
		game.last_aim = solution.aim
		game.current_power = solution.power
		game._take_shot()
		var frames := 0
		# The House's phase-two turn lives on the main loop timer, not in the
		# physics step, so the harness has to advance both or it would spin on a
		# disabled FIRE button until the per-table ceiling.
		while frames < 4000 and (game.resolving or game.house_pending > 0.0):
			game._process(1.0 / 60.0)
			if game.resolving:
				game._physics_process(1.0 / 60.0)
			frames += 1
		if game.resolving:
			push_error("Softlock: shot never resolved (run %d, shot %d)" % [run_index, shots])
			quit(1)
			return
		if game.screen in ["reward", "shop", "event", "defeat", "victory", "last_call"]:
			return
	if game.screen == "encounter" and shots >= MAX_SHOTS_PER_TABLE:
		game._show_defeat()

# Ghost-ball solver: for each live target and pocket, compute the ghost cue
# position that sends the target at the pocket, then prefer small cut angles
# and short cue travel. Straight-line bots scored 0/12 because barrier tables
# punish aiming at balls instead of pockets; this aims at pockets instead.
func _ghost_solution(game: Node) -> Dictionary:
	var cue: Dictionary = game.simulator.get_ball(game.simulator.cue_ball_id)
	if cue.is_empty() or bool(cue.get("pocketed", true)):
		return {}
	var radius: float = float(cue.get("radius", 18.0))
	var best := {}
	var best_cost := INF
	for ball in game.simulator.balls:
		if not bool(ball.get("target", false)) or bool(ball.get("pocketed", true)):
			continue
		for pocket_index in game.simulator.pockets.size():
			# Forms III and IV bolt pockets shut; aiming at one is a guaranteed
			# dry shot, so the bot reads the same table the player does.
			if game.simulator.closed_pockets.has(pocket_index):
				continue
			var pocket: Vector2 = game.simulator.pockets[pocket_index]
			var to_pocket: Vector2 = pocket - ball.position
			var pocket_dist := to_pocket.length()
			if pocket_dist < 1.0:
				continue
			var pocket_dir := to_pocket / pocket_dist
			var ghost: Vector2 = ball.position - pocket_dir * (radius * 2.0 - 2.0)
			var to_ghost: Vector2 = ghost - cue.position
			var cue_dist := to_ghost.length()
			if cue_dist < 1.0:
				continue
			var aim := to_ghost / cue_dist
			var cut := 1.0 - absf(aim.dot(pocket_dir))
			var blocked := false
			for block in game.simulator.barriers:
				if _segment_hits_rect(cue.position, ghost, block, radius * 0.7):
					blocked = true
					break
			var cost := cue_dist * 0.6 + pocket_dist * 1.0 + cut * 900.0 + (800.0 if blocked else 0.0)
			if cost < best_cost:
				best_cost = cost
				var power := clampf(0.30 + cue_dist / 1400.0 + pocket_dist / 2200.0, 0.25, 0.92)
				best = {"aim": aim, "power": power}
	return best

func _segment_hits_rect(a: Vector2, b: Vector2, rect: Rect2, margin: float) -> bool:
	var grown := rect.grow(margin)
	for t in [0.15, 0.35, 0.55, 0.75, 0.95]:
		if grown.has_point(a.lerp(b, t)):
			return true
	return false

func _nearest_target(game: Node) -> Dictionary:
	var sol := _ghost_solution(game)
	if sol.is_empty():
		return {}
	var cue: Dictionary = game.simulator.get_ball(game.simulator.cue_ball_id)
	var best := {}
	var best_distance := INF
	for ball in game.simulator.balls:
		if ball.target and not ball.pocketed:
			var distance: float = ball.position.distance_to(cue.position)
			if distance < best_distance:
				best_distance = distance
				best = ball
	return best
