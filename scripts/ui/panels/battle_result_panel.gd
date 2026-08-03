## Battle result screen — the first thing shown after the VICTORY/DEFEAT
## banner clears. Mission-scoped facts only: turns vs par, itemized bEXP
## income (MissionCatalog award lines rendered verbatim), kills/losses, and
## roster damage (injuries / recoveries / permadeath). Unit-scoped celebration
## (level-ups, stat reveals) deliberately lives in the NEXT screen
## (LevelUpReportPanel) — this screen answers "how did the mission go",
## that one answers "how did my people grow".
##
## Chain position (UIManager._on_post_mission_report_ready, reordered
## 2026-08-03): banner → THIS → level-ups → bEXP spend → conclude. Continue
## only emits `closed`; UIManager owns what comes next.
##
## SCOPE — functionality-first scaffolding per [[feedback-ui-scope-order]]:
## contents are the locked part, visuals are placeholder until the mockup
## pass (the projection-on-glass treatment arrives with the intermission
## redesign).
class_name BattleResultPanel
extends Control


signal closed


@onready var _result_label: RichTextLabel = %ResultLabel
@onready var _continue_button: Button = %ContinueButton


func _ready() -> void:
	visible = false
	_continue_button.pressed.connect(_on_continue_pressed)


## stats keys (from TurnManager via UIManager.show_battle_result):
##   is_victory, turn_count, player_units_lost, enemies_defeated,
##   total_players, total_enemies
## award_lines: MissionCatalog.compute_award_lines output ({label, amount}).
## report: SquadManager's post_mission_report_ready payload (injuries etc.).
func show_result(stats: Dictionary, award_lines: Array, report: Array) -> void:
	_result_label.clear()
	_result_label.append_text(_format_result(stats, award_lines, report))
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


func _format_result(stats: Dictionary, award_lines: Array, report: Array) -> String:
	var is_victory: bool = stats.get("is_victory", true)
	var lines: Array[String] = []

	var outcome_color: Color = GameColors.PLAYER_UNIT if is_victory else GameColors.ENEMY_UNIT
	lines.append("[color=%s][b]%s[/b][/color]" % [
			outcome_color.to_html(false), "VICTORY" if is_victory else "DEFEAT"])
	lines.append("")

	# Turns vs par — par is a displayed fact per mission_objectives.md; the
	# player should never have to learn the speed incentive from a wiki.
	var entry: Dictionary = MissionCatalog.entry_for(CampaignManager.get_current_mission_path())
	lines.append("%s  Turns: %d   (par %d · dawdle %d)" % [
			_dim("▸"), int(stats.get("turn_count", 0)),
			int(entry.get("par_turns", 0)), int(entry.get("dawdle_turns", 0))])
	lines.append("%s  Enemies defeated: %d/%d" % [_dim("▸"),
			int(stats.get("enemies_defeated", 0)), int(stats.get("total_enemies", 0))])
	lines.append("%s  Units lost: %d/%d" % [_dim("▸"),
			int(stats.get("player_units_lost", 0)), int(stats.get("total_players", 0))])
	lines.append("")

	lines.append("[b]Bonus XP earned[/b]")
	if award_lines.is_empty():
		if is_victory:
			lines.append(_dim("  None — finished past the dawdle threshold."))
		else:
			lines.append(_dim("  None — a lost mission pays nothing."))
	else:
		var total: int = 0
		for award: Dictionary in award_lines:
			total += int(award.get("amount", 0))
			lines.append("  %s  [color=%s]+%d[/color]" % [
					str(award.get("label", "?")),
					GameColors.TEXT_SUCCESS.to_html(false), int(award.get("amount", 0))])
		lines.append("  [b]Total  [color=%s]+%d[/color][/b]" % [
				GameColors.TEXT_SUCCESS.to_html(false), total])
	lines.append("")

	lines.append("[b]Roster[/b]")
	lines.append_array(_roster_lines(report))

	return "\n".join(lines)


## Injuries / recoveries / permadeath only. Level-ups are deliberately absent
## — they celebrate on the next screen, and repeating them here as text would
## deflate that reveal.
func _roster_lines(report: Array) -> Array[String]:
	var lines: Array[String] = []
	for entry: Dictionary in report:
		var char_name: String = entry.get("character_name", "?")
		var new_injuries: Array = entry.get("new_injuries", [])
		var recovered: Array = entry.get("recovered_injuries", [])
		if entry.get("permadead", false):
			lines.append("  [color=%s]%s — LOST (injury overflow)[/color]" % [
					GameColors.TEXT_DANGER.to_html(false), char_name])
			continue
		for injury: Injury in new_injuries:
			lines.append("  [color=%s]%s — injured: %s[/color]" % [
					GameColors.TEXT_DANGER.to_html(false), char_name, _injury_label(injury)])
		for injury: Injury in recovered:
			lines.append("  [color=%s]%s — recovered: %s[/color]" % [
					GameColors.TEXT_SUCCESS.to_html(false), char_name, _injury_label(injury)])
	if lines.is_empty():
		lines.append(_dim("  Everyone came through intact."))
	return lines


func _injury_label(injury: Injury) -> String:
	if injury == null:
		return "?"
	var data: InjuryData = injury.get_data()
	var display: String = data.display_name if data != null and data.display_name != "" else injury.injury_id
	var severity: String = Enums.InjurySeverity.keys()[injury.severity].capitalize()
	return "%s (%s)" % [display, severity]


func _dim(text: String) -> String:
	return "[color=%s]%s[/color]" % [GameColors.TEXT_SECONDARY.to_html(false), text]
