extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	game.save_path = "user://tmp_dump_meta.cfg"
	game.run_save_path = "user://tmp_dump_run.cfg"
	root.add_child(game)
	await process_frame
	game._show_title()
	await process_frame
	_dump(game, 0)
	quit(0)

func _dump(node: Node, depth: int) -> void:
	for child in node.get_children():
		if child is Control:
			var ctrl := child as Control
			if ctrl.is_visible_in_tree() and ctrl.size.x >= 118 and ctrl.size.x <= 170 and ctrl.size.y >= 44 and ctrl.size.y <= 85:
				print("MATCH depth=%d class=%s name=%s pos=%s size=%s text=%s" % [depth, ctrl.get_class(), ctrl.name, ctrl.global_position, ctrl.size, (ctrl as Button).text if ctrl is Button else ""])
		_dump(child, depth + 1)
