class_name BilliardsSimulator
extends RefCounted

const EPSILON := 0.0001
# A ball below this speed is visually parked; the old 5 px/s threshold kept
# nearly-still balls simulating for seconds. Nine seconds is the hard ceiling
# for a shot, so a pocket-mouth rattle can never hold a portal session hostage.
const REST_SPEED := 8.0
const MAX_SHOT_TIME := 9.0
const BALL_RADIUS := 18.0
const FOLLOW_IMPULSE := 140.0
const BASE_FRICTION := 0.72

var table_rect := Rect2(120.0, 110.0, 1040.0, 500.0)
var pockets: Array[Vector2] = []
var pocket_kinds: Array[String] = []
# Pocket indexes the House has bolted shut. Physics and the aim preview both
# skip them, so a shut pocket can never eat a ball the player aimed at it.
var closed_pockets: Array[int] = []
var barriers: Array[Rect2] = []
var zones: Array[Dictionary] = []
var balls: Array[Dictionary] = []
var cue_ball_id := 0
var rails_restitution := 0.86
var ball_restitution := 0.94
var friction := BASE_FRICTION
var next_ball_id := 1
var authored_table := Rect2(120.0, 110.0, 1040.0, 500.0)
var layout_variant := 0

func configure_table(rect: Rect2) -> void:
	table_rect = rect
	# Felt speed is a per-table rule (daily twists can change it), so every
	# table starts from the base value instead of inheriting the last table's.
	friction = BASE_FRICTION
	closed_pockets.clear()
	pockets = [
		Vector2(rect.position.x, rect.position.y),
		Vector2(rect.end.x, rect.position.y),
		Vector2(rect.position.x, rect.end.y),
		Vector2(rect.end.x, rect.end.y),
		Vector2(rect.get_center().x, rect.position.y),
		Vector2(rect.get_center().x, rect.end.y)
	]
	pocket_kinds = ["corner", "corner", "corner", "corner", "side", "side"]

func reset() -> void:
	balls.clear()
	closed_pockets.clear()
	layout_variant = 0
	barriers.clear()
	zones.clear()
	next_ball_id = 1

func ball_mass(kind: String) -> float:
	match kind:
		"heavy":
			return 1.8
		"light":
			return 0.6
		"anchor":
			return 3.2
		"cue":
			return 1.0
	return 1.0

func add_ball(position: Vector2, value: int, kind := "standard", target := true, color := Color.WHITE) -> int:
	if kind != "cue":
		var variant_offset: Vector2 = [Vector2.ZERO, Vector2(0, 22), Vector2(0, -22), Vector2(22, 0)][posmod(layout_variant, 4)]
		position += variant_offset
	position = _layout_point(position)
	var id := next_ball_id
	next_ball_id += 1
	balls.append({
		"id": id,
		"position": position,
		"velocity": Vector2.ZERO,
		"radius": BALL_RADIUS,
		"value": value,
		"kind": kind,
		"target": target,
		"color": color,
		"pocketed": false,
		"spin": Vector2.ZERO,
		"first_contact": false,
		"first_contact_target_id": -1,
		"ice_touched": false,
		"rails_touched": 0,
		"barriers_touched": 0
	})
	if not target:
		cue_ball_id = id
	return id

func add_barrier(rect: Rect2) -> void:
	barriers.append(_layout_rect(rect))

func add_zone(rect: Rect2, kind: String, color: Color) -> void:
	zones.append({"rect": _layout_rect(rect), "kind": kind, "color": color})

func _layout_point(point: Vector2) -> Vector2:
	var normalized := Vector2(
		(point.x - authored_table.position.x) / authored_table.size.x,
		(point.y - authored_table.position.y) / authored_table.size.y
	)
	return table_rect.position + normalized * table_rect.size

func _layout_rect(rect: Rect2) -> Rect2:
	var top_left := _layout_point(rect.position)
	var bottom_right := _layout_point(rect.end)
	return Rect2(top_left, bottom_right - top_left)

func set_shot(aim_angle: float, power: float, spin: Vector2 = Vector2.ZERO) -> Dictionary:
	var cue := get_ball(cue_ball_id)
	if cue.is_empty() or cue.pocketed:
		return {"ok": false, "reason": "Cue ball unavailable"}
	var speed := lerpf(120.0, 1900.0, clampf(power, 0.0, 1.0))
	cue.velocity = Vector2.RIGHT.rotated(aim_angle) * speed
	# Spin is small, readable, deterministic: x = side english, y = top/back.
	cue.spin = Vector2(clampf(spin.x, -1.0, 1.0), clampf(spin.y, -1.0, 1.0))
	for ball in balls:
		ball.first_contact = false
		ball.first_contact_target_id = -1
		ball.rails_touched = 0
		ball.barriers_touched = 0
	return {"ok": true}

# Angry-Birds style prediction: rail bounces + first ball contact + ghost target dir.
# Cheap analytic raycast, not a full sim — deterministic and fast for UI.
func predict_shot(origin: Vector2, angle: float, max_dist: float, spin := Vector2.ZERO) -> Dictionary:
	var dir := Vector2.RIGHT.rotated(angle)
	var bounds := table_rect.grow(-BALL_RADIUS - 2.0)
	var points: Array[Vector2] = [origin]
	var pos := origin
	var remaining := max_dist
	var bounces: Array[Vector2] = []
	for _b in 3:
		if remaining <= 1.0:
			break
		var tx := 1000000000.0
		var ty := 1000000000.0
		if dir.x > 0.01:
			tx = (bounds.end.x - pos.x) / dir.x
		elif dir.x < -0.01:
			tx = (bounds.position.x - pos.x) / dir.x
		if dir.y > 0.01:
			ty = (bounds.end.y - pos.y) / dir.y
		elif dir.y < -0.01:
			ty = (bounds.position.y - pos.y) / dir.y
		var rail_t := minf(tx, ty)
		var ball_t := remaining
		var hit_ball := {}
		for ball in balls:
			if ball.pocketed:
				continue
			if ball.id == cue_ball_id:
				continue
			# Ray vs circle.
			var oc: Vector2 = ball.position - pos
			var tca := oc.dot(dir)
			if tca < 0.0 or tca > remaining:
				continue
			var d2 := oc.length_squared() - tca * tca
			var r := BALL_RADIUS * 2.0
			if d2 > r * r:
				continue
			var thc := sqrt(r * r - d2)
			var t := tca - thc
			if t > 4.0 and t < ball_t:
				ball_t = t
				hit_ball = ball
		# Barriers block the aim line: stop the preview at the first barrier the ray enters.
		var barrier_t := _barrier_entry_t(pos, dir)
		if barrier_t >= 0.0 and barrier_t < minf(ball_t, rail_t) and barrier_t <= remaining:
			points.append(pos + dir * barrier_t)
			return {"points": points, "bounces": bounces, "contact": Vector2.ZERO, "hit_ball": {}, "target_dir": Vector2.ZERO, "ghost_end": Vector2.ZERO, "hit": false, "blocked": true}
		if not hit_ball.is_empty() and ball_t <= rail_t and ball_t <= remaining:
			var contact: Vector2 = pos + dir * ball_t
			points.append(contact)
			var normal: Vector2 = (hit_ball.position - contact).normalized()
			if normal.length_squared() < 0.01:
				normal = dir
			var target_dir: Vector2 = normal
			var ghost_end: Vector2 = hit_ball.position + target_dir * 120.0
			# Cue ball after contact: a stun collision transfers the normal component
			# to the object ball, so the cue keeps the tangent component. A full hit
			# has no tangent left and the cue stops (zero vector).
			var tangent: Vector2 = dir - normal * dir.dot(normal)
			# Top/back spin bends the cue off the pure tangent line: follow pushes it
			# through the contact, draw pulls it back. Weighted for the preview only.
			var cue_vec: Vector2 = tangent + normal * (spin.y * 0.55)
			var cue_dir := cue_vec.normalized() if cue_vec.length() > 0.02 else Vector2.ZERO
			return {"points": points, "bounces": bounces, "contact": contact, "hit_ball": hit_ball, "target_dir": target_dir, "ghost_end": ghost_end, "cue_dir": cue_dir, "hit": true, "blocked": false}
		var travel := minf(rail_t, remaining)
		if travel <= 1.0:
			break
		var endpoint: Vector2 = pos + dir * travel
		points.append(endpoint)
		remaining -= travel
		if travel >= rail_t - 0.5 and rail_t <= remaining + travel:
			bounces.append(endpoint)
			if absf(endpoint.x - bounds.position.x) < 6.0 or absf(endpoint.x - bounds.end.x) < 6.0:
				dir.x *= -1.0
			else:
				dir.y *= -1.0
			pos = endpoint + dir * 2.0
		else:
			break
	return {"points": points, "bounces": bounces, "contact": Vector2.ZERO, "hit_ball": {}, "target_dir": Vector2.ZERO, "ghost_end": Vector2.ZERO, "hit": false, "blocked": false}

# Distance along the ray where it first enters a barrier (barrier grown by the ball radius), or -1.
func _barrier_entry_t(origin: Vector2, dir: Vector2) -> float:
	var best := -1.0
	for barrier in barriers:
		var box: Rect2 = barrier.grow(BALL_RADIUS)
		var t_min := -1000000000.0
		var t_max := 1000000000.0
		var missed := false
		for axis in 2:
			var o: float = origin[axis]
			var d: float = dir[axis]
			var lo: float = box.position[axis]
			var hi: float = box.end[axis]
			if absf(d) < EPSILON:
				if o < lo or o > hi:
					missed = true
				continue
			var t1 := (lo - o) / d
			var t2 := (hi - o) / d
			t_min = maxf(t_min, minf(t1, t2))
			t_max = minf(t_max, maxf(t1, t2))
		if missed or t_min > t_max or t_max < 0.0:
			continue
		var entry := maxf(t_min, 0.0)
		if best < 0.0 or entry < best:
			best = entry
	return best

func step(delta: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var substeps := 3
	var sub_delta := delta / float(substeps)
	for _i in substeps:
		for ball in balls:
			if ball.pocketed:
				continue
			_apply_zone_forces(ball, sub_delta)
			ball.position += ball.velocity * sub_delta
			var damp := friction * 460.0 * sub_delta
			# Light balls glide slightly longer, heavy settle faster.
			if ball.kind == "light":
				damp *= 0.85
			elif ball.kind == "heavy" or ball.kind == "anchor":
				damp *= 1.2
			ball.velocity = ball.velocity.move_toward(Vector2.ZERO, damp)
			_resolve_rails(ball, events)
			_resolve_barriers(ball, events)
			_resolve_pockets(ball, events)
			_resolve_ball_collisions(events)
	return events

func is_settled() -> bool:
	for ball in balls:
		if not ball.pocketed and ball.velocity.length() > REST_SPEED:
			return false
	return true

# Runs remaining motion to rest in fixed steps. Used when a shot must end early
# (fast resolve or the time cap) so no ball is ever left rolling after a shot
# is declared finished. Pocket events are returned so they still score.
func fast_forward(max_time := 60.0) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var elapsed := 0.0
	while not is_settled() and elapsed < max_time:
		events.append_array(step(1.0 / 60.0))
		elapsed += 1.0 / 60.0
	for ball in balls:
		ball.velocity = Vector2.ZERO
	return events

func get_ball(id: int) -> Dictionary:
	for ball in balls:
		if ball.id == id:
			return ball
	return {}

func active_target_count() -> int:
	var count := 0
	for ball in balls:
		if ball.target and not ball.pocketed:
			count += 1
	return count

func close_pocket(index: int) -> void:
	if index < 0 or index >= pockets.size() or closed_pockets.has(index):
		return
	closed_pockets.append(index)

func open_pocket_count() -> int:
	return pockets.size() - closed_pockets.size()

func _apply_zone_forces(ball: Dictionary, delta: float) -> void:
	for zone in zones:
		if zone.rect.has_point(ball.position):
			if zone.kind == "ice" and ball.target:
				ball.ice_touched = true
			match zone.kind:
				"ice":
					ball.velocity *= 1.0 + 0.30 * delta
				"mud":
					ball.velocity = ball.velocity.move_toward(Vector2.ZERO, 260.0 * delta)
				"elastic":
					ball.velocity *= 1.0 + 0.22 * delta
				"drift":
					ball.velocity += Vector2(85.0, 0.0) * delta

func _resolve_rails(ball: Dictionary, events: Array[Dictionary]) -> void:
	var r: float = ball.radius
	var rect := table_rect
	# Side english slightly alters rebound angle.
	var english: float = float(ball.get("spin", Vector2.ZERO).x) if ball.has("spin") else 0.0
	if ball.position.x < rect.position.x + r and ball.velocity.x < -REST_SPEED:
		ball.position.x = rect.position.x + r
		ball.velocity.x = absf(ball.velocity.x) * rails_restitution
		ball.velocity.y += english * 60.0
		ball.rails_touched += 1
		events.append({"type": "rail", "ball_id": ball.id})
	elif ball.position.x > rect.end.x - r and ball.velocity.x > REST_SPEED:
		ball.position.x = rect.end.x - r
		ball.velocity.x = -absf(ball.velocity.x) * rails_restitution
		ball.velocity.y += english * 60.0
		ball.rails_touched += 1
		events.append({"type": "rail", "ball_id": ball.id})
	if ball.position.y < rect.position.y + r and ball.velocity.y < -REST_SPEED:
		ball.position.y = rect.position.y + r
		ball.velocity.y = absf(ball.velocity.y) * rails_restitution
		ball.velocity.x -= english * 60.0
		ball.rails_touched += 1
		events.append({"type": "rail", "ball_id": ball.id})
	elif ball.position.y > rect.end.y - r and ball.velocity.y > REST_SPEED:
		ball.position.y = rect.end.y - r
		ball.velocity.y = -absf(ball.velocity.y) * rails_restitution
		ball.velocity.x -= english * 60.0
		ball.rails_touched += 1
		events.append({"type": "rail", "ball_id": ball.id})

func _resolve_barriers(ball: Dictionary, events: Array[Dictionary]) -> void:
	for barrier in barriers:
		var closest := Vector2(
			clampf(ball.position.x, barrier.position.x, barrier.end.x),
			clampf(ball.position.y, barrier.position.y, barrier.end.y)
		)
		var offset: Vector2 = ball.position - closest
		if offset.length_squared() < ball.radius * ball.radius and ball.velocity.length_squared() > EPSILON:
			var normal := offset.normalized()
			if normal.length_squared() < EPSILON:
				normal = Vector2.UP
			ball.position = closest + normal * ball.radius
			ball.velocity = ball.velocity.bounce(normal) * rails_restitution
			ball.barriers_touched += 1
			events.append({"type": "barrier", "ball_id": ball.id})

func _resolve_pockets(ball: Dictionary, events: Array[Dictionary]) -> void:
	for index in pockets.size():
		if closed_pockets.has(index):
			continue
		var dist: float = ball.position.distance_to(pockets[index])
		# A ball resting in a pocket mouth drops even when slow, so contracts stay winnable.
		if dist <= 36.0 and (ball.velocity.length() > 12.0 or dist <= 26.0):
			# Anchors resist capture unless hit hard.
			if ball.kind == "anchor" and ball.velocity.length() < 320.0:
				continue
			ball.pocketed = true
			ball.velocity = Vector2.ZERO
			events.append({"type": "pocket", "ball_id": ball.id, "pocket": index, "pocket_kind": pocket_kinds[index], "ice_touched": ball.ice_touched, "rails": ball.rails_touched, "barriers": ball.barriers_touched})
			return

func _resolve_ball_collisions(events: Array[Dictionary]) -> void:
	for i in balls.size():
		var a: Dictionary = balls[i]
		if a.pocketed:
			continue
		for j in range(i + 1, balls.size()):
			var b: Dictionary = balls[j]
			if b.pocketed:
				continue
			var delta: Vector2 = b.position - a.position
			var distance := delta.length()
			var min_distance: float = a.radius + b.radius
			if distance >= min_distance or distance < EPSILON:
				continue
			var normal := delta / distance
			var overlap := min_distance - distance
			var ma := ball_mass(str(a.kind))
			var mb := ball_mass(str(b.kind))
			var total := ma + mb
			a.position -= normal * overlap * (mb / total)
			b.position += normal * overlap * (ma / total)
			var relative: Vector2 = b.velocity - a.velocity
			var speed_along_normal := relative.dot(normal)
			if speed_along_normal > 0.0:
				continue
			var impulse := -(1.0 + ball_restitution) * speed_along_normal / (1.0 / ma + 1.0 / mb)
			var impulse_vector := normal * impulse
			a.velocity -= impulse_vector / ma
			b.velocity += impulse_vector / mb
			# Follow/draw carried into the contact. The direction is defined from the
			# cue toward the object ball, so the result is identical no matter which
			# ball came first in the array (the previous version flipped its sign when
			# the cue happened to be `a`, inverting spin on half of all shots).
			var cue_ref: Dictionary = {}
			var object_ref: Dictionary = {}
			if a.id == cue_ball_id:
				cue_ref = a
				object_ref = b
			elif b.id == cue_ball_id:
				cue_ref = b
				object_ref = a
			if not cue_ref.is_empty():
				var spin_y: float = float(cue_ref.get("spin", Vector2.ZERO).y)
				if absf(spin_y) > 0.05:
					var follow_dir: Vector2 = (object_ref.position - cue_ref.position).normalized()
					cue_ref.velocity += follow_dir * spin_y * FOLLOW_IMPULSE
			# Speed rides along so the game can scale the click by impact instead
			# of firing the same sound for a nudge and a break.
			events.append({"type": "collision", "a": a.id, "b": b.id, "speed": absf(speed_along_normal)})
			if a.id == cue_ball_id and b.target and a.first_contact_target_id == -1:
				a.first_contact_target_id = b.id
				events.append({"type": "first_contact", "cue_id": a.id, "target_id": b.id})
			if b.id == cue_ball_id and a.target and b.first_contact_target_id == -1:
				b.first_contact_target_id = a.id
				events.append({"type": "first_contact", "cue_id": b.id, "target_id": a.id})
			if a.target and not a.first_contact:
				a.first_contact = true
				if b.target and not b.first_contact:
					b.first_contact = true
