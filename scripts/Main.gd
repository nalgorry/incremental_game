extends Node
## Root controller. Switches between the Town screen and the Dungeon screen.

const TownScript := preload("res://scripts/Town.gd")
const DungeonScript := preload("res://scripts/Dungeon.gd")

var _current: Node = null


func _ready() -> void:
	show_town()


func _clear_current() -> void:
	if is_instance_valid(_current):
		_current.queue_free()
	_current = null


func show_town() -> void:
	_clear_current()
	var layer := CanvasLayer.new()
	var town := Control.new()
	town.set_script(TownScript)
	town.set_anchors_preset(Control.PRESET_FULL_RECT)
	town.set_offsets_preset(Control.PRESET_FULL_RECT)
	town.go_to_dungeon.connect(_on_go_to_dungeon)
	layer.add_child(town)
	add_child(layer)
	_current = layer


func _on_go_to_dungeon(start_floor: int) -> void:
	show_dungeon(start_floor)


func show_dungeon(start_floor: int) -> void:
	GameState.register_dungeon_run()
	_clear_current()
	var dungeon := Node2D.new()
	dungeon.set_script(DungeonScript)
	dungeon.return_to_town.connect(_on_return_to_town)
	add_child(dungeon)
	_current = dungeon
	dungeon.begin_run(start_floor)


func _on_return_to_town() -> void:
	show_town()
