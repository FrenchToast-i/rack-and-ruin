extends SceneTree

const BilliardsSimulator = preload("res://scripts/core/billiards_simulator.gd")
const ScenarioLibrary = preload("res://scripts/core/scenario_library.gd")

func _init() -> void:
	var library := ScenarioLibrary.new()
	var first := library.get_for_seed(104729)
	var second := library.get_for_seed(104729)
	assert(first.id == second.id, "Seed must choose the same scenario")
	assert(first.target == second.target, "Seed must preserve scenario parameters")

	for seed in [1, 2, 3, 4, 5, 99, 104729]:
		var sim := BilliardsSimulator.new()
		var scenario := library.get_for_seed(seed)
		library.build_scenario(sim, scenario)
		assert(sim.balls.size() >= 5, "Scenario must contain a playable rack")
		assert(sim.pockets.size() == 6, "Table must contain six pockets")
		assert(sim.active_target_count() >= 4, "Scenario must contain target balls")
		for ball in sim.balls:
			assert(sim.table_rect.grow(-ball.radius).has_point(ball.position), "Ball must spawn inside table")

	for entry in library.scenarios:
		var sim := BilliardsSimulator.new()
		var scenario := library.get_by_id(str(entry.id), 2)
		library.build_scenario(sim, scenario)
		assert(sim.pockets.size() == 6, "Every table must contain six pockets: %s" % entry.id)
		assert(sim.active_target_count() >= 4, "Every table must contain targets: %s" % entry.id)
		for ball in sim.balls:
			assert(sim.table_rect.grow(-ball.radius).has_point(ball.position), "Ball must spawn inside table: %s" % entry.id)


	var variant_a := library.get_for_seed(1)
	var variant_b := library.get_for_seed(2)
	var variant_sim_a := BilliardsSimulator.new()
	var variant_sim_b := BilliardsSimulator.new()
	library.build_scenario(variant_sim_a, variant_a)
	library.build_scenario(variant_sim_b, variant_b)
	assert(variant_sim_a.layout_variant != variant_sim_b.layout_variant, "Different seeds must produce different table variants")

	var deterministic_a := BilliardsSimulator.new()
	var deterministic_b := BilliardsSimulator.new()
	var deterministic_scenario := library.get_for_seed(1)
	library.build_scenario(deterministic_a, deterministic_scenario)
	library.build_scenario(deterministic_b, deterministic_scenario)
	var cue_a := deterministic_a.get_ball(deterministic_a.cue_ball_id)
	var cue_b := deterministic_b.get_ball(deterministic_b.cue_ball_id)
	var shot_a := deterministic_a.set_shot(0.2, 0.7)
	var shot_b := deterministic_b.set_shot(0.2, 0.7)
	assert(shot_a.ok and shot_b.ok, "Identical deterministic shots must be accepted")
	for _i in 120:
		deterministic_a.step(1.0 / 60.0)
		deterministic_b.step(1.0 / 60.0)
	var final_a := deterministic_a.get_ball(deterministic_a.cue_ball_id)
	var final_b := deterministic_b.get_ball(deterministic_b.cue_ball_id)
	assert(final_a.position.is_equal_approx(final_b.position), "Identical shots must resolve identically")

	# Shot shape: rail contacts are counted per ball and reported on pocket events.
	# A direct shot into the side pocket at (500, 0) touches no rail: count 0.
	# A simulator needs configure_table to create pockets; the library does this for every scenario.
	var direct_sim := BilliardsSimulator.new()
	direct_sim.configure_table(Rect2(120.0, 110.0, 1040.0, 500.0))
	direct_sim.reset()
	direct_sim.add_ball(Vector2(640, 400), 0, "cue", false, Color.WHITE)
	direct_sim.add_ball(Vector2(640, 240), 20, "standard", true, Color.RED)
	direct_sim.balls[1].velocity = Vector2(0, -900)
	var direct_pocket := _run_until_pocket(direct_sim, 2)
	assert(not direct_pocket.is_empty(), "Direct shot must pocket")
	assert(int(direct_pocket.rails) == 0, "Direct pocket must report zero rails")
	# A ball driven into a rail must register that contact before it stops.
	var bank_sim := BilliardsSimulator.new()
	bank_sim.configure_table(Rect2(120.0, 110.0, 1040.0, 500.0))
	bank_sim.reset()
	bank_sim.add_ball(Vector2(640, 400), 0, "cue", false, Color.WHITE)
	bank_sim.add_ball(Vector2(400, 200), 20, "standard", true, Color.RED)
	bank_sim.balls[1].velocity = Vector2(0, -900)
	for _i in 600:
		bank_sim.step(1.0 / 60.0)
		if bank_sim.is_settled():
			break
	assert(bank_sim.get_ball(2).rails_touched >= 1, "A rail contact must be counted")

	# Aim preview: a barrier on the ray must end the preview before the far side of the table.
	var aim_sim := BilliardsSimulator.new()
	aim_sim.configure_table(Rect2(120.0, 110.0, 1040.0, 500.0))
	aim_sim.reset()
	aim_sim.add_ball(Vector2(200, 360), 0, "cue", false, Color.WHITE)
	aim_sim.add_barrier(Rect2(500, 300, 40, 120))
	var aim_cue := aim_sim.get_ball(aim_sim.cue_ball_id)
	var aim_prediction := aim_sim.predict_shot(aim_cue.position, 0.0, 1000.0)
	var aim_end: Vector2 = aim_prediction.points[aim_prediction.points.size() - 1]
	assert(aim_end.x < 500.0, "Aim preview must stop at a barrier it hits, not pass through it")

	# Procedural tables: same seed identical, different seeds differ, cue always present.
	var proc_a := BilliardsSimulator.new()
	var proc_b := BilliardsSimulator.new()
	var proc_c := BilliardsSimulator.new()
	library.build_procedural(proc_a, 42)
	library.build_procedural(proc_b, 42)
	library.build_procedural(proc_c, 43)
	assert(proc_a.balls[1].position == proc_b.balls[1].position and proc_a.barriers == proc_b.barriers, "Same seed must build the same procedural table")
	assert(proc_a.barriers != proc_c.barriers or proc_a.balls[2].position != proc_c.balls[2].position, "Different seeds must build different procedural tables")
	assert(proc_a.get_ball(proc_a.cue_ball_id).pocketed == false, "Procedural table must have a live cue ball")
	assert(proc_a.active_target_count() >= 4, "Procedural table must have targets")
	# No generated ball may start inside a barrier: that target is unplayable and
	# the aim line reads as blocked for no visible reason.
	for check_index in 40:
		var check_seed := 11 + check_index * 97
		var clear_sim := BilliardsSimulator.new()
		library.build_procedural(clear_sim, check_seed)
		assert(clear_sim.active_target_count() >= 4, "Procedural table must keep at least four targets (seed %d)" % check_seed)
		assert(clear_sim.get_ball(clear_sim.cue_ball_id).pocketed == false, "Procedural table must keep a live cue ball (seed %d)" % check_seed)
		for ball in clear_sim.balls:
			if ball.kind == "cue" or ball.pocketed:
				continue
			for block in clear_sim.barriers:
				var nearest := Vector2(
					clampf(ball.position.x, block.position.x, block.end.x),
					clampf(ball.position.y, block.position.y, block.end.y)
				)
				assert(ball.position.distance_to(nearest) > ball.radius - 0.5, "Ball must not spawn inside a barrier (seed %d)" % check_seed)

	# Boss shapes: every index builds a distinct table with a cue ball.
	for shape_index in 4:
		var boss := BilliardsSimulator.new()
		library.build_boss_shape(boss, shape_index)
		assert(boss.barriers.size() >= 1, "Boss shape must have barriers: %d" % shape_index)
		assert(boss.get_ball(boss.cue_ball_id).pocketed == false, "Boss shape must have a cue ball: %d" % shape_index)

	# Cue-ball prediction: a cut sends the cue along the tangent line, a full hit stops it.
	var cut_sim := BilliardsSimulator.new()
	cut_sim.configure_table(Rect2(120.0, 110.0, 1040.0, 500.0))
	cut_sim.reset()
	cut_sim.add_ball(Vector2(640, 400), 0, "cue", false, Color.WHITE)
	cut_sim.add_ball(Vector2(700, 366), 20, "standard", true, Color.RED)
	var cut := cut_sim.predict_shot(cut_sim.get_ball(cut_sim.cue_ball_id).position, 0.0, 1000.0)
	assert(bool(cut.hit), "Offset aim must contact the ball")
	var cut_dir: Vector2 = cut.get("cue_dir", Vector2.ZERO)
	assert(cut_dir.length() > 0.5, "A cut must leave the cue ball travelling")
	assert(absf(cut_dir.dot(cut.target_dir)) < 0.02, "Cue must leave along the tangent, not into the object ball")
	# The preview must respond to follow and draw: follow bends the cue toward the
	# object ball's line, draw bends it away.
	var aim_origin: Vector2 = cut_sim.get_ball(cut_sim.cue_ball_id).position
	var cut_follow := cut_sim.predict_shot(aim_origin, 0.0, 1000.0, Vector2(0, 1))
	var cut_draw := cut_sim.predict_shot(aim_origin, 0.0, 1000.0, Vector2(0, -1))
	var follow_along := Vector2(cut_follow.cue_dir).dot(cut_follow.target_dir)
	var draw_along := Vector2(cut_draw.cue_dir).dot(cut_draw.target_dir)
	assert(follow_along > draw_along, "Follow must bend the cue preview toward the object line more than draw")

	var stun_sim := BilliardsSimulator.new()
	stun_sim.configure_table(Rect2(120.0, 110.0, 1040.0, 500.0))
	stun_sim.reset()
	stun_sim.add_ball(Vector2(640, 400), 0, "cue", false, Color.WHITE)
	stun_sim.add_ball(Vector2(640, 340), 20, "standard", true, Color.RED)
	var stun := stun_sim.predict_shot(stun_sim.get_ball(stun_sim.cue_ball_id).position, -PI / 2.0, 1000.0)
	assert(bool(stun.hit), "Head-on aim must contact the ball")
	assert(Vector2(stun.get("cue_dir", Vector2.ZERO)).length() < 0.1, "A full hit must predict the cue ball stopping")

	# Follow/draw: the effect must match the spin applied and must not depend on
	# which ball happens to be stored first in the array.
	var follow_first := _cue_velocity_after_contact(true, 1.0)
	var follow_second := _cue_velocity_after_contact(false, 1.0)
	var draw_first := _cue_velocity_after_contact(true, -1.0)
	assert(follow_first.y < -20.0, "Follow must drive the cue through the contact")
	assert(draw_first.y > 20.0, "Draw must pull the cue back toward the player")
	assert(absf(follow_first.y - follow_second.y) < 1.0, "Follow must be identical regardless of ball order")

	# The House Duel rack is its own generator: deterministic per seed, nine
	# targets, no overlapping balls, and nothing spawned inside a block or rail.
	for duel_seed in [1, 424242, 777]:
		var duel_a := BilliardsSimulator.new()
		var duel_b := BilliardsSimulator.new()
		library.build_duel_rack(duel_a, duel_seed)
		library.build_duel_rack(duel_b, duel_seed)
		assert(duel_a.active_target_count() == 9, "A duel rack must hold nine targets")
		assert(duel_a.balls.size() == 10, "A duel rack must hold nine targets and one cue")
		for i in duel_a.balls.size():
			var ball_a: Dictionary = duel_a.balls[i]
			assert(duel_a.table_rect.grow(-ball_a.radius).has_point(ball_a.position), "Duel ball must spawn inside the felt")
			for barrier in duel_a.barriers:
				assert(not barrier.grow(ball_a.radius * 0.75).has_point(ball_a.position), "Duel ball must not spawn inside a block")
			for j in range(i + 1, duel_a.balls.size()):
				var ball_b: Dictionary = duel_a.balls[j]
				assert(ball_a.position.distance_to(ball_b.position) >= ball_a.radius * 2.0 - 1.0, "Duel balls must not overlap")
		assert(duel_a.balls[4].position.is_equal_approx(duel_b.balls[4].position), "A duel seed must deal the same rack")

	print("Rack & Ruin smoke test passed")
	quit(0)

# Fires a head-on shot with the given top/back spin and returns the cue velocity
# at the moment of first contact.
func _cue_velocity_after_contact(cue_added_first: bool, spin_y: float) -> Vector2:
	var sim := BilliardsSimulator.new()
	sim.configure_table(Rect2(120.0, 110.0, 1040.0, 500.0))
	if cue_added_first:
		sim.add_ball(Vector2(640, 400), 0, "cue", false, Color.WHITE)
		sim.add_ball(Vector2(640, 300), 20, "standard", true, Color.RED)
	else:
		sim.add_ball(Vector2(640, 300), 20, "standard", true, Color.RED)
		sim.add_ball(Vector2(640, 400), 0, "cue", false, Color.WHITE)
	var cue_id := sim.cue_ball_id
	sim.set_shot(-PI / 2.0, 0.5, Vector2(0, spin_y))
	for _i in 240:
		sim.step(1.0 / 60.0)
		if sim.get_ball(cue_id).first_contact_target_id != -1:
			break
	return sim.get_ball(cue_id).velocity

func _run_until_pocket(sim: BilliardsSimulator, ball_id: int) -> Dictionary:
	for _i in 600:
		for event in sim.step(1.0 / 60.0):
			if event.type == "pocket" and event.ball_id == ball_id:
				return event
		if sim.is_settled():
			break
	return {}
