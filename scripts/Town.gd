extends Control
## Town screen: spend Gold on stats, spend Emeralds on abilities,
## pick a checkpoint and start a run. Built entirely in code (no art assets).

signal go_to_dungeon(start_floor: int)

var _gold_label: Label
var _emerald_label: Label
var _stats_list: VBoxContainer
var _abilities_list: VBoxContainer
var _equipped_label: Label
var _checkpoint_option: OptionButton
var _progress_label: Label
var _selected_upgrade_node: String = "foundation"


func _ready() -> void:
	_build_ui()
	GameState.currencies_changed.connect(_refresh)
	GameState.abilities_changed.connect(_refresh)
	GameState.progress_changed.connect(_refresh)
	_refresh()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.09, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	# --- Header -------------------------------------------------------------
	var header := HBoxContainer.new()
	root.add_child(header)

	var title := Label.new()
	title.text = "TOWN"
	title.add_theme_font_size_override("font_size", 32)
	header.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 22)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	header.add_child(_gold_label)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(24, 0)
	header.add_child(gap)

	_emerald_label = Label.new()
	_emerald_label.add_theme_font_size_override("font_size", 22)
	_emerald_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	header.add_child(_emerald_label)

	# --- Body: three columns ------------------------------------------------
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	root.add_child(columns)

	_stats_list = _make_column(columns, "HERO UPGRADE TREE  (Gold)", 0.42)
	_abilities_list = _make_column(columns, "ABILITIES  (Emeralds)", 0.40)
	var run_col := _make_column(columns, "START RUN", 0.18)
	_build_run_column(run_col)


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
	_progress_label.text = "Deepest floor: %d / %d\nHighest checkpoint: %d" % [
		GameState.deepest_floor, Database.MAX_FLOORS, GameState.highest_checkpoint
	]
	_rebuild_stats()
	_rebuild_abilities()
	_rebuild_checkpoints()
	_update_equipped_label()


func _rebuild_stats() -> void:
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

	var reset_btn := Button.new()
	reset_btn.text = "Reset Tree (Testing)"
	reset_btn.tooltip_text = "Clears only hero upgrade tree ranks and revealed nodes."
	reset_btn.pressed.connect(_on_reset_upgrade_tree_pressed)
	_stats_list.add_child(reset_btn)

	var graph := Control.new()
	graph.custom_minimum_size = Vector2(760, 540)
	graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_list.add_child(graph)
	_build_upgrade_tree_graph(graph)
	_build_upgrade_node_details()


func _build_upgrade_tree_graph(graph: Control) -> void:
	var positions := _upgrade_node_positions()
	var ids := Database.UPGRADE_TREE.keys()
	ids.sort_custom(func(a, b): return Database.UPGRADE_TREE[a].order < Database.UPGRADE_TREE[b].order)

	# Draw parent links first so circular node buttons sit above them.
	for id in ids:
		if not GameState.is_upgrade_node_visible(id):
			continue
		var parent := GameState.get_upgrade_reveal_parent(id)
		if parent == "" or not positions.has(parent) or not positions.has(id):
			continue
		var line := Line2D.new()
		line.points = PackedVector2Array([positions[parent], positions[id]])
		line.width = 4.0
		line.default_color = _node_link_color(parent, id)
		graph.add_child(line)
		var extra_parent := GameState.get_upgrade_extra_reveal_parent(id)
		if extra_parent != "" and positions.has(extra_parent):
			var extra_line := Line2D.new()
			extra_line.points = PackedVector2Array([positions[extra_parent], positions[id]])
			extra_line.width = 4.0
			extra_line.default_color = _node_link_color(extra_parent, id)
			graph.add_child(extra_line)

	for id in ids:
		var d: Dictionary = Database.UPGRADE_TREE[id]
		var visible: bool = GameState.is_upgrade_node_visible(id)
		if not visible:
			continue
		var complete: bool = GameState.is_upgrade_node_complete(id)
		var selected: bool = String(id) == _selected_upgrade_node
		var path_locked := GameState.is_upgrade_node_path_locked(id)
		var btn := Button.new()
		btn.text = _node_short_label(id) if visible else "?"
		btn.position = positions[id] - Vector2(30, 30)
		btn.size = Vector2(60, 60)
		btn.tooltip_text = d.name
		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_stylebox_override("normal", _node_style(_node_color(id), selected))
		btn.add_theme_stylebox_override("hover", _node_style(_node_color(id).lightened(0.15), true))
		btn.add_theme_stylebox_override("pressed", _node_style(_node_color(id).darkened(0.1), true))
		btn.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55) if path_locked else Color(0.95, 0.95, 1.0))
		btn.pressed.connect(func(): _select_upgrade_node(id))
		graph.add_child(btn)
		_add_upgrade_node_icon(graph, id, positions[id], visible)

		var rank_label := Label.new()
		rank_label.text = "LOCK" if path_locked else ("%d/%d" % [GameState.get_upgrade_node_rank(id), int(d.max_ranks)] if visible else "LOCK")
		rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rank_label.add_theme_font_size_override("font_size", 10)
		rank_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65) if path_locked else (Color(0.6, 0.95, 0.6) if complete else Color(0.75, 0.75, 0.85)))
		rank_label.position = positions[id] + Vector2(-32, 34)
		rank_label.size = Vector2(64, 16)
		graph.add_child(rank_label)


func _build_upgrade_node_details() -> void:
	if not Database.UPGRADE_TREE.has(_selected_upgrade_node) or not GameState.is_upgrade_node_visible(_selected_upgrade_node):
		_selected_upgrade_node = "foundation"
	var id := _selected_upgrade_node
	var d: Dictionary = Database.UPGRADE_TREE[id]
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
	var d: Dictionary = Database.UPGRADE_TREE[id]
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


func _on_reset_upgrade_tree_pressed() -> void:
	_selected_upgrade_node = "foundation"
	GameState.reset_upgrade_tree()
	_refresh()


func _upgrade_node_positions() -> Dictionary:
	var result := {}
	var roots := _visible_upgrade_ids_in_tier(0)
	for id in roots:
		result[id] = Vector2(380.0, 485.0)

	var starters := _visible_upgrade_ids_in_tier(1)
	var slots := _upgrade_starter_slots(starters.size())
	for i in starters.size():
		result[starters[i]] = Vector2(slots[i], 405.0)

	for starter_id in starters:
		var group := GameState.get_upgrade_reveal_group(starter_id)
		if group.is_empty() or not result.has(starter_id):
			continue
		_add_group_positions(result, starter_id, group)

	for tier in [2, 3]:
		var ids := _visible_upgrade_ids_in_tier(tier)
		for id in ids:
			if result.has(id):
				continue
			var parent := GameState.get_upgrade_reveal_parent(id)
			if parent != "" and result.has(parent):
				result[id] = Vector2(result[parent].x, _upgrade_tier_y(tier))
			else:
				result[id] = Vector2(380.0, _upgrade_tier_y(tier))
	return result


func _upgrade_starter_slots(count: int) -> Array[float]:
	match count:
		0:
			return []
		1:
			return [380.0]
		2:
			return [250.0, 510.0]
		3:
			return [170.0, 380.0, 590.0]
		_:
			return [95.0, 285.0, 475.0, 665.0]


func _add_group_positions(result: Dictionary, starter_id: String, group: Dictionary) -> void:
	var origin: Vector2 = result[starter_id]
	var path_a: Array = group.get("path_a", [])
	var path_b: Array = group.get("path_b", [])
	var common := String(group.get("common", ""))
	var lane_offset := 54.0
	for i in path_a.size():
		var id := String(path_a[i])
		if GameState.is_upgrade_node_visible(id):
			result[id] = Vector2(origin.x - lane_offset, 310.0 - float(i) * 80.0)
	for i in path_b.size():
		var id := String(path_b[i])
		if GameState.is_upgrade_node_visible(id):
			result[id] = Vector2(origin.x + lane_offset, 310.0 - float(i) * 80.0)
	if common != "" and GameState.is_upgrade_node_visible(common):
		result[common] = Vector2(origin.x, 115.0)


func _visible_upgrade_ids_in_tier(tier: int) -> Array[String]:
	var result: Array[String] = []
	var ids := Database.UPGRADE_TREE.keys()
	ids.sort_custom(func(a, b): return Database.UPGRADE_TREE[a].order < Database.UPGRADE_TREE[b].order)
	for id_raw in ids:
		var id := String(id_raw)
		if int(Database.UPGRADE_TREE[id].tier) == tier and GameState.is_upgrade_node_visible(id):
			result.append(id)
	return result


func _upgrade_tier_y(tier: int) -> float:
	match tier:
		0:
			return 485.0
		1:
			return 405.0
		2:
			return 270.0
		3:
			return 160.0
	return 485.0


func _node_short_label(id: String) -> String:
	match id:
		"foundation":
			return ""
		"basic_attack_update":
			return "ATK"
		"basic_heal_update":
			return "HEAL"
		"basic_ability_update":
			return "ABL"
		"more_gold":
			return "GOLD"
		"blade_training":
			return "ATK"
		"iron_skin":
			return "DEF"
		"quick_casting":
			return "SPD"
		"basic_regen":
			return "REG"
		"basic_reserves":
			return "HP"
		"basic_haste":
			return "CD"
		"ability_update":
			return "POW"
		"advanced_blade_training":
			return "ATK+"
		"reinforced_skin":
			return "DEF+"
		"swift_casting":
			return "SPD+"
		"greater_regen":
			return "REG+"
		"greater_reserves":
			return "HP+"
		"greater_haste":
			return "CD+"
		"ability_mastery":
			return "POW+"
		"recover_on_hit":
			return "HIT"
		"double_spell":
			return "CD%"
		"crushing_criticals":
			return "CRx"
		"battle_rhythm":
			return "RHY"
	return _node_generated_label(id)


func _node_generated_label(id: String) -> String:
	var d: Dictionary = Database.UPGRADE_TREE[id]
	var words := String(d.get("name", id)).split(" ", false)
	var label := ""
	for word in words:
		if label.length() >= 4:
			break
		label += String(word).substr(0, 1).to_upper()
	return label if label != "" else "?"


func _add_upgrade_node_icon(graph: Control, id: String, pos: Vector2, visible: bool) -> void:
	if id != "foundation":
		return
	var color := Color(0.95, 0.95, 1.0) if visible else Color(0.45, 0.45, 0.55)

	var shield := Polygon2D.new()
	shield.polygon = PackedVector2Array([
		pos + Vector2(-10, -9),
		pos + Vector2(10, -9),
		pos + Vector2(8, 4),
		pos + Vector2(0, 14),
		pos + Vector2(-8, 4),
	])
	shield.color = Color(color.r, color.g, color.b, 0.22)
	graph.add_child(shield)

	var shield_outline := Line2D.new()
	shield_outline.points = PackedVector2Array([
		pos + Vector2(-10, -9),
		pos + Vector2(10, -9),
		pos + Vector2(8, 4),
		pos + Vector2(0, 14),
		pos + Vector2(-8, 4),
		pos + Vector2(-10, -9),
	])
	shield_outline.width = 2.0
	shield_outline.default_color = color
	graph.add_child(shield_outline)

	var sword := Line2D.new()
	sword.points = PackedVector2Array([
		pos + Vector2(-13, 12),
		pos + Vector2(12, -13),
	])
	sword.width = 3.0
	sword.default_color = color
	graph.add_child(sword)

	var guard := Line2D.new()
	guard.points = PackedVector2Array([
		pos + Vector2(-2, 3),
		pos + Vector2(6, 11),
	])
	guard.width = 2.0
	guard.default_color = color
	graph.add_child(guard)


func _node_color(id: String) -> Color:
	if not GameState.is_upgrade_node_visible(id):
		return Color(0.11, 0.12, 0.18)
	if GameState.is_upgrade_node_path_locked(id):
		return Color(0.14, 0.14, 0.18)
	if GameState.is_upgrade_node_common_locked(id):
		return Color(0.20, 0.20, 0.28)
	if GameState.is_upgrade_node_complete(id):
		return Color(0.15, 0.48, 0.28)
	if GameState.can_upgrade_node(id):
		return Color(0.28, 0.42, 0.9)
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


func _node_link_color(parent_id: String, child_id: String) -> Color:
	if GameState.is_upgrade_node_path_locked(parent_id) or GameState.is_upgrade_node_path_locked(child_id):
		return Color(0.24, 0.24, 0.30, 0.75)
	if GameState.is_upgrade_node_common_locked(child_id):
		return Color(0.34, 0.34, 0.44, 0.75)
	if GameState.is_upgrade_node_visible(child_id):
		return Color(0.72, 0.75, 0.86, 0.85)
	if GameState.is_upgrade_node_complete(parent_id):
		return Color(0.38, 0.45, 0.75, 0.55)
	return Color(0.17, 0.18, 0.25, 0.65)


func _required_parent_names(id: String) -> String:
	var d: Dictionary = Database.UPGRADE_TREE[id]
	var names: Array[String] = []
	for parent_id in d.parents:
		var parent := String(parent_id)
		if not GameState.is_upgrade_node_complete(parent):
			names.append(Database.UPGRADE_TREE[parent].name)
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
		desc.text = d.desc
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
