## Minimal post-mission report. Shown after SquadManager commits injuries and
## ticks recovery. Displays a text log of what changed per character. Intended
## as a placeholder — the real reveal UI will replace this once art/flow settle.
class_name PostMissionReportPanel
extends Control


signal closed


@onready var _log_label: RichTextLabel = %ReportLabel
@onready var _continue_button: Button = %ContinueButton

# Battle outcome for the report currently being shown. Drives whether Continue
# advances to the next mission (victory) or replays the current one (defeat) —
# see CampaignManager.conclude_mission. Captured in show_report from the report's
# is_victory flag so _on_continue_pressed (also reachable via key input) can read
# it without re-deriving from the report array.
var _is_victory: bool = true


func _ready() -> void:
	visible = false
	_continue_button.pressed.connect(_on_continue_pressed)


func show_report(report: Array) -> void:
	_is_victory = report[0].get("is_victory", true) if not report.is_empty() else true
	_log_label.clear()
	_log_label.append_text(_format_report(report))
	visible = true
	_continue_button.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_on_continue_pressed()
		get_viewport().set_input_as_handled()


func _on_continue_pressed() -> void:
	visible = false
	closed.emit()
	var campaign_manager: Node = get_node_or_null("/root/CampaignManager")
	if campaign_manager != null and campaign_manager.is_active():
		# Victory advances; defeat replays this mission (CampaignManager owns the
		# advance-vs-replay policy, gated by RESTART_MISSION_ON_LOSS).
		campaign_manager.conclude_mission(_is_victory)
	else:
		# No active campaign (e.g. launched a map directly from the editor).
		# Fall back to the start screen so the player can pick a campaign.
		SceneRouter.change_scene_to("res://scenes/ui/start_screen.tscn")


func _format_report(report: Array) -> String:
	if report.is_empty():
		return "[b]Mission complete.[/b]\n\nNo roster changes."

	var is_victory: bool = report[0].get("is_victory", true)
	var lines: Array[String] = []
	lines.append("[b]%s[/b]\n" % ("VICTORY" if is_victory else "DEFEAT"))

	for entry: Dictionary in report:
		var char_name: String = entry.get("character_name", "?")
		var new_injuries: Array = entry.get("new_injuries", [])
		var recovered: Array = entry.get("recovered_injuries", [])
		var permadead: bool = entry.get("permadead", false)
		var level_before: int = entry.get("level_before", 0)
		var level_after: int = entry.get("level_after", level_before)
		var stat_ups_gained: int = entry.get("stat_ups_gained", 0)
		var growths_gained: Array = entry.get("growths_gained", [])
		var leveled: bool = level_after > level_before

		if (new_injuries.is_empty() and recovered.is_empty() and not permadead
				and not leveled and stat_ups_gained <= 0):
			lines.append("[color=#888888]%s — no changes.[/color]" % char_name)
			continue

		var header: String = char_name
		if permadead:
			header += " [color=#ff5555](PERMADEAD)[/color]"
		lines.append("[b]%s[/b]" % header)

		if leveled:
			lines.append("  [color=#ffd86a]Lv %d → %d[/color]" % [level_before, level_after])
		if not growths_gained.is_empty():
			lines.append("  [color=#a0e0ff]+ %s[/color]" % ", ".join(growths_gained))
		if stat_ups_gained > 0:
			var noun: String = "stat-up point" if stat_ups_gained == 1 else "stat-up points"
			lines.append("  [color=#88ffaa]+%d %s to spend[/color]" % [stat_ups_gained, noun])

		for injury: Injury in new_injuries:
			lines.append("  [color=#ff8888]+ %s[/color]" % _injury_label(injury))
		for injury: Injury in recovered:
			lines.append("  [color=#88ff88]- %s (recovered)[/color]" % _injury_label(injury))

	return "\n".join(lines)


func _injury_label(injury: Injury) -> String:
	if injury == null:
		return "?"
	var data: InjuryData = injury.get_data()
	var display: String = data.display_name if data != null and data.display_name != "" else injury.injury_id
	var severity: String = Enums.InjurySeverity.keys()[injury.severity].capitalize()
	return "%s (%s)" % [display, severity]
