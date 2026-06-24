extends Node
## Persistent runtime state: currencies, upgrade levels, abilities and progress.
## Saved to user://savegame.json on every meaningful change.

signal currencies_changed
signal abilities_changed
signal progress_changed

const SAVE_PATH := "user://savegame.json"

var gold: int = 0
var emeralds: int = 0

# stat_id -> level (int). Missing key == level 0.
var stat_levels: Dictionary = {}

# ability_id -> level (int >= 1). Presence of key == unlocked.
var ability_levels: Dictionary = {}

# Ordered list of equipped ability ids (max Database.MAX_EQUIPPED).
var equipped: Array[String] = []

# Highest checkpoint floor reached (multiple of CHECKPOINT_INTERVAL). 0 = none.
var highest_checkpoint: int = 0
# Deepest floor ever cleared (for display).
var deepest_floor: int = 0
# Floor the next run should begin on.
var selected_start_floor: int = 1


func _ready() -> void:
	load_game()


# --- Currencies ------------------------------------------------------------
func add_gold(amount: int) -> void:
	gold += amount
	currencies_changed.emit()

func add_emeralds(amount: int) -> void:
	emeralds += amount
	currencies_changed.emit()


# --- Stats -----------------------------------------------------------------
func get_stat_level(id: String) -> int:
	return int(stat_levels.get(id, 0))

func get_stat_value(id: String) -> float:
	return Database.stat_value(id, get_stat_level(id))

func stat_upgrade_cost(id: String) -> int:
	return Database.stat_cost(id, get_stat_level(id))

func can_upgrade_stat(id: String) -> bool:
	return gold >= stat_upgrade_cost(id)

func upgrade_stat(id: String) -> bool:
	var cost := stat_upgrade_cost(id)
	if gold < cost:
		return false
	gold -= cost
	stat_levels[id] = get_stat_level(id) + 1
	currencies_changed.emit()
	save_game()
	return true


# --- Abilities -------------------------------------------------------------
func is_unlocked(id: String) -> bool:
	return ability_levels.has(id)

func get_ability_level(id: String) -> int:
	return int(ability_levels.get(id, 0))

func ability_action_cost(id: String) -> int:
	# Cost to unlock if locked, otherwise cost to upgrade to next level.
	if not is_unlocked(id):
		return int(Database.ABILITIES[id].unlock_cost)
	return Database.ability_upgrade_cost(id, get_ability_level(id))

func upgrade_or_unlock_ability(id: String) -> bool:
	var cost := ability_action_cost(id)
	if emeralds < cost:
		return false
	emeralds -= cost
	if is_unlocked(id):
		ability_levels[id] = get_ability_level(id) + 1
	else:
		ability_levels[id] = 1
	currencies_changed.emit()
	abilities_changed.emit()
	save_game()
	return true

func is_equipped(id: String) -> bool:
	return equipped.has(id)

func toggle_equip(id: String) -> bool:
	if not is_unlocked(id):
		return false
	if equipped.has(id):
		equipped.erase(id)
	else:
		if equipped.size() >= Database.MAX_EQUIPPED:
			return false
		equipped.append(id)
	abilities_changed.emit()
	save_game()
	return true


# --- Progress / checkpoints ------------------------------------------------
func unlocked_checkpoint_floors() -> Array[int]:
	# Floor 1 is always available, plus every reached checkpoint.
	var result: Array[int] = [1]
	var c := Database.CHECKPOINT_INTERVAL
	while c <= highest_checkpoint:
		result.append(c)
		c += Database.CHECKPOINT_INTERVAL
	return result

func register_floor_cleared(floor_num: int) -> void:
	if floor_num > deepest_floor:
		deepest_floor = floor_num
	if floor_num % Database.CHECKPOINT_INTERVAL == 0 and floor_num > highest_checkpoint:
		highest_checkpoint = floor_num
	progress_changed.emit()
	save_game()


# --- Save / load -----------------------------------------------------------
func to_dict() -> Dictionary:
	return {
		"gold": gold,
		"emeralds": emeralds,
		"stat_levels": stat_levels,
		"ability_levels": ability_levels,
		"equipped": equipped,
		"highest_checkpoint": highest_checkpoint,
		"deepest_floor": deepest_floor,
		"selected_start_floor": selected_start_floor,
	}

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Could not open save file for writing.")
		return
	f.store_string(JSON.stringify(to_dict(), "\t"))
	f.close()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_new_game_defaults()
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		_new_game_defaults()
		return
	var text := f.get_as_text()
	f.close()
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		_new_game_defaults()
		return
	gold = int(data.get("gold", 0))
	emeralds = int(data.get("emeralds", 0))
	stat_levels = data.get("stat_levels", {})
	ability_levels = data.get("ability_levels", {})
	equipped = []
	for a in data.get("equipped", []):
		equipped.append(String(a))
	highest_checkpoint = int(data.get("highest_checkpoint", 0))
	deepest_floor = int(data.get("deepest_floor", 0))
	selected_start_floor = int(data.get("selected_start_floor", 1))
	_ensure_starter_ability()

func _new_game_defaults() -> void:
	gold = 0
	emeralds = 0
	stat_levels = {}
	ability_levels = {}
	equipped = []
	highest_checkpoint = 0
	deepest_floor = 0
	selected_start_floor = 1
	_ensure_starter_ability()
	save_game()

func _ensure_starter_ability() -> void:
	# Fireball is free and always available so the player can fight from turn 1.
	if not ability_levels.has("fireball"):
		ability_levels["fireball"] = 1
	if equipped.is_empty():
		equipped.append("fireball")

func reset_progress() -> void:
	_new_game_defaults()
	currencies_changed.emit()
	abilities_changed.emit()
	progress_changed.emit()
