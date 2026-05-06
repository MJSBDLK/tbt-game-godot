## Centralized debug logging configuration.
## Toggle flags to enable/disable debug output per system.
## Registered as Autoload "DebugConfig".
extends Node

# ===== SYSTEM FLAGS =====
# Set these to true to enable debug logs for that system

# Grid & Tilemap
var tilemap_sync: bool = false
var grid_manager: bool = false
var z_index: bool = false

# Units
var unit_movement: bool = false
var unit_health: bool = false
var unit_init: bool = false

# Combat
var combat: bool = false
var ai: bool = false
var status_effects: bool = false
var testing_status_effects: bool = false  # Assign random status effects on unit spawn
var testing_passives: bool = false  # Randomly equip passives from base pool on unit spawn
var testing_injuries: bool = false  # Run InjurySystem self-test at SquadManager bootstrap
var testing_random_injuries_on_spawn: bool = false  # Apply 0-4 random injuries to each player unit on spawn
var testing_enemy_ghost: bool = false  # Grant every enemy the Ghost passive (pathfind through allies)
# note: enable unit_health debug (below) for randomized health values
var testing_hypoesthesia: bool = false  # Give every player unit a Minor Hypoesthesia injury on spawn (censors HP bar above 50%)
var testing_hypoesthesia_major: bool = false  # Use Major severity instead of Minor (censor always on unless HP=0)
var testing_random_hp_on_spawn: bool = true  # Spawn every player unit at 15-100% HP — useful for testing heals

# Input & State
var input: bool = false
var game_state: bool = false

# UI
var action_menu: bool = false
var icons: bool = false
var combat_preview: bool = false
var pixel_perfect_ui: bool = false

# Turn Management
var turn_manager: bool = false

# Cheats (dev-only keybinds — Ctrl+W instawin, Ctrl+L instalose, Ctrl+R refresh hovered unit)
var cheats_enabled: bool = true


# ===== HELPER METHODS =====

## Log only if the specified flag is enabled.
func log_if(flag: bool, message: String) -> void:
	if flag:
		print(message)


## LogWarning only if the specified flag is enabled.
func log_warning(flag: bool, message: String) -> void:
	if flag:
		push_warning(message)


## LogError always logs (errors should never be suppressed).
func log_error(message: String) -> void:
	push_error(message)


# ===== CONVENIENCE METHODS =====

func log_tilemap(message: String) -> void:
	log_if(tilemap_sync, message)

func log_grid(message: String) -> void:
	log_if(grid_manager, message)

func log_z_index(message: String) -> void:
	log_if(z_index, message)

func log_unit_move(message: String) -> void:
	log_if(unit_movement, message)

func log_unit_health(message: String) -> void:
	log_if(unit_health, message)

func log_unit_init(message: String) -> void:
	log_if(unit_init, message)

func log_combat(message: String) -> void:
	log_if(combat, message)

func log_ai(message: String) -> void:
	log_if(ai, message)

func log_status(message: String) -> void:
	log_if(status_effects, message)

func log_input(message: String) -> void:
	log_if(input, message)

func log_state(message: String) -> void:
	log_if(game_state, message)

func log_action_menu(message: String) -> void:
	log_if(action_menu, message)

func log_icons(message: String) -> void:
	log_if(icons, message)

func log_turn(message: String) -> void:
	log_if(turn_manager, message)

func log_combat_preview(message: String) -> void:
	log_if(combat_preview, message)

func log_pixel_perfect_ui(message: String) -> void:
	log_if(pixel_perfect_ui, message)

# Warning variants
func warn_tilemap(message: String) -> void:
	log_warning(tilemap_sync, message)

func warn_grid(message: String) -> void:
	log_warning(grid_manager, message)
