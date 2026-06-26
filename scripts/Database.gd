extends Node
## Static, data-driven catalogs for the whole game.
## Add new stats / abilities here and the rest of the game picks them up
## automatically (UI and combat both iterate over these dictionaries).

# ---------------------------------------------------------------------------
# HERO STATS
# Base values plus any bonuses from the hero upgrade tree.
# "percent" stats are displayed as XX% in the UI.
# ---------------------------------------------------------------------------
const STATS := {
	"max_hp": {
		"name": "Max HP", "order": 0,
		"base": 100.0, "growth": 25.0,
		"cost_base": 10, "cost_growth": 1.15,
		"percent": false,
	},
	"attack": {
		"name": "Attack", "order": 1,
		"base": 10.0, "growth": 3.0,
		"cost_base": 10, "cost_growth": 1.15,
		"percent": false,
	},
	"attack_speed": {
		"name": "Attack Speed", "order": 2,
		"base": 1.0, "growth": 0.06,
		"cost_base": 25, "cost_growth": 1.22,
		"percent": false,
	},
	"defense": {
		"name": "Defense", "order": 3,
		"base": 2.0, "growth": 1.0,
		"cost_base": 12, "cost_growth": 1.15,
		"percent": false,
	},
	"hp_regen": {
		"name": "HP Regen", "order": 4,
		"base": 0.0, "growth": 0.0,
		"cost_base": 1, "cost_growth": 1.0,
		"percent": false,
	},
	"crit_chance": {
		"name": "Crit Chance", "order": 5,
		"base": 0.05, "growth": 0.01,
		"cost_base": 40, "cost_growth": 1.30,
		"percent": true,
	},
	"crit_damage": {
		"name": "Crit Damage", "order": 6,
		"base": 1.5, "growth": 0.10,
		"cost_base": 40, "cost_growth": 1.25,
		"percent": true,
	},
}

# ---------------------------------------------------------------------------
# HERO UPGRADE TREE (Gold)
# Nodes have limited ranks. Tier 0 appears first; later tiers unlock when the
# previous tier is complete. Parents are kept for visual branch lines only.
# ---------------------------------------------------------------------------
const UPGRADE_TREE := {
	"foundation": {
		"name": "All start here", "order": 0, "tier": 0,
		"desc": "Build the first foundation of every run.",
		"bonuses": {"max_hp": 20.0, "attack": 10.0},
		"max_ranks": 1, "costs": [15],
		"parents": [],
	},
	"blade_training": {
		"name": "Blade Training", "order": 10, "tier": 1,
		"desc": "Hit harder with every basic attack.",
		"stat": "attack", "bonus_per_rank": 4.0,
		"max_ranks": 3, "costs": [35, 60, 85],
		"parents": ["foundation"],
	},
	"iron_skin": {
		"name": "Iron Skin", "order": 11, "tier": 1,
		"desc": "Reduce incoming damage.",
		"stat": "defense", "bonus_per_rank": 1.5,
		"max_ranks": 3, "costs": [30, 55, 80],
		"parents": ["foundation"],
	},
	"quick_casting": {
		"name": "Quick Casting", "order": 12, "tier": 1,
		"desc": "Attack faster while abilities cycle.",
		"stat": "attack_speed", "bonus_per_rank": 0.08,
		"max_ranks": 2, "costs": [45, 70],
		"parents": ["foundation"],
	},
	"basic_regen": {
		"name": "Basic Regen", "order": 13, "tier": 1,
		"desc": "Regenerate HP over time.",
		"stat": "hp_regen", "bonus_per_rank": 1.0,
		"max_ranks": 3, "costs": [100, 125, 150],
		"parents": ["foundation"],
	},
	"basic_reserves": {
		"name": "Basic Reserves", "order": 14, "tier": 1,
		"desc": "A deeper health pool for long runs.",
		"stat": "max_hp", "bonus_per_rank": 30.0,
		"max_ranks": 3, "costs": [50, 75, 100],
		"parents": ["foundation"],
	},
	"basic_haste": {
		"name": "Basic Haste", "order": 15, "tier": 1,
		"desc": "Faster abilities.",
		"cooldown_reduction_per_rank": 0.02,
		"max_ranks": 3, "costs": [150, 175, 200],
		"parents": ["foundation"],
	},
	"ability_update": {
		"name": "Ability Update", "order": 16, "tier": 1,
		"desc": "More powerful abilities.",
		"ability_power_per_rank": 0.02,
		"max_ranks": 3, "costs": [200, 225, 250],
		"parents": ["foundation"],
	},
	"recover_on_hit": {
		"name": "Recover On Hit", "order": 20, "tier": 2,
		"desc": "Faster abilities on hit.",
		"chance_by_rank": [0.02, 0.03, 0.05],
		"cooldown_recover_on_hit": 0.5,
		"max_ranks": 3, "costs": [200, 225, 250],
		"parents": ["basic_haste"],
	},
	"advanced_blade_training": {
		"name": "Advanced Blade Training", "order": 21, "tier": 2,
		"desc": "Sharper technique for deeper floors.",
		"stat": "attack", "bonus_per_rank": 8.0,
		"max_ranks": 3, "costs": [140, 175, 210],
		"parents": ["blade_training"],
	},
	"reinforced_skin": {
		"name": "Reinforced Skin", "order": 22, "tier": 2,
		"desc": "Stronger defenses against elite enemies.",
		"stat": "defense", "bonus_per_rank": 3.0,
		"max_ranks": 3, "costs": [130, 165, 200],
		"parents": ["iron_skin"],
	},
	"swift_casting": {
		"name": "Swift Casting", "order": 23, "tier": 2,
		"desc": "Move and cast with greater rhythm.",
		"stat": "attack_speed", "bonus_per_rank": 0.14,
		"max_ranks": 2, "costs": [150, 190],
		"parents": ["quick_casting"],
	},
	"greater_regen": {
		"name": "Greater Regen", "order": 24, "tier": 2,
		"desc": "Recover health faster during long fights.",
		"stat": "hp_regen", "bonus_per_rank": 2.0,
		"max_ranks": 3, "costs": [180, 220, 260],
		"parents": ["basic_regen"],
	},
	"greater_reserves": {
		"name": "Greater Reserves", "order": 25, "tier": 2,
		"desc": "Expand your life pool for boss waves.",
		"stat": "max_hp", "bonus_per_rank": 60.0,
		"max_ranks": 3, "costs": [160, 200, 240],
		"parents": ["basic_reserves"],
	},
	"greater_haste": {
		"name": "Greater Haste", "order": 26, "tier": 2,
		"desc": "Push abilities closer to constant use.",
		"cooldown_reduction_per_rank": 0.04,
		"max_ranks": 3, "costs": [240, 290, 340],
		"parents": ["basic_haste"],
	},
	"ability_mastery": {
		"name": "Ability Mastery", "order": 27, "tier": 2,
		"desc": "Greatly improve ability power.",
		"ability_power_per_rank": 0.04,
		"max_ranks": 3, "costs": [280, 335, 390],
		"parents": ["ability_update"],
	},
	"double_spell": {
		"name": "Double Spell", "order": 30, "tier": 3,
		"desc": "Abilities can reduce their next cooldown by 50%.",
		"chance_by_rank": [0.10, 0.15, 0.25],
		"max_ranks": 3, "costs": [95, 120, 145],
		"parents": ["quick_casting"],
	},
	"crushing_criticals": {
		"name": "Crushing Criticals", "order": 31, "tier": 3,
		"desc": "Critical hits deal more damage.",
		"stat": "crit_damage", "bonus_per_rank": 0.15,
		"max_ranks": 3, "costs": [220, 245, 270],
		"parents": ["blade_training"],
	},
	"battle_rhythm": {
		"name": "Battle Rhythm", "order": 32, "tier": 3,
		"desc": "Blend speed and power.",
		"stat": "attack_speed", "bonus_per_rank": 0.12,
		"max_ranks": 2, "costs": [240, 265],
		"parents": ["quick_casting", "blade_training"],
	},
}

# ---------------------------------------------------------------------------
# ABILITIES (unlocked / upgraded with Green Emeralds)
# type: "damage" (single), "aoe", "dot", "buff", "heal"
# power(level)  = base_power + power_growth * (level - 1)
# upgrade cost(level) = ceil(upgrade_base * upgrade_growth ^ (level - 1))
# ---------------------------------------------------------------------------
const ABILITIES := {
	"fireball": {
		"name": "Fireball", "order": 0,
		"type": "damage", "target": "single",
		"desc": "Hurl a fireball at the front enemy.",
		"cooldown": 2.5,
		"base_power": 25.0, "power_growth": 14.0,
		"unlock_cost": 0,
		"upgrade_base": 8, "upgrade_growth": 1.40,
		"color": Color(1.0, 0.5, 0.1),
	},
	"meteor": {
		"name": "Meteor", "order": 1,
		"type": "aoe", "target": "all",
		"desc": "Smash every enemy in the wave.",
		"cooldown": 6.0,
		"base_power": 18.0, "power_growth": 10.0,
		"unlock_cost": 15,
		"upgrade_base": 12, "upgrade_growth": 1.45,
		"color": Color(0.9, 0.3, 0.2),
	},
	"poison_cloud": {
		"name": "Magic Shield", "order": 2,
		"type": "shield", "target": "self",
		"desc": "Gain a shield equal to 50% of starting life.",
		"cooldown": 40.0,
		"cooldown_reduction_per_level": 2.0, "cooldown_min": 20.0,
		"base_power": 0.5, "power_growth": 0.05,
		"unlock_cost": 20,
		"upgrade_base": 12, "upgrade_growth": 1.45,
		"color": Color(0.35, 0.65, 1.0),
	},
	"frenzy": {
		"name": "Frenzy", "order": 3,
		"type": "buff", "target": "self",
		"desc": "Boost Attack & Attack Speed for a few seconds.",
		"cooldown": 10.0,
		"base_power": 0.4, "power_growth": 0.1,
		"buff_duration": 4.0,
		"unlock_cost": 25,
		"upgrade_base": 15, "upgrade_growth": 1.5,
		"color": Color(1.0, 0.85, 0.2),
	},
	"mend": {
		"name": "Mend", "order": 4,
		"type": "heal", "target": "self",
		"desc": "Instantly restore some health.",
		"cooldown": 8.0,
		"base_power": 40.0, "power_growth": 25.0,
		"unlock_cost": 20,
		"upgrade_base": 12, "upgrade_growth": 1.45,
		"color": Color(0.3, 0.9, 0.6),
	},
}

# ---------------------------------------------------------------------------
# GLOBAL BALANCE
# ---------------------------------------------------------------------------
const MAX_FLOORS := 100
const WAVES_PER_FLOOR := 2
const CHECKPOINT_INTERVAL := 10
const MAX_EQUIPPED := 3
const ENEMIES_PER_WAVE := 4

# --- Stat helpers ----------------------------------------------------------
static func stat_value(id: String, level: int) -> float:
	var d: Dictionary = STATS[id]
	return d.base + d.growth * float(level)

static func stat_cost(id: String, level: int) -> int:
	var d: Dictionary = STATS[id]
	return int(ceil(d.cost_base * pow(d.cost_growth, level)))

static func upgrade_node_cost(id: String, rank: int) -> int:
	var d: Dictionary = UPGRADE_TREE[id]
	if d.has("costs"):
		var costs: Array = d.costs
		return int(costs[clampi(rank, 0, costs.size() - 1)])
	return int(ceil(d.cost_base * pow(d.cost_growth, rank)))

static func format_stat(id: String, value: float) -> String:
	var d: Dictionary = STATS[id]
	if d.percent:
		return "%.0f%%" % (value * 100.0)
	if is_equal_approx(value, floor(value)):
		return str(int(round(value)))
	return "%.2f" % value

# --- Ability helpers -------------------------------------------------------
static func ability_power(id: String, level: int) -> float:
	var d: Dictionary = ABILITIES[id]
	return d.base_power + d.power_growth * float(level - 1)

static func ability_upgrade_cost(id: String, level: int) -> int:
	var d: Dictionary = ABILITIES[id]
	return int(ceil(d.upgrade_base * pow(d.upgrade_growth, level - 1)))

static func ability_cooldown(id: String, level: int) -> float:
	var d: Dictionary = ABILITIES[id]
	var reduction := float(d.get("cooldown_reduction_per_level", 0.0)) * float(level - 1)
	var min_cooldown := float(d.get("cooldown_min", 0.1))
	return maxf(min_cooldown, float(d.cooldown) - reduction)

# --- Enemy / floor scaling -------------------------------------------------
static func enemy_stats(floor_num: int, is_boss: bool) -> Dictionary:
	var f := float(floor_num)
	var hp := 30.0 * pow(1.12, f - 1.0)
	var atk := 5.0 * pow(1.10, f - 1.0)
	var def := 1.0 + (f - 1.0) * 0.5
	var gold := int(ceil(4.0 * pow(1.09, f - 1.0)))
	var emerald_chance := 0.15
	var emerald_amount := 1
	if is_boss:
		hp *= 6.0
		atk *= 1.8
		def *= 1.5
		gold *= 12
		emerald_chance = 1.0
		emerald_amount = 3 + int(floor(f / 10.0))
	return {
		"max_hp": hp,
		"attack": atk,
		"defense": def,
		"attack_speed": 0.8,
		"gold": gold,
		"emerald_chance": emerald_chance,
		"emerald_amount": emerald_amount,
		"is_boss": is_boss,
	}
