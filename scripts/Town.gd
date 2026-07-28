extends Control
## Town screen: spend Gold on stats, spend Emeralds on abilities,
## pick a checkpoint and start a run. Built entirely in code (no art assets).

signal go_to_dungeon(start_floor: int)

var _gold_label: Label
var _emerald_label: Label
var _stats_list: VBoxContainer
var _stats_scroll: ScrollContainer
var _abilities_list: VBoxContainer
var _equipped_label: Label
var _checkpoint_option: OptionButton
var _progress_label: Label
var _hover_upgrade_title: Label
var _hover_upgrade_desc: Label
var _node_hover_popup: Panel
var _node_hover_popup_title: Label
var _node_hover_popup_desc: Label
var _selected_upgrade_node: String = "foundation"
var _stats_overlay: ColorRect
var _stats_content: VBoxContainer
var _upgrade_graph: Control
var _reset_confirm_overlay: ColorRect
var _new_game_confirm_overlay: ColorRect
var _known_upgrade_nodes: Dictionary = {}  # node_id -> true, for reveal fade
var _last_graph_height: float = 0.0
var _preserve_tree_scroll: bool = false


func _ready() -> void:
	_build_ui()
	GameState.currencies_changed.connect(_refresh)
	GameState.abilities_changed.connect(_refresh)
	GameState.progress_changed.connect(_refresh)
	_refresh()
	_scroll_upgrade_tree_to_bottom.call_deferred()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.09, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.set_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.set_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	# --- Header -------------------------------------------------------------
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(header)

	var title := Label.new()
	title.text = "TOWN"
	title.add_theme_font_size_override("font_size", 32)
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	header.add_child(title)

	var header_gap := Control.new()
	header_gap.custom_minimum_size = Vector2(32, 0)
	header.add_child(header_gap)

	var currencies := HBoxContainer.new()
	currencies.add_theme_constant_override("separation", 20)
	currencies.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	header.add_child(currencies)

	_gold_label = Label.new()
	_gold_label.text = "Gold: 0"
	_gold_label.add_theme_font_size_override("font_size", 22)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	currencies.add_child(_gold_label)

	_emerald_label = Label.new()
	_emerald_label.text = "Emeralds: 0"
	_emerald_label.add_theme_font_size_override("font_size", 22)
	_emerald_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	currencies.add_child(_emerald_label)

	var stats_gap := Control.new()
	stats_gap.custom_minimum_size = Vector2(40, 0)
	header.add_child(stats_gap)

	var stats_btn := Button.new()
	stats_btn.text = "Hero Stats"
	stats_btn.pressed.connect(_toggle_player_stats_panel)
	header.add_child(stats_btn)

	var reset_gap := Control.new()
	reset_gap.custom_minimum_size = Vector2(20, 0)
	header.add_child(reset_gap)

	var reset_btn := Button.new()
	reset_btn.text = "Reset Skills"
	reset_btn.add_theme_color_override("font_color", Color(0.9, 0.35, 0.35))
	reset_btn.pressed.connect(_show_reset_confirm)
	header.add_child(reset_btn)

	var new_game_gap := Control.new()
	new_game_gap.custom_minimum_size = Vector2(20, 0)
	header.add_child(new_game_gap)

	var new_game_btn := Button.new()
	new_game_btn.text = "New Game"
	new_game_btn.add_theme_color_override("font_color", Color(0.95, 0.4, 0.4))
	new_game_btn.tooltip_text = "Wipe all progress and start from scratch."
	new_game_btn.pressed.connect(_show_new_game_confirm)
	header.add_child(new_game_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	# --- Body: three columns ------------------------------------------------
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	root.add_child(columns)

	_stats_list = _make_column(columns, "HERO UPGRADE TREE  (Gold)", 0.42)
	_abilities_list = _make_column(columns, "ABILITIES  (Emeralds)", 0.40)
	var run_col := _make_column(columns, "START RUN", 0.18)
	_build_run_column(run_col)
	_build_player_stats_overlay()
	_build_reset_confirm_overlay()
	_build_new_game_confirm_overlay()


func _make_column(parent: Control, title_text: String, stretch: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = stretch
	parent.add_child(panel)

	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 12)
	inner.add_theme_constant_override("margin_right", 12)
	inner.add_theme_constant_override("margin_top", 10)
	inner.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(inner)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	inner.add_child(vbox)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	if title_text.begins_with("HERO UPGRADE TREE"):
		_stats_scroll = scroll

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	return list


func _build_run_column(col: VBoxContainer) -> void:
	_progress_label = Label.new()
	_progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_progress_label)

	var cp_title := Label.new()
	cp_title.text = "Start from checkpoint:"
	col.add_child(cp_title)

	_checkpoint_option = OptionButton.new()
	_checkpoint_option.item_selected.connect(_on_checkpoint_selected)
	col.add_child(_checkpoint_option)

	var start_btn := Button.new()
	start_btn.text = "DESCEND"
	start_btn.add_theme_font_size_override("font_size", 24)
	start_btn.custom_minimum_size = Vector2(0, 56)
	start_btn.pressed.connect(_on_start_pressed)
	col.add_child(start_btn)

	_equipped_label = Label.new()
	_equipped_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_equipped_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	col.add_child(_equipped_label)


# --- Refresh ---------------------------------------------------------------
func _refresh() -> void:
	_gold_label.text = "Gold: %d" % GameState.gold
	_emerald_label.text = "Emeralds: %d" % GameState.emeralds
	_gold_label.reset_size()
	_emerald_label.reset_size()
	_progress_label.text = "Deepest floor: %d / %d\nHighest checkpoint: %d\nDungeon runs: %d" % [
		GameState.deepest_floor, Database.MAX_FLOORS, GameState.highest_checkpoint, GameState.dungeon_runs
	]
	_rebuild_stats()
	_rebuild_abilities()
	_rebuild_checkpoints()
	_update_equipped_label()
	if _stats_overlay.visible:
		_refresh_player_stats_panel()


func _rebuild_stats() -> void:
	var old_scroll := 0
	var old_height := _last_graph_height
	var keep_scroll := _preserve_tree_scroll and _stats_scroll != null
	if keep_scroll:
		old_scroll = _stats_scroll.scroll_vertical

	_hide_node_hover_popup()
	for c in _stats_list.get_children():
		c.queue_free()

	var summary := Label.new()
	summary.text = "Current stats: %s" % _current_stats_text()
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_font_size_override("font_size", 12)
	summary.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	_stats_list.add_child(summary)

	var hint := Label.new()
	hint.text = "Upgrade the root to reveal one starter per category. Each starter reveals two random paths; buying one path locks the other."
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.55, 0.65, 0.9))
	_stats_list.add_child(hint)

	var test_row := HBoxContainer.new()
	test_row.add_theme_constant_override("separation", 8)
	_stats_list.add_child(test_row)

	var reset_btn := Button.new()
	reset_btn.text = "Reset Tree (Testing)"
	reset_btn.tooltip_text = "Clears only hero upgrade tree ranks and revealed nodes."
	reset_btn.pressed.connect(_on_reset_upgrade_tree_pressed)
	test_row.add_child(reset_btn)

	var gold_test_btn := Button.new()
	gold_test_btn.text = "+10,000 Gold (Testing)"
	gold_test_btn.tooltip_text = "Adds 10,000 gold for testing upgrades."
	gold_test_btn.pressed.connect(_on_add_test_gold_pressed)
	test_row.add_child(gold_test_btn)

	var emerald_test_btn := Button.new()
	emerald_test_btn.text = "+100 Emeralds (Testing)"
	emerald_test_btn.tooltip_text = "Adds 100 emeralds for testing abilities."
	emerald_test_btn.pressed.connect(_on_add_test_emeralds_pressed)
	test_row.add_child(emerald_test_btn)

	_upgrade_graph = Control.new()
	_upgrade_graph.custom_minimum_size = Vector2(720, 200)
	_upgrade_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_list.add_child(_upgrade_graph)
	_build_upgrade_tree_graph(_upgrade_graph)
	_build_upgrade_hover_preview()
	_build_upgrade_node_details()

	_last_graph_height = _upgrade_graph.custom_minimum_size.y
	if keep_scroll:
		var grew := maxf(0.0, _last_graph_height - old_height)
		_restore_tree_scroll.call_deferred(old_scroll + int(grew))
	_preserve_tree_scroll = true


func _scroll_upgrade_tree_to_bottom() -> void:
	if _stats_scroll == null:
		return
	_preserve_tree_scroll = false
	await get_tree().process_frame
	var scrollbar := _stats_scroll.get_v_scroll_bar()
	_stats_scroll.scroll_vertical = int(scrollbar.max_value)
	_last_graph_height = _upgrade_graph.custom_minimum_size.y if _upgrade_graph != null else 0.0
	_preserve_tree_scroll = true


func _restore_tree_scroll(scroll_y: int) -> void:
	if _stats_scroll == null:
		return
	await get_tree().process_frame
	var scrollbar := _stats_scroll.get_v_scroll_bar()
	_stats_scroll.scroll_vertical = clampi(scroll_y, 0, int(scrollbar.max_value))


func _build_upgrade_tree_graph(graph: Control) -> void:
	var positions := _normalize_upgrade_positions(_upgrade_node_positions(), graph)
	var ids: Array = GameState.visible_upgrade_nodes.duplicate()
	ids.sort_custom(func(a, b): return GameState.skill_data(a).get("order", 0) < GameState.skill_data(b).get("order", 0))
	_build_node_hover_popup(graph)

	var first_build := _known_upgrade_nodes.is_empty()
	var fade_nodes: Array[CanvasItem] = []

	# Draw parent links first so circular node buttons sit above them.
	for id in ids:
		var parent := GameState.get_upgrade_reveal_parent(id)
		if parent == "" or not positions.has(parent) or not positions.has(id):
			continue
		var line := Line2D.new()
		line.points = PackedVector2Array([positions[parent], positions[id]])
		line.width = 4.0
		line.default_color = _node_link_color(parent, id)
		graph.add_child(line)
		if not first_build and not _known_upgrade_nodes.has(id):
			line.modulate.a = 0.0
			fade_nodes.append(line)
		var extra_parent := GameState.get_upgrade_extra_reveal_parent(id)
		if extra_parent != "" and positions.has(extra_parent):
			var extra_line := Line2D.new()
			extra_line.points = PackedVector2Array([positions[extra_parent], positions[id]])
			extra_line.width = 4.0
			extra_line.default_color = _node_link_color(extra_parent, id)
			graph.add_child(extra_line)
			if not first_build and not _known_upgrade_nodes.has(id):
				extra_line.modulate.a = 0.0
				fade_nodes.append(extra_line)

	for id in ids:
		var d: Dictionary = GameState.skill_data(id)
		if d.is_empty():
			continue
		var complete: bool = GameState.is_upgrade_node_complete(id)
		var selected: bool = String(id) == _selected_upgrade_node
		var path_locked := GameState.is_upgrade_node_path_locked(id)
		var is_new := not first_build and not _known_upgrade_nodes.has(id)
		var btn := Button.new()
		btn.text = ""
		btn.position = positions[id] - Vector2(30, 30)
		btn.size = Vector2(60, 60)
		btn.add_theme_font_size_override("font_size", 10)
		btn.add_theme_stylebox_override("normal", _node_style(_node_color(id), selected))
		btn.add_theme_stylebox_override("hover", _node_style(_node_color(id).lightened(0.15), true))
		btn.add_theme_stylebox_override("pressed", _node_style(_node_color(id).darkened(0.1), true))
		btn.pressed.connect(func(): _on_upgrade_node_pressed(id))
		btn.mouse_entered.connect(func(): _preview_upgrade_node(id, positions[id]))
		btn.mouse_exited.connect(func(): _clear_upgrade_preview(id))
		graph.add_child(btn)
		_add_skill_icon(btn, id, path_locked)

		var rank_label := Label.new()
		rank_label.text = "LOCK" if path_locked else ("%d/%d" % [GameState.get_upgrade_node_rank(id), int(d.max_ranks)])
		rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rank_label.add_theme_font_size_override("font_size", 10)
		rank_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65) if path_locked else (Color(0.95, 0.88, 0.45) if complete else Color(0.75, 0.75, 0.85)))
		rank_label.position = positions[id] + Vector2(-32, 34)
		rank_label.size = Vector2(64, 16)
		graph.add_child(rank_label)

		if is_new:
			btn.modulate.a = 0.0
			rank_label.modulate.a = 0.0
			fade_nodes.append(btn)
			fade_nodes.append(rank_label)

	_known_upgrade_nodes.clear()
	for id in ids:
		_known_upgrade_nodes[String(id)] = true

	if not fade_nodes.is_empty():
		_fade_in_nodes(fade_nodes)


func _fade_in_nodes(nodes: Array[CanvasItem]) -> void:
	for node in nodes:
		if not is_instance_valid(node):
			continue
		var tween := create_tween()
		tween.tween_property(node, "modulate:a", 1.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _build_upgrade_hover_preview() -> void:
	var panel := PanelContainer.new()
	_stats_list.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	margin.add_child(box)

	_hover_upgrade_title = Label.new()
	_hover_upgrade_title.text = "Hover a node to preview"
	_hover_upgrade_title.add_theme_font_size_override("font_size", 13)
	_hover_upgrade_title.add_theme_color_override("font_color", Color(0.75, 0.82, 1.0))
	box.add_child(_hover_upgrade_title)

	_hover_upgrade_desc = Label.new()
	_hover_upgrade_desc.text = "Click a node to pin its full upgrade details below."
	_hover_upgrade_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hover_upgrade_desc.add_theme_font_size_override("font_size", 12)
	_hover_upgrade_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	box.add_child(_hover_upgrade_desc)


func _build_node_hover_popup(graph: Control) -> void:
	_node_hover_popup = Panel.new()
	_node_hover_popup.visible = false
	_node_hover_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_node_hover_popup.z_index = 200
	_node_hover_popup.size = Vector2(260, 120)
	_node_hover_popup.custom_minimum_size = Vector2(260, 120)
	_node_hover_popup.add_theme_stylebox_override("panel", _tooltip_style())
	graph.add_child(_node_hover_popup)

	_node_hover_popup_title = Label.new()
	_node_hover_popup_title.position = Vector2(10, 8)
	_node_hover_popup_title.size = Vector2(240, 20)
	_node_hover_popup_title.clip_text = true
	_node_hover_popup_title.add_theme_font_size_override("font_size", 13)
	_node_hover_popup_title.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_node_hover_popup.add_child(_node_hover_popup_title)

	_node_hover_popup_desc = Label.new()
	_node_hover_popup_desc.position = Vector2(10, 32)
	_node_hover_popup_desc.size = Vector2(240, 78)
	_node_hover_popup_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_node_hover_popup_desc.clip_text = true
	_node_hover_popup_desc.add_theme_font_size_override("font_size", 11)
	_node_hover_popup_desc.add_theme_color_override("font_color", Color(0.76, 0.76, 0.82))
	_node_hover_popup.add_child(_node_hover_popup_desc)


func _build_upgrade_node_details() -> void:
	if not GameState.is_upgrade_node_visible(_selected_upgrade_node):
		_selected_upgrade_node = "foundation"
	var id := _selected_upgrade_node
	var d: Dictionary = GameState.skill_data(id)
	var visible := GameState.is_upgrade_node_visible(id)
	var rank := GameState.get_upgrade_node_rank(id)
	var max_ranks := int(d.max_ranks)

	var panel := PanelContainer.new()
	_stats_list.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	var title := Label.new()
	title.text = "%s  Rank %d/%d  Tier %d" % [d.name, rank, max_ranks, int(d.tier)]
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0) if visible else Color(0.55, 0.55, 0.65))
	box.add_child(title)

	var desc := Label.new()
	desc.text = d.desc + "  " + _node_bonus_text(id)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	box.add_child(desc)

	var btn := Button.new()
	if not visible:
		btn.text = "Locked: complete Tier %d first" % (int(d.tier) - 1)
		btn.disabled = true
	elif GameState.is_upgrade_node_path_locked(id):
		btn.text = "Path locked"
		btn.disabled = true
	elif GameState.is_upgrade_node_common_locked(id):
		btn.text = "Locked: complete your chosen path first"
		btn.disabled = true
	elif GameState.is_upgrade_node_complete(id):
		btn.text = "Complete"
		btn.disabled = true
	else:
		btn.text = "Upgrade  %d g" % GameState.upgrade_node_cost(id)
		btn.disabled = not GameState.can_upgrade_node(id)
	btn.pressed.connect(func(): GameState.upgrade_tree_node(id))
	box.add_child(btn)


func _current_stats_text() -> String:
	var parts: Array[String] = []
	var ids := Database.STATS.keys()
	ids.sort_custom(func(a, b): return Database.STATS[a].order < Database.STATS[b].order)
	for id in ids:
		var d: Dictionary = Database.STATS[id]
		parts.append("%s %s" % [d.name, Database.format_stat(id, GameState.get_stat_value(id))])
	return " | ".join(parts)


func _node_bonus_text(id: String) -> String:
	var d: Dictionary = GameState.skill_data(id)
	if d.has("effect_text"):
		return "(%s)" % String(d.effect_text)
	if d.has("chance_by_rank"):
		var rank := GameState.get_upgrade_node_rank(id)
		var chances: Array = d["chance_by_rank"]
		var parts: Array[String] = []
		for chance in chances:
			parts.append("%.0f%%" % (float(chance) * 100.0))
		if d.has("cooldown_recover_on_hit"):
			var recover := float(d.cooldown_recover_on_hit)
			if rank > 0:
				var index := clampi(rank, 1, chances.size()) - 1
				return "(Current: %.0f%% chance to recover %.1fs cooldown when hit; ranks: %s)" % [float(chances[index]) * 100.0, recover, " / ".join(parts)]
			return "(Ranks: %s chance to recover %.1fs cooldown when hit)" % [" / ".join(parts), recover]
		if rank > 0:
			var index := clampi(rank, 1, chances.size()) - 1
			return "(Current: %.0f%% chance to reduce cooldown by 50%%; ranks: %s)" % [float(chances[index]) * 100.0, " / ".join(parts)]
		return "(Ranks: %s chance to reduce cooldown by 50%%)" % " / ".join(parts)
	if d.has("cooldown_reduction_per_rank"):
		return "(-%.0f%% ability cooldown per rank)" % (float(d.cooldown_reduction_per_rank) * 100.0)
	if d.has("ability_power_per_rank"):
		return "(+%.0f%% ability power per rank)" % (float(d.ability_power_per_rank) * 100.0)
	if d.has("gold_bonus_by_rank"):
		var rank := GameState.get_upgrade_node_rank(id)
		var bonuses: Array = d["gold_bonus_by_rank"]
		var parts: Array[String] = []
		for bonus in bonuses:
			parts.append("+%.0f%%" % (float(bonus) * 100.0))
		if rank > 0:
			var index := clampi(rank, 1, bonuses.size()) - 1
			return "(Current: +%.0f%% gold from kills; ranks: %s)" % [float(bonuses[index]) * 100.0, " / ".join(parts)]
		return "(Ranks: %s gold from kills)" % " / ".join(parts)
	if d.has("bonuses"):
		var bonuses: Dictionary = d.bonuses
		var parts: Array[String] = []
		var stat_ids := bonuses.keys()
		stat_ids.sort_custom(func(a, b): return Database.STATS[a].order < Database.STATS[b].order)
		for stat_id_raw in stat_ids:
			var stat_id := String(stat_id_raw)
			var stat: Dictionary = Database.STATS[stat_id]
			var formatted := Database.format_stat(stat_id, float(bonuses[stat_id]))
			if stat.percent:
				parts.append("+%s" % formatted)
			else:
				parts.append("+%s %s" % [formatted, stat.name])
		return "(%s per rank)" % ", ".join(parts)
	if not d.has("stat") or not d.has("bonus_per_rank"):
		return ""
	var stat_id := String(d.stat)
	var stat: Dictionary = Database.STATS[stat_id]
	var value := float(d.bonus_per_rank)
	var formatted := Database.format_stat(stat_id, value)
	if stat.percent:
		return "(+%s per rank)" % formatted
	return "(+%s %s per rank)" % [formatted, stat.name]


func _select_upgrade_node(id: String) -> void:
	_selected_upgrade_node = id
	_refresh()


func _on_upgrade_node_pressed(id: String) -> void:
	_hide_node_hover_popup()
	_selected_upgrade_node = id
	if GameState.can_upgrade_node(id):
		GameState.upgrade_tree_node(id)
	else:
		_refresh()


func _preview_upgrade_node(id: String, node_pos: Vector2 = Vector2.ZERO) -> void:
	var d: Dictionary = GameState.skill_data(id)
	if _hover_upgrade_title == null or d.is_empty():
		return
	var title := "%s  Tier %d  Rank %d/%d" % [
		d.name,
		int(d.tier),
		GameState.get_upgrade_node_rank(id),
		int(d.max_ranks)
	]
	var description := "%s\n%s\n%s" % [_node_price_text(id), d.desc, _node_bonus_text(id)]
	_hover_upgrade_title.text = title
	_hover_upgrade_desc.text = description
	if _node_hover_popup != null:
		_node_hover_popup_title.text = title
		_node_hover_popup_desc.text = description
		_node_hover_popup.size = Vector2(260, 120)
		var popup_pos := node_pos + Vector2(42, -42)
		var parent := _node_hover_popup.get_parent() as Control
		if parent != null:
			var right_limit := parent.size.x - _node_hover_popup.size.x - 8.0
			var bottom_limit := parent.size.y - _node_hover_popup.size.y - 8.0
			if popup_pos.x > right_limit:
				popup_pos.x = node_pos.x - _node_hover_popup.size.x - 42.0
			popup_pos.x = clampf(popup_pos.x, 8.0, maxf(8.0, right_limit))
			popup_pos.y = clampf(popup_pos.y, 8.0, maxf(8.0, bottom_limit))
		_node_hover_popup.position = popup_pos
		_node_hover_popup.visible = true


func _clear_upgrade_preview(id: String) -> void:
	_hide_node_hover_popup()
	if _hover_upgrade_title == null or id == _selected_upgrade_node:
		return
	_hover_upgrade_title.text = "Selected: %s" % GameState.skill_data(_selected_upgrade_node).get("name", "?")
	_hover_upgrade_desc.text = "Click a node to pin its full upgrade details below."


func _hide_node_hover_popup() -> void:
	if _node_hover_popup != null:
		_node_hover_popup.visible = false


func _node_price_text(id: String) -> String:
	if GameState.is_upgrade_node_path_locked(id):
		return "Path locked"
	if GameState.is_upgrade_node_common_locked(id):
		return "Locked until chosen path is learned"
	if GameState.is_upgrade_node_complete(id):
		return "Complete"
	return "Price: %d gold" % GameState.upgrade_node_cost(id)


func _on_reset_upgrade_tree_pressed() -> void:
	_selected_upgrade_node = "foundation"
	_known_upgrade_nodes.clear()
	_last_graph_height = 0.0
	_preserve_tree_scroll = false
	GameState.reset_upgrade_tree()
	_refresh()
	_scroll_upgrade_tree_to_bottom.call_deferred()


func _on_add_test_gold_pressed() -> void:
	GameState.add_gold(10000)
	GameState.save_game()
	_refresh()

func _on_add_test_emeralds_pressed() -> void:
	GameState.add_emeralds(100)
	GameState.save_game()
	_refresh()


func _upgrade_node_positions() -> Dictionary:
	var result := {}
	var roots := _visible_upgrade_ids_in_tier(0)
	for id in roots:
		result[id] = Vector2(360.0, 2400.0)

	var starters := _visible_upgrade_ids_in_tier(1)
	var slots := _upgrade_starter_slots(starters.size())
	for i in starters.size():
		result[starters[i]] = Vector2(slots[i], 2240.0)

	_add_all_group_positions(result)

	for tier in [2, 3]:
		var ids := _visible_upgrade_ids_in_tier(tier)
		for id in ids:
			if result.has(id):
				continue
			var parent := GameState.get_upgrade_reveal_parent(id)
			if parent != "" and result.has(parent):
				result[id] = Vector2(result[parent].x, result[parent].y - 140.0)
			else:
				result[id] = Vector2(360.0, _upgrade_tier_y(tier))
	return result


func _normalize_upgrade_positions(positions: Dictionary, graph: Control) -> Dictionary:
	if positions.is_empty():
		graph.custom_minimum_size = Vector2(720, 200)
		return positions
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	for pos_raw in positions.values():
		var pos: Vector2 = pos_raw
		min_x = minf(min_x, pos.x)
		max_x = maxf(max_x, pos.x)
		min_y = minf(min_y, pos.y)
		max_y = maxf(max_y, pos.y)
	var pad_y := 70.0
	var side_pad := 50.0
	var content_w := maxf(0.0, max_x - min_x)
	var content_h := maxf(0.0, max_y - min_y)
	var avail_w := 720.0
	var scale_x := 1.0
	var max_span := avail_w - side_pad * 2.0
	if content_w > max_span:
		scale_x = max_span / content_w
	var used_w := content_w * scale_x
	var origin_x := (avail_w - used_w) * 0.5
	var normalized := {}
	for id in positions.keys():
		var p: Vector2 = positions[id]
		normalized[id] = Vector2(
			origin_x + (p.x - min_x) * scale_x,
			pad_y + (p.y - min_y)
		)
	# Grow with the tree; stay compact at the start so no huge empty scroll.
	var height := content_h + pad_y * 2.0 + 50.0
	graph.custom_minimum_size = Vector2(avail_w, maxf(200.0, height))
	return normalized


func _upgrade_starter_slots(count: int) -> Array[float]:
	match count:
		0:
			return []
		1:
			return [360.0]
		2:
			return [220.0, 500.0]
		3:
			return [140.0, 360.0, 580.0]
		_:
			return [90.0, 270.0, 450.0, 630.0]


func _add_all_group_positions(result: Dictionary) -> void:
	var changed := true
	while changed:
		changed = false
		for group_id_raw in GameState.upgrade_reveal_groups.keys():
			var group_id := String(group_id_raw)
			if not result.has(group_id):
				continue
			var before_count := result.size()
			_add_group_positions(result, group_id, GameState.upgrade_reveal_groups[group_id])
			if result.size() > before_count:
				changed = true


func _add_group_positions(result: Dictionary, starter_id: String, group: Dictionary) -> void:
	var origin: Vector2 = result[starter_id]
	var path_a: Array = group.get("path_a", [])
	var path_b: Array = group.get("path_b", [])
	var common := String(group.get("common", ""))
	# Narrow lanes so adjacent category columns do not collide.
	var lane_offset := 48.0
	var first_step_y := origin.y - 130.0
	var step_gap := 120.0
	for i in path_a.size():
		var id := String(path_a[i])
		if GameState.is_upgrade_node_visible(id):
			result[id] = Vector2(origin.x - lane_offset, first_step_y - float(i) * step_gap)
	for i in path_b.size():
		var id := String(path_b[i])
		if GameState.is_upgrade_node_visible(id):
			result[id] = Vector2(origin.x + lane_offset, first_step_y - float(i) * step_gap)
	if common != "" and GameState.is_upgrade_node_visible(common):
		var path_steps := maxi(path_a.size(), path_b.size())
		var common_y := first_step_y - float(maxi(path_steps - 1, 0)) * step_gap - 140.0
		result[common] = Vector2(origin.x, common_y)


func _visible_upgrade_ids_in_tier(tier: int) -> Array[String]:
	var result: Array[String] = []
	var ids: Array = GameState.visible_upgrade_nodes.duplicate()
	ids.sort_custom(func(a, b): return GameState.skill_data(a).get("order", 0) < GameState.skill_data(b).get("order", 0))
	for id in ids:
		var node: Dictionary = GameState.skill_data(id)
		if not node.is_empty() and int(node.tier) == tier:
			result.append(id)
	return result


func _upgrade_tier_y(tier: int) -> float:
	match tier:
		0:
			return 2400.0
		1:
			return 2240.0
		2:
			return 2080.0
		3:
			return 1920.0
	return 2400.0


const ICON_FAMILY := {
	"greater_chain_strike": "chain_strike",
	"greater_execute_weakness": "execute_weakness",
	"greater_overpower": "overpower",
	"greater_bleeding_strikes": "bleeding_strikes",
	"greater_rampage": "rampage",
	"greater_regen": "basic_regen",
	"greater_reserves": "basic_reserves",
	"greater_life_steal": "life_steal",
	"greater_thorns": "thorns",
	"greater_last_stand": "last_stand",
	"greater_battle_mending": "battle_mending",
	"greater_shield_recovery": "shield_recovery",
	"greater_spell_echo": "spell_echo",
	"greater_arcane_flow": "arcane_flow",
	"greater_empowered_first_cast": "empowered_first_cast",
	"greater_boss_focus": "boss_focus",
	"greater_quick_recovery": "quick_recovery",
	"greater_haste": "basic_haste",
	"greater_gold_rush": "gold_rush",
	"greater_lucky_emeralds": "lucky_emeralds",
	"greater_discount_training": "discount_training",
	"greater_treasure_boss": "treasure_boss",
	"greater_greedy_momentum": "greedy_momentum",
	"steady_training": "basic_attack_update",
	"spell_power_training": "ability_update",
"advanced_blade_training": "basic_attack_update",
	"reinforced_skin": "iron_skin",
	"ability_mastery": "ability_update",
	"swift_casting": "quick_casting",
	"simple_boss_gold": "boss_focus",
	"simple_discount": "discount_training",
}


func _add_skill_icon(btn: Button, id: String, dimmed: bool) -> void:
	var base_id := GameState.base_skill_id(id)
	var icon_id: String = ICON_FAMILY.get(base_id, base_id)
	var path := "res://assets/icons/%s.png" % icon_id
	if not ResourceLoader.exists(path):
		btn.text = base_id.substr(0, 3).to_upper()
		return
	var tex := load(path) as Texture2D
	if tex == null:
		btn.text = id.substr(0, 3).to_upper()
		return
	var icon := TextureRect.new()
	icon.texture = tex
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(36, 36)
	icon.position = Vector2(12, 8)
	icon.size = Vector2(36, 36)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dimmed:
		icon.modulate = Color(0.4, 0.4, 0.5, 0.6)
	btn.add_child(icon)

	var tier := int(GameState.skill_data(id).get("tier", 0))
	if tier > 0:
		var numerals := ["", "I", "II", "III", "IV"]
		var tier_text: String = numerals[clampi(tier, 1, 4)]
		var badge := Label.new()
		badge.text = tier_text
		badge.add_theme_font_size_override("font_size", 9)
		badge.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0) if not dimmed else Color(0.45, 0.45, 0.55))
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.position = Vector2(42, -2)
		badge.size = Vector2(18, 18)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.35, 0.38, 0.55, 0.9)
		bg.corner_radius_top_left = 9
		bg.corner_radius_top_right = 9
		bg.corner_radius_bottom_left = 9
		bg.corner_radius_bottom_right = 9
		badge.add_theme_stylebox_override("normal", bg)
		btn.add_child(badge)


func _node_color(id: String) -> Color:
	if not GameState.is_upgrade_node_visible(id):
		return Color(0.11, 0.12, 0.18)
	if GameState.is_upgrade_node_path_locked(id):
		return Color(0.14, 0.14, 0.18)
	if GameState.is_upgrade_node_common_locked(id):
		return Color(0.20, 0.20, 0.28)
	if GameState.is_upgrade_node_complete(id):
		return Color(0.82, 0.68, 0.12)
	if GameState.can_upgrade_node(id):
		return Color(0.18, 0.58, 0.32)
	return Color(0.26, 0.27, 0.36)


func _node_style(color: Color, highlighted: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.9, 0.9, 1.0) if highlighted else Color(0.45, 0.48, 0.6)
	style.border_width_left = 3 if highlighted else 2
	style.border_width_right = 3 if highlighted else 2
	style.border_width_top = 3 if highlighted else 2
	style.border_width_bottom = 3 if highlighted else 2
	style.corner_radius_top_left = 60
	style.corner_radius_top_right = 60
	style.corner_radius_bottom_left = 60
	style.corner_radius_bottom_right = 60
	return style


func _tooltip_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 1.0)
	style.border_color = Color(0.62, 0.68, 0.9, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


func _node_link_color(parent_id: String, child_id: String) -> Color:
	if GameState.is_upgrade_node_path_locked(parent_id) or GameState.is_upgrade_node_path_locked(child_id):
		return Color(0.24, 0.24, 0.30, 0.75)
	if GameState.is_upgrade_node_common_locked(child_id):
		return Color(0.34, 0.34, 0.44, 0.75)
	if GameState.is_upgrade_node_visible(child_id):
		return Color(0.72, 0.75, 0.86, 0.85)
	if GameState.is_upgrade_node_complete(parent_id):
		return Color(0.78, 0.65, 0.18, 0.65)
	return Color(0.17, 0.18, 0.25, 0.65)


func _required_parent_names(id: String) -> String:
	var d: Dictionary = GameState.skill_data(id)
	if d.is_empty():
		return ""
	var names: Array[String] = []
	for parent_id in d.parents:
		var parent := String(parent_id)
		if not GameState.is_upgrade_node_complete(parent):
			var pd: Dictionary = GameState.skill_data(parent)
			if not pd.is_empty():
				names.append(pd.name)
	return ", ".join(names)


func _rebuild_abilities() -> void:
	for c in _abilities_list.get_children():
		c.queue_free()
	var ids := Database.ABILITIES.keys()
	ids.sort_custom(func(a, b): return Database.ABILITIES[a].order < Database.ABILITIES[b].order)
	for id in ids:
		var d: Dictionary = Database.ABILITIES[id]
		var unlocked := GameState.is_unlocked(id)
		var lvl := GameState.get_ability_level(id)

		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)

		var name_lbl := Label.new()
		var status := ("Lv.%d" % lvl) if unlocked else "LOCKED"
		name_lbl.text = "%s  -  %s" % [d.name, status]
		name_lbl.add_theme_color_override("font_color", d.color)
		box.add_child(name_lbl)

		var desc := Label.new()
		var display_level := lvl if unlocked else 1
		desc.text = Database.ability_description(
			id,
			display_level,
			GameState.ability_power_multiplier(),
			GameState.ability_cooldown_multiplier()
		)
		desc.add_theme_font_size_override("font_size", 12)
		desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(desc)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var cost := GameState.ability_action_cost(id)
		var act_btn := Button.new()
		act_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		act_btn.text = ("Unlock  %d em" % cost) if not unlocked else ("Upgrade  %d em" % cost)
		act_btn.disabled = GameState.emeralds < cost
		act_btn.pressed.connect(func(): GameState.upgrade_or_unlock_ability(id))
		row.add_child(act_btn)

		var equip_btn := Button.new()
		equip_btn.toggle_mode = true
		equip_btn.button_pressed = GameState.is_equipped(id)
		equip_btn.text = "Equipped" if GameState.is_equipped(id) else "Equip"
		equip_btn.disabled = not unlocked
		equip_btn.pressed.connect(func(): _on_equip_pressed(id))
		row.add_child(equip_btn)

		box.add_child(row)

		var sep := HSeparator.new()
		box.add_child(sep)

		_abilities_list.add_child(box)


func _on_equip_pressed(id: String) -> void:
	GameState.toggle_equip(id)  # refresh happens via abilities_changed


func _rebuild_checkpoints() -> void:
	_checkpoint_option.clear()
	var floors := GameState.unlocked_checkpoint_floors()
	var select_index := 0
	for i in floors.size():
		var fnum := floors[i]
		_checkpoint_option.add_item("Floor %d" % fnum, fnum)
		if fnum == GameState.selected_start_floor:
			select_index = i
	# Clamp selection if previously-selected floor is no longer valid.
	if not floors.has(GameState.selected_start_floor):
		GameState.selected_start_floor = floors[select_index]
	_checkpoint_option.select(select_index)


func _on_checkpoint_selected(index: int) -> void:
	GameState.selected_start_floor = _checkpoint_option.get_item_id(index)
	GameState.save_game()


func _update_equipped_label() -> void:
	var names: Array[String] = []
	for id in GameState.equipped:
		names.append(Database.ABILITIES[id].name)
	var listed := ", ".join(names) if names.size() > 0 else "(none)"
	_equipped_label.text = "Equipped %d/%d:\n%s" % [
		GameState.equipped.size(), Database.MAX_EQUIPPED, listed
	]


func _on_start_pressed() -> void:
	go_to_dungeon.emit(GameState.selected_start_floor)


func _build_player_stats_overlay() -> void:
	_stats_overlay = ColorRect.new()
	_stats_overlay.color = Color(0, 0, 0, 0.65)
	_stats_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stats_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_stats_overlay.visible = false
	add_child(_stats_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 560)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var title := Label.new()
	title.text = "HERO STATISTICS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	root.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(480, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_stats_content = VBoxContainer.new()
	_stats_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_content.add_theme_constant_override("separation", 4)
	scroll.add_child(_stats_content)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(0, 40)
	close_btn.pressed.connect(_hide_player_stats_panel)
	root.add_child(close_btn)


func _toggle_player_stats_panel() -> void:
	if _stats_overlay.visible:
		_hide_player_stats_panel()
	else:
		_show_player_stats_panel()


func _show_player_stats_panel() -> void:
	_refresh_player_stats_panel()
	_stats_overlay.visible = true


func _hide_player_stats_panel() -> void:
	_stats_overlay.visible = false


func _refresh_player_stats_panel() -> void:
	for child in _stats_content.get_children():
		child.queue_free()

	_add_stats_section("Progress")
	_add_stats_line("Gold", str(GameState.gold))
	_add_stats_line("Emeralds", str(GameState.emeralds))
	_add_stats_line("Deepest Floor", "%d / %d" % [GameState.deepest_floor, Database.MAX_FLOORS])
	_add_stats_line("Dungeon Runs", str(GameState.dungeon_runs))
	_add_stats_line("Highest Checkpoint", str(GameState.highest_checkpoint))

	_add_stats_section("Core Stats")
	var stat_ids := Database.STATS.keys()
	stat_ids.sort_custom(func(a, b): return Database.STATS[a].order < Database.STATS[b].order)
	for id in stat_ids:
		var d: Dictionary = Database.STATS[id]
		_add_stats_line(d.name, Database.format_stat(id, GameState.get_stat_value(id)))

	_add_stats_section("Combat Modifiers")
	_add_stats_line("Ability Power", "+%.0f%%" % ((GameState.ability_power_multiplier() - 1.0) * 100.0))
	_add_stats_line("Ability Cooldown", "-%.0f%%" % ((1.0 - GameState.ability_cooldown_multiplier()) * 100.0))
	var double_spell := GameState.double_spell_chance()
	if double_spell > 0.0:
		_add_stats_line("Double Spell", "%.0f%% chance to halve cooldown" % (double_spell * 100.0))
	var recover_chance := GameState.recover_on_hit_chance()
	if recover_chance > 0.0:
		_add_stats_line("Recover on Hit", "%.0f%% chance to recover %.1fs cooldown" % [
			recover_chance * 100.0, GameState.recover_on_hit_seconds()
		])

	_add_stats_section("Economy")
	_add_stats_line("Gold Rewards", "x%.2f" % GameState.gold_reward_multiplier())
	var upgrade_discount := GameState.upgrade_effect_value("upgrade_discount_by_rank")
	if upgrade_discount > 0.0:
		_add_stats_line("Upgrade Discount", "-%.0f%% gold skill costs" % (upgrade_discount * 100.0))
	var emerald_bonus := GameState.upgrade_effect_value("emerald_chance_bonus_by_rank")
	if emerald_bonus > 0.0:
		_add_stats_line("Emerald Drop Chance", "+%.1f%%" % (emerald_bonus * 100.0))

	_add_active_skill_sections()
	_add_ability_section()


func _add_stats_section(title: String) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	_stats_content.add_child(spacer)

	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.65, 0.78, 1.0))
	_stats_content.add_child(label)


func _add_stats_line(name: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_stats_content.add_child(row)

	var name_lbl := Label.new()
	name_lbl.text = name
	name_lbl.custom_minimum_size = Vector2(190, 0)
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.78, 0.78, 0.82))
	row.add_child(name_lbl)

	var value_lbl := Label.new()
	value_lbl.text = value
	value_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value_lbl.add_theme_font_size_override("font_size", 13)
	value_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	row.add_child(value_lbl)


func _add_active_skill_sections() -> void:
	var active_ids: Array[String] = []
	for node_id in GameState.upgrade_node_ranks.keys():
		if GameState.get_upgrade_node_rank(String(node_id)) <= 0:
			continue
		if GameState.skill_data(String(node_id)).is_empty():
			continue
		active_ids.append(String(node_id))
	active_ids.sort_custom(func(a, b):
		var na: Dictionary = GameState.skill_data(a)
		var nb: Dictionary = GameState.skill_data(b)
		if int(na.tier) == int(nb.tier):
			return int(na.order) < int(nb.order)
		return int(na.tier) < int(nb.tier)
	)

	if active_ids.is_empty():
		return

	_add_stats_section("Active Skills")
	for node_id in active_ids:
		var node: Dictionary = GameState.skill_data(node_id)
		var rank := GameState.get_upgrade_node_rank(node_id)
		var max_rank := int(node.max_ranks)
		var detail := _active_skill_detail(node_id, node, rank)
		_add_stats_line("%s (%d/%d)" % [node.name, rank, max_rank], detail)


func _active_skill_detail(node_id: String, node: Dictionary, rank: int) -> String:
	if node.has("effect_text"):
		return String(node.effect_text)
	if node.has("stat"):
		return "+%s %s per rank" % [
			Database.format_stat(String(node.stat), float(node.bonus_per_rank)),
			Database.STATS[String(node.stat)].name
		]
	if node.has("gold_bonus_by_rank"):
		var bonuses: Array = node["gold_bonus_by_rank"]
		var index := clampi(rank, 1, bonuses.size()) - 1
		return "+%.0f%% gold" % (float(bonuses[index]) * 100.0)
	if node.has("chance_by_rank"):
		var chances: Array = node["chance_by_rank"]
		var index := clampi(rank, 1, chances.size()) - 1
		return "%.0f%% chance" % (float(chances[index]) * 100.0)
	if node.has("cooldown_reduction_per_rank"):
		return "-%.0f%% ability cooldown per rank" % (float(node.cooldown_reduction_per_rank) * 100.0)
	if node.has("ability_power_per_rank"):
		return "+%.0f%% ability power per rank" % (float(node.ability_power_per_rank) * 100.0)
	return String(node.get("desc", ""))


func _add_ability_section() -> void:
	_add_stats_section("Abilities")
	var ids := Database.ABILITIES.keys()
	ids.sort_custom(func(a, b): return Database.ABILITIES[a].order < Database.ABILITIES[b].order)
	for id in ids:
		var d: Dictionary = Database.ABILITIES[id]
		if not GameState.is_unlocked(id):
			_add_stats_line(d.name, "Locked")
			continue
		var lvl := GameState.get_ability_level(id)
		var status := "Equipped" if GameState.is_equipped(id) else "Unlocked"
		var detail := Database.ability_description(
			id,
			lvl,
			GameState.ability_power_multiplier(),
			GameState.ability_cooldown_multiplier()
		)
		_add_stats_line("%s Lv.%d" % [d.name, lvl], "%s — %s" % [status, detail])


func _build_reset_confirm_overlay() -> void:
	_reset_confirm_overlay = ColorRect.new()
	_reset_confirm_overlay.color = Color(0, 0, 0, 0.75)
	_reset_confirm_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reset_confirm_overlay.visible = false
	_reset_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_reset_confirm_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reset_confirm_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	margin.add_child(root)
	panel.add_child(margin)

	var title := Label.new()
	title.text = "Reset Skill Tree?"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var desc := Label.new()
	desc.text = "All skill points will be refunded and the tree will be regenerated. This cannot be undone."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 16)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(desc)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(120, 40)
	cancel_btn.pressed.connect(_hide_reset_confirm)
	btn_row.add_child(cancel_btn)

	var confirm_btn := Button.new()
	confirm_btn.text = "Reset"
	confirm_btn.custom_minimum_size = Vector2(120, 40)
	confirm_btn.add_theme_color_override("font_color", Color(0.9, 0.35, 0.35))
	confirm_btn.pressed.connect(_confirm_reset_skills)
	btn_row.add_child(confirm_btn)


func _show_reset_confirm() -> void:
	_reset_confirm_overlay.visible = true


func _hide_reset_confirm() -> void:
	_reset_confirm_overlay.visible = false


func _confirm_reset_skills() -> void:
	_hide_reset_confirm()
	var refund := _calculate_refund()
	GameState.gold += refund
	_known_upgrade_nodes.clear()
	_last_graph_height = 0.0
	_preserve_tree_scroll = false
	GameState.reset_upgrade_tree()
	_refresh()
	_scroll_upgrade_tree_to_bottom.call_deferred()


func _calculate_refund() -> int:
	var total := 0
	for node_id in GameState.upgrade_node_ranks:
		var rank: int = GameState.upgrade_node_ranks[node_id]
		if rank <= 0:
			continue
		var node_data: Dictionary = GameState.skill_data(String(node_id))
		var costs: Array = node_data.get("costs", [])
		for i in range(rank):
			if i < costs.size():
				total += int(costs[i])
	return total


func _rebuild_upgrade_graph() -> void:
	for child in _upgrade_graph.get_children():
		child.queue_free()
	_build_upgrade_tree_graph(_upgrade_graph)


func _build_new_game_confirm_overlay() -> void:
	_new_game_confirm_overlay = ColorRect.new()
	_new_game_confirm_overlay.color = Color(0, 0, 0, 0.75)
	_new_game_confirm_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_new_game_confirm_overlay.visible = false
	_new_game_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_new_game_confirm_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_new_game_confirm_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	center.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	margin.add_child(root)
	panel.add_child(margin)

	var title := Label.new()
	title.text = "Start New Game?"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var desc := Label.new()
	desc.text = "This deletes all progress: gold, emeralds, skills, abilities, and floors. You will start from scratch. This cannot be undone."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 16)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(desc)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(120, 40)
	cancel_btn.pressed.connect(_hide_new_game_confirm)
	btn_row.add_child(cancel_btn)

	var confirm_btn := Button.new()
	confirm_btn.text = "New Game"
	confirm_btn.custom_minimum_size = Vector2(140, 40)
	confirm_btn.add_theme_color_override("font_color", Color(0.95, 0.4, 0.4))
	confirm_btn.pressed.connect(_confirm_new_game)
	btn_row.add_child(confirm_btn)


func _show_new_game_confirm() -> void:
	_new_game_confirm_overlay.visible = true


func _hide_new_game_confirm() -> void:
	_new_game_confirm_overlay.visible = false


func _confirm_new_game() -> void:
	_hide_new_game_confirm()
	_hide_player_stats_panel()
	_selected_upgrade_node = "foundation"
	_known_upgrade_nodes.clear()
	_last_graph_height = 0.0
	_preserve_tree_scroll = false
	GameState.reset_progress()
	_refresh()
	_scroll_upgrade_tree_to_bottom.call_deferred()
