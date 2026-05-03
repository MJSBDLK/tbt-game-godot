## Autoload singleton holding the active campaign's state across missions.
## A "campaign" is an ordered list of mission scene paths, a start level, and
## a recruit pool the player draws from between missions. Persists for the
## lifetime of the process — quit the game to clear state.
##
## Flow:
##   start_screen.gd           -> CampaignManager.start_campaign(level, missions, pool)
##   post_mission_report_panel -> CampaignManager.advance_mission()
##   advance_mission()         -> show recruit picker -> register choice -> load next scene
##                              | end_campaign() if no missions remain
##
## Stub-first scope (alpha item #1): mission_index increment + scene routing.
## Auto-leveling (item #2) reads start_level when it lands. Squad roster mutation
## reset between campaigns is a TODO — for now, restart the game to clear.
##
## Registered as "CampaignManager" in project.godot.
extends Node


signal campaign_started(start_level: int, mission_paths: Array)
signal mission_advanced(new_index: int)
signal recruit_added(character_data: CharacterData)
signal campaign_ended()


const START_SCREEN_PATH: String = "res://scenes/ui/start_screen.tscn"
const PREP_SCREEN_PATH: String = "res://scenes/ui/prep_screen.tscn"
const RECRUIT_OFFER_COUNT: int = 3

# Per-character starting levels. Lookup by character_id. Anyone not listed
# defaults to the squad's current average level at the moment they're recruited
# (see _resolve_target_level). Move/passive pools are still shallow — once they
# fill out we can let the player pick start level instead.
const CHARACTER_START_LEVELS: Dictionary = {
	"spaceman": 1,
	"ernesto": 5,
	"maam": 11,
}
const FALLBACK_DEFAULT_LEVEL: int = 5


var _mission_paths: Array[String] = []
# Pool of JSON paths that the player can be offered between missions. Picks
# are drawn at random from paths NOT in _recruited_paths (avoids re-offering
# someone already in the active roster this campaign).
var _recruit_pool: Array[String] = []
var _recruited_paths: Array[String] = []
var _current_mission_index: int = -1
var _start_level: int = 5

# Player's deployment choice for the upcoming mission. Subset of character_ids
# from SquadManager's active roster. Set by prep_screen via set_deployment()
# right before deploy_to_current_mission(). Empty list means "deploy everyone"
# (the legacy behavior — used as fallback if prep screen never set it).
var _deployment_selection: Array[String] = []


# =============================================================================
# PUBLIC API
# =============================================================================

func start_campaign(start_level: int, mission_paths: Array[String],
		recruit_pool: Array[String] = []) -> void:
	if mission_paths.is_empty():
		push_error("CampaignManager: Cannot start campaign with empty mission list")
		return
	_start_level = start_level
	_mission_paths = mission_paths.duplicate()
	_recruit_pool = recruit_pool.duplicate()
	_recruited_paths.clear()
	_current_mission_index = 0

	# Auto-level the player's bootstrapped roster up to the campaign start level.
	# SquadManager's _bootstrap_default_roster has already loaded these from JSON
	# at level 1; we now simulate growth rolls for them.
	for character: CharacterData in SquadManager.get_active_roster():
		_auto_level_to_start(character)

	campaign_started.emit(_start_level, _mission_paths)
	DebugConfig.log_unit_init("CampaignManager: Started campaign — level %d, %d missions, %d in recruit pool" % [
		_start_level, _mission_paths.size(), _recruit_pool.size()])
	get_tree().change_scene_to_file(PREP_SCREEN_PATH)


## Called by post_mission_report_panel after the player clicks Continue.
## At each mission boundary, offers the player a choice of N candidates from
## the recruit pool (defaults to RECRUIT_OFFER_COUNT = 3). Awaits the picker;
## once chosen, registers the recruit and loads the next mission. Skips the
## picker silently if the pool has nothing left to offer.
func advance_mission() -> void:
	if not is_active():
		push_warning("CampaignManager: advance_mission() called with no active campaign")
		_return_to_start_screen()
		return

	_current_mission_index += 1
	if _current_mission_index >= _mission_paths.size():
		end_campaign()
		return

	var candidates: Array[String] = _pick_recruit_candidates(RECRUIT_OFFER_COUNT)
	if not candidates.is_empty():
		var ui_manager: Node = get_node_or_null("/root/UIManager")
		if ui_manager != null and ui_manager.has_method("show_recruit_picker_and_wait"):
			var chosen_path: String = await ui_manager.show_recruit_picker_and_wait(candidates)
			_register_recruit(chosen_path)
		else:
			push_warning("CampaignManager: UIManager missing show_recruit_picker_and_wait — skipping recruit step")

	mission_advanced.emit(_current_mission_index)
	DebugConfig.log_unit_init("CampaignManager: Advancing to mission %d/%d (via prep screen)" % [
		_current_mission_index + 1, _mission_paths.size()])
	get_tree().change_scene_to_file(PREP_SCREEN_PATH)


## Records which roster members the player has chosen to deploy in the next
## mission. Called by prep_screen right before deploy_to_current_mission().
## Empty array = "deploy everyone" (legacy fallback for callers that never set it).
func set_deployment(character_ids: Array[String]) -> void:
	_deployment_selection = character_ids.duplicate()


## Returns the player's deployment selection. Empty array means no filter
## (deploy everyone). BattleScene reads this when spawning player units.
func get_deployment() -> Array[String]:
	return _deployment_selection.duplicate()


## Loads the actual mission scene for the current mission_index. Called by
## prep_screen's Begin Mission button after the player confirms their squad.
func deploy_to_current_mission() -> void:
	if not is_active():
		push_warning("CampaignManager: deploy_to_current_mission() called with no active campaign")
		_return_to_start_screen()
		return
	DebugConfig.log_unit_init("CampaignManager: Deploying to mission %d/%d" % [
		_current_mission_index + 1, _mission_paths.size()])
	get_tree().change_scene_to_file(_mission_paths[_current_mission_index])


## Returns up to `count` randomly-shuffled paths from _recruit_pool, excluding
## any that have already been recruited this campaign. May return fewer than
## `count` (or empty) if the pool is exhausted.
func _pick_recruit_candidates(count: int) -> Array[String]:
	var available: Array[String] = []
	for path: String in _recruit_pool:
		if not _recruited_paths.has(path):
			available.append(path)
	available.shuffle()
	var picked: Array[String] = []
	for i: int in range(mini(count, available.size())):
		picked.append(available[i])
	return picked


## Adds a character to SquadManager's active roster and tracks the path so we
## don't re-offer them. Silently no-ops on empty path (caller may pass "" if
## the pool was exhausted or the picker was skipped). New recruits are
## auto-leveled to the campaign start level so they don't drag down the
## already-leveled team.
func _register_recruit(json_path: String) -> void:
	if json_path.is_empty():
		return
	var character: CharacterData = SquadManager.get_character_by_path(json_path)
	if character == null:
		push_warning("CampaignManager: Failed to recruit '%s' (load failed or permadead)" % json_path)
		return
	if not _recruited_paths.has(json_path):
		_recruited_paths.append(json_path)
	_auto_level_to_start(character)
	recruit_added.emit(character)
	DebugConfig.log_unit_init("CampaignManager: Recruited %s (level %d)" % [character.character_name, character.level])


## Simulates growth rolls on a character until they reach their target level.
## Target comes from CHARACTER_START_LEVELS for known IDs; recruits without an
## entry get the squad's current average level (so a new joiner isn't a
## level-1 weakling on a level-10 team). Mutates in place.
func _auto_level_to_start(character: CharacterData) -> void:
	if character == null:
		return
	var target: int = _resolve_target_level(character)
	if character.level >= target:
		return
	character.simulate_levels_up_to(target)


func _resolve_target_level(character: CharacterData) -> int:
	if CHARACTER_START_LEVELS.has(character.character_id):
		return int(CHARACTER_START_LEVELS[character.character_id])
	return _squad_average_level()


func _squad_average_level() -> int:
	var roster: Array[CharacterData] = SquadManager.get_active_roster()
	if roster.is_empty():
		return FALLBACK_DEFAULT_LEVEL
	var total: int = 0
	for character: CharacterData in roster:
		total += character.level
	return maxi(1, int(roundf(float(total) / roster.size())))


## Minimum effective span (in level units) used for both Gaussian sampling and
## quintile bucket calculation. Ensures even a flat-leveled squad still has a
## meaningful difficulty spread for enemy spawns. ±2 around the squad center.
const MIN_EFFECTIVE_SPAN: int = 4


## Picks a level for an enemy spawn given its difficulty bucket from the
## spawn tile.
##  - DEFAULT bucket: Gaussian centered on squad mean, std dev = effective_span/4,
##    clamped to the effective range. Most common = squad center.
##  - VERY_LOW..VERY_HIGH (5 quintiles of the squad's effective range): uniform
##    pick within the quintile.
##  - MINIBOSS / BOSS: uniform pick in the projected band beyond max
##    (max..max+0.2*span and max+0.2..max+0.4*span respectively).
##
## "Effective range" is the squad's actual [min, max], expanded outward to a
## minimum span of MIN_EFFECTIVE_SPAN (4) so a tightly-bunched squad still has
## quintile variety. All results floored at level 1.
##
## Each call rerolls — call once per enemy spawn for tile-level variance.
func pick_enemy_level(difficulty: Enums.EnemyDifficulty = Enums.EnemyDifficulty.DEFAULT) -> int:
	var roster: Array[CharacterData] = SquadManager.get_active_roster()
	if roster.is_empty():
		return FALLBACK_DEFAULT_LEVEL

	var squad_min: int = roster[0].level
	var squad_max: int = roster[0].level
	var total: int = 0
	for character: CharacterData in roster:
		if character.level < squad_min:
			squad_min = character.level
		if character.level > squad_max:
			squad_max = character.level
		total += character.level
	var squad_mean: float = float(total) / float(roster.size())

	# Apply the minimum-span floor (centered on the actual midpoint).
	var actual_span: int = squad_max - squad_min
	var effective_span: int = maxi(actual_span, MIN_EFFECTIVE_SPAN)
	var center_f: float = float(squad_min + squad_max) / 2.0
	var effective_min: float = center_f - float(effective_span) / 2.0
	var effective_max: float = center_f + float(effective_span) / 2.0
	var span_f: float = float(effective_span)

	if difficulty == Enums.EnemyDifficulty.DEFAULT:
		# Gaussian over the effective range, centered on squad mean.
		var std_dev: float = span_f / 4.0
		var u1: float = maxf(randf(), 1e-9)  # avoid log(0)
		var u2: float = randf()
		var z: float = sqrt(-2.0 * log(u1)) * cos(TAU * u2)
		var sample: float = squad_mean + z * std_dev
		return maxi(1, clampi(roundi(sample), int(roundf(effective_min)), int(roundf(effective_max))))

	# Bucket-based: each named bucket has a [low, high] band as a fraction of
	# effective_span, anchored at effective_min for quintiles or effective_max
	# for boss bands.
	var band: Array = _bucket_band(difficulty, effective_min, effective_max, span_f)
	var lo: float = band[0]
	var hi: float = band[1]
	# Uniform pick within the band, rounded to int.
	var pick: float = lo + randf() * (hi - lo)
	return maxi(1, roundi(pick))


func _bucket_band(difficulty: Enums.EnemyDifficulty, effective_min: float,
		effective_max: float, span: float) -> Array:
	match difficulty:
		Enums.EnemyDifficulty.VERY_LOW:
			return [effective_min, effective_min + 0.2 * span]
		Enums.EnemyDifficulty.LOW:
			return [effective_min + 0.2 * span, effective_min + 0.4 * span]
		Enums.EnemyDifficulty.NORMAL:
			return [effective_min + 0.4 * span, effective_min + 0.6 * span]
		Enums.EnemyDifficulty.HIGH:
			return [effective_min + 0.6 * span, effective_min + 0.8 * span]
		Enums.EnemyDifficulty.VERY_HIGH:
			return [effective_min + 0.8 * span, effective_max]
		Enums.EnemyDifficulty.MINIBOSS:
			return [effective_max, effective_max + 0.2 * span]
		Enums.EnemyDifficulty.BOSS:
			return [effective_max + 0.2 * span, effective_max + 0.4 * span]
	return [effective_min, effective_max]


func end_campaign() -> void:
	DebugConfig.log_unit_init("CampaignManager: Campaign complete — returning to start screen")
	_mission_paths.clear()
	_current_mission_index = -1
	campaign_ended.emit()
	_return_to_start_screen()


func is_active() -> bool:
	return _current_mission_index >= 0 and _current_mission_index < _mission_paths.size()


func get_start_level() -> int:
	return _start_level


func get_current_mission_index() -> int:
	return _current_mission_index


func get_mission_count() -> int:
	return _mission_paths.size()


func is_final_mission() -> bool:
	return _current_mission_index == _mission_paths.size() - 1


# =============================================================================
# INTERNAL
# =============================================================================

func _return_to_start_screen() -> void:
	get_tree().change_scene_to_file(START_SCREEN_PATH)
