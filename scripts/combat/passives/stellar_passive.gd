## Stellar passive: grants the Maximum effect (stat debuffs can't lower stats
## below base) to allied units within 2 tiles — including the Stellar unit itself.
##
## A stat aura: it sets the maximum_from_aura flag on nearby allies each recompute.
## The flag is consumed by StatusEffectSystem._recalculate_stat_modifiers (via
## CharacterData.has_maximum_protection); PassiveEffectsSystem re-runs that recalc
## after the aura pass so the protection tracks positions. Unlike Glib's aura, this
## one includes self — the star is protected by its own light.
class_name StellarPassive
extends CombatEffect


const RANGE_TILES: int = 2


func apply_stat_aura(unit: Unit, faction_units: Array[Unit]) -> void:
	if unit.current_tile == null:
		return
	var origin_x: int = unit.current_tile.grid_x
	var origin_y: int = unit.current_tile.grid_y
	for ally: Unit in faction_units:
		if ally == null or ally.is_defeated() or ally.current_tile == null or ally.character_data == null:
			continue
		var dx: int = absi(ally.current_tile.grid_x - origin_x)
		var dy: int = absi(ally.current_tile.grid_y - origin_y)
		if dx + dy <= RANGE_TILES:  # includes self at distance 0
			ally.character_data.maximum_from_aura = true
