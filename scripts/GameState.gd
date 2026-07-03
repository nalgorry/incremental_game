extends Node
## Persistent runtime state: currencies, upgrade levels, abilities and progress.
## Saved to user://savegame.json on every meaningful change.

signal currencies_changed
signal abilities_changed
signal progress_changed

const SAVE_PATH := "user://savegame.json"
const UPGRADE_CATEGORIES: Array[String] = ["Attack", "Defence", "Ability Update", "Misc"]

var gold: int = 0
var emeralds: int = 0

# Legacy flat stat upgrades from older saves. New purchases use upgrade_node_ranks.
var stat_levels: Dictionary = {}

# upgrade_node_id -> rank (int). Missing key == rank 0.
var upgrade_node_ranks: Dictionary = {}

# Nodes that have appeared in the randomized upgrade tree.
var visible_upgrade_nodes: Array[String] = []

# node_id -> node_id that revealed it. Used for drawing the randomized tree.
var visible_upgrade_parents: Dictionary = {}

# group_id -> randomized two-path reveal data for a learned Tier 1 starter.
var upgrade_reveal_groups: Dictionary = {}

# node_id -> {group, path, step}. Used for path locking and layout.
var upgrade_node_groups: Dictionary = {}

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
	var value := Database.stat_value(id, get_stat_level(id))
	for node_id in Database.UPGRADE_TREE.keys():
		var node: Dictionary = Database.UPGRADE_TREE[node_id]
		var rank := float(get_upgrade_node_rank(node_id))
		if node.has("bonuses"):
			var bonuses: Dictionary = node.bonuses
			if bonuses.has(id):
				value += float(bonuses[id]) * rank
		elif node.has("stat") and String(node.stat) == id:
			value += float(node.bonus_per_rank) * rank
	return value

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

func get_upgrade_node_rank(id: String) -> int:
	return int(upgrade_node_ranks.get(id, 0))

func is_upgrade_node_complete(id: String) -> bool:
	var node: Dictionary = Database.UPGRADE_TREE[id]
	return get_upgrade_node_rank(id) >= int(node.max_ranks)

func is_upgrade_node_visible(id: String) -> bool:
	return id == "foundation" or visible_upgrade_nodes.has(id) or get_upgrade_node_rank(id) > 0

func is_upgrade_tier_complete(tier: int) -> bool:
	var has_nodes := false
	for node_id in Database.UPGRADE_TREE.keys():
		var node: Dictionary = Database.UPGRADE_TREE[node_id]
		if int(node.tier) != tier:
			continue
		has_nodes = true
		if not is_upgrade_node_complete(String(node_id)):
			return false
	return has_nodes

func upgrade_node_cost(id: String) -> int:
	var base_cost := Database.upgrade_node_cost(id, get_upgrade_node_rank(id))
	var discount := upgrade_effect_value("upgrade_discount_by_rank")
	return max(1, int(round(float(base_cost) * maxf(0.1, 1.0 - discount))))

func can_upgrade_node(id: String) -> bool:
	if not is_upgrade_node_visible(id) or is_upgrade_node_complete(id):
		return false
	if is_upgrade_node_path_locked(id) or is_upgrade_node_common_locked(id):
		return false
	if _is_upgrade_node_path_step_locked(id):
		return false
	return gold >= upgrade_node_cost(id)

func upgrade_tree_node(id: String) -> bool:
	if not can_upgrade_node(id):
		return false
	var old_rank := get_upgrade_node_rank(id)
	var cost := upgrade_node_cost(id)
	gold -= cost
	upgrade_node_ranks[id] = old_rank + 1
	if old_rank == 0:
		_choose_upgrade_reveal_path(id)
		if _should_reveal_after_learning(id):
			_reveal_next_upgrade_nodes(id)
	currencies_changed.emit()
	save_game()
	return true

func reset_upgrade_tree() -> void:
	upgrade_node_ranks = {}
	visible_upgrade_nodes = ["foundation"]
	visible_upgrade_parents = {}
	upgrade_reveal_groups = {}
	upgrade_node_groups = {}
	currencies_changed.emit()
	save_game()

func _reveal_next_upgrade_nodes(source_id: String) -> void:
	var source: Dictionary = Database.UPGRADE_TREE[source_id]
	var next_tier := int(source.tier) + 1
	if source_id == "foundation" and next_tier == 1:
		_reveal_one_upgrade_per_category(source_id, next_tier)
		return
	if int(source.tier) == 1:
		_reveal_upgrade_path_group(source_id, 1)
		return
	if _is_upgrade_group_common_node(source_id):
		_reveal_upgrade_path_group(source_id, _next_reveal_stage(source_id))
		return
	var source_category := String(source.get("category", ""))
	var candidates: Array[String] = []
	for node_id_raw in Database.UPGRADE_TREE.keys():
		var node_id := String(node_id_raw)
		var node: Dictionary = Database.UPGRADE_TREE[node_id]
		if int(node.tier) == next_tier and String(node.get("category", "")) == source_category and not is_upgrade_node_visible(node_id):
			candidates.append(node_id)
	candidates.shuffle()
	if not candidates.is_empty():
		var revealed_id := candidates[0]
		visible_upgrade_nodes.append(revealed_id)
		visible_upgrade_parents[revealed_id] = source_id

func _should_reveal_after_learning(id: String) -> bool:
	if not upgrade_node_groups.has(id):
		return true
	return _is_upgrade_group_common_node(id)

func _is_upgrade_group_common_node(id: String) -> bool:
	if not upgrade_node_groups.has(id):
		return false
	var info: Dictionary = upgrade_node_groups[id]
	return String(info.get("path", "")) == "common"

func _reveal_upgrade_path_group(source_id: String, stage: int) -> void:
	if upgrade_reveal_groups.has(source_id):
		return
	var source: Dictionary = Database.UPGRADE_TREE[source_id]
	var category := String(source.get("category", ""))
	var path_a: Array[String] = []
	var path_b: Array[String] = []
	var common := ""
	path_a = _take_stage_candidates(category, source_id, stage, 2)
	path_b = _take_stage_candidates(category, source_id, stage, 2, path_a)
	common = _take_stage_candidate(category, source_id, stage, path_a + path_b)
	var group := {
		"source": source_id,
		"category": category,
		"stage": stage,
		"path_a": path_a,
		"path_b": path_b,
		"common": common,
		"chosen_path": "",
	}
	upgrade_reveal_groups[source_id] = group
	_register_upgrade_reveal_group(source_id, group)

func _next_reveal_stage(source_id: String) -> int:
	if not upgrade_node_groups.has(source_id):
		return 1
	var info: Dictionary = upgrade_node_groups[source_id]
	var parent_group_id := String(info.get("group", ""))
	if not upgrade_reveal_groups.has(parent_group_id):
		return 1
	var parent_group: Dictionary = upgrade_reveal_groups[parent_group_id]
	return mini(int(parent_group.get("stage", 1)) + 1, 5)

func _upgrade_candidates_for_tier(category: String, source_id: String, tier: int, excluded: Array = []) -> Array[String]:
	var candidates: Array[String] = []
	for node_id_raw in Database.UPGRADE_TREE.keys():
		var node_id := String(node_id_raw)
		var node: Dictionary = Database.UPGRADE_TREE[node_id]
		if node_id == source_id or bool(node.get("branch_start", false)) or excluded.has(node_id):
			continue
		if String(node.get("category", "")) == category and int(node.get("tier", 0)) == tier and not is_upgrade_node_visible(node_id):
			candidates.append(node_id)
	candidates.shuffle()
	return candidates

func _take_stage_candidates(category: String, source_id: String, stage: int, count: int, excluded: Array = []) -> Array[String]:
	var result: Array[String] = []
	for i in count:
		var next_id := _take_stage_candidate(category, source_id, stage, excluded + result)
		if next_id == "":
			break
		result.append(next_id)
	return result

func _take_stage_candidate(category: String, source_id: String, stage: int, excluded: Array = []) -> String:
	var tiers := _weighted_stage_tiers(stage)
	for tier in tiers:
		var candidates := _upgrade_candidates_for_tier(category, source_id, tier, excluded)
		if not candidates.is_empty():
			return candidates[0]
	return ""

func _weighted_stage_tiers(stage: int) -> Array[int]:
	var weights := _stage_tier_weights(stage)
	var result: Array[int] = []
	var first_tier := _roll_weighted_tier(weights)
	if first_tier > 0:
		result.append(first_tier)
	var keys := weights.keys()
	keys.sort()
	for key in keys:
		var tier := int(String(key))
		if not result.has(tier):
			result.append(tier)
	return result

func _stage_tier_weights(stage: int) -> Dictionary:
	var stage_key := "stage_%d" % clampi(stage, 1, 5)
	if Database.UPGRADE_TREE_STAGES.has(stage_key):
		var stage_data: Dictionary = Database.UPGRADE_TREE_STAGES[stage_key]
		if stage_data.has("tier_weights"):
			return stage_data.tier_weights
	return {"2": 1.0}

func _roll_weighted_tier(weights: Dictionary) -> int:
	var total := 0.0
	for weight in weights.values():
		total += maxf(0.0, float(weight))
	if total <= 0.0:
		return 0
	var roll := randf() * total
	var running := 0.0
	for key in weights.keys():
		running += maxf(0.0, float(weights[key]))
		if roll <= running:
			return int(String(key))
	return int(String(weights.keys()[0]))

func _take_upgrade_candidates(candidates: Array[String], count: int) -> Array[String]:
	var result: Array[String] = []
	for i in mini(count, candidates.size()):
		result.append(candidates.pop_front())
	return result

func _register_upgrade_reveal_group(group_id: String, group: Dictionary) -> void:
	var source_id := String(group.get("source", group_id))
	var path_a: Array = group.get("path_a", [])
	var path_b: Array = group.get("path_b", [])
	var common := String(group.get("common", ""))
	for i in path_a.size():
		_register_group_node(String(path_a[i]), group_id, "a", i + 1, source_id if i == 0 else String(path_a[i - 1]))
	if common != "":
		var parent_a := String(path_a[path_a.size() - 1]) if not path_a.is_empty() else source_id
		var parent_b := String(path_b[path_b.size() - 1]) if not path_b.is_empty() else source_id
		_register_group_node(common, group_id, "common", 0, parent_a)
		# Keep the second parent available for UI layout/links without changing legacy parent lookup.
		visible_upgrade_parents["%s:path_b" % common] = parent_b
	for i in path_b.size():
		_register_group_node(String(path_b[i]), group_id, "b", i + 1, source_id if i == 0 else String(path_b[i - 1]))

func _register_group_node(node_id: String, group_id: String, path: String, step: int, parent_id: String) -> void:
	if node_id == "" or not Database.UPGRADE_TREE.has(node_id):
		return
	if not visible_upgrade_nodes.has(node_id):
		visible_upgrade_nodes.append(node_id)
	visible_upgrade_parents[node_id] = parent_id
	upgrade_node_groups[node_id] = {"group": group_id, "path": path, "step": step}

func _reveal_one_upgrade_per_category(source_id: String, tier: int) -> void:
	for category in UPGRADE_CATEGORIES:
		var candidates: Array[String] = []
		for node_id_raw in Database.UPGRADE_TREE.keys():
			var node_id := String(node_id_raw)
			var node: Dictionary = Database.UPGRADE_TREE[node_id]
			if int(node.tier) == tier and bool(node.get("branch_start", false)) and String(node.get("category", "")) == category and not is_upgrade_node_visible(node_id):
				candidates.append(node_id)
		candidates.shuffle()
		if candidates.is_empty():
			continue
		var revealed_id := candidates[0]
		visible_upgrade_nodes.append(revealed_id)
		visible_upgrade_parents[revealed_id] = source_id

func get_upgrade_reveal_parent(id: String) -> String:
	if visible_upgrade_parents.has(id):
		return String(visible_upgrade_parents[id])
	if id == "foundation":
		return ""
	return _fallback_upgrade_parent(id)

func get_upgrade_extra_reveal_parent(id: String) -> String:
	var key := "%s:path_b" % id
	return String(visible_upgrade_parents.get(key, ""))

func get_upgrade_reveal_group(id: String) -> Dictionary:
	if upgrade_reveal_groups.has(id):
		return upgrade_reveal_groups[id]
	if upgrade_node_groups.has(id):
		var info: Dictionary = upgrade_node_groups[id]
		var group_id := String(info.get("group", ""))
		if upgrade_reveal_groups.has(group_id):
			return upgrade_reveal_groups[group_id]
	return {}

func is_upgrade_node_path_locked(id: String) -> bool:
	if not upgrade_node_groups.has(id):
		return false
	var info: Dictionary = upgrade_node_groups[id]
	var path := String(info.get("path", ""))
	if path == "common":
		return false
	var group_id := String(info.get("group", ""))
	if not upgrade_reveal_groups.has(group_id):
		return false
	var group: Dictionary = upgrade_reveal_groups[group_id]
	var chosen := String(group.get("chosen_path", ""))
	return chosen != "" and chosen != path

func is_upgrade_node_common_locked(id: String) -> bool:
	if not upgrade_node_groups.has(id):
		return false
	var info: Dictionary = upgrade_node_groups[id]
	if String(info.get("path", "")) != "common":
		return false
	var group_id := String(info.get("group", ""))
	if not upgrade_reveal_groups.has(group_id):
		return false
	var group: Dictionary = upgrade_reveal_groups[group_id]
	var chosen := String(group.get("chosen_path", ""))
	if chosen == "":
		return true
	var path_ids: Array = group.get("path_%s" % chosen, [])
	if path_ids.is_empty():
		return false
	return get_upgrade_node_rank(String(path_ids[path_ids.size() - 1])) <= 0

func _is_upgrade_node_path_step_locked(id: String) -> bool:
	if not upgrade_node_groups.has(id):
		return false
	var info: Dictionary = upgrade_node_groups[id]
	var path := String(info.get("path", ""))
	var step := int(info.get("step", 0))
	if path == "common" or step <= 1:
		return false
	var group_id := String(info.get("group", ""))
	if not upgrade_reveal_groups.has(group_id):
		return false
	var group: Dictionary = upgrade_reveal_groups[group_id]
	var path_ids: Array = group.get("path_%s" % path, [])
	if step - 2 < 0 or step - 2 >= path_ids.size():
		return false
	return get_upgrade_node_rank(String(path_ids[step - 2])) <= 0

func _choose_upgrade_reveal_path(id: String) -> void:
	if not upgrade_node_groups.has(id):
		return
	var info: Dictionary = upgrade_node_groups[id]
	var path := String(info.get("path", ""))
	if path == "" or path == "common":
		return
	var group_id := String(info.get("group", ""))
	if not upgrade_reveal_groups.has(group_id):
		return
	var group: Dictionary = upgrade_reveal_groups[group_id]
	if String(group.get("chosen_path", "")) == "":
		group["chosen_path"] = path
		upgrade_reveal_groups[group_id] = group

func _fallback_upgrade_parent(id: String) -> String:
	var node: Dictionary = Database.UPGRADE_TREE[id]
	if int(node.tier) == 1:
		return "foundation"
	for parent_id in node.parents:
		var parent := String(parent_id)
		if is_upgrade_node_visible(parent) or get_upgrade_node_rank(parent) > 0:
			return parent
	if not node.parents.is_empty():
		return String(node.parents[0])
	return ""

func double_spell_chance() -> float:
	var rank := get_upgrade_node_rank("double_spell")
	if rank <= 0:
		return 0.0
	var node: Dictionary = Database.UPGRADE_TREE["double_spell"]
	var chances: Array = node["chance_by_rank"]
	var index := clampi(rank, 1, chances.size()) - 1
	return float(chances[index])

func ability_cooldown_multiplier() -> float:
	var reduction := 0.0
	for node_id in Database.UPGRADE_TREE.keys():
		var node: Dictionary = Database.UPGRADE_TREE[node_id]
		if node.has("cooldown_reduction_per_rank"):
			reduction += float(node.cooldown_reduction_per_rank) * float(get_upgrade_node_rank(String(node_id)))
	return maxf(0.1, 1.0 - reduction)

func ability_power_multiplier() -> float:
	var bonus := 0.0
	for node_id in Database.UPGRADE_TREE.keys():
		var node: Dictionary = Database.UPGRADE_TREE[node_id]
		if node.has("ability_power_per_rank"):
			bonus += float(node.ability_power_per_rank) * float(get_upgrade_node_rank(String(node_id)))
	return 1.0 + bonus

func gold_reward_multiplier() -> float:
	var bonus := 0.0
	for node_id in Database.UPGRADE_TREE.keys():
		var node: Dictionary = Database.UPGRADE_TREE[node_id]
		if not node.has("gold_bonus_by_rank"):
			continue
		var rank := get_upgrade_node_rank(String(node_id))
		if rank <= 0:
			continue
		var bonuses: Array = node["gold_bonus_by_rank"]
		var index := clampi(rank, 1, bonuses.size()) - 1
		bonus += float(bonuses[index])
	return 1.0 + bonus

func upgrade_effect_value(field: String) -> float:
	var total := 0.0
	for node_id in Database.UPGRADE_TREE.keys():
		var node: Dictionary = Database.UPGRADE_TREE[node_id]
		if not node.has(field):
			continue
		var rank := get_upgrade_node_rank(String(node_id))
		if rank <= 0:
			continue
		var value = node[field]
		if value is Array:
			var values: Array = value
			if values.is_empty():
				continue
			var index := clampi(rank, 1, values.size()) - 1
			total += float(values[index])
		else:
			total += float(value) * float(rank)
	return total

func upgrade_effect_max(field: String) -> float:
	var result := 0.0
	for node_id in Database.UPGRADE_TREE.keys():
		var node: Dictionary = Database.UPGRADE_TREE[node_id]
		if not node.has(field) or get_upgrade_node_rank(String(node_id)) <= 0:
			continue
		result = maxf(result, float(node[field]))
	return result

func upgrade_effect_min_positive(field: String) -> float:
	var result := 0.0
	for node_id in Database.UPGRADE_TREE.keys():
		var node: Dictionary = Database.UPGRADE_TREE[node_id]
		if not node.has(field) or get_upgrade_node_rank(String(node_id)) <= 0:
			continue
		var value := float(node[field])
		if value <= 0.0:
			continue
		result = value if result <= 0.0 else minf(result, value)
	return result

func recover_on_hit_chance() -> float:
	var rank := get_upgrade_node_rank("recover_on_hit")
	if rank <= 0:
		return 0.0
	var node: Dictionary = Database.UPGRADE_TREE["recover_on_hit"]
	var chances: Array = node["chance_by_rank"]
	var index := clampi(rank, 1, chances.size()) - 1
	return float(chances[index])

func recover_on_hit_seconds() -> float:
	var node: Dictionary = Database.UPGRADE_TREE["recover_on_hit"]
	return float(node.cooldown_recover_on_hit)


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
		if equipped.size() < Database.MAX_EQUIPPED and not equipped.has(id):
			equipped.append(id)
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
	var c := Database.CHECKPOINT_INTERVAL + 1
	while c <= highest_checkpoint:
		result.append(c)
		c += Database.CHECKPOINT_INTERVAL
	return result

func register_floor_cleared(floor_num: int) -> void:
	if floor_num > deepest_floor:
		deepest_floor = floor_num
	if floor_num % Database.CHECKPOINT_INTERVAL == 0:
		var checkpoint_floor := floor_num + 1
		if checkpoint_floor <= Database.MAX_FLOORS and checkpoint_floor > highest_checkpoint:
			highest_checkpoint = checkpoint_floor
	progress_changed.emit()
	save_game()


# --- Save / load -----------------------------------------------------------
func to_dict() -> Dictionary:
	return {
		"gold": gold,
		"emeralds": emeralds,
		"stat_levels": stat_levels,
		"upgrade_node_ranks": upgrade_node_ranks,
		"visible_upgrade_nodes": visible_upgrade_nodes,
		"visible_upgrade_parents": visible_upgrade_parents,
		"upgrade_reveal_groups": upgrade_reveal_groups,
		"upgrade_node_groups": upgrade_node_groups,
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
	upgrade_node_ranks = data.get("upgrade_node_ranks", {})
	visible_upgrade_nodes = []
	for node_id in data.get("visible_upgrade_nodes", []):
		visible_upgrade_nodes.append(String(node_id))
	visible_upgrade_parents = data.get("visible_upgrade_parents", {})
	upgrade_reveal_groups = data.get("upgrade_reveal_groups", {})
	_rebuild_upgrade_node_groups()
	ability_levels = data.get("ability_levels", {})
	equipped = []
	for a in data.get("equipped", []):
		equipped.append(String(a))
	highest_checkpoint = int(data.get("highest_checkpoint", 0))
	deepest_floor = int(data.get("deepest_floor", 0))
	selected_start_floor = int(data.get("selected_start_floor", 1))
	_ensure_starter_ability()
	_ensure_upgrade_tree_visibility()

func _new_game_defaults() -> void:
	gold = 0
	emeralds = 0
	stat_levels = {}
	upgrade_node_ranks = {}
	visible_upgrade_nodes = []
	visible_upgrade_parents = {}
	upgrade_reveal_groups = {}
	upgrade_node_groups = {}
	ability_levels = {}
	equipped = []
	highest_checkpoint = 0
	deepest_floor = 0
	selected_start_floor = 1
	_ensure_starter_ability()
	_ensure_upgrade_tree_visibility()
	save_game()

func _ensure_starter_ability() -> void:
	# Fireball is free and always available so the player can fight from turn 1.
	if not ability_levels.has("fireball"):
		ability_levels["fireball"] = 1
	if equipped.is_empty():
		equipped.append("fireball")

func _ensure_upgrade_tree_visibility() -> void:
	if not visible_upgrade_nodes.has("foundation"):
		visible_upgrade_nodes.append("foundation")
	_rebuild_upgrade_node_groups()
	for node_id_raw in upgrade_node_ranks.keys():
		var node_id := String(node_id_raw)
		if get_upgrade_node_rank(node_id) > 0 and not visible_upgrade_nodes.has(node_id):
			visible_upgrade_nodes.append(node_id)
	for node_id in visible_upgrade_nodes:
		if node_id != "foundation" and not visible_upgrade_parents.has(node_id):
			visible_upgrade_parents[node_id] = _fallback_upgrade_parent(node_id)
	_ensure_foundation_category_reveals()
	# Saves from older tree rules may have learned nodes but no revealed choices.
	for node_id_raw in Database.UPGRADE_TREE.keys():
		var node_id := String(node_id_raw)
		if upgrade_node_groups.has(node_id):
			continue
		if get_upgrade_node_rank(node_id) > 0 and _visible_nodes_in_tier(int(Database.UPGRADE_TREE[node_id].tier) + 1).is_empty():
			_reveal_next_upgrade_nodes(node_id)

func _rebuild_upgrade_node_groups() -> void:
	upgrade_node_groups = {}
	for group_id_raw in upgrade_reveal_groups.keys():
		var group_id := String(group_id_raw)
		var group: Dictionary = upgrade_reveal_groups[group_id]
		_register_upgrade_reveal_group(group_id, group)

func _ensure_foundation_category_reveals() -> void:
	if get_upgrade_node_rank("foundation") <= 0:
		return
	for category in UPGRADE_CATEGORIES:
		if _has_visible_upgrade_category(1, category):
			continue
		var candidates: Array[String] = []
		for node_id_raw in Database.UPGRADE_TREE.keys():
			var node_id := String(node_id_raw)
			var node: Dictionary = Database.UPGRADE_TREE[node_id]
			if int(node.tier) == 1 and bool(node.get("branch_start", false)) and String(node.get("category", "")) == category and not is_upgrade_node_visible(node_id):
				candidates.append(node_id)
		candidates.shuffle()
		if candidates.is_empty():
			continue
		var revealed_id := candidates[0]
		visible_upgrade_nodes.append(revealed_id)
		visible_upgrade_parents[revealed_id] = "foundation"

func _has_visible_upgrade_category(tier: int, category: String) -> bool:
	for node_id_raw in Database.UPGRADE_TREE.keys():
		var node_id := String(node_id_raw)
		var node: Dictionary = Database.UPGRADE_TREE[node_id]
		if int(node.tier) == tier and String(node.get("category", "")) == category and is_upgrade_node_visible(node_id):
			return true
	return false

func _visible_nodes_in_tier(tier: int) -> Array[String]:
	var result: Array[String] = []
	for node_id_raw in Database.UPGRADE_TREE.keys():
		var node_id := String(node_id_raw)
		if int(Database.UPGRADE_TREE[node_id].tier) == tier and is_upgrade_node_visible(node_id):
			result.append(node_id)
	return result

func reset_progress() -> void:
	_new_game_defaults()
	currencies_changed.emit()
	abilities_changed.emit()
	progress_changed.emit()
