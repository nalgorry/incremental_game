# Dungeon Descent Idle RPG

An indie incremental RPG built with **Godot 4.7** and **GDScript**. A hero
automatically fights through a 100-floor dungeon; when they die you return to
town, spend resources to permanently upgrade the hero, and dive again from the
deepest checkpoint you've unlocked.

> **Core loop:** Fight → Progress deeper → Die → Upgrade → Try again

---

## Gameplay

- **Auto-combat.** The hero auto-attacks and auto-casts up to **3 equipped
  abilities** the moment they come off cooldown.
- **100 floors**, each with **2 waves** of progressively stronger enemies.
  The second wave includes a stronger **Blue Boss**.
- **Bosses** appear every 10th floor and unlock the next-floor **checkpoint**
  after the fight, e.g. clearing floor 10 unlocks floor 11.
- **Two currencies:**
  - **Gold** — upgrade hero stats.
  - **Green Emeralds** — unlock and upgrade abilities.
- **Death** returns you to town with all progress saved.

### Hero stats (upgraded with Gold)

| Stat | Effect |
| --- | --- |
| Max HP | Total health |
| Attack | Base damage per hit |
| Attack Speed | Attacks per second |
| Defense | Reduces incoming damage |
| Crit Chance | Chance to deal a critical hit |
| Crit Damage | Critical hit damage multiplier |

### Abilities (unlocked/upgraded with Emeralds)

| Ability | Type | Effect |
| --- | --- | --- |
| Fireball | Damage | Hits the front enemy (free starter) |
| Meteor | AoE | Damages the whole wave |
| Magic Shield | Shield | Adds a shield based on starting life; upgrades increase shield and reduce cooldown |
| Frenzy | Buff | Temporary Attack & Attack Speed boost |
| Mend | Heal | Instantly restores health |

---

## Running the game

1. Install [Godot 4.7](https://godotengine.org/download) (standard / GDScript edition).
2. Open the project: launch Godot, **Import** this folder (it contains
   `project.godot`).
3. Press **F5** to play.

### From the command line (Windows)

```powershell
& "C:\Users\<you>\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe" --path "."
```

Save data is written to Godot's user folder as `user://savegame.json`.

---

## Project structure

```
project.godot              Engine config: autoloads, window, renderer
scenes/
  Main.tscn                Entry scene
scripts/
  Database.gd      (autoload)  Data-driven catalogs: stats, abilities, enemy/floor scaling + balance
  GameState.gd     (autoload)  Currencies, upgrade levels, equipped abilities, checkpoints, save/load
  Main.gd                      Switches between the Town and Dungeon screens
  Town.gd                      Town UI: stat upgrades, ability unlock/upgrade/equip, checkpoint picker
  Dungeon.gd                   Isometric auto-combat: waves, ability casting, rewards, win/loss
  CombatEntity.gd              Hero / enemy token: combat stats, HP bar, simple isometric visuals
```

### Data-driven design

All hero stats and abilities are plain dictionary entries in `Database.gd`.
Adding a new stat or ability is a **single entry** — the Town UI and the combat
system both iterate over these catalogs, so no other code needs to change.

- `Database.STATS` — stat definitions (base value, growth, gold cost curve).
- `Database.ABILITIES` — ability definitions (type, power, cooldown, emerald costs).
- `Database.enemy_stats()` — per-floor enemy scaling and rewards.

---

## Tuning the balance

Key knobs live in `Database.gd`:

- `MAX_FLOORS`, `WAVES_PER_FLOOR`, `CHECKPOINT_INTERVAL`, `ENEMIES_PER_WAVE`,
  `MAX_EQUIPPED`.
- Per-stat `base` / `growth` and `cost_base` / `cost_growth`.
- Per-ability `base_power` / `power_growth`, `cooldown`, `unlock_cost`,
  `upgrade_base` / `upgrade_growth`.
- Enemy/boss scaling and reward formulas in `enemy_stats()`.

---

## MVP scope

**Included:** auto-combat, 100 floors with waves & bosses, checkpoints, two
currencies, 6 stats, 5 abilities, equip system, save/load, town upgrade screen.

**Not yet (future work):** loot/equipment, multiple hero classes, prestige
layers, offline/idle earnings, audio, and polished art (current visuals are
placeholder isometric tokens).
