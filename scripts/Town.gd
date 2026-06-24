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

	_stats_list = _make_column(columns, "HERO STATS  (Gold)", 0.42)
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
	var ids := Database.STATS.keys()
	ids.sort_custom(func(a, b): return Database.STATS[a].order < Database.STATS[b].order)
	for id in ids:
		var d: Dictionary = Database.STATS[id]
		var lvl := GameState.get_stat_level(id)
		var val := GameState.get_stat_value(id)
		var cost := GameState.stat_upgrade_cost(id)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.text = "%s  Lv.%d  (%s)" % [d.name, lvl, Database.format_stat(id, val)]
		row.add_child(info)

		var btn := Button.new()
		btn.text = "+  %d g" % cost
		btn.disabled = not GameState.can_upgrade_stat(id)
		btn.pressed.connect(func(): GameState.upgrade_stat(id))
		row.add_child(btn)

		_stats_list.add_child(row)


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
