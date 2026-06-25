extends Node2D
## The dungeon run: isometric auto-combat against waves of enemies.
## Handles hero auto-attack, automatic ability casting, rewards, floor /
## wave / checkpoint progression and win / loss.

signal return_to_town

const CombatEntity := preload("res://scripts/CombatEntity.gd")

const HERO_POS := Vector2(360.0, 440.0)
const ENEMY_ANCHOR := Vector2(820.0, 360.0)
const INTER_WAVE_DELAY := 0.7
const NEXT_WAVE_SPAWN_DELAY := 5.0

var running: bool = false
var floor_num: int = 1
var wave_index: int = 0
var waves: Array = []            # Array[Array[Dictionary]] enemy specs for current floor
var enemies: Array = []          # Array[CombatEntity] currently alive
var hero: CombatEntity

# Equipped ability runtime: each {id, level, cooldown, timer}.
var _abilities: Array = []
var _ability_labels: Array = []

var _transition: float = 0.0
var _pending_action: String = ""   # "next_floor" | ""
var _wave_spawn_timer: float = 0.0

var hero_buff_timer: float = 0.0
var hero_buff_mult: float = 0.0    # +fraction to attack & attack speed
var hero_shield: float = 0.0

var run_gold: int = 0
var run_emeralds: int = 0

# HUD nodes.
var _ui: Control
var _floor_label: Label
var _wave_label: Label
var _gold_label: Label
var _emerald_label: Label
var _hp_label: Label
var _ability_hud: VBoxContainer
var _end_overlay: ColorRect
var _end_panel: PanelContainer
var _end_label: Label


func begin_run(start_floor: int) -> void:
	randomize()
	floor_num = clampi(start_floor, 1, Database.MAX_FLOORS)
	run_gold = 0
	run_emeralds = 0
	hero_shield = 0.0
	_build_environment()
	_build_ui()
	_spawn_hero()
	_build_abilities()
	_start_floor()
	running = true


# --- Environment -----------------------------------------------------------
func _build_environment() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.09)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Big isometric floor diamond.
	var ground := Polygon2D.new()
	var cx := 640.0
	var cy := 430.0
	var w := 1180.0
	var h := 560.0
	ground.polygon = PackedVector2Array([
		Vector2(cx, cy - h * 0.5),
		Vector2(cx + w * 0.5, cy),
		Vector2(cx, cy + h * 0.5),
		Vector2(cx - w * 0.5, cy),
	])
	ground.color = Color(0.14, 0.14, 0.2)
	add_child(ground)

	var edge := Line2D.new()
	edge.points = ground.polygon
	edge.add_point(ground.polygon[0])
	edge.width = 3.0
	edge.default_color = Color(0.25, 0.25, 0.35)
	add_child(edge)


# --- Hero ------------------------------------------------------------------
func _spawn_hero() -> void:
	hero = CombatEntity.new()
	hero.position = HERO_POS
	add_child(hero)
	hero.setup("Hero", Color(0.35, 0.6, 1.0), true, 1.1)
	hero.init_stats(
		GameState.get_stat_value("max_hp"),
		GameState.get_stat_value("attack"),
		GameState.get_stat_value("defense"),
		GameState.get_stat_value("attack_speed")
	)
	hero.crit_chance = GameState.get_stat_value("crit_chance")
	hero.crit_damage = GameState.get_stat_value("crit_damage")


# --- Abilities -------------------------------------------------------------
func _build_abilities() -> void:
	_abilities.clear()
	for id in GameState.equipped:
		if not GameState.is_unlocked(id):
			continue
		var d: Dictionary = Database.ABILITIES[id]
		var starts_ready: bool = String(d.type) != "shield"
		_abilities.append({
			"id": id,
			"level": GameState.get_ability_level(id),
			"cooldown": Database.ability_cooldown(id, GameState.get_ability_level(id)),
			"timer": Database.ability_cooldown(id, GameState.get_ability_level(id)) if starts_ready else 0.0,
		})


# --- Floor / wave flow -----------------------------------------------------
func _start_floor() -> void:
	waves = _build_waves(floor_num)
	wave_index = 0
	_wave_spawn_timer = 0.0
	_spawn_wave(wave_index, true)


func _build_waves(f: int) -> Array:
	var result: Array = []
	var is_boss_floor := f % Database.CHECKPOINT_INTERVAL == 0
	result.append(_make_pack(f, Database.ENEMIES_PER_WAVE))
	var final_wave := _make_pack(f, Database.ENEMIES_PER_WAVE)
	if is_boss_floor:
		final_wave.append(Database.enemy_stats(f, true))
	final_wave.append(_make_blue_boss(f))
	result.append(final_wave)
	return result


func _make_pack(f: int, count: int) -> Array:
	var pack: Array = []
	for i in count:
		pack.append(Database.enemy_stats(f, false))
	return pack


func _make_blue_boss(f: int) -> Dictionary:
	var spec := Database.enemy_stats(f, false)
	spec.max_hp *= 2.0
	spec.attack *= 2.0
	spec.gold *= 2
	spec.emerald_chance = maxf(spec.emerald_chance, 0.35)
	spec.variant = "blue_boss"
	return spec


func _spawn_wave(index: int, clear_existing: bool = false) -> void:
	if clear_existing:
		for e in enemies:
			if is_instance_valid(e):
				e.queue_free()
		enemies.clear()

	var specs: Array = waves[index]
	for i in specs.size():
		var spec: Dictionary = specs[i]
		var e := CombatEntity.new()
		var is_boss: bool = spec.is_boss
		e.position = _enemy_position(i, specs.size(), is_boss)
		add_child(e)
		var col := Color(0.85, 0.35, 0.3)
		var ename := "Enemy"
		var scl := 1.0
		if is_boss:
			col = Color(0.7, 0.2, 0.7)
			ename = "BOSS"
			scl = 1.7
		elif spec.get("variant", "") == "blue_boss":
			col = Color(0.15, 0.45, 1.0)
			ename = "Blue Boss"
			scl = 1.35
		e.setup(ename, col, false, scl)
		e.init_stats(spec.max_hp, spec.attack, spec.defense, spec.attack_speed)
		e.reward_gold = spec.gold
		e.emerald_chance = spec.emerald_chance
		e.emerald_amount = spec.emerald_amount
		e.is_boss = is_boss
		e.modulate.a = 0.0
		enemies.append(e)
		var fade := create_tween()
		fade.tween_property(e, "modulate:a", 1.0, 0.45)


func _enemy_position(i: int, total: int, is_boss: bool) -> Vector2:
	if is_boss:
		return ENEMY_ANCHOR + Vector2(randf_range(-25.0, 70.0), randf_range(-25.0, 45.0))
	# Randomized positions inside the enemy side of the isometric arena.
	var spread_x := randf_range(-70.0, 230.0)
	var spread_y := randf_range(-120.0, 150.0)
	return ENEMY_ANCHOR + Vector2(spread_x, spread_y)


# --- Main loop -------------------------------------------------------------
func _process(delta: float) -> void:
	if not running:
		return

	if _transition > 0.0:
		_transition -= delta
		if _transition <= 0.0:
			_resolve_transition()
		_update_hud()
		return

	_update_buff(delta)
	_hero_attack(delta)
	_cast_abilities(delta)
	_tick_enemy_dots(delta)
	_enemy_attacks(delta)
	_reap_dead()

	if not hero.alive:
		_end_run(false)
		_update_hud()
		return

	_maybe_spawn_next_wave(delta)

	if enemies.is_empty():
		_begin_transition()

	_update_hud()


func _begin_transition() -> void:
	_pending_action = "next_floor"
	_transition = INTER_WAVE_DELAY


func _resolve_transition() -> void:
	match _pending_action:
		"next_floor":
			GameState.register_floor_cleared(floor_num)
			if floor_num >= Database.MAX_FLOORS:
				_end_run(true)
				return
			floor_num += 1
			_start_floor()
	_pending_action = ""


func _maybe_spawn_next_wave(delta: float) -> void:
	if wave_index + 1 >= waves.size():
		return
	_wave_spawn_timer += delta
	if _wave_spawn_timer < NEXT_WAVE_SPAWN_DELAY and enemies.size() > 1:
		return
	wave_index += 1
	_wave_spawn_timer = 0.0
	_spawn_wave(wave_index, false)


# --- Combat steps ----------------------------------------------------------
func _hero_attack(delta: float) -> void:
	if enemies.is_empty():
		return
	var spd: float = hero.attack_speed * (1.0 + (hero_buff_mult if hero_buff_timer > 0.0 else 0.0))
	hero.atk_timer += delta
	var interval := 1.0 / maxf(0.1, spd)
	if hero.atk_timer < interval:
		return
	hero.atk_timer -= interval
	var target: CombatEntity = enemies[0]
	var atk: float = hero.attack * (1.0 + (hero_buff_mult if hero_buff_timer > 0.0 else 0.0))
	var dmg := maxf(1.0, atk - target.defense)
	var is_crit := randf() < hero.crit_chance
	if is_crit:
		dmg *= hero.crit_damage
	# Launch a projectile; damage is applied when it reaches the target.
	_fire_projectile(hero.position, target, Color(0.6, 0.85, 1.0), dmg, is_crit)


func _cast_abilities(delta: float) -> void:
	for i in _abilities.size():
		var ab: Dictionary = _abilities[i]
		ab.timer += delta
		if ab.timer >= ab.cooldown:
			if _try_cast(ab):
				ab.timer = 0.0


func _try_cast(ab: Dictionary) -> bool:
	var id: String = ab.id
	var d: Dictionary = Database.ABILITIES[id]
	var power := Database.ability_power(id, ab.level)
	match d.type:
		"damage":
			if enemies.is_empty():
				return false
			var t: CombatEntity = enemies[0]
			_fire_projectile(
				hero.position,
				t,
				Color(1.0, 0.15, 0.05),
				power,
				false,
				10.0,
				18.0,
				900.0,
				0.45,
				d.color,
				true
			)
		"aoe":
			if enemies.is_empty():
				return false
			_call_meteor(power, d.color)
		"dot":
			if enemies.is_empty():
				return false
			for e in enemies:
				e.add_dot(power, d.dot_duration, d.dot_interval)
			_spawn_text(enemies[0].position, d.name, d.color, false)
		"buff":
			hero_buff_mult = power
			hero_buff_timer = d.buff_duration
			_spawn_text(hero.position, "Frenzy!", d.color, true)
		"shield":
			var shield_amount := hero.max_hp * power
			hero_shield = maxf(hero_shield, shield_amount)
			_spawn_text(hero.position, "+%d shield" % int(round(shield_amount)), d.color, true)
		"heal":
			hero.heal(power)
			_spawn_text(hero.position, "+" + str(int(round(power))), d.color, false)
		_:
			return false
	return true


func _update_buff(delta: float) -> void:
	if hero_buff_timer > 0.0:
		hero_buff_timer -= delta


func _tick_enemy_dots(delta: float) -> void:
	for e in enemies:
		if not e.alive:
			continue
		var remaining: Array = []
		for dot in e.dots:
			dot.time_left -= delta
			dot.tick_timer -= delta
			if dot.tick_timer <= 0.0:
				dot.tick_timer += dot.interval
				e.take_damage(dot.dps)
				_spawn_text(e.position, str(int(round(dot.dps))), Color(0.5, 0.9, 0.3), false)
			if dot.time_left > 0.0:
				remaining.append(dot)
		e.dots = remaining


func _enemy_attacks(delta: float) -> void:
	for e in enemies:
		if not e.alive:
			continue
		e.atk_timer += delta
		var interval := 1.0 / maxf(0.1, e.attack_speed)
		if e.atk_timer < interval:
			continue
		e.atk_timer -= interval
		var dmg := maxf(1.0, e.attack - hero.defense)
		var core_radius := 7.0 if e.is_boss else 5.0
		var glow_radius := 13.0 if e.is_boss else 9.0
		var shot_color := Color(0.95, 0.25, 0.2) if e.is_boss else Color(0.8, 0.25, 0.15)
		_fire_projectile(
			e.position,
			hero,
			shot_color,
			dmg,
			false,
			core_radius,
			glow_radius,
			1250.0,
			0.32,
			Color(1, 0.4, 0.4),
			false
		)


func _reap_dead() -> void:
	var survivors: Array = []
	for e in enemies:
		if e.alive:
			survivors.append(e)
		else:
			_grant_rewards(e)
			e.play_death()
	enemies = survivors


func _grant_rewards(e: CombatEntity) -> void:
	GameState.add_gold(e.reward_gold)
	run_gold += e.reward_gold
	if randf() < e.emerald_chance:
		GameState.add_emeralds(e.emerald_amount)
		run_emeralds += e.emerald_amount
		_spawn_text(e.position + Vector2(0, -30), "+%d em" % e.emerald_amount, Color(0.4, 0.9, 0.4), false)


# --- End of run ------------------------------------------------------------
func _end_run(victory: bool) -> void:
	if not running:
		return
	running = false
	GameState.save_game()
	var msg := ""
	if victory:
		msg = "VICTORY!\nYou cleared all %d floors.\n\nThis run: +%d gold, +%d emeralds" % [
			Database.MAX_FLOORS, run_gold, run_emeralds]
	else:
		msg = "YOU DIED\nFloor %d\n\nThis run: +%d gold, +%d emeralds" % [
			floor_num, run_gold, run_emeralds]
	_end_label.text = msg
	_end_overlay.visible = true


# --- UI / HUD --------------------------------------------------------------
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)

	# Top bar.
	var top := HBoxContainer.new()
	top.position = Vector2(20, 14)
	top.add_theme_constant_override("separation", 24)
	_ui.add_child(top)

	_floor_label = _make_hud_label(top, 24, Color(1, 1, 1))
	_wave_label = _make_hud_label(top, 20, Color(0.8, 0.8, 0.9))

	var right := HBoxContainer.new()
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.position = Vector2(-360, 14)
	right.add_theme_constant_override("separation", 20)
	_ui.add_child(right)
	_gold_label = _make_hud_label(right, 20, Color(1, 0.85, 0.2))
	_emerald_label = _make_hud_label(right, 20, Color(0.4, 0.9, 0.4))

	# Hero HP label.
	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 18)
	_hp_label.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
	_hp_label.position = Vector2(20, 660)
	_ui.add_child(_hp_label)

	# Ability cooldown HUD (bottom-left).
	_ability_hud = VBoxContainer.new()
	_ability_hud.position = Vector2(20, 500)
	_ui.add_child(_ability_hud)

	# End-of-run modal overlay (dims screen, centers the panel, blocks clicks).
	_end_overlay = ColorRect.new()
	_end_overlay.color = Color(0, 0, 0, 0.65)
	_end_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_end_overlay.visible = false
	_ui.add_child(_end_overlay)

	var end_center := CenterContainer.new()
	end_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_overlay.add_child(end_center)

	_end_panel = PanelContainer.new()
	_end_panel.custom_minimum_size = Vector2(400, 220)
	end_center.add_child(_end_panel)

	var ep_margin := MarginContainer.new()
	ep_margin.add_theme_constant_override("margin_left", 24)
	ep_margin.add_theme_constant_override("margin_right", 24)
	ep_margin.add_theme_constant_override("margin_top", 20)
	ep_margin.add_theme_constant_override("margin_bottom", 20)
	_end_panel.add_child(ep_margin)

	var ep_vbox := VBoxContainer.new()
	ep_vbox.add_theme_constant_override("separation", 16)
	ep_margin.add_child(ep_vbox)

	_end_label = Label.new()
	_end_label.add_theme_font_size_override("font_size", 22)
	_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ep_vbox.add_child(_end_label)

	var town_btn := Button.new()
	town_btn.text = "Return to Town"
	town_btn.custom_minimum_size = Vector2(0, 44)
	town_btn.pressed.connect(_on_flee_pressed)
	ep_vbox.add_child(town_btn)


func _make_hud_label(parent: Control, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _update_hud() -> void:
	_floor_label.text = "Floor %d / %d" % [floor_num, Database.MAX_FLOORS]
	var total_waves := waves.size()
	_wave_label.text = "Wave %d / %d" % [mini(wave_index + 1, total_waves), total_waves]
	_gold_label.text = "Gold: %d" % GameState.gold
	_emerald_label.text = "Emeralds: %d" % GameState.emeralds
	if hero != null:
		var shield_text := ""
		if hero_shield > 0.0:
			shield_text = "   Shield: %d" % int(ceil(hero_shield))
		_hp_label.text = "HP: %d / %d%s" % [int(ceil(hero.hp)), int(round(hero.max_hp)), shield_text]
	_update_ability_hud()


func _update_ability_hud() -> void:
	# Lazily create one label per equipped ability, then keep them updated.
	while _ability_labels.size() < _abilities.size():
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 16)
		_ability_hud.add_child(l)
		_ability_labels.append(l)
	for i in _abilities.size():
		var ab: Dictionary = _abilities[i]
		var d: Dictionary = Database.ABILITIES[ab.id]
		var lbl: Label = _ability_labels[i]
		if ab.timer >= ab.cooldown:
			lbl.text = "%s: READY" % d.name
			lbl.add_theme_color_override("font_color", d.color)
		else:
			var left: float = ab.cooldown - ab.timer
			lbl.text = "%s: %.1fs" % [d.name, left]
			lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))


# --- Projectiles -----------------------------------------------------------
func _call_meteor(damage: float, color: Color) -> void:
	var impact_pos := Vector2.ZERO
	for e in enemies:
		impact_pos += e.position
	impact_pos /= max(1, enemies.size())
	impact_pos += Vector2(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0))

	var meteor := Node2D.new()
	meteor.position = impact_pos + Vector2(-170.0, -520.0)
	meteor.z_index = 80
	add_child(meteor)

	var glow := Polygon2D.new()
	glow.polygon = _circle(36.0)
	glow.color = Color(color.r, color.g, color.b, 0.35)
	meteor.add_child(glow)

	var core := Polygon2D.new()
	core.polygon = _circle(22.0)
	core.color = color
	meteor.add_child(core)

	var trail := Line2D.new()
	trail.points = PackedVector2Array([Vector2(-70, -110), Vector2.ZERO])
	trail.width = 10.0
	trail.default_color = Color(color.r, color.g, color.b, 0.45)
	meteor.add_child(trail)

	var tween := create_tween()
	tween.tween_property(meteor, "position", impact_pos, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_meteor_impact(impact_pos, damage, color)
		meteor.queue_free()
	)


func _meteor_impact(impact_pos: Vector2, damage: float, color: Color) -> void:
	var shockwave := Polygon2D.new()
	shockwave.position = impact_pos
	shockwave.polygon = _circle(18.0)
	shockwave.color = Color(color.r, color.g, color.b, 0.28)
	shockwave.z_index = 70
	add_child(shockwave)

	var tween := create_tween()
	tween.tween_property(shockwave, "scale", Vector2(5.0, 2.0), 0.28)
	tween.parallel().tween_property(shockwave, "modulate:a", 0.0, 0.28)
	tween.tween_callback(shockwave.queue_free)

	for e in enemies.duplicate():
		if is_instance_valid(e) and e.alive:
			e.take_damage(damage)
			_spawn_text(e.position, str(int(round(damage))), color, true)


func _fire_projectile(
	from: Vector2,
	target: CombatEntity,
	color: Color,
	damage: float,
	is_crit: bool,
	core_radius: float = 6.0,
	glow_radius: float = 11.0,
	speed: float = 1600.0,
	max_duration: float = 0.25,
	impact_text_color: Color = Color(1, 1, 1),
	impact_text_big: bool = false
) -> void:
	var start := from + Vector2(10, -45)
	var target_pos := target.position + Vector2(0, -40)

	var ball := Node2D.new()
	ball.position = start
	ball.z_index = 60
	add_child(ball)

	var glow := Polygon2D.new()
	glow.polygon = _circle(glow_radius)
	glow.color = Color(color.r, color.g, color.b, 0.35)
	ball.add_child(glow)

	var core := Polygon2D.new()
	core.polygon = _circle(core_radius)
	core.color = color
	ball.add_child(core)

	var dist := start.distance_to(target_pos)
	var dur := clampf(dist / speed, 0.08, max_duration)
	var tween := create_tween()
	tween.tween_property(ball, "position", target_pos, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		if is_instance_valid(target) and target.alive:
			var hp_damage := _apply_projectile_damage(target, damage)
			if hp_damage > 0.0:
				_spawn_text(target.position, str(int(round(hp_damage))),
					Color(1, 1, 0.4) if is_crit else impact_text_color,
					is_crit or impact_text_big)
		ball.queue_free()
	)


func _apply_projectile_damage(target: CombatEntity, damage: float) -> float:
	if target != hero or hero_shield <= 0.0:
		target.take_damage(damage)
		return damage
	var absorbed := minf(hero_shield, damage)
	hero_shield -= absorbed
	var remaining := damage - absorbed
	_spawn_text(hero.position + Vector2(0, -18), "-%d shield" % int(round(absorbed)), Color(0.35, 0.65, 1.0), false)
	if remaining > 0.0:
		target.take_damage(remaining)
	return remaining


func _circle(radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts


# --- Floating combat text --------------------------------------------------
func _spawn_text(world_pos: Vector2, text: String, color: Color, big: bool) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22 if big else 16)
	l.add_theme_color_override("font_color", color)
	l.position = world_pos + Vector2(randf_range(-12, 12), -60)
	l.z_index = 100
	add_child(l)
	var tween := create_tween()
	tween.tween_property(l, "position:y", l.position.y - 40.0, 0.7)
	tween.parallel().tween_property(l, "modulate:a", 0.0, 0.7)
	tween.tween_callback(l.queue_free)


func _on_flee_pressed() -> void:
	running = false
	GameState.save_game()
	return_to_town.emit()
