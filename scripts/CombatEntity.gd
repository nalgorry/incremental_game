extends Node2D
## A hero or enemy token in the dungeon: holds combat numbers and draws a
## simple isometric character (no art assets needed) plus an HP bar.

var max_hp: float = 1.0
var hp: float = 1.0
var attack: float = 1.0
var defense: float = 0.0
var attack_speed: float = 1.0
var atk_timer: float = 0.0
var is_hero: bool = false
var alive: bool = true

# Hero-only combat modifiers.
var crit_chance: float = 0.0
var crit_damage: float = 1.5

# Enemy-only rewards.
var reward_gold: int = 0
var emerald_chance: float = 0.0
var emerald_amount: int = 0
var is_boss: bool = false

# Active damage-over-time effects: each {dps, time_left, tick_timer}.
var dots: Array = []

var _hp_fill: ColorRect
var _hp_bg: ColorRect
var _name_label: Label
var _body: Polygon2D


func setup(display_name: String, color: Color, hero: bool, scale_mult: float = 1.0) -> void:
	is_hero = hero
	var size := 26.0 * scale_mult

	# Ground shadow (flat diamond for the isometric feel).
	var shadow := Polygon2D.new()
	shadow.polygon = _diamond(size * 1.3, size * 0.5)
	shadow.color = Color(0, 0, 0, 0.3)
	shadow.position = Vector2(0, size * 0.2)
	add_child(shadow)

	# Body diamond.
	_body = Polygon2D.new()
	_body.polygon = _diamond(size, size * 1.4)
	_body.color = color
	_body.position = Vector2(0, -size)
	add_child(_body)

	var outline := Line2D.new()
	var pts := _diamond(size, size * 1.4)
	outline.points = pts
	outline.add_point(pts[0])
	outline.width = 2.0
	outline.default_color = color.darkened(0.4)
	outline.position = _body.position
	add_child(outline)

	# Head.
	var head := Polygon2D.new()
	head.polygon = _regular_polygon(size * 0.5, 10)
	head.color = color.lightened(0.2)
	head.position = Vector2(0, -size * 2.1)
	add_child(head)

	# HP bar.
	var bar_w := 56.0 * scale_mult
	var bar_h := 7.0
	var bar_y := -size * 3.0
	_hp_bg = ColorRect.new()
	_hp_bg.color = Color(0.15, 0.05, 0.05)
	_hp_bg.size = Vector2(bar_w, bar_h)
	_hp_bg.position = Vector2(-bar_w * 0.5, bar_y)
	add_child(_hp_bg)

	_hp_fill = ColorRect.new()
	_hp_fill.color = Color(0.3, 0.85, 0.3) if hero else Color(0.85, 0.3, 0.3)
	_hp_fill.size = Vector2(bar_w, bar_h)
	_hp_fill.position = Vector2(-bar_w * 0.5, bar_y)
	add_child(_hp_fill)

	# Name label.
	_name_label = Label.new()
	_name_label.text = display_name
	_name_label.add_theme_font_size_override("font_size", 13)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.size = Vector2(bar_w + 40, 18)
	_name_label.position = Vector2(-(bar_w + 40) * 0.5, bar_y - 20)
	add_child(_name_label)

	_update_bar()


func init_stats(_max_hp: float, _attack: float, _defense: float, _attack_speed: float) -> void:
	max_hp = _max_hp
	hp = _max_hp
	attack = _attack
	defense = _defense
	attack_speed = _attack_speed
	# Stagger first attack so combat doesn't all fire on the same frame.
	atk_timer = randf_range(0.0, 1.0 / max(0.1, attack_speed))
	_update_bar()


func take_damage(amount: float) -> void:
	if not alive:
		return
	hp = max(0.0, hp - amount)
	_update_bar()
	if hp <= 0.0:
		alive = false

func heal(amount: float) -> void:
	if not alive:
		return
	hp = min(max_hp, hp + amount)
	_update_bar()

func add_dot(dps: float, duration: float, interval: float) -> void:
	dots.append({"dps": dps, "time_left": duration, "tick_timer": interval, "interval": interval})


func _update_bar() -> void:
	if _hp_fill == null:
		return
	var ratio := 0.0 if max_hp <= 0.0 else clampf(hp / max_hp, 0.0, 1.0)
	_hp_fill.size.x = _hp_bg.size.x * ratio


func play_death() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.parallel().tween_property(self, "scale", Vector2(0.4, 0.4), 0.25)
	tween.tween_callback(queue_free)


func _diamond(w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, -h * 0.5),
		Vector2(w * 0.5, 0),
		Vector2(0, h * 0.5),
		Vector2(-w * 0.5, 0),
	])


func _regular_polygon(radius: float, sides: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in sides:
		var a := TAU * float(i) / float(sides) - PI * 0.5
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts
