## Autoload singleton holding the active campaign's state across missions.
## A "campaign" is an ordered list of mission scene paths, a start level, and
## a recruit pool the player draws from between missions. Persists for the
## lifetime of the process — quit the game to clear state.
##
## Flow:
##   start_screen.gd           -> CampaignManager.start_campaign(level, missions, pool)
##   UIManager (end of post-mission chain) -> CampaignManager.conclude_mission(is_victory)
##   conclude_mission(true)    -> advance_mission() -> recruit picker -> next scene
##                              | end_campaign() if no missions remain
##   conclude_mission(false)   -> _restart_current_mission() — replay the same
##                                mission when RESTART_MISSION_ON_LOSS (else advance)
##
## Stub-first scope (alpha item #1): mission_index increment + scene routing.
## Auto-leveling (item #2) reads start_level when it lands. Squad roster mutation
## reset between campaigns is a TODO — for now, restart the game to clear.
##
## Registered as "CampaignManager" in project.godot.
extends Node


signal campaign_started(start_level: int, mission_paths: Array)
signal mission_advanced(new_index: int)
signal mission_restarted(index: int)
signal recruit_added(character_data: CharacterData)
signal campaign_ended()


const START_SCREEN_PATH: String = "res://scenes/ui/start_screen.tscn"
## Every mission boundary lands on the intermission HUB (2026-08-07), not
## straight into the squad editor. The hub is the quiet beat between the battle
## and the spreadsheet, and it owns Save / Options / Begin Mission; Manage Units
## is one entry inside it (the three-column workspace — see
## IntermissionHub.MANAGE_UNITS_PATH).
const INTERMISSION_PATH: String = "res://scenes/ui/intermission_hub.tscn"
const CAMPAIGN_COMPLETE_SCREEN_PATH: String = "res://scenes/ui/campaign_complete_screen.tscn"
const RECRUIT_OFFER_COUNT: int = 3

## TESTING-PHASE behavior: when true, losing a mission replays that same mission
## instead of advancing to the next one. Either way the player's persistent
## roster — levels and any injuries committed during battle_ended — carries over,
## because SquadManager owns that state and doesn't branch on the win/loss
## outcome. So a loss costs you progress on this mission but not your characters'
## growth. Flip to false to restore the old placeholder "advance regardless of
## outcome" behavior. The shipping game will handle defeat differently; this is a
## balance-playtest convenience (todo: "restart the level on loss, keep injuries
## and levels").
const RESTART_MISSION_ON_LOSS: bool = true

# Per-character starting levels. Lookup by character_id. Anyone not listed
# defaults to the squad's current average level at the moment they're recruited
# (see _resolve_target_level). Move/passive pools are still shallow — once they
# fill out we can let the player pick start level instead.
const CHARACTER_START_LEVELS: Dictionary = {
	"spaceman": 1,
	"ernesto": 5,
	"maam": 11,
	"elfPirate": 5,
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
# from SquadManager's active roster, ALWAYS in roster order (spawn order is
# roster order — intermission.md §4d). Seeded by the intermission hub on
# arrival, rewritten by the Manage Units rail on every pip toggle.
#
# UNSET vs. EMPTY (RQD 2026-08-16): `_deployment_chosen` says whether anyone
# has written a selection yet. Unset → "deploy everyone" (the legacy fallback
# for ad-hoc battles that never passed through the hub — F6 on a map). Chosen
# and EMPTY → the player benched everyone; that's a real 0/N the hub shows and
# refuses to launch, not a request to deploy the whole roster. Before this
# split, an empty list WAS the everyone-sentinel, which is why the rail had
# to forbid benching the last unit.
var _deployment_selection: Array[String] = []
var _deployment_chosen: bool = false


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
	# A selection carried from a previous campaign in this session names a
	# different roster's people — the hub re-seeds a fresh one on arrival.
	clear_deployment()

	# Auto-level the player's bootstrapped roster up to the campaign start level.
	# SquadManager's _bootstrap_default_roster has already loaded these from JSON
	# at level 1; we now simulate growth rolls for them.
	for character: CharacterData in SquadManager.get_active_roster():
		_auto_level_to_start(character)

	campaign_started.emit(_start_level, _mission_paths)
	DebugConfig.log_unit_init("CampaignManager: Started campaign — level %d, %d missions, %d in recruit pool" % [
		_start_level, _mission_paths.size(), _recruit_pool.size()])
	SceneRouter.change_scene_to(INTERMISSION_PATH)


## Entry point called by UIManager._finish_post_mission_flow at the end of
## the post-mission chain. Routes on the battle outcome: a victory advances to the next
## mission; a defeat replays the current one (RESTART_MISSION_ON_LOSS) so the
## player retries with the roster — levels and injuries — they finished the loss
## holding. With the toggle off, a defeat advances like a victory (the old
## placeholder behavior).
func conclude_mission(is_victory: bool) -> void:
	if not is_active():
		push_warning("CampaignManager: conclude_mission() called with no active campaign")
		_return_to_start_screen()
		return
	if _should_advance_after(is_victory, RESTART_MISSION_ON_LOSS):
		advance_mission()
	else:
		_restart_current_mission()


## Pure decision behind conclude_mission, factored out so the advance-vs-replay
## logic is unit-testable without triggering scene routing. Returns true to
## advance to the next mission, false to replay the current one.
static func _should_advance_after(is_victory: bool, restart_on_loss: bool) -> bool:
	return is_victory or not restart_on_loss


## The victory branch of conclude_mission (also the no-restart defeat branch).
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
		var ui_manager: Node = UIManager
		if ui_manager != null and ui_manager.has_method("show_recruit_picker_and_wait"):
			var chosen_path: String = await ui_manager.show_recruit_picker_and_wait(candidates)
			_register_recruit(chosen_path)
		else:
			push_warning("CampaignManager: UIManager missing show_recruit_picker_and_wait — skipping recruit step")

	mission_advanced.emit(_current_mission_index)
	DebugConfig.log_unit_init("CampaignManager: Advancing to mission %d/%d (via prep screen)" % [
		_current_mission_index + 1, _mission_paths.size()])
	SceneRouter.change_scene_to(INTERMISSION_PATH)


## The defeat branch of conclude_mission. Replays the current mission without
## advancing the index and without offering a recruit (a loss isn't progress, so
## no between-mission reward). The persistent roster already carried over via
## SquadManager's battle_ended processing, so the player retries with whatever
## levels/injuries they finished the defeat holding. Routes back through the prep
## screen so they can re-pick their deployment.
func _restart_current_mission() -> void:
	assert(is_active(), "_restart_current_mission requires an active campaign")
	mission_restarted.emit(_current_mission_index)
	DebugConfig.log_unit_init("CampaignManager: Replaying mission %d/%d after defeat" % [
		_current_mission_index + 1, _mission_paths.size()])
	SceneRouter.change_scene_to(INTERMISSION_PATH)


## Records which roster members the player has chosen to deploy in the next
## mission. Called by the intermission hub (arrival seeding) and the Manage
## Units rail (pip toggles), both of which pass ids in roster order. An empty
## array is a real choice — nobody — and marks the selection chosen; see
## has_deployment().
func set_deployment(character_ids: Array[String]) -> void:
	_deployment_selection = character_ids.duplicate()
	_deployment_chosen = true


## Back to UNSET: no selection on record, spawn logic falls back to everyone.
func clear_deployment() -> void:
	_deployment_selection.clear()
	_deployment_chosen = false


## Whether a deployment has been written at all. False = unset = "deploy
## everyone" (BattleScene) / "seed the first cap" (hub arrival). True with an
## empty get_deployment() = the player benched everyone.
func has_deployment() -> bool:
	return _deployment_chosen


## Returns the player's deployment selection. Only meaningful when
## has_deployment() — an unset selection reads empty too, and means everyone.
func get_deployment() -> Array[String]:
	return _deployment_selection.duplicate()


## Loads the actual mission scene for the current mission_index. Called by
## the intermission hub's Begin Mission entry.
func deploy_to_current_mission() -> void:
	if not is_active():
		push_warning("CampaignManager: deploy_to_current_mission() called with no active campaign")
		_return_to_start_screen()
		return
	DebugConfig.log_unit_init("CampaignManager: Deploying to mission %d/%d" % [
		_current_mission_index + 1, _mission_paths.size()])
	SceneRouter.change_scene_to(_mission_paths[_current_mission_index])


## Returns up to `count` randomly-shuffled paths from _recruit_pool, excluding
## any that have already been recruited this campaign. May return fewer than
## `count` (or empty) if the pool is exhausted.
func _pick_recruit_candidates(count: int) -> Array[String]:
	var available: Array[String] = []
	for path: String in _recruit_pool:
		if not _recruited_paths.has(path):
			available.append(path)
	GameRng.shuffle(available)
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
		var u1: float = maxf(GameRng.randf(), 1e-9)  # avoid log(0)
		var u2: float = GameRng.randf()
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
	var pick: float = lo + GameRng.randf() * (hi - lo)
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
	DebugConfig.log_unit_init("CampaignManager: Campaign complete — showing completion screen")
	_mission_paths.clear()
	_current_mission_index = -1
	campaign_ended.emit()
	SceneRouter.change_scene_to(CAMPAIGN_COMPLETE_SCREEN_PATH)


func is_active() -> bool:
	return _current_mission_index >= 0 and _current_mission_index < _mission_paths.size()


func get_start_level() -> int:
	return _start_level


func get_current_mission_index() -> int:
	return _current_mission_index


func get_current_mission_path() -> String:
	if not is_active():
		return ""
	return _mission_paths[_current_mission_index]


func get_mission_count() -> int:
	return _mission_paths.size()


func is_final_mission() -> bool:
	return _current_mission_index == _mission_paths.size() - 1


# =============================================================================
# SAVE / LOAD — orchestrated by SaveManager
# =============================================================================

## Serializes campaign progress: mission list + index, recruit bookkeeping,
## start level, and the player's deployment pick. All paths/ids — no object state.
func capture_save_state() -> Dictionary:
	return {
		"mission_paths": _mission_paths.duplicate(),
		"recruit_pool": _recruit_pool.duplicate(),
		"recruited_paths": _recruited_paths.duplicate(),
		"current_mission_index": _current_mission_index,
		"start_level": _start_level,
		"deployment_selection": _deployment_selection.duplicate(),
		"deployment_chosen": _deployment_chosen,
	}


## Restores a capture_save_state() snapshot. Does NOT route scenes — the
## caller (SaveManager) decides where the player lands after a load.
func restore_save_state(state: Dictionary) -> void:
	_mission_paths.assign(_to_string_array(state.get("mission_paths", [])))
	_recruit_pool.assign(_to_string_array(state.get("recruit_pool", [])))
	_recruited_paths.assign(_to_string_array(state.get("recruited_paths", [])))
	_deployment_selection.assign(_to_string_array(state.get("deployment_selection", [])))
	# Saves from before the unset/empty split (2026-08-16) carry no flag: an
	# empty list there was the everyone-sentinel, so it reads as unset.
	_deployment_chosen = bool(state.get("deployment_chosen", not _deployment_selection.is_empty()))
	_current_mission_index = int(state.get("current_mission_index", -1))
	_start_level = int(state.get("start_level", FALLBACK_DEFAULT_LEVEL))


## JSON arrays parse untyped — coerce elementwise before assigning to the
## typed Array[String] fields.
static func _to_string_array(values: Variant) -> Array[String]:
	var out: Array[String] = []
	if values is Array:
		for value: Variant in values:
			out.append(str(value))
	return out


# =============================================================================
# INTERNAL
# =============================================================================

func _return_to_start_screen() -> void:
	SceneRouter.change_scene_to(START_SCREEN_PATH)
