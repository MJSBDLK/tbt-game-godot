## Dev cheat keys for a battle (DebugConfig.cheats_enabled). InputManager
## asks first, even while input is off, so a stuck battle can always be
## ended: Ctrl+W wins, Ctrl+L loses, Ctrl+R refreshes and Ctrl+K kills the unit
## under the mouse. Not F9/F10: those are the Godot editor's debug pause.
class_name BattleCheats
extends RefCounted


## True when `event` was a cheat key; the caller marks it handled.
## `tile_under_mouse` is the tile Ctrl+R and Ctrl+K act on (may be null).
static func handle(event: InputEvent, tile_under_mouse: Tile) -> bool:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo or not key_event.ctrl_pressed:
		return false
	match key_event.keycode:
		KEY_W:
			end_battle(true)
		KEY_L:
			end_battle(false)
		KEY_R:
			refresh_unit_on(tile_under_mouse)
		KEY_K:
			kill_unit_on(tile_under_mouse)
		_:
			return false
	return true


static func end_battle(is_victory: bool) -> void:
	if TurnManager.is_battle_ended():
		return
	print("CHEAT: Forcing battle end — %s" % ("VICTORY" if is_victory else "DEFEAT"))
	TurnManager._end_battle(is_victory)


## Refresh the unit on `tile` (any faction). Useful for re-using First Aid on
## the same caster repeatedly when iterating on heal UX.
static func refresh_unit_on(tile: Tile) -> void:
	var unit := _living_unit_on(tile)
	if unit == null:
		return
	unit.refresh_unit()
	print("CHEAT: Refreshed '%s'" % unit.unit_name)


## Kill the unit on `tile`, and — for player units — queue a random injury
## onto its character. Exercises the full death + injury pipeline for balance
## testing: the unit dies now; the injury commits at mission end through the
## normal slot-check / permadeath path. Enemies just die — their
## character_data isn't persisted, so injuring them is meaningless.
static func kill_unit_on(tile: Tile) -> void:
	var unit := _living_unit_on(tile)
	if unit == null:
		return
	# Queue the random injury BEFORE the kill. Killing the last player unit can
	# end the battle synchronously (unit_defeated → victory check → battle_ended),
	# which commits pending injuries right then — so it must already be queued.
	var summary: String = "CHEAT: Killed '%s'" % unit.unit_name
	if unit.faction == Enums.UnitFaction.PLAYER and unit.character_data != null:
		var injury: Injury = InjurySystem.queue_random_injury(unit.character_data)
		if injury != null:
			var injury_data: InjuryData = injury.get_data()
			var label: String = injury_data.display_name if injury_data != null else injury.injury_id
			summary += " + random injury %s (%s)" % [label, Enums.InjurySeverity.keys()[injury.severity]]
	# Empty killing source → take_damage's own (type-based) death injury no-ops,
	# leaving the random injury as the only one queued.
	unit.take_damage(unit.current_hp, {})
	# take_damage only zeroes HP + emits unit_defeated (the victory check). The
	# visual death — gray out, fade, and clearing tile occupancy — lives in
	# _handle_defeat, which combat awaits after the hit. Run it here too
	# (fire-and-forget; it self-guards via _defeat_visuals_played) so the
	# cheat-killed unit actually leaves the map instead of sitting at 0 HP.
	unit._handle_defeat()
	print(summary)


static func _living_unit_on(tile: Tile) -> Unit:
	if tile == null or tile.current_unit == null or not tile.current_unit is Unit:
		return null
	var unit := tile.current_unit as Unit
	return null if unit.is_defeated() else unit
