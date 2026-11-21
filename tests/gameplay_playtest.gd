extends SceneTree

const SimulatorScript = preload("res://scripts/core/billiards_simulator.gd")

func _init() -> void:
	call_deferred("_play")

func _play() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	assert(game.screen == "title", "Game must boot into title screen")
	# The finish case is part of the front door: a returning player must be able
	# to see the stick they earned without digging through the vault.
	assert(_button_labels(game.screen_root).has("CUE CASE"), "The title must open THE CUE CASE")
	# Hermetic save slots: a developer's real unlocks, streak and run must not
	# change what the assertions see, and a failing run must not poison the next.
	game.save_path = "user://rack_ruin_test_meta.cfg"
	game.run_save_path = "user://rack_ruin_test_run.cfg"
	for path in [game.save_path, game.run_save_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	game.reputation = 0
	game.best_score = 0
	game.total_runs = 0
	game.run_log = []
	game.daily_streak = 0
	game.daily_last_date = ""
	game.daily_best = 0
	game.daily_best_key = ""
	game.unlocks.clear()
	game.permanent_shot_bonus = 0
	game.tutorial_seen = false
	game.trophies.clear()
	game.runs_finished = 0
	game.wins = 0
	game.tables_cleared = 0
	game.best_tables = 0
	game.best_shot_ever = 0
	game.best_streak_ever = 0
	game.bosses_beaten = 0
	game.best_bosses_in_run = 0
	game.scouted.clear()
	game.dailies_played = 0
	game.best_daily_streak = 0
	game.best_build = 0
	game.best_set_tier = 0
	game.best_sets_in_run = 0
	game.stake2_wins = 0
	game.house_spot_hits = 0
	game.duel_wins = 0
	game.duel_streak = 0
	game.duel_best_streak = 0
	game.duel_best_form = 0
	game.gauntlet_active = false
	game.gauntlet_best_stage = 0
	game.gauntlet_best_score = 0
	game.grind_daily_active = false
	game.grind_daily_key = ""
	game.grind_daily_best_stage = 0
	game.grind_daily_best_score = 0
	game.grind_daily_last_date = ""
	game.grind_daily_streak = 0
	game.grind_daily_rep_key = ""
	game.grind_pace_splits.clear()
	game.grind_daily_pace_splits.clear()
	game.run_pace_splits.clear()
	game.run_pace_target.clear()
	game._start_new_run()
	assert(game.screen == "map", "New run must open the map")
	assert(game.map_unlocked == [0], "A new route must begin at one starting node")
	assert(game.pending_node == 0, "A one-option map must preselect the only node")
	assert(_button_labels(game.screen_root).has("ENTER TABLE"), "A preselected node must offer one-click entry")
	# The House has to be present on the route it owns, not only at the last node.
	assert(_label_texts(game.screen_root).has("THE HOUSE"), "The map must carry the House's line")
	assert(game._house_taunt() != "", "The House must always have something to say")
	# A mouse is not guaranteed on a portal. Every menu must leave one control
	# focused or Enter / pad A cannot act at all.
	assert(game.node_buttons.has(game.get_viewport().gui_get_focus_owner()), "The map must focus a route node")
	game._select_node(4)
	assert(game.screen == "map", "Unconnected map nodes must not be selectable")
	game.current_node = 0
	game._start_encounter(false)
	assert(game.screen == "encounter", "Selecting a table must open encounter screen")
	assert(game.coach_active, "A first run's opening table must open the coach")
	assert(game._coach_step() == 0, "The coach must start on the aim step")
	assert(game.simulator.table_rect.position.x >= 350.0, "Encounter table must be inside the framed board")
	var cue: Dictionary = game.simulator.get_ball(game.simulator.cue_ball_id)
	assert(game.simulator.table_rect.grow(-cue.radius).has_point(cue.position), "Cue ball must spawn inside framed table")
	var target := {}
	for ball in game.simulator.balls:
		if ball.target:
			target = ball
			break
	assert(not target.is_empty(), "Encounter must contain a target")
	game.last_aim = (target.position - cue.position).normalized()
	game.current_power = 0.55
	var outside_click := InputEventMouseButton.new()
	outside_click.button_index = MOUSE_BUTTON_LEFT
	outside_click.pressed = true
	outside_click.position = Vector2(90, 90)
	game._input(outside_click)
	assert(not game.resolving, "Clicks outside the board must not fire")
	var power_before: float = game.current_power
	var power_key := InputEventKey.new()
	power_key.keycode = KEY_W
	power_key.pressed = true
	game._input(power_key)
	assert(game.current_power > power_before, "Power control must respond to keyboard input")
	var meter_power: float = game.current_power
	game._set_power_from_pointer(1120.0)
	assert(game.current_power > meter_power, "Power meter must respond to direct adjustment")
	assert(game.coach_powered, "Power input must tick the coach's power step")
	var aim_motion := InputEventMouseMotion.new()
	aim_motion.position = target.position
	game._input(aim_motion)
	assert(game.coach_aimed and game._coach_step() == 2, "Aiming must tick the coach and move it to firing")
	var fire_key := InputEventKey.new()
	fire_key.keycode = KEY_SPACE
	fire_key.pressed = true
	game._input(fire_key)
	assert(game.resolving, "Firing a valid shot must enter resolution")
	for _i in 500:
		game._physics_process(0.05)
		if not game.resolving:
			break
	assert(not game.resolving, "Shot resolution must always terminate")
	assert(game.shot_number == 1, "A single fire input must produce one shot")
	assert(not game.coach_active and game.tutorial_seen, "Firing must retire the first-shot coach")
	# A controller player must be able to aim, not just fire and adjust power.
	assert(game._aim_with_stick(Vector2.DOWN), "A gamepad stick must set the shot direction")
	assert(game.last_aim.is_equal_approx(Vector2.DOWN), "Stick aim must point the cue ball at the stick direction")
	assert(not game._aim_with_stick(Vector2(0.1, 0.0)), "The stick dead zone must be ignored")
	assert(game.last_aim.is_equal_approx(Vector2.DOWN), "A centered stick must not change aim")
	var tutorial_cfg := ConfigFile.new()
	var tutorial_saved := tutorial_cfg.load(game.save_path) == OK and bool(tutorial_cfg.get_value("meta", "tutorial_seen", false))
	assert(tutorial_saved, "A retired coach must stay retired across sessions")
	var contact_sim = SimulatorScript.new()
	contact_sim.configure_table(Rect2(120, 110, 1040, 500))
	contact_sim.add_ball(Vector2(260, 360), 0, "cue", false)
	contact_sim.add_ball(Vector2(520, 360), 20, "standard", true)
	contact_sim.set_shot(0.0, 0.45)
	var saw_first_contact := false
	for _step in 120:
		var contact_events: Array[Dictionary] = contact_sim.step(0.05)
		for contact_event in contact_events:
			if contact_event.type == "first_contact": saw_first_contact = true
		if saw_first_contact: break
	assert(saw_first_contact, "A legal shot must record first target contact")
	var seen_reward_ids := {}
	for item in game.reward_catalog:
		assert(not seen_reward_ids.has(str(item.id)), "Reward ids must be unique: %s" % item.id)
		seen_reward_ids[str(item.id)] = true
	game._show_reward()
	assert(game.screen == "reward", "A reward screen must be reachable after a table")
	assert(game.get_viewport().gui_get_focus_owner() is Button, "The reward room must focus a piece for keyboard and controller players")
	assert(game.reward_offers.size() == 3, "Reward room must offer three named build pieces")
	var offer_ids := {}
	for offer in game.reward_offers:
		offer_ids[str(offer.id)] = true
	assert(offer_ids.size() == 3, "Reward room must not repeat an offer")
	var offered_disciplines := {}
	for offer in game.reward_offers:
		offered_disciplines[game._archetype(offer)] = true
	assert(offered_disciplines.size() == 3, "Reward offers must come from three different disciplines")
	assert(game.reward_offers[0].has("type"), "Reward offers must identify their item type")
	for discipline in ["BANK", "COMBO", "RAIL", "CONTROL", "TEMPO"]:
		assert(game._discipline_role(discipline) != "", "Every discipline needs a one-line role: %s" % discipline)
		assert(game._archetype_color(discipline) != Color.TRANSPARENT, "Every discipline needs an identity colour: %s" % discipline)
	game._choose_reward(0)
	assert(not game.collection.is_empty(), "Named reward choice must affect the active build")
	assert(not game._archetype_counts().is_empty(), "A taken piece must register in the build identity")
	game._show_shop()
	assert(game.screen == "shop", "Shop screen must be reachable")
	assert(game.get_viewport().gui_get_focus_owner() is Button, "The shop must focus a control for keyboard and controller players")
	# An empty wallet must say what is missing instead of showing a dead BUY.
	var shop_cash: int = game.run_cash
	game.run_cash = 0
	game._draw_shop()
	var saw_shortfall := false
	for label in _button_labels(game.screen_root):
		if label.begins_with("NEED "):
			saw_shortfall = true
	assert(saw_shortfall, "An unaffordable shop piece must name the cash shortfall")
	game.run_cash = shop_cash
	game._draw_shop()
	game._show_collection()
	assert(game.screen == "collection", "Collection screen must be reachable")
	# Deep banks: a target pocketed after 3 rails must score more than one pocketed after 1 rail.
	game._start_encounter(false)
	var scored_ball := {}
	for ball in game.simulator.balls:
		if ball.target:
			scored_ball = ball
			break
	var shallow_score := _score_pocket(game, scored_ball, 1)
	var deep_score := _score_pocket(game, scored_ball, 3)
	assert(deep_score > shallow_score, "A 3-rail bank must score more than a 1-rail bank")
	# The bonus feeds the same multipliers as every other shot value, so the gap is at least the raw bonus.
	assert(deep_score - shallow_score >= 2 * game.DEEP_BANK_BONUS, "Each extra rail must add at least the deep-bank bonus")
	# A rail stroke that pockets nothing is a miss and must not pay. The old
	# runner paid 3 per cushion, so a player could clear a score contract
	# without ever dropping a target.
	game.rail_bonus = 0
	assert(_score_miss(game, scored_ball, 2) == 0, "A shot with no pocket must not score")
	game.rail_bonus = 5
	game.run_best_shot = 0
	assert(_score_miss(game, scored_ball, 2) > 0, "Rail-pay pieces must still pay per cushion")
	assert(game.run_best_shot == 0, "A rail-pay miss must not set a best-shot record")
	game.rail_bonus = 0
	assert(game._shot_tags(2, 0, true) == "MISS", "Rails without a pocket are not a bank tag")
	assert(game._shot_tags(0, 1, false) == "CLEAN", "A straight pot must read CLEAN")
	assert(game._shot_tags(1, 1, true) == "BANK", "A target off one rail that drops must read BANK")
	assert(game._shot_tags(3, 1, true) == "DEEP BANK", "Two or more target rails must read DEEP BANK")
	assert(game._shot_tags(1, 1, false) == "KICK", "A cue-ball rail before a pot must read KICK")
	# The aim guide promises a pocket only when the target's direction actually
	# lands inside the mouth and nothing blocks the line.
	var guide_sim = SimulatorScript.new()
	guide_sim.configure_table(Rect2(120, 110, 1040, 500))
	guide_sim.add_ball(Vector2(400, 360), 0, "cue", false)
	var guide_id: int = guide_sim.add_ball(Vector2(900, 250), 20, "standard", true)
	var guide_ball: Dictionary = guide_sim.get_ball(guide_id)
	var guide_pocket: Vector2 = guide_sim.pockets[1]
	var preview_aim: Vector2 = (guide_pocket - guide_ball.position).normalized()
	game.simulator = guide_sim
	var guide_hit: Dictionary = game._pocket_line_target(guide_ball, preview_aim)
	assert(not guide_hit.is_empty() and int(guide_hit.index) == 1, "A clear pocket line must be previewed")
	game.simulator.add_barrier(Rect2(980, 190, 50, 60))
	assert(game._pocket_line_target(guide_ball, preview_aim).is_empty(), "A blocked pocket line must not be promised")
	game._start_new_run()
	game.current_node = 0
	game._start_encounter(false)
	game.current_node = 10
	game._show_boss_intro()
	assert(game.screen == "boss_intro", "Boss nodes must show their rule before the table")
	# The gate preview must quote the stake-adjusted target and shot budget.
	game.stake = 2
	game._show_boss_intro()
	var stake_intro_ok := false
	for text in _label_texts(game.screen_root):
		if text.contains("145 score in 9 shots"):
			stake_intro_ok = true
	assert(stake_intro_ok, "A Stake 2 boss intro must quote its real target and budget")
	game.stake = 0
	game._show_boss_intro()
	game.next_shot_modifier = -1
	game._start_encounter(true)
	assert(game.shots_remaining == 9, "Boss encounters must use their contract shot count plus preparation modifiers")
	game.resolving = false
	game.shot_events.clear()
	game.shots_remaining = 5
	game._finish_shot()
	assert(game.shots_remaining == 3, "A boss foul must cost exactly two shots")
	game._start_encounter(true)
	assert(game.shots_remaining == 10, "Restarting the boss must restore its shot budget")
	game._take_shot()
	assert(game.resolving, "Boss shot must enter resolution")
	game._show_map()
	assert(not game.resolving, "Leaving during a shot must cancel physics cleanly")
	game._show_settings()
	assert(game.screen == "settings", "Settings screen must be reachable")
	# A locked finish must stay locked, and the one you take must survive a save.
	game._show_cue_case()
	assert(game.screen == "cue_case", "The cue case must be reachable")
	assert(game._cue_unlocked("ash"), "The starting finish must always be available")
	assert(not game._cue_unlocked("brass"), "A trophy finish must start locked")
	game._equip_cue_finish("brass")
	assert(game.cue_finish == "ash", "A locked finish must not equip")
	game.trophies.append("first_break")
	game._show_cue_case()
	assert(game._cue_unlocked("brass"), "Earning the trophy must unlock its finish")
	game._equip_cue_finish("brass")
	assert(game.cue_finish == "brass", "An unlocked finish must equip")
	assert(game._cue_palette("brass").butt != game._cue_palette("ash").butt, "Each finish must have its own palette")
	var cue_cfg := ConfigFile.new()
	assert(cue_cfg.load(game.save_path) == OK and str(cue_cfg.get_value("meta", "cue_finish", "")) == "brass", "The chosen finish must persist")
	game._equip_cue_finish("ash")
	game.trophies.erase("first_break")
	var case_escape := InputEventKey.new()
	case_escape.keycode = KEY_ESCAPE
	case_escape.pressed = true
	game._input(case_escape)
	assert(game.screen == "title", "Escape must back out of the cue case like every other menu")
	# House cam only replays a genuine highlight, and its own timer must end it.
	assert(game._house_cam_caption(2, false) == "DOUBLE POT", "Two pots must caption as a double")
	assert(game._house_cam_caption(1, true) == "BANKED POT", "A banked pot must caption as a bank")
	assert(game._house_cam_caption(0, false) == "", "A dry shot must not be replayed")
	game.house_cam_frames.clear()
	for _frame in 6:
		game._capture_house_cam_frame()
	game._maybe_start_house_cam(2, false, false)
	assert(game.house_cam_active and game.house_cam_caption == "DOUBLE POT", "A highlight must start the inset replay")
	game._process(3.0)
	assert(not game.house_cam_active, "The inset must dismiss itself without blocking play")
	var house_cam_before: bool = game.settings_house_cam
	game._toggle_house_cam()
	assert(game.settings_house_cam != house_cam_before, "House cam must be switchable off")
	var cam_cfg := ConfigFile.new()
	assert(cam_cfg.load(game.save_path) == OK and bool(cam_cfg.get_value("settings", "house_cam", not house_cam_before)) == game.settings_house_cam, "The house cam preference must persist")
	game._toggle_house_cam()
	game._show_settings()
	game._start_encounter(false)
	# Spend the favor first: this assertion covers the no-rescue defeat path.
	game.favor_available = false
	game.shots_remaining = 0
	game._finish_shot()
	assert(game.screen == "defeat", "An exhausted encounter must end the run")
	game._show_map()
	game._open_settings_from_map()
	assert(game.menu_return_screen == "map", "Settings opened from map must remember its return destination")
	game.current_node = game.map_nodes.size() - 1
	game._complete_current_node()
	assert(game.screen == "victory", "Completing the bottom House node must win the run")
	game._start_new_run()
	# A single route must never schedule the same table twice.
	var scheduled := {}
	for node in game.map_nodes:
		var sid := str(node.get("scenario_id", ""))
		if sid == "" or str(node.type) == "boss":
			continue
		assert(not scheduled.has(sid), "A run must not schedule the same table twice: %s" % sid)
		scheduled[sid] = true
	var first_seed: int = game.run_seed
	game._retry_seed()
	assert(game.run_seed == first_seed, "Retry seed must replay the same tables")
	assert(game.screen == "map", "Retry seed must open the map")
	# Cards must read as distinct tables. An elite that draws the boss scenario
	# used to put two THE LOCKSMITH cards on one route.
	var route_seed: int = game.run_seed
	for probe in 24:
		game.run_seed = 1000 + probe * 613
		game._build_map()
		var seen_names := {}
		for node in game.map_nodes:
			var card_name := str(node.name).to_lower()
			assert(not seen_names.has(card_name), "Map cards must not repeat a name: %s" % node.name)
			seen_names[card_name] = true
	game.run_seed = route_seed
	game._build_map()
	game.current_node = 0
	game._start_encounter(false)
	game._toggle_pause()
	assert(game.paused, "Pause must engage during an encounter")
	game._toggle_pause()
	assert(not game.paused, "Resume must disengage pause")
	game._toggle_pause()
	game._take_shot()
	assert(game.shot_number == 0, "Paused encounters must not fire")
	game._toggle_pause()
	game.current_node = 10
	game._start_encounter(true)
	game.score = 100
	game._check_boss_phase()
	assert(game.boss_phase == 1, "Bosses must escalate at half score")
	game.current_node = 11
	game._start_encounter(true)
	game.score = int(game.scenario.target) / 2
	game._check_boss_phase()
	assert(game.boss_phase == 1, "The House must reach phase two at half its target")
	# The House's advertised phase rule is now a real opponent: every pocket
	# starts open, a miss hands it the cue, and a pot lets it bolt one pocket.
	assert(game.simulator.pockets.size() == 6, "The House must start with every pocket open")
	assert(game._house_should_shoot(0), "A missed shot must hand the cue to the House")
	assert(not game._house_should_shoot(1), "A pot must keep the House seated")
	# Deterministic House pot: one target, one corner, no obstruction, no jitter.
	game.house_aim_error = 0.0
	game.simulator.reset()
	game.simulator.configure_table(Rect2(120, 110, 1040, 500))
	var hcue: int = game.simulator.add_ball(Vector2(420, 360), 0, "cue", false)
	var htarget: int = game.simulator.add_ball(Vector2(960, 500), 30, "standard", true, Color("#d8b44a"))
	var hdir := (Vector2(1160, 610) - Vector2(960, 500)).normalized()
	var hcue_ball: Dictionary = game.simulator.get_ball(hcue)
	hcue_ball.position = Vector2(960, 500) - hdir * 260.0
	var score_before: int = game.score
	var shots_before: int = game.shots_remaining
	game._house_take_shot()
	assert(game.house_shooting, "A House turn must fire the cue")
	var hframes := 0
	while game.resolving and hframes < 4000:
		game._physics_process(1.0 / 60.0)
		hframes += 1
	assert(not game.resolving and not game.house_shooting, "A House shot must settle")
	assert(game.simulator.closed_pockets.size() == 1, "A House pot must bolt exactly one pocket")
	assert(game.simulator.active_target_count() == 1, "The House must spot its capture back on the felt")
	assert(game.simulator.get_ball(htarget).pocketed == false, "The spotted target must be live again")
	assert(game.score == score_before, "The House's own pot must not pay the player's contract")
	assert(game.shots_remaining == shots_before, "The House shooting must never cost the player a shot")
	assert(game.pocketed_count == 0, "A House pot must not count as the player's pocket")
	for hball in game.simulator.balls:
		if bool(hball.get("pocketed", false)) or int(hball.id) == hcue:
			continue
		assert(hball.position.distance_to(hcue_ball.position) >= BilliardsSimulator.BALL_RADIUS * 2.0, "A spotted ball must not overlap the cue")
	# A bolted pocket is physics, not paint: a ball resting in it stays live.
	var closed_sim = SimulatorScript.new()
	closed_sim.configure_table(Rect2(120, 110, 1040, 500))
	var shut_id: int = closed_sim.add_ball(closed_sim.pockets[3], 20)
	closed_sim.close_pocket(3)
	for shut_step in 20:
		closed_sim.step(1.0 / 60.0)
	assert(not bool(closed_sim.get_ball(shut_id).pocketed), "A shut pocket must not capture a ball")
	# A queued House turn owns the cue: the fire path must decline it.
	game.house_pending = 0.0
	game.current_power = 0.5
	game._queue_house_turn()
	assert(game.house_pending > 0.0, "A House turn must announce itself before it fires")
	game._take_shot()
	assert(not game.resolving, "A queued House turn must block the player's fire")
	game._cancel_active_shot()
	game.house_aim_error = 0.035
	game._show_shop()
	assert(game.shop_offers.size() == 3, "Shops must stock three named pieces")
	assert(str(game.shop_offers[0].id) != str(game.shop_offers[1].id), "Shop stock must not repeat")
	# Route depth and cleared tables are separate counters: a shop advances the
	# route but must never inflate "TABLES CLEARED" in the summary or trophies.
	game._start_new_run()
	game.current_node = 1
	game._show_shop()
	game._advance_after_stop()
	assert(game.run_stage == 2 and game.run_tables_cleared == 0, "A shop must not count as a cleared table")
	assert(not game.run_log.is_empty(), "Completed runs must append to run history")
	game._start_new_run()
	game.current_node = 0
	game.run_stage = 2
	game.run_cash = 99
	game.favor_available = false
	game._save_run()
	assert(game._has_run_save(), "Map boundaries must persist a continuable run")
	game.run_cash = 0
	game.run_stage = 1
	game.favor_available = true
	assert(game._load_run(), "A saved run must reload")
	assert(game.run_cash == 99 and game.run_stage == 2, "Reloaded runs must restore cash and stage")
	assert(not game.favor_available, "A spent favor must stay spent when a run is continued")
	assert(game.screen == "map", "Reloaded runs must resume at the map")
	game._clear_run_save()
	game._start_new_run()
	# A shop is not a table; its commit button must say so.
	game.pending_node = 1
	game._show_map(true)
	assert(_button_labels(game.screen_root).has("ENTER SHOP"), "A shop node must offer ENTER SHOP, not ENTER TABLE")
	game._select_node(0)
	assert(game.screen == "map" and game.pending_node == 0, "First tap must preview, not enter")
	game._select_node(0)
	assert(game.screen == "encounter", "Second tap must enter the previewed node")
	game._show_practice()
	assert(game.screen == "encounter" and game.shots_remaining == 99, "Practice must open a pressure-free table")
	game._show_title()
	assert(game.screen_root.get_child_count() == 1, "Switching screens must clear the previous screen, not draw over it")
	game._show_howto()
	assert(game.screen == "howto", "How to Play must be reachable from the title")
	var howto_labels := _button_labels(game.screen_root)
	assert(howto_labels.has("TRY PRACTICE TABLE"), "How to Play must lead into practice")
	game._show_practice()
	assert(game.screen == "encounter", "The How to Play practice button must open a table")
	game._show_title()
	# A saved run must offer a fresh run as well as continue; a CONTINUE-only
	# title traps players in a run they no longer want.
	game.run_stage = 2
	game._save_run()
	game._show_title()
	var title_labels := _button_labels(game.screen_root)
	assert(title_labels.has("START NEW RUN"), "Title with a save must still offer a fresh run")
	assert(title_labels.has("CONTINUE RUN"), "Title with a save must offer continue")
	assert(title_labels.has("HOW TO PLAY"), "Title must link the how-to screen")
	game._clear_run_save()
	game._start_new_run()
	game.current_node = 3
	game._show_event()
	assert(game.screen == "event", "Event screen must be reachable")
	assert(game.event_choices.size() == 3, "Events must offer three choices")
	game._take_event_deal(2)
	assert(game.screen == "reward", "Resolving an event must advance the route")
	game._clear_run_save()
	game._continue_run()
	assert(game.screen == "map", "Continue with no save must start a fresh run")
	game.current_node = 0
	game._start_encounter(false)
	assert(game.current_spin == Vector2.ZERO, "A fresh table must start with centred spin")
	var pad_center: Vector2 = game.SPIN_PAD_RECT.get_center()
	var pad_tap := InputEventMouseButton.new()
	pad_tap.button_index = MOUSE_BUTTON_LEFT
	pad_tap.pressed = true
	pad_tap.position = pad_center + Vector2(0, -22)
	game._input(pad_tap)
	assert(game.current_spin.y > 0.0, "Tapping above the spin pad centre must set follow")
	var aim_before: Vector2 = game.last_aim
	var pad_drag := InputEventMouseMotion.new()
	pad_drag.position = pad_center + Vector2(0, 30)
	pad_drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	game._input(pad_drag)
	assert(game.current_spin.y < 0.0, "Dragging below the spin pad centre must set draw")
	assert(game.last_aim == aim_before, "Spin drags must not swing the aim")
	# The HUD is not a table: moving the pointer to FIRE used to swing the cue at
	# the button before the shot, and a touch there did the same.
	var aim_hud: Vector2 = game.last_aim
	var fire_point: Vector2 = game.HUD_DOCK_RECT.position + Vector2(450, 58)
	var hud_move := InputEventMouseMotion.new()
	hud_move.position = fire_point
	game._input(hud_move)
	assert(game.last_aim == aim_hud, "Mouse motion over the HUD must not aim")
	var brief_move := InputEventMouseMotion.new()
	brief_move.position = game.HUD_BRIEF_RECT.get_center()
	game._input(brief_move)
	assert(game.last_aim == aim_hud, "Mouse motion over the table brief must not aim")
	var hud_tap := InputEventScreenTouch.new()
	hud_tap.position = fire_point
	hud_tap.pressed = true
	game._input(hud_tap)
	assert(game.last_aim == aim_hud, "A touch on the HUD must not aim")
	var felt_move := InputEventMouseMotion.new()
	felt_move.position = game.simulator.get_ball(game.simulator.cue_ball_id).position + Vector2(-120, 40)
	game._input(felt_move)
	assert(game.last_aim != aim_hud, "Mouse motion over the felt must aim")
	game._set_power_from_pointer(320.0)
	assert(game.current_power <= 0.09, "Meter left edge must read near minimum")
	game._set_power_from_pointer(660.0)
	assert(game.current_power >= 0.99, "Meter right edge must read near full")
	# The HUD updates in place. Rebuilding it on every power tick restarted the
	# screen fade and stole focus from FIRE, which read as a strobe while dragging.
	var hud_before: Node = game.hud_root
	var root_before: Node = game.screen_root.get_child(0)
	assert(is_instance_valid(hud_before), "Encounter must build a live HUD")
	game._set_power_from_pointer(640.0)
	assert(game.hud_root == hud_before, "Power changes must update the HUD, not rebuild it")
	assert(game.screen_root.get_child(0) == root_before, "Power changes must keep the same screen root")
	assert(game.hud_power_label.text == "100%", "Power change must refresh the readout")
	game._toggle_pause()
	assert(game.screen_root.get_child_count() == 2, "Pause must layer over the encounter, not replace it")
	assert(is_instance_valid(game.hud_root), "Pausing must not clear the encounter HUD")
	game._toggle_pause()
	assert(game.screen_root.get_child_count() == 1, "Resuming must remove the pause layer")
	# The Vault: reputation buys permanent upgrades that apply to normal tours
	# only, and the meta file is the thing that makes them permanent.
	var saved_rep: int = game.reputation
	var saved_unlocks: Array[String] = game.unlocks.duplicate()
	game.reputation = 4
	game.unlocks.clear()
	game._buy_unlock("cue_rack")
	assert(game.unlocks.is_empty() and game.reputation == 4, "The vault must refuse an unlock under its cost")
	game.reputation = 5
	game._show_vault()
	assert(game.screen == "vault", "The vault screen must be reachable")
	game._buy_unlock("cue_rack")
	assert(game._has_unlock("cue_rack") and game.reputation == 0, "An unlock must cost its stated reputation")
	game._show_title()
	assert(_button_labels(game.screen_root).has("THE VAULT"), "The title must link the vault")
	game._buy_unlock("cue_rack")
	assert(game.reputation == 0, "Buying an owned unlock must not charge again")
	game._start_new_run()
	assert(game.active_cue_id == "surveyor", "The cue rack must change the starting cue")
	assert(game.bank_bonus >= 10, "The cue rack must grant its bank bonus")
	game.reputation = 14
	game._buy_unlock("house_credit")
	assert(game.reputation == 0 and game._has_unlock("house_credit"), "House credit must buy at its stated price")
	game._show_title()
	var title_texts := _label_texts(game.screen_root)
	assert(title_texts.has("THE SURVEYOR"), "The title loadout must show the unlocked cue")
	var shows_unlocked_cash := false
	for text in title_texts:
		if text.begins_with("080 CASH"):
			shows_unlocked_cash = true
	assert(shows_unlocked_cash, "The title loadout must show the unlocked starting cash")
	game.unlocks.append("allowance")
	game._start_new_run()
	game.current_node = 0
	game._start_encounter(false)
	assert(game.shots_remaining == int(game.scenario.shots) + 1, "Felt allowance must add a shot to every table")
	game.run_stage = 2
	game._save_run()
	game.permanent_shot_bonus = 0
	assert(game._load_run() and game.permanent_shot_bonus == 1, "A continued run must keep its vault shot bonus")
	game._clear_run_save()
	game._start_daily()
	var twist_today: Dictionary = game._daily_twist(game.daily_key)
	assert(game.run_cash == 60 + int(twist_today.get("cash", 0)), "The daily twist must shape starting cash")
	assert(game.bank_bonus == int(twist_today.get("bank", 0)), "The daily twist must shape bank pay")
	assert(game.rail_bonus == int(twist_today.get("rail", 0)), "The daily twist must shape rail pay")
	assert(game.side_pocket_bonus == int(twist_today.get("side", 0)), "The daily twist must shape side-pocket pay")
	assert(game.permanent_shot_bonus == int(twist_today.get("shots", 0)), "The daily twist must shape the shot budget")
	game.current_node = 0
	game.tutorial_seen = false
	game._start_encounter(false)
	assert(game.coach_active, "A first daily table must teach a new player the controls")
	game.coach_active = false
	game.tutorial_seen = true
	assert(game.active_cue_id == "house", "Dailies must ignore vault cues")
	assert(game.shots_remaining == int(game.scenario.shots) + int(twist_today.get("shots", 0)), "Dailies must keep the level shot budget plus the day's twist")
	game._save_meta()
	game.unlocks.clear()
	game.reputation = 0
	game._load_meta()
	assert(game._has_unlock("cue_rack") and game._has_unlock("allowance") and game._has_unlock("house_credit"), "Vault unlocks must survive a reload")
	game.unlocks = saved_unlocks
	game.reputation = saved_rep
	game._save_meta()
	game._start_new_run()
	# An affordable piece is offered on the run summary, so the rep just earned
	# is one click from being spent.
	game.reputation = 5
	game.unlocks.clear()
	game._show_run_summary(false, true)
	assert(_button_labels(game.screen_root).has("SPEND REP IN THE VAULT"), "An affordable vault piece must be offered on the run summary")
	game.reputation = saved_rep
	game.unlocks = saved_unlocks
	game._save_meta()
	game._start_new_run()
	# Daily challenge: date-seeded, streak-aware, and never allowed to eat an
	# in-progress run save.
	assert(game._daily_seed_for("2026-11-08") == game._daily_seed_for("2026-11-08"), "A daily seed must be stable for its date")
	assert(game._daily_seed_for("2026-11-08") != game._daily_seed_for("2026-11-09"), "Each day must seed a different tour")
	var saved_streak: int = game.daily_streak
	var saved_last: String = game.daily_last_date
	var saved_daily_best: int = game.daily_best
	var saved_daily_key: String = game.daily_best_key
	game.daily_streak = 0
	game.daily_last_date = ""
	game.daily_best = 0
	game.daily_best_key = ""
	game._record_daily_result("2026-01-01", 120)
	assert(game.daily_streak == 1 and game.daily_best == 120, "The first daily must start a one-day streak")
	game._record_daily_result("2026-01-01", 90)
	assert(game.daily_streak == 1 and game.daily_best == 120, "A same-day replay must not raise the streak or lower the best")
	game._record_daily_result("2026-01-02", 200)
	assert(game.daily_streak == 2 and game.daily_best == 200, "Playing the next day must extend the streak")
	game._record_daily_result("2026-01-05", 50)
	assert(game.daily_streak == 1 and game.daily_best == 50, "A missed day must reset the streak and the day's best")
	game.daily_streak = saved_streak
	game.daily_last_date = saved_last
	game.daily_best = saved_daily_best
	game.daily_best_key = saved_daily_key
	assert(game._today_key().length() == 10, "The daily key must be a calendar date")
	# The daily card counts down to the next tour, so a returning player knows
	# how long today's challenge is still open.
	var reset_secs: int = game._seconds_to_daily_reset()
	assert(reset_secs >= 0 and reset_secs <= 86400, "The daily reset must land inside the next day")
	assert(str(game._daily_reset_label()).begins_with("NEW DAILY"), "The daily reset must be labelled")
	game._show_title()
	var saw_reset := false
	for text in _label_texts(game.screen_root):
		if text.begins_with("NEW DAILY"):
			saw_reset = true
	assert(saw_reset, "The title daily card must show the next-daily countdown")
	# Daily twists: a stable date-picked modifier, always from the deck and
	# always changing something the scoring already understands.
	var twist_ids := {}
	for twist in game.DAILY_TWISTS:
		assert(not twist_ids.has(str(twist.id)), "Daily twist ids must be unique: %s" % twist.id)
		twist_ids[str(twist.id)] = true
		assert(str(twist.name) != "" and str(twist.body) != "", "Every daily twist needs a name and a rule")
		assert(twist.has("bank") or twist.has("rail") or twist.has("side") or twist.has("cash") or twist.has("shots") or str(twist.get("table", "")) != "", "Every daily twist must change something")
	assert(twist_ids.has(str(game._daily_twist("2026-11-08").id)), "The daily twist must come from the deck")
	assert(game._daily_twist("2026-11-08").id == game._daily_twist("2026-11-08").id, "The daily twist must be stable for its date")
	# A normal tour never inherits the daily twist's modifiers.
	var normal_saved_unlocks: Array[String] = game.unlocks.duplicate()
	game.unlocks.clear()
	game._start_new_run()
	assert(game.run_cash == 60 and game.bank_bonus == 0 and game.rail_bonus == 0 and game.side_pocket_bonus == 0, "Normal runs must not inherit daily twist pay")
	assert(game.permanent_shot_bonus == 0, "Normal runs must not inherit the daily twist shot")
	game.unlocks = normal_saved_unlocks
	game._start_new_run()
	game.current_node = 0
	game.run_stage = 2
	game._save_run()
	assert(game._has_run_save(), "A run save must exist before the daily starts")
	game._start_daily()
	assert(game.daily_active and game.daily_key == game._today_key(), "Starting the daily must mark the run as daily")
	assert(game._has_run_save(), "Starting the daily must not delete an in-progress run")
	game._save_run()
	assert(game._has_run_save(), "A daily must not overwrite the normal run save")
	var daily_seed: int = game.run_seed
	game._retry_seed()
	assert(game.daily_active and game.run_seed == daily_seed, "Retrying the daily must replay the same day as a daily")
	# A daily pays reputation once per day; replays are for score and streak.
	var rep_before_daily: int = game.reputation
	game.daily_rep_key = ""
	game._record_run_end(false)
	assert(game.reputation == rep_before_daily + 1, "The first daily of a day must pay reputation")
	game._record_run_end(false)
	assert(game.reputation == rep_before_daily + 1, "A same-day daily replay must not pay reputation twice")
	# The summary names the day's twist, not just "daily".
	game._show_run_summary(false, true)
	var twist_on_summary := false
	for text in _label_texts(game.screen_root):
		if text.begins_with("DAILY") and text.contains(str(twist_today.name)):
			twist_on_summary = true
	assert(twist_on_summary, "The run summary must name the daily twist")
	# Daily table rules rebuild the rack itself: no blocks, corners only, or
	# slick felt. Each must show up on the table and reset on the next one.
	game._start_new_run()
	game.current_node = 0
	game._start_encounter(false)
	var table_pockets: int = game.simulator.pockets.size()
	assert(table_pockets == 6, "A normal table must keep all six pockets")
	game._apply_table_rule("corner")
	assert(game.simulator.pockets.size() == 4 and game.simulator.pocket_kinds.count("corner") == 4, "Corner-only must leave four corner pockets")
	game._start_encounter(false)
	assert(game.simulator.pockets.size() == table_pockets, "A fresh table must restore closed side pockets")
	game._apply_table_rule("open")
	assert(game.simulator.barriers.is_empty(), "The open-table rule must strip every block")
	game._start_encounter(false)
	assert(not game.simulator.barriers.is_empty(), "A fresh table must restore its blocks")
	var base_friction: float = game.simulator.friction
	game._apply_table_rule("fast")
	assert(game.simulator.friction < base_friction, "Slick felt must reduce friction")
	game._start_encounter(false)
	assert(is_equal_approx(game.simulator.friction, base_friction), "A fresh table must reset the felt speed")
	# A real daily date applies its rule to a route table and states it in the
	# brief; the rule must never leak into the next normal table.
	var rule_day := ""
	for day in 90:
		var day_key := Time.get_date_string_from_unix_time(Time.get_unix_time_from_datetime_string("2026-01-01T00:00:00") + day * 86400)
		if str(game._daily_twist(day_key).get("table", "")) != "":
			rule_day = day_key
			break
	assert(rule_day != "", "The twist deck must include at least one table rule")
	game.daily_active = true
	game.daily_key = rule_day
	game.current_node = 0
	game._start_encounter(false)
	match str(game._daily_twist(rule_day).get("table", "")):
		"open":
			assert(game.simulator.barriers.is_empty(), "A daily open-table day must clear the rack")
		"corner":
			assert(game.simulator.pockets.size() == 4, "A daily corner-only day must close the side pockets")
		"fast":
			assert(game.simulator.friction < base_friction, "A daily slick-felt day must change the felt")
	assert(str(game.scenario.hint).contains("Daily rule"), "The table brief must state the daily table rule")
	# A corner-only day must not sell side-pocket pieces that can never pay.
	var corner_day := ""
	for day in 400:
		var day_key := Time.get_date_string_from_unix_time(Time.get_unix_time_from_datetime_string("2026-01-01T00:00:00") + day * 86400)
		if str(game._daily_twist(day_key).get("table", "")) == "corner":
			corner_day = day_key
			break
	assert(corner_day != "", "The twist deck must include a corner-only day")
	game.daily_key = corner_day
	var side_free := true
	for item in game._reward_pool():
		if int(item.get("side", 0)) > 0:
			side_free = false
	assert(side_free, "A corner-only daily must not offer side-pocket pieces")
	game.daily_active = false
	game.daily_key = ""
	game._start_encounter(false)
	assert(is_equal_approx(game.simulator.friction, base_friction) and game.simulator.pockets.size() == table_pockets, "A normal table after a daily rule must be a normal table")
	game._clear_run_save()
	# Practice is the explicit teaching space, so a first-time player sees the
	# coach there too.
	game.tutorial_seen = false
	game.daily_active = false
	var saved_node: int = game.current_node
	game.current_node = -1
	game._start_coach_if_new(false)
	assert(game.coach_active, "Practice must show the coach to a first-time player")
	game.coach_active = false
	game.current_node = saved_node
	game.tutorial_seen = true
	# The opening table is the first impression: a small clear, not a 95-point
	# score ask that can end a new player's tour before they pocket twice.
	game._start_new_run()
	game.current_node = 0
	game._start_encounter(false)
	assert(str(game.scenario.contract_type) == "clear", "The opening table must ask for pockets, not a score total")
	assert(int(game.scenario.target) <= 3, "The opening table must ask for at most three pockets")
	assert(game.shots_remaining >= 10, "The opening table must leave room to miss")
	assert(str(game.scenario.hint).contains("FIRE SHOT"), "The opening brief must name the shot control")
	assert(game.simulator.active_target_count() == 5, "The opening rack must hold five targets")
	# The first shot must teach success: one target sits on the cue-to-corner
	# line, with a clear pocket preview. A new player can aim at it and drop it.
	var opening_cue: Dictionary = game.simulator.get_ball(game.simulator.cue_ball_id)
	var opening_pocket: Vector2 = game.simulator.pockets[3]
	var opening_line: Vector2 = opening_pocket - opening_cue.position
	var opening_gimme := {}
	var opening_offset := INF
	for ball in game.simulator.balls:
		if not bool(ball.get("target", false)):
			continue
		var offset: float = absf((ball.position - opening_cue.position).cross(opening_line))
		if offset < opening_offset:
			opening_offset = offset
			opening_gimme = ball
	assert(opening_offset < 2.0, "The opening rack must line one target up with the cue and a pocket")
	var opening_dir: Vector2 = (opening_pocket - opening_gimme.position).normalized()
	assert(not game._pocket_line_target(opening_gimme, opening_dir).is_empty(), "The opening gimme must show a clear pocket line")
	# RETRY TABLE must deal the same rack: fishing for an easier layout on R
	# breaks both the seed promise and the authored difficulty curve.
	var retry_table_seed: int = game.seed_value
	game._start_encounter(false)
	assert(game.seed_value == retry_table_seed, "Retrying a table must deal the same seed and layout")
	# THE HOUSE'S SPOT: every scored table owns one open position target, and a
	# pot that leaves the cue on it pays score, heat, and one shot back per rack.
	assert(game.house_spot != Vector2.ZERO, "A scored table must place a House's Spot")
	assert(game.simulator.table_rect.grow(-40.0).has_point(game.house_spot), "The House's Spot must be on open felt")
	for spot_ball in game.simulator.balls:
		if bool(spot_ball.get("pocketed", false)):
			continue
		assert(spot_ball.position.distance_to(game.house_spot) >= 40.0, "The House's Spot must not spawn under a ball")
	var spot_cue: Dictionary = game.simulator.get_ball(game.simulator.cue_ball_id)
	spot_cue.position = game.house_spot
	var spot_score: int = game.score
	var spot_shots: int = game.shots_remaining
	var spot_heat: float = game.heat
	game.last_result = "POT"
	assert(game._try_park_house_spot(), "The cue resting on the House's Spot must park")
	assert(game.score == spot_score + 10, "A park must pay ten score")
	assert(game.shots_remaining == spot_shots + 1, "The first park on a table must return one shot")
	assert(game.heat > spot_heat, "A park must charge House Heat")
	assert(game.house_spot != Vector2.ZERO and game.house_spot.distance_to(spot_cue.position) > 40.0, "A park must move the spot for the next shot")
	# The refund is once per table; a second park still pays the score line.
	spot_cue.position = game.house_spot
	spot_score = game.score
	spot_shots = game.shots_remaining
	assert(game._try_park_house_spot(), "A second park must still pay")
	assert(game.score == spot_score + 10, "Every park must pay its score")
	assert(game.shots_remaining == spot_shots, "Only the first park on a table may refund a shot")
	assert(game.house_spot_hits == 2, "Lifetime parks must be counted for the trophy shelf")
	spot_cue.position = game.house_spot + Vector2(120, 0)
	assert(not game._try_park_house_spot(), "A cue away from the ring must not park")
	# THE HOUSE MARK turns one park per table into a repeatable position engine.
	game._apply_reward(game._reward_by_id("house_mark"))
	assert(game.house_spot_boost == 1, "The House Mark must own the spot boost")
	for mark_park in 2:
		spot_cue.position = game.house_spot
		spot_score = game.score
		spot_shots = game.shots_remaining
		assert(game._try_park_house_spot(), "The House Mark must allow repeated parks")
		assert(game.score == spot_score + 15, "The House Mark must raise a park to fifteen")
		assert(game.shots_remaining == spot_shots + 1, "The House Mark must return a shot on every park")
	# A scratch used to drop the cue on the table centre even when a ball was
	# already there. The recovered cue must never overlap a live ball or block.
	var scratch_cue: Dictionary = game.simulator.get_ball(game.simulator.cue_ball_id)
	var scratch_blocker := {}
	for ball in game.simulator.balls:
		if bool(ball.get("target", false)):
			scratch_blocker = ball
			break
	scratch_blocker.position = game.simulator.table_rect.get_center()
	scratch_cue.pocketed = true
	game._recover_cue()
	assert(not bool(scratch_cue.pocketed), "A recovered cue must be live")
	for ball in game.simulator.balls:
		if bool(ball.get("pocketed", false)) or int(ball.id) == game.simulator.cue_ball_id:
			continue
		assert(scratch_cue.position.distance_to(ball.position) >= BilliardsSimulator.BALL_RADIUS * 2.0, "A recovered cue must not spawn inside a ball")
	for barrier in game.simulator.barriers:
		assert(not barrier.grow(BilliardsSimulator.BALL_RADIUS).has_point(scratch_cue.position), "A recovered cue must not spawn inside a block")
	# Trophies: unique milestones, paid once, persisted, and shown on their own
	# screen reachable from the title. The stats settle at run end so a partial
	# or abandoned table cannot unlock one.
	var trophy_ids := {}
	for trophy in game.TROPHIES:
		assert(not trophy_ids.has(str(trophy.id)), "Trophy ids must be unique: %s" % trophy.id)
		trophy_ids[str(trophy.id)] = true
		assert(str(trophy.name) != "" and str(trophy.body) != "", "Every trophy needs a name and a rule")
		assert(int(trophy.rep) >= 1, "Every trophy must pay reputation")
	game.trophies.clear()
	game.unlocks.clear()
	game.reputation = 0
	game.runs_finished = 0
	game.wins = 0
	game.tables_cleared = 0
	game.best_tables = 0
	game.best_shot_ever = 0
	game.best_streak_ever = 0
	game.bosses_beaten = 0
	game.best_bosses_in_run = 0
	game.scouted.clear()
	game.dailies_played = 0
	game.best_daily_streak = 0
	game.best_build = 0
	game.best_set_tier = 0
	game.best_sets_in_run = 0
	game.stake2_wins = 0
	game.house_spot_hits = 0
	game.duel_wins = 0
	game.duel_streak = 0
	game.duel_best_streak = 0
	game.duel_best_form = 0
	game.house_calls = 0
	game.house_shutouts = 0
	game.gauntlet_best_stage = 0
	game.grind_daily_best_stage = 0
	game.grind_daily_best_score = 0
	game.grind_daily_key = ""
	game.grind_daily_last_date = ""
	game.grind_daily_streak = 0
	game.grind_daily_rep_key = ""
	game.grind_pace_splits.clear()
	game.grind_daily_pace_splits.clear()
	game.run_pace_splits.clear()
	game.run_pace_target.clear()
	assert(game._check_trophies() == 0, "An empty career must not unlock a trophy")
	var first_goal: Dictionary = game._next_trophy()
	assert(str(first_goal.id) == "first_break", "A fresh career's next milestone must be the first table")
	# Table-count trophies must be reachable on the actual route. Counting shops
	# as tables once hid two impossible asks; this keeps the shelf honest after
	# any future map change.
	game._build_map()
	var max_route_tables: int = _longest_table_route(game)
	for trophy in game.TROPHIES:
		if str(trophy.stat) == "best_tables":
			assert(int(trophy.target) <= max_route_tables, "Trophy %s asks for more tables than a route can hold" % trophy.id)
	game.tables_cleared = 20
	game.runs_finished = 1
	game.wins = 1
	game.best_tables = max_route_tables
	game.best_shot_ever = 90
	game.best_streak_ever = 6
	game.bosses_beaten = 2
	game.best_bosses_in_run = 2
	game.best_build = 6
	game.best_set_tier = 4
	game.best_sets_in_run = 3
	game.stake2_wins = 1
	game.house_spot_hits = 8
	game.house_calls = 10
	game.house_shutouts = 1
	game.grudges_settled = 3
	game.duel_wins = 1
	game.duel_best_streak = 5
	game.duel_best_form = 4
	game.scouted.assign(["a", "b", "c", "d", "e", "f", "g", "h", "i", "j"])
	var shelf_rep := 0
	var pending_rep := 0
	for trophy in game.TROPHIES:
		shelf_rep += int(trophy.rep)
		if str(trophy.stat) in ["dailies_played", "best_daily_streak", "unlocks", "best_grind_stage"]:
			pending_rep += int(trophy.rep)
	var paid_trophies: int = game._check_trophies()
	assert(paid_trophies == shelf_rep - pending_rep, "Milestone trophies must pay their stated reputation (got %d of %d)" % [paid_trophies, shelf_rep - pending_rep])
	assert(game.trophies.has("two_of_a_kind") and game.trophies.has("full_house") and game.trophies.has("set_collector"), "House Set milestones must be reachable")
	assert(game.trophies.has("first_break") and game.trophies.has("house_falls"), "Clearing and winning must both award")
	assert(game._check_trophies() == 0, "An earned trophy must never pay twice")
	game.dailies_played = 1
	game.best_daily_streak = 7
	game.unlocks.append_array(["cue_rack", "allowance", "house_credit"])
	assert(game._check_trophies() == 6, "Daily and vault milestones must pay when met")
	game.gauntlet_best_stage = 10
	assert(game._check_trophies() == 3, "Grind depth milestones must pay when met")
	assert(game.trophies.size() == game.TROPHIES.size(), "Every trophy must be reachable")
	# The summary's next-milestone card must acknowledge a completed shelf
	# instead of trying to name a nonexistent goal.
	game._show_run_summary(false, false)
	var saw_shelf_complete := false
	for text in _label_texts(game.screen_root):
		if text.begins_with("SHELF COMPLETE"):
			saw_shelf_complete = true
	assert(saw_shelf_complete, "A completed trophy shelf must be acknowledged on the run summary")
	var trophies_before_reload: int = game.trophies.size()
	game._save_meta()
	game.trophies.clear()
	game._load_meta()
	assert(game.trophies.size() == trophies_before_reload, "Earned trophies must survive a reload")
	game._show_title()
	var title_buttons := _button_labels(game.screen_root)
	assert(title_buttons.has("TROPHIES"), "The title must link the trophy shelf")
	assert(_has_button_prefix(game.screen_root, "THE GRIND"), "The title must offer the endless Grind")
	assert(game.toast_root.get_child_count() <= 1, "Milestone toasts must never stack into a wall of popups")
	game._show_trophies()
	assert(game.screen == "trophies", "The trophy shelf must open")
	assert(_label_texts(game.screen_root).has("FIRST BREAK"), "The shelf must list trophy names")
	assert(_label_texts(game.screen_root).has("EARNED"), "The shelf must mark earned trophies")
	var toast_children_before: int = game.screen_root.get_child_count()
	game._check_trophies()
	assert(game.screen_root.get_child_count() == toast_children_before, "A toast must not be counted as a screen child")
	# HOUSE SETS: every discipline needs enough pieces to reach its IV rule, the
	# tier is derived from the owned names, and each rule changes a real number.
	for discipline in game.DISCIPLINES:
		var owned_in_discipline := 0
		for item in game.reward_catalog:
			if int(item.tier) > 0 and game._archetype(item) == discipline:
				owned_in_discipline += 1
		assert(owned_in_discipline >= 4, "Discipline %s needs four pieces to reach its IV set" % discipline)
	game.collection.clear()
	assert(game._set_tier("BANK") == 0, "An empty build must not carry a set")
	game.collection.append_array(["BANKER'S CHALK", "DEADWEIGHT"])
	assert(game._set_tier("BANK") == 2, "Two BANK pieces must wake set II")
	assert(game._set_reward_note("BANK", 1).contains("SET II"), "A threshold piece must name the set it completes")
	game.collection.append_array(["THE SURVEYOR", "SIDE ACTION"])
	assert(game._set_tier("BANK") == 4, "Four BANK pieces must upgrade to set IV")
	assert(game._sets_line().contains("BANK IV"), "The HUD line must name an active set")
	# A banked pot must pay the BOOK rule on top of the normal pot value. Every
	# other scoring input is held constant, so the delta is the set itself.
	game.bank_bonus = 0
	game.combo_bonus = 0
	game.rail_bonus = 0
	game.side_pocket_bonus = 0
	game._start_new_run()
	game.run_contract = "mark"
	game.last_signed_contract = "mark"
	game.current_node = -1
	game.scenario.contract_type = "clear"
	game._start_encounter(false)
	var set_ball := {}
	for ball in game.simulator.balls:
		if bool(ball.target):
			set_ball = ball
			break
	assert(not set_ball.is_empty(), "The House Set test needs a target ball")
	game.collection.clear()
	game.combo_streak = 0
	var plain_bank: int = _score_pocket(game, set_ball, 1)
	game.collection.append_array(["BANKER'S CHALK", "DEADWEIGHT"])
	game.combo_streak = 0
	var set_two_bank: int = _score_pocket(game, set_ball, 1)
	# The pot also starts a 5% streak multiplier, so integer rounding can add a
	# point to the observed delta; the set itself is the fixed +15.
	assert(set_two_bank - plain_bank >= 15 and set_two_bank - plain_bank <= 16, "Set II must add +15 to a banked pot (got %+d)" % (set_two_bank - plain_bank))
	game.collection.append_array(["THE SURVEYOR", "SIDE ACTION"])
	game.combo_streak = 0
	var set_four_bank: int = _score_pocket(game, set_ball, 1)
	assert(set_four_bank - plain_bank >= 30 and set_four_bank - plain_bank <= 32, "Set IV must add +30 to a banked pot (got %+d)" % (set_four_bank - plain_bank))
	# CONTROL grants table-start guards without letting them stack forever.
	game.collection.clear()
	game.collection.append_array(["STEADY CHALK", "SAFETY CHALK"])
	game.streak_guard = 0
	game._start_encounter(false)
	assert(game.streak_guard >= 1, "A CONTROL set must open the table with a streak guard")
	game.collection.append_array(["CORKED CASE", "CORK BOARD"])
	game.streak_guard = 0
	game.scratch_guard = 0
	game._start_encounter(false)
	assert(game.streak_guard >= 1 and game.scratch_guard >= 1, "CONTROL IV must add a scratch guard too")
	# TEMPO buys shots at table start, and IV replaces II rather than stacking.
	game.collection.clear()
	game.collection.append_array(["LUCKY FELT", "HOUSE PAYOUT"])
	game.next_shot_modifier = 0
	game.grind_par_shots = 0
	game._start_encounter(false)
	var tempo_two_shots: int = game.shots_remaining
	game.collection.clear()
	game._start_encounter(false)
	var tempo_base_shots: int = game.shots_remaining
	assert(tempo_two_shots == tempo_base_shots + 1, "TEMPO II must open every table with +1 shot")
	game.collection.append_array(["LUCKY FELT", "HOUSE PAYOUT", "HOUSE LEDGER", "SECOND WIND"])
	game._start_encounter(false)
	assert(game.shots_remaining == tempo_base_shots + 2, "TEMPO IV must grant +2 shots, not +3")
	# Leave the run clean for the mode tests that follow.
	game.collection.clear()
	game.bank_bonus = 0
	game.combo_bonus = 0
	game.rail_bonus = 0
	game.side_pocket_bonus = 0
	game.streak_guard = 0
	game.scratch_guard = 0
	game.heat = 0.0
	game._start_new_run()
	game._clear_run_save()
	# Share text: seed and score for a normal tour, date, twist and streak for a
	# daily. No URL is invented because the game has no server to resolve one.
	game.run_seed = 424242
	game.run_score = 777
	game.run_stage = 4
	game.daily_active = false
	var share_normal: String = game._run_share_text()
	assert(share_normal.contains("424242") and share_normal.contains("777"), "A shared result must name its seed and score")
	# The share text closes the loop with a code a friend can actually enter.
	var share_contract: String = game.run_contract
	var share_stake: int = game.stake
	game.run_contract = "banker"
	game.stake = 1
	assert(game._challenge_code() == "RR1-424242-BANKER-1", "A challenge code must pack seed, term and stake")
	assert(game._run_share_text().contains("RR1-424242-BANKER-1"), "A normal share must carry a usable code")
	assert(game._parse_challenge_code("pasted run · CODE RR1-999999-GRIFTER-2").get("contract") == "grifter", "A code inside a pasted result must parse")
	assert(game._parse_challenge_code("rr1-777-collector-2").get("stake") == 2, "Codes must accept lowercase input")
	assert(game._parse_challenge_code("RR1-0-MARK-0").is_empty(), "A zero seed must be rejected")
	assert(game._parse_challenge_code("RR1-424242-NOPE-1").is_empty(), "An unknown term must be rejected")
	assert(game._parse_challenge_code("RR1-424242-MARK-9").is_empty(), "A stake outside 0-2 must be rejected")
	game.run_contract = share_contract
	game.stake = share_stake
	game.daily_active = true
	game.daily_key = "2026-11-08"
	game.daily_streak = 3
	var share_daily: String = game._run_share_text()
	assert(share_daily.contains("DAILY") and share_daily.contains("NOV 8"), "A shared daily must name the day")
	game.daily_active = false
	game.daily_key = ""
	# Settings survive a reload.
	var saved_volume: float = game.settings_volume
	game.settings_volume = 0.35
	game._save_settings()
	game.settings_volume = 0.8
	game._load_meta()
	assert(is_equal_approx(game.settings_volume, 0.35), "Volume must persist across loads")
	game.settings_volume = saved_volume
	game._save_settings()
	# THE HOUSE'S FAVOR: a lost table must offer the rescue before the run is
	# recorded, and the rescue must actually restore the table's budget.
	game._start_new_run()
	game._clear_run_save()
	game.current_node = 0
	game._start_encounter(false)
	game.favor_available = true
	game.shots_remaining = 0
	game._finish_shot()
	assert(game.screen == "last_call", "An exhausted table with a favor must offer a rescue, not defeat")
	assert(_button_labels(game.screen_root).has("CALL IN THE FAVOR"), "The rescue screen must name the favor")
	game._call_in_favor()
	assert(game.screen == "encounter", "Calling the favor must rerack the table")
	assert(not game.favor_available, "A favor can only be called once")
	assert(game.shots_remaining >= 10, "A favor must restore the table's full shot budget")
	game.shots_remaining = 0
	game._finish_shot()
	assert(game.screen == "defeat", "Without a favor, an exhausted table must end the run")

	# HOUSE HEAT: pots charge it, a called shot doubles its score, and the call
	# absorbs one scratch instead of a shot. Heat must reset on every table so
	# it can never be banked across a route.
	game._start_new_run()
	game._clear_run_save()
	game.current_node = 0
	game._start_encounter(false)
	assert(is_zero_approx(game.heat), "A fresh table must open with an empty heat meter")
	var heat_ball := {}
	for ball in game.simulator.balls:
		if ball.target:
			heat_ball = ball
			break
	assert(not heat_ball.is_empty(), "The heat test needs a target ball")
	game.combo_streak = 0
	var plain_pot := _score_pocket(game, heat_ball, 0)
	assert(game.heat > 0.0, "A pocket must charge HOUSE HEAT")
	var calls_before: int = int(game.house_calls)
	game._arm_house_call()
	assert(not game.house_call_armed, "An under-filled meter must not arm a House call")
	game.heat = 100.0
	game._arm_house_call()
	assert(game.house_call_armed, "A full meter must arm the House call")
	assert(is_zero_approx(game.heat), "Arming the call must empty the meter")
	game.combo_streak = 0
	var called_pot := _score_pocket(game, heat_ball, 0)
	assert(called_pot == plain_pot * 2, "A called shot must pay double (%d vs %d)" % [called_pot, plain_pot])
	assert(not game.house_call_armed, "The call must be spent by the shot")
	assert(game.house_calls == calls_before + 1, "Every call must count toward the trophy shelf")
	game.heat = 100.0
	game._arm_house_call()
	# A dock control with focus owns the confirm key: Enter on HOUSE HEAT must not
	# fire the shot the player has not called yet.
	game._refresh_hud()
	game.hud_heat_button.grab_focus()
	var shots_held: int = game.shots_remaining
	var confirm := InputEventKey.new()
	confirm.keycode = KEY_ENTER
	confirm.pressed = true
	game._input(confirm)
	assert(game.shots_remaining == shots_held, "Enter on a focused dock button must not fire a shot")
	game._arm_house_call()
	game.scratch_guard = 0
	game.shots_remaining = 4
	game.resolving = false
	game.shot_events.clear()
	game.shot_events.append({"type": "first_contact"})
	game.shot_events.append({"type": "pocket", "ball_id": game.simulator.cue_ball_id, "pocket": 0, "pocket_kind": "corner", "ice_touched": false, "rails": 0, "barriers": 0})
	game.current_node = -1
	game._finish_shot()
	assert(game.shots_remaining == 4, "A called House shot must absorb one scratch")
	# THE HOUSE'S NUMBER: every table posts a par, beating it pays 15 on top of
	# the clear, and missing it must never block the contract payout.
	game._start_new_run()
	game._clear_run_save()
	game.current_node = 0
	game._start_encounter(false)
	assert(game.table_par > 0, "Every table must post the House's par")
	game.run_stage = 1
	var saved_contract := str(game.scenario.contract_type)
	var saved_target := int(game.scenario.target)
	game.scenario.contract_type = "score"
	game.scenario.target = 100
	game.encounter_is_elite = false
	game.encounter_is_boss = false
	assert(game._table_par() == 115, "A score table's par must sit above its contract ask (got %d)" % game._table_par())
	game.scenario.contract_type = saved_contract
	game.scenario.target = saved_target
	game.current_node = 0
	game.score = game.table_par
	game.run_cash = 0
	game._complete_current_node()
	assert(game.run_cash == 35, "Beating par must pay the clear plus 15 (got %d)" % game.run_cash)
	game._start_new_run()
	game._clear_run_save()
	game.current_node = 0
	game._start_encounter(false)
	game.score = 0
	game.run_cash = 0
	game.encounter_is_elite = false
	game.encounter_is_boss = false
	game._complete_current_node()
	assert(game.run_cash == 20, "Missing par must still pay the clean clear only (got %d)" % game.run_cash)

	# HOUSE TERMS: the four run identities are selectable, the Mark is the
	# untouched baseline, and a signed term is baked into the run and its save.
	# Clear vault perks so the term's shot cost is measured on a level table.
	game.unlocks.clear()
	game.last_signed_contract = "mark"
	game.run_contract = "mark"
	game._show_contract_select()
	assert(game.screen == "contract", "Starting a run must open the terms screen")
	var term_texts := _label_texts(game.screen_root)
	for term_name in ["THE MARK", "THE BANKER", "THE COLLECTOR", "THE GRIFTER"]:
		assert(term_texts.has(term_name), "The terms screen must offer %s" % term_name)
	game._sign_contract("banker")
	assert(game.screen == "map", "Signing a term must start the run at the map")
	assert(game.run_contract == "banker", "The signed term must own the run")
	assert(game.bank_bonus >= 18 and game.rail_bonus >= 2, "The Banker must start with bank and rail pay")
	assert(game.permanent_shot_bonus == -1, "The Banker must pay for its edge with one shot per table")
	# Measure the term on a normal route table: the opening table keeps its
	# guaranteed ten-shot lesson regardless of the signed term.
	game.current_node = 2
	game._start_encounter(false)
	assert(game.shots_remaining == maxi(3, int(game.scenario.shots) - 1), "A Banker table must use the shorter budget")
	assert(_label_texts(game.screen_root).has("CUE  House Cue   ·   THE BANKER"), "The table must name the active term")
	# Banked pots pay, direct pots do not: the identity must be measurable, not
	# just a line on a card.
	var term_ball := {}
	for ball in game.simulator.balls:
		if ball.target:
			term_ball = ball
			break
	assert(not term_ball.is_empty(), "The terms test needs a target ball")
	game.score = 0
	game.shots_remaining = 5
	game.resolving = false
	game.encounter_is_elite = false
	game.encounter_is_boss = false
	game.scenario.contract_type = "clear"
	game.shot_events.clear()
	game.shot_events.append({"type": "first_contact"})
	game.shot_events.append({"type": "pocket", "ball_id": term_ball.id, "pocket": 0, "pocket_kind": "corner", "ice_touched": false, "rails": 0, "barriers": 0})
	game.current_node = -1
	game._finish_shot()
	var banker_direct: int = game.score
	game.score = 0
	game.shots_remaining = 5
	game.resolving = false
	game.shot_events.clear()
	game.shot_events.append({"type": "first_contact"})
	game.shot_events.append({"type": "rail", "ball_id": term_ball.id})
	game.shot_events.append({"type": "pocket", "ball_id": term_ball.id, "pocket": 0, "pocket_kind": "corner", "ice_touched": false, "rails": 1, "barriers": 0})
	game._finish_shot()
	var banker_bowl: int = game.score
	assert(banker_bowl > banker_direct, "A banked pot must outpay a direct pot under the Banker (%d vs %d)" % [banker_bowl, banker_direct])
	game.last_signed_contract = "mark"
	game.run_contract = "mark"
	game._start_new_run()
	game._clear_run_save()
	game.current_node = 0
	game._start_encounter(false)
	var mark_ball := {}
	for ball in game.simulator.balls:
		if ball.target:
			mark_ball = ball
			break
	assert(not mark_ball.is_empty(), "The Mark comparison needs a target ball")
	game.score = 0
	game.shots_remaining = 5
	game.resolving = false
	game.scenario.contract_type = "clear"
	game.shot_events.clear()
	game.shot_events.append({"type": "first_contact"})
	game.shot_events.append({"type": "pocket", "ball_id": mark_ball.id, "pocket": 0, "pocket_kind": "corner", "ice_touched": false, "rails": 0, "barriers": 0})
	game.current_node = -1
	game._finish_shot()
	assert(game.score > banker_direct, "The Mark must not be taxed on a direct pot (%d vs %d)" % [game.score, banker_direct])
	# The Grifter's clear money lands in the table payout.
	game.last_signed_contract = "grifter"
	game.run_contract = "grifter"
	game._start_new_run()
	game._clear_run_save()
	game.current_node = 0
	game._start_encounter(false)
	game.score = 0
	game.run_cash = 0
	game.encounter_is_elite = false
	game.encounter_is_boss = false
	game._complete_current_node()
	assert(game.run_cash == 40, "The Grifter must pay 20 on top of the clean clear (got %d)" % game.run_cash)
	# THE GRIND: a first-class endless mode. The title opens a rules card, the
	# run deals procedural racks, every clear opens the reward room, the fifth
	# rack is a score gate, and defeat is final (no favor, no map).
	game.gauntlet_best_stage = 0
	game.gauntlet_best_score = 0
	# A parked tour must survive both entering and ending the Grind: the mode
	# has no save slot, so it can never steal CONTINUE.
	game.current_node = 2
	game.map_position = 2
	game.run_stage = 3
	game._save_run()
	assert(FileAccess.file_exists(game.run_save_path), "The test needs a parked tour save")
	game._show_title()
	assert(_has_button_prefix(game.screen_root, "THE GRIND"), "The title must open the Grind card")
	game._show_grind_intro()
	assert(game.screen == "grind", "The Grind must open its rules card before the first rack")
	assert(_label_texts(game.screen_root).has("HOW DEEP CAN YOU GO?"), "The Grind card must state its promise")
	# Seed a previous record so the first clear races a real pace target.
	game.grind_pace_splits.clear()
	game.grind_pace_splits.append(30)
	game._start_gauntlet()
	assert(FileAccess.file_exists(game.run_save_path), "Starting the Grind must preserve a parked tour save")
	assert(game.gauntlet_active, "Starting the Grind must set the endless mode")
	assert(game.screen == "encounter", "The Grind must deal its first rack immediately")
	assert(game.map_nodes.size() == 1, "The Grind must not build a tour map")
	assert(game.run_stage == 1, "The Grind starts at table one")
	assert(game.run_pace_target == [30], "The Grind must snapshot the record pace at start")
	assert(str(game.scenario.name) == "THE GRIND  //  TABLE 01", "The Grind rack must name its table (got %s)" % game.scenario.name)
	assert(str(game.scenario.contract_type) == "clear", "Standard Grind racks are clears")
	assert(game.shots_remaining >= 6, "Every Grind rack must leave a playable budget")
	# One clear pays the reward room and deals the next, harder rack.
	game.run_tables_cleared = 1
	game.score = 40
	game.run_score = 40
	game.table_par = 30
	game.current_node = 0
	game._complete_current_node()
	assert(game.screen == "reward", "A Grind clear must open the reward room")
	assert(game.grind_pace_splits == [40], "A new Grind pace must bank the cleared split (got %s)" % str(game.grind_pace_splits))
	assert(game._grind_pace_label() == "PACE +10", "The pace label must compare against the start-time record")
	assert(_has_label_suffix(game.screen_root, "PACE +10"), "The reward room must show the pace delta")
	assert(_label_texts(game.screen_root).has("NEXT GATE  TABLE 05"), "The reward room must name the next Grind gate")
	assert(game.gauntlet_best_stage == 1, "A Grind clear must bank its depth immediately")
	assert(game.run_stage == 2, "A Grind clear must advance to the next table")
	assert(game.grind_par_shots == 1, "A par beat must bank an extra shot for the next Grind rack")
	assert(_label_texts(game.screen_root).has("PAR 30  BEATEN  ·  +1 SHOT NEXT"), "The reward room must state the par shot bonus")
	var grind_offers: int = game.reward_offers.size()
	assert(grind_offers == 3, "The Grind offers one piece from three")
	# Reward pieces can also grant a next-table shot. The assertion below tests
	# the par bonus specifically, so it must account for the chosen piece.
	var reward_shots: int = int(game.reward_offers[0].get("shots", 0))
	game._choose_reward(0)
	assert(game.screen == "encounter", "Taking a Grind piece must deal the next rack")
	assert(str(game.scenario.name) == "THE GRIND  //  TABLE 02", "The second Grind rack must name table two")
	assert(game.shots_remaining == 11 + reward_shots, "A par beat must carry one extra shot into the next Grind rack (got %d, reward %+d)" % [game.shots_remaining, reward_shots])
	assert(game.grind_par_shots == 0, "The par shot bonus must be consumed by the next rack")
	assert(_has_label_suffix(game.screen_root, "PACE +10"), "The encounter HUD must keep the pace delta visible")
	# Every fifth rack is an elite score gate with a fixed eight-shot budget.
	game.run_stage = 5
	game._start_grind_table()
	assert(game.encounter_is_elite, "The fifth Grind rack must be an elite gate")
	assert(str(game.scenario.contract_type) == "score", "A Grind gate must ask for score")
	assert(int(game.scenario.target) >= 72 and int(game.scenario.target) <= 105, "A fifth gate must ask within the rack's value (got %d)" % game.scenario.target)
	assert(game.shots_remaining >= 8, "A Grind gate must keep its eight-shot gate budget")
	assert(str(game.scenario.name) == "THE GRIND  //  GATE 05", "A Grind gate must name itself")
	# The endless line has no favor and no map: running out ends the run.
	game.shots_remaining = 0
	game.score = 0
	game.run_score = 1234
	game.run_tables_cleared = 4
	game._finish_shot()
	assert(game.screen == "defeat", "A lost Grind rack must end the run, not offer a favor")
	assert(game.gauntlet_best_stage == 4, "The Grind record must keep the deepest table (got %d)" % game.gauntlet_best_stage)
	assert(FileAccess.file_exists(game.run_save_path), "Ending the Grind must preserve a parked tour save")
	assert(_label_texts(game.screen_root).has("THE GRIND  ·  04 TABLES DEEP"), "The summary must report Grind depth")
	assert(game._run_share_text().begins_with("RACK & RUIN · THE GRIND"), "A Grind result must share as a Grind run")
	game.gauntlet_active = false
	# THE DAILY LADDER: one date-seeded sequence with its own board, base rules,
	# one reputation payout per day, and no theft of the parked tour save.
	game.grind_daily_key = game._today_key()
	game.grind_daily_best_stage = 0
	game.grind_daily_best_score = 0
	game.grind_daily_last_date = ""
	game.grind_daily_streak = 0
	game.grind_daily_rep_key = ""
	game.grind_daily_pace_splits.clear()
	game._show_grind_intro()
	assert(_label_texts(game.screen_root).has("TODAY'S LADDER  ·  NOT PLAYED"), "The Grind card must advertise today's ladder")
	assert(_button_labels(game.screen_root).has("TODAY'S LADDER"), "The Grind card must offer today's ladder")
	var runs_before_ladder: int = game.total_runs
	game._start_grind_daily()
	assert(game.gauntlet_active and game.grind_daily_active, "The ladder must run as a daily Grind")
	assert(game.total_runs == runs_before_ladder, "A ladder session must not count as a tour start")
	assert(game.run_seed == game._daily_seed_for(game.grind_daily_key), "The ladder must use the day's shared seed")
	assert(game.permanent_shot_bonus == 0 and game.active_cue_id == "house", "The ladder must play without vault perks")
	assert(game.run_contract == "mark", "The ladder must play under the Mark")
	assert(str(game.scenario.name) == "DAILY LADDER  //  TABLE 01", "The ladder must name its first rack (got %s)" % game.scenario.name)
	assert(FileAccess.file_exists(game.run_save_path), "Starting the ladder must preserve a parked tour save")
	assert(_label_texts(game.screen_root).has("TODAY'S BEST  00"), "The ladder HUD must show today's board, not the free best")
	game.run_tables_cleared = 1
	game.score = 32
	game.run_score = 32
	game.table_par = 0
	game.current_node = 0
	game._complete_current_node()
	assert(game.screen == "reward", "A ladder clear must open the reward room")
	assert(game.grind_daily_best_stage == 1 and game.grind_daily_best_score == 32, "A ladder clear must bank today's best immediately")
	assert(game.grind_daily_pace_splits == [32], "The ladder must set today's first pace")
	assert(_label_texts(game.screen_root).has("TODAY'S LADDER"), "The reward room must label the ladder")
	assert(_has_label_suffix(game.screen_root, "PACE SET"), "A first ladder clear must announce the new pace")
	game._choose_reward(0)
	assert(str(game.scenario.name) == "DAILY LADDER  //  TABLE 02", "The ladder must deal table two after a reward")
	# A four-table ladder pays one reputation; a same-day replay pays nothing.
	var rep_before_ladder: int = game.reputation
	game.run_tables_cleared = 4
	game.run_score = 240
	game.shots_remaining = 0
	game.score = 0
	game._finish_shot()
	assert(game.screen == "defeat", "A lost ladder rack must end the session")
	assert(game.grind_daily_best_stage == 4, "The ladder board must keep the deepest table")
	assert(game.grind_daily_streak == 1, "A first ladder run must start the streak")
	assert(game.reputation == rep_before_ladder + 1, "A four-table ladder must pay one reputation")
	assert(FileAccess.file_exists(game.run_save_path), "Ending the ladder must preserve a parked tour save")
	assert(_label_texts(game.screen_root).has("TODAY'S LADDER  ·  04 TABLES DEEP"), "The summary must report ladder depth")
	assert(game._run_share_text().begins_with("RACK & RUIN · %s DAILY LADDER" % game._pretty_date(game.grind_daily_key)), "A ladder result must share as a ladder run")
	game._start_grind_daily()
	assert(game.run_pace_target == [32], "A ladder replay must race the saved daily pace")
	game.run_tables_cleared = 3
	game.run_score = 180
	game.shots_remaining = 0
	game.score = 0
	game._finish_shot()
	assert(game.last_rep_gain == 0 and game.reputation == rep_before_ladder + 1, "Replaying the ladder all day must not farm reputation")
	assert(game.grind_daily_best_stage == 4, "A weaker replay must never lower today's best")
	# The ladder board must survive a reload, or a returning player loses the
	# only proof that today's shared run happened.
	game._save_meta()
	game.grind_daily_best_stage = 0
	game.grind_daily_best_score = 0
	game.grind_daily_streak = 0
	game.grind_daily_rep_key = ""
	game.grind_daily_pace_splits.clear()
	game.grind_pace_splits.clear()
	game._load_meta()
	assert(game.grind_daily_best_stage == 4 and game.grind_daily_best_score == 240, "The ladder board must survive a reload")
	assert(game.grind_daily_streak == 1 and game.grind_daily_rep_key == game.grind_daily_key, "The ladder streak and payout guard must survive a reload")
	assert(game.grind_daily_pace_splits == [32], "The ladder pace must survive a reload")
	assert(game.grind_pace_splits == [40], "The free Grind pace must survive a reload")
	game.grind_daily_active = false
	game.gauntlet_active = false
	# A played ladder clears the title's readiness dot.
	game._show_title()
	assert(_button_labels(game.screen_root).has("THE GRIND"), "A played ladder must leave a plain Grind button")
	assert(_label_texts(game.screen_root).has("THE HOUSE DUEL"), "The title must offer the House Duel")
	assert(_button_labels(game.screen_root).has("DUEL THE HOUSE"), "The duel card must have an entry button")
	assert(_button_labels(game.screen_root).has("PASS & PLAY"), "The title must offer the local second seat")
	# THE HOUSE DUEL: a self-contained race to five. It must own its rack, its
	# opponent and its records without touching the parked tour save.
	game.duel_wins = 0
	game.duel_streak = 0
	game.duel_best_streak = 0
	game.duel_best_form = 0
	var duel_parked_save := FileAccess.file_exists(game.run_save_path)
	game._start_duel(0, 424242)
	assert(game.screen == "encounter" and game.duel_active, "Sitting down must deal a duel table")
	assert(str(game.scenario.id) == "duel", "A duel must use its own scenario")
	assert(game.simulator.active_target_count() == 9, "A duel rack must hold nine targets")
	assert(game.duel_player == 0 and game.duel_house == 0, "A duel must start level")
	assert(is_equal_approx(game.house_aim_error, 0.105), "Form I must be the forgiving opponent")
	assert(game.hud_heat_label.text == "THE RACE", "A duel must repurpose the heat slot as a race tile")
	assert(game.hud_heat_button.disabled and game.hud_heat_button.text == "0 — 0", "The race tile must show the live score and not act like a button")
	assert(_label_texts(game.screen_root).has("FIRST TO 5"), "The duel brief must state the race")
	assert(_label_texts(game.screen_root).has("YOUR TURN\nSTREAK x0"), "The duel brief must name the turn")
	assert(FileAccess.file_exists(game.run_save_path) == duel_parked_save, "Sitting down must not write a run save")
	# A pot keeps the cue; the fifth pot closes the match and pays reputation.
	var rep_before_duel: int = game.reputation
	game.duel_player = 4
	game._duel_resolve_player_shot(1, false, true)
	assert(game.screen == "duel_result", "The fifth pot must resolve the duel")
	assert(not game.duel_active, "A finished duel must leave the table state")
	assert(game.duel_wins == 1 and game.duel_streak == 1, "A duel win must bank its record")
	assert(game.duel_best_form == 1, "Beating Form I must unlock Form II")
	assert(game.reputation == rep_before_duel + 1, "A duel win must pay one reputation")
	assert(_label_texts(game.screen_root).has("THE TABLE IS YOURS"), "A win must say so")
	assert(_button_labels(game.screen_root).has("FACE FORM II"), "A win must offer the unlocked form")
	assert(game._has_run_save() == duel_parked_save, "A duel must never overwrite a parked tour")
	# Records survive a reload and the next form is a harder opponent.
	game._save_meta()
	game.duel_wins = 0
	game.duel_streak = 0
	game.duel_best_streak = 0
	game.duel_best_form = 0
	game._load_meta()
	assert(game.duel_wins == 1 and game.duel_best_streak == 1 and game.duel_best_form == 1, "Duel records must survive a reload")
	game._start_duel(1, 424242)
	assert(game.duel_form == 1, "The ladder must start the chosen form")
	assert(is_equal_approx(game.house_aim_error, 0.068), "Form II must tighten the House's aim")
	# The House keeps the cue after a pot and hands it back after a dry shot.
	var duel_target := {}
	for ball in game.simulator.balls:
		if bool(ball.target) and not bool(ball.pocketed):
			duel_target = ball
			break
	game.duel_turn_house = true
	game.shot_events.clear()
	game.shot_events.append({"type": "pocket", "ball_id": int(duel_target.id), "pocket": 0})
	game._finish_house_shot()
	assert(game.duel_house == 1, "A House pot must count on the race")
	assert(game.duel_turn_house and game.house_pending > 0.0, "A House pot must keep its turn")
	game.resolving = false
	game._take_shot()
	assert(not game.resolving, "The player must not shoot during the House's turn")
	game.shot_events.clear()
	game._finish_house_shot()
	assert(not game.duel_turn_house, "A dry House shot must hand the cue back")
	game.duel_house = 4
	game.shot_events.clear()
	game.shot_events.append({"type": "pocket", "ball_id": int(duel_target.id), "pocket": 0})
	game._finish_house_shot()
	assert(game.screen == "duel_result" and not game.duel_active, "The House's fifth pot must end the match")
	assert(game.duel_streak == 0, "A duel loss must break the streak")
	assert(_label_texts(game.screen_root).has("THE HOUSE COLLECTS"), "A loss must name the winner")
	# Higher forms own the table itself. The Closer bolts one pocket shut on a
	# pot; the House bolts two. The cap is what keeps the race playable.
	game._start_duel(2, 424244)
	var closer_target := {}
	for ball in game.simulator.balls:
		if bool(ball.target) and not bool(ball.pocketed):
			closer_target = ball
			break
	assert(game.simulator.closed_pockets.is_empty(), "A new duel must start with every pocket open")
	game.duel_turn_house = true
	game.shot_events.clear()
	game.shot_events.append({"type": "pocket", "ball_id": int(closer_target.id), "pocket": 0})
	game._finish_house_shot()
	assert(game.simulator.closed_pockets.size() == 1, "The Closer must bolt one pocket on a pot")
	game.shot_events.clear()
	game.shot_events.append({"type": "pocket", "ball_id": int(closer_target.id), "pocket": 1})
	game._finish_house_shot()
	assert(game.simulator.closed_pockets.size() == 1, "The Closer must not exceed its pocket cap")
	game._start_duel(3, 424245)
	var house_target := {}
	for ball in game.simulator.balls:
		if bool(ball.target) and not bool(ball.pocketed):
			house_target = ball
			break
	game.duel_turn_house = true
	for pocket_index in [0, 1]:
		game.shot_events.clear()
		game.shot_events.append({"type": "pocket", "ball_id": int(house_target.id), "pocket": pocket_index})
		game._finish_house_shot()
	assert(game.simulator.closed_pockets.size() == 2, "The House must bolt two pockets on two pots")
	# Quitting a duel is a forfeit, not a free exit from the ladder.
	game._start_duel(1, 424243)
	game.duel_streak = 3
	game._resume_to_map()
	assert(game.screen == "duel_result" and not game.duel_active, "Forfeiting must resolve the duel")
	assert(game.duel_streak == 0, "Forfeiting must break the streak")
	# A tour table must never inherit the duel's opponent tuning.
	game.duel_active = true
	game.house_aim_error = 0.105
	game._start_encounter(false)
	assert(not game.duel_active, "Starting a tour table must clear the duel flag")
	assert(is_equal_approx(game.house_aim_error, 0.035), "A tour boss must restore the House's normal aim")
	# The second seat opens on a setup card: race length and the couch record.
	game.duel_race = 5
	game.duel_couch_p1 = 0
	game.duel_couch_p2 = 0
	game._show_local_setup()
	assert(game.screen == "local_setup", "Pass & Play must open its setup card")
	var setup_buttons := _button_labels(game.screen_root)
	assert(setup_buttons.has("TO 3") and setup_buttons.has("TO 5") and setup_buttons.has("TO 7"), "The setup must offer three race lengths")
	assert(setup_buttons.has("START MATCH"), "The setup must start the match")
	game._choose_duel_race(7)
	assert(game.screen == "local_setup" and game.duel_race == 7, "Choosing a race must keep the setup open")
	game._start_local_match()
	assert(game.duel_active and game.duel_target == 7, "The chosen race must set the match")
	assert(_label_texts(game.screen_root).has("FIRST TO 7"), "The table must state the chosen race")
	# PASS & PLAY: two humans share the duel's turn state, so each pot must land
	# on the seat that shot and each miss must pass the cue to the other human —
	# never to the House's AI timer, and never into a ladder record.
	game.duel_wins = 0
	game.duel_streak = 0
	game.duel_best_streak = 0
	game.reputation = 0
	game.duel_race = 5
	game._start_duel(0, 515151, true)
	assert(game.screen == "encounter" and game.duel_local, "Pass & Play must deal a local table")
	assert(str(game.scenario.name) == "PASS & PLAY", "The local table must name its mode")
	assert(not game.duel_turn_house and not game.duel_handoff, "Player 1 must break the first rack")
	assert(game.duel_series_p1 == 0 and game.duel_series_p2 == 0, "A new series must start level")
	assert(_label_texts(game.screen_root).has("FIRST TO 5"), "A local match must state the race")
	# A local match has no AI turn to wait for: FIRE must stay live as SPEED UP
	# while the balls roll, or a rattling pocket costs the full physics wait.
	game.resolving = true
	game._refresh_hud()
	assert(not game.hud_fire_button.disabled and game.hud_fire_button.text == "SPEED UP", "FIRE must stay live as SPEED UP in a local match")
	game.resolving = false
	game._refresh_hud()
	game._duel_resolve_player_shot(1, false, true)
	assert(game.duel_player == 1 and game.duel_house == 0, "Player 1's pot must count for Player 1")
	assert(not game.duel_turn_house and not game.duel_handoff, "A pot must keep the same seat")
	game._duel_resolve_player_shot(0, false, true)
	assert(game.duel_turn_house and game.duel_handoff, "A dry shot must hand the cue to Player 2")
	assert(game.house_pending == 0.0, "A local handoff must never queue the House AI")
	assert(game.hud_fire_button.text == "PLAYER 2 READY", "The handoff must own FIRE")
	game._take_shot()
	assert(not game.duel_handoff and not game.resolving, "The ready press must take the cue without firing")
	game._duel_resolve_player_shot(1, false, true)
	assert(game.duel_house == 1 and game.duel_player == 1, "Player 2's pot must count for Player 2")
	assert(game.duel_turn_house, "Player 2 must keep the table after a pot")
	game.duel_house = 4
	var rep_before_local: int = game.reputation
	game._duel_resolve_player_shot(1, false, true)
	assert(game.screen == "duel_result" and not game.duel_active, "Player 2's fifth pot must end the match")
	assert(game.duel_winner == 2 and game.duel_series_p2 == 1, "The local result must name Player 2")
	assert(_label_texts(game.screen_root).has("PLAYER 2 WINS"), "A local win must name the winner")
	assert(game.duel_wins == 0 and game.duel_streak == 0 and game.reputation == rep_before_local, "A local match must never write ladder records")
	assert(game.duel_couch_p2 == 1 and game.duel_couch_p1 == 0, "A local win must bank the all-time couch record")
	assert(_button_labels(game.screen_root).has("REMATCH"), "A local result must offer a rematch")
	# The couch record is the one local stat that survives a reload.
	game._save_meta()
	game.duel_couch_p1 = 0
	game.duel_couch_p2 = 0
	game._load_meta()
	assert(game.duel_couch_p1 == 0 and game.duel_couch_p2 == 1, "The couch record must survive a reload")
	# The winner breaks the next rack and the series survives the rematch.
	game._start_duel(0, 515151, true, true)
	assert(game.duel_turn_house, "The winner must break the next rack")
	assert(game.duel_series_p2 == 1, "A rematch must keep the series")
	# Leaving a local match abandons it; no ladder streak is at stake.
	game._resume_to_map()
	assert(game.screen == "duel_result" and game.duel_winner == 0, "Leaving a local match must abandon it")
	assert(game.duel_wins == 0 and game.duel_streak == 0, "Leaving a local match must not break a ladder streak")
	# A duel carries no shot budget: a long shared match must not dead-end on FIRE.
	game._start_duel(0, 777777, true)
	game.shots_remaining = 0
	game._take_shot()
	assert(game.resolving, "A duel must never run out of shots")
	game._skip_resolution()
	game._show_title()
	game.duel_series_p1 = 0
	game.duel_series_p2 = 0
	game.duel_breaker = 0
	# Leave the isolated test meta on the baseline for future assertions.
	game.duel_wins = 0
	game.duel_streak = 0
	game.duel_best_streak = 0
	game.duel_best_form = 0
	game.duel_couch_p1 = 0
	game.duel_couch_p2 = 0
	game.duel_race = 5
	game.last_signed_contract = "mark"
	game.run_contract = "mark"
	# THE HOUSE REMEMBERS: a winning route teaches the House one habit. The read
	# is deterministic, a mixed route leaves no read at all, the tax lands only
	# on the final House rack, and settling it pays +2 REP and persists.
	game.house_grudge = ""
	game.grudge_active = false
	game.run_banks = 0
	game.run_scratches = 0
	game.run_combo_shots = 0
	game.run_best_streak = 0
	assert(game._read_house_grudge() == "", "A quiet route must leave the House with no read")
	game.run_banks = 5
	assert(game._read_house_grudge() == "rails", "A bank-heavy win must be read as rails")
	game.run_banks = 0
	game.run_best_streak = 6
	assert(game._read_house_grudge() == "streak", "A long streak must be read as streak")
	game.run_best_streak = 0
	game.run_combo_shots = 3
	assert(game._read_house_grudge() == "chain", "Chained pots must be read as chain")
	game.run_combo_shots = 0
	game.run_scratches = 5
	assert(game._read_house_grudge() == "scratch", "A scratch-heavy win must be read as scratch")
	# The tax only lands on the final House rack, never on the route that built it.
	game.house_grudge = "rails"
	game.grudge_active = true
	game.encounter_is_boss = false
	game.current_node = 0
	assert(game._grudge_multiplier(1, true) == 1.0, "A grudge must not tax route tables")
	game.encounter_is_boss = true
	game.current_node = game.map_nodes.size() - 1
	game.map_nodes[game.current_node].name = "THE HOUSE"
	assert(game._grudge_table_active(), "The grudge must be live on the House finale")
	# The pending read belongs on the front door, in the ledger beside the loadout.
	game._show_title()
	assert(_label_texts(game.screen_root).has("IT REMEMBERS YOU"), "The title ledger must announce the House's read")
	game.current_node = game.map_nodes.size() - 1
	game.encounter_is_boss = true
	assert(game._grudge_multiplier(1, true) == 0.5, "The rail grudge must halve a banked pot")
	assert(game._grudge_multiplier(1, false) == 1.0, "The rail grudge must spare a direct pot")
	game.house_grudge = "chain"
	assert(game._grudge_multiplier(2, false) == 0.6, "The chain grudge must tax a multi-ball pot")
	assert(game._grudge_multiplier(1, false) == 1.0, "The chain grudge must spare a single pot")
	# A streak grudge bolts a pocket before the break.
	game.house_grudge = "streak"
	game._start_encounter(true)
	assert(game.simulator.closed_pockets.size() == 1, "The streak grudge must bolt a pocket before the break")
	assert(game._grudge_table_active(), "The finale must still read the grudge after the rack is dealt")
	assert(game.hud_guard_label.text.begins_with("IT REMEMBERS"), "The live brief must repeat the grudge rule")
	# The route's House card must name the rule before the player walks in.
	game.house_grudge = "rails"
	game._build_map()
	game.pending_node = game.map_nodes.size() - 1
	game.map_nodes[game.pending_node].name = "THE HOUSE"
	game._show_map(true)
	var saw_grudge_rail := false
	for text in _label_texts(game.screen_root):
		if text.begins_with("IT REMEMBERS"):
			saw_grudge_rail = true
	assert(saw_grudge_rail, "The boss preview card must name the grudge")
	# A scratch grudge takes the table at a third of the target.
	game.current_node = game.map_nodes.size() - 1
	game.house_grudge = "scratch"
	game._start_encounter(true)
	game.boss_phase = 0
	game.score = int(float(game.scenario.target) * 0.4)
	game._check_boss_phase()
	assert(game.boss_phase == 1, "The scratch grudge must trigger phase two early")
	# Settling: beating the finale clears the read, pays +2 REP and survives reload.
	game.house_grudge = "rails"
	game.grudge_active = true
	game.grudges_settled = 0
	game.reputation = 10
	game.last_rep_gain = 0
	game.stake = 0
	game.daily_active = false
	game.gauntlet_active = false
	game.run_score = 123
	game.run_tables_cleared = 2
	game._record_run_end(true)
	assert(game.house_grudge == "", "Beating a grudge must clear it")
	assert(game.grudges_settled == 1, "Beating a grudge must bank a settlement")
	assert(game.reputation == 14, "A grudge settlement must pay +2 REP on top of the win")
	assert(game.summary_grudge_settled, "The summary must know the grudge was settled")
	game._save_meta()
	game.grudges_settled = 0
	game.house_grudge = "chain"
	game._load_meta()
	assert(game.grudges_settled == 1 and game.house_grudge == "", "The House's book must persist across sessions")
	# THE HOUSE'S WAGER: the stake leaves the wallet only when the rack starts,
	# pays at the table's odds on a clear, and stays with the House on a loss or
	# a walk-out. The daily is a shared board, so it never accepts a stake.
	game.daily_active = false
	game.gauntlet_active = false
	game.grind_daily_active = false
	game._start_new_run()
	assert(game.screen == "map", "The wager test must start on the route")
	assert(game._wager_node(0), "The opening table must accept a wager")
	var wager_cash: int = game.run_cash
	game._set_wager(20)
	assert(game.pending_wager == 20, "Choosing a stake must hold it for the previewed table")
	assert(game.run_cash == wager_cash, "A previewed stake must not leave the wallet before the break")
	game._select_node(0)
	assert(game.screen == "encounter", "A wagered table must still open its rack")
	assert(game.table_wager == 20, "The stake must join the table at the break")
	assert(game.run_cash == wager_cash - 20, "The stake must leave run cash at the break")
	game._show_map()
	assert(game.table_wager == 0, "Walking out must clear the live stake")
	assert(game.run_cash == wager_cash - 20, "Walking out must not refund the stake")
	# Re-enter with a fresh stake and force a clear. Zero par keeps the payout
	# math exact instead of folding a par bonus into the same assertion.
	assert(game.pending_node == 0, "The unfinished opening table must stay preselected")
	game._set_wager(20)
	game._select_node(0)
	assert(game.table_wager == 20, "A second entry must take a fresh stake")
	game.table_par = 0
	game.score = int(game.scenario.target)
	var cash_before_clear: int = game.run_cash
	game._complete_current_node()
	assert(game.table_wager == 0, "A cleared table must settle its stake")
	assert(game.last_wager_payout == 40, "A standard table must pay the stake at even money")
	assert(game.run_cash == cash_before_clear + 20 + 40, "A clear must pay base cash plus the wager")
	assert(_has_label_prefix(game.screen_root, "HOUSE WAGER"), "The reward room must name the wager payout")
	# The daily ladder is the same racks for everyone; a cash bet would let one
	# player buy an advantage on a shared board.
	game.daily_active = true
	game._show_map()
	game.pending_node = game.map_unlocked[0]
	game._set_wager(20)
	assert(game.pending_wager == 0, "A daily must never carry a wager")
	game.daily_active = false
	# A lost table keeps the stake and says so on the summary.
	game._start_new_run()
	game._set_wager(20)
	game._select_node(0)
	assert(game.table_wager == 20, "The loss test must begin with a live stake")
	game._show_defeat()
	assert(game.last_wager_stake == 20 and game.last_wager_payout == 0, "A loss must keep the stake")
	assert(_has_label_suffix(game.screen_root, "WAGER 20 LOST"), "The summary must name the lost stake")
	# THE HOUSE'S CHALLENGE: an invalid paste must not leave the screen, and a
	# valid code must start the exact route, term and stake it names.
	game.daily_active = false
	game.gauntlet_active = false
	game.grind_daily_active = false
	game._show_challenge_entry()
	assert(game.screen == "challenge", "The title must open a challenge entry card")
	assert(game.challenge_input != null, "The challenge card must offer a code field")
	assert(not game._enter_challenge_code("not a code"), "An invalid challenge code must be rejected")
	assert(game.screen == "challenge", "An invalid code must leave the entry card open")
	assert(game._enter_challenge_code("RR1-424242-BANKER-1"), "A valid challenge code must start a run")
	assert(game.screen == "map", "A challenge must open its route map")
	assert(game.run_seed == 424242 and game.run_contract == "banker" and game.stake == 1, "A challenge must restore its seed, term and stake")
	assert(game._run_share_text().contains("RR1-424242-BANKER-1"), "The challenge result must be shareable again")
	for path in [game.save_path, game.run_save_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("Rack & Ruin gameplay playtest passed")
	quit(0)

# Runs one scored shot with a single pocketed target that touched `rails` rails, and returns the score.
# Collects every Button label under a screen root, so screen-content assertions
# do not depend on widget paths.
func _button_labels(node: Node) -> Array[String]:
	var labels: Array[String] = []
	for child in node.get_children():
		if child is Button:
			labels.append((child as Button).text)
		labels.append_array(_button_labels(child))
	return labels

# Buttons can carry a readiness dot ("THE GRIND  •"), so prefix checks keep a
# test about presence from breaking on a cosmetic suffix.
func _has_button_prefix(node: Node, prefix: String) -> bool:
	for label in _button_labels(node):
		if label.begins_with(prefix):
			return true
	return false

func _has_label_suffix(node: Node, suffix: String) -> bool:
	for text in _label_texts(node):
		if text.ends_with(suffix):
			return true
	return false

func _has_label_prefix(node: Node, prefix: String) -> bool:
	for text in _label_texts(node):
		if text.begins_with(prefix):
			return true
	return false

func _label_texts(node: Node) -> Array[String]:
	var texts: Array[String] = []
	for child in node.get_children():
		if child is Label:
			texts.append((child as Label).text)
		texts.append_array(_label_texts(child))
	return texts

# Longest table-count path through the map DAG, used to keep trophy asks
# achievable when shops and events stop counting as cleared tables.
func _longest_table_route(game: Node) -> int:
	var best := 0
	var stack: Array = [[0, 0]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var index: int = int(item[0])
		var count: int = int(item[1])
		if str(game.map_nodes[index].type) in ["standard", "elite", "boss"]:
			count += 1
		best = maxi(best, count)
		for edge in game.map_edges:
			if int(edge.x) == index:
				stack.append([int(edge.y), count])
	return best

func _score_pocket(game: Node, ball: Dictionary, rails: int) -> int:
	game.resolving = false
	game.score = 0
	game.shots_remaining = 5
	game.encounter_is_boss = false
	game.encounter_is_elite = false
	game.scenario.contract_type = "clear"
	game.shot_events.clear()
	game.shot_events.append({"type": "first_contact"})
	game.shot_events.append({"type": "pocket", "ball_id": ball.id, "pocket": 0, "pocket_kind": "corner", "ice_touched": false, "rails": rails, "barriers": 0})
	game.current_node = -1
	game._finish_shot()
	return game.score

# Runs a legal shot that touches rails but drops nothing; returns the score it paid.
func _score_miss(game: Node, ball: Dictionary, rails: int) -> int:
	game.resolving = false
	game.score = 0
	game.shots_remaining = 5
	game.encounter_is_boss = false
	game.encounter_is_elite = false
	game.scenario.contract_type = "clear"
	game.shot_events.clear()
	game.shot_events.append({"type": "first_contact"})
	for _i in rails:
		game.shot_events.append({"type": "rail", "ball_id": ball.id})
	game.current_node = -1
	game._finish_shot()
	return game.score
