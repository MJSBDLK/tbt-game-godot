## Tag Along passive: he's hard to get away from. When a foe that started its
## walk next to the owner ends it out of reach, the owner steps into the tile
## it left. Kiting him costs; baiting him out of a line is the counterplay.
##
## A reaction hook: PassiveEffectsSystem.notify_walked fires on a COMMITTED
## walk (Unit.path_traversed, from set_acted), so an undone move never drags
## him, and a shove is not a walk. No step when he's Rooted or Frozen, when
## the tile is taken or impassable for him, or past an On Duty leash.
class_name TagAlongPassive
extends CombatEffect


const CALLOUT: String = "TAG ALONG"


func on_foe_walked_away(unit: Unit, foe: Unit, left_tile: Tile) -> void:
	if left_tile == null or left_tile.current_unit != null:
		return
	if not left_tile.can_unit_move_to(GridManager.get_unit_type(unit)):
		return
	if StatusEffectSystem.get_effect_stacks(unit, "ROOTED") > 0 \
			or StatusEffectSystem.get_effect_stacks(unit, "FREEZE") > 0:
		return
	if not GridManager.displacement_allows(unit, Vector2i(left_tile.grid_x, left_tile.grid_y)):
		return
	unit.step_to(left_tile)
	if unit.is_inside_tree():
		unit.spawn_text_callout(CALLOUT, GameColors.TEXT_SECONDARY)
	DebugConfig.log_combat("Tag Along: %s steps to [%d,%d] after %s" % [
		unit.unit_name, left_tile.grid_x, left_tile.grid_y, foe.unit_name])
