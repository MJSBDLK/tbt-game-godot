## Glib passive: "gets along with other sarcastic little shits." A stat aura —
## the unit's banter only lands with its own kind.
##   • allied HUMOR units in range  → +AVOID_BOOST (they're in on the bit)
##   • allied non-humor units in range → -AVOID_PENALTY (they're sick of it)
##   • self excluded — you need a banter buddy, so a lone Glib unit gets no boost
##     and still annoys the earnest allies next to it.
## Stacks: cluster Glib units and they all buff each other; the optimal play is to
## clump the sarcastic ones together and keep them away from the earnest crew.
##
## Uses the dedicated avoid channel (CharacterData.passive_bonus_avoid), kept apart
## from agility so it's pure dodge with no turn-speed coupling. Emitter-writes to
## OTHER units, which is why the aura recompute runs in two passes (see
## PassiveEffectsSystem.recompute_faction).
##
## HUMOR_PASSIVES is the in-group: add "Sarcastic" / "Dry Wit" here later so those
## units also count as appreciative (and, if wanted, give them this same aura).
class_name GlibPassive
extends CombatEffect


# The "sarcastic in-group" — passives whose PERSONALITY is irreverent/dismissive,
# so a Glib unit appreciates them (boost) instead of grating on them (penalty).
# REVISIT THIS whenever a new passive is added: decide if its flavor fits the bit.
# Members here only RECEIVE the boost; only Glib currently emits the aura. If this
# taxonomy ends up used outside Glib, promote it to a shared location.
#   Flippant / Cavalier = literal synonyms for glib (dismissive, offhand).
#   Anti-Gravity = breezy, nothing weighs them down. (Capricious is a maybe —
#   whimsical, but more flighty than sarcastic. Reckless/Impetuous/Impulsive are
#   rash, not witty; Reliable/Waste Not are earnest — the opposite vibe.)
const HUMOR_PASSIVES: Array[String] = ["Glib", "Anti-Gravity", "Flippant", "Cavalier"]
const RANGE_TILES: int = 3
const AVOID_BOOST: int = 10
const AVOID_PENALTY: int = 10


func apply_stat_aura(unit: Unit, faction_units: Array[Unit]) -> void:
	if unit.current_tile == null:
		return
	var origin_x: int = unit.current_tile.grid_x
	var origin_y: int = unit.current_tile.grid_y
	for ally: Unit in faction_units:
		if ally == null or ally == unit or ally.is_defeated() or ally.current_tile == null:
			continue
		if ally.character_data == null:
			continue
		var dx: int = absi(ally.current_tile.grid_x - origin_x)
		var dy: int = absi(ally.current_tile.grid_y - origin_y)
		if dx + dy > RANGE_TILES:
			continue
		if _appreciates_banter(ally.character_data):
			ally.character_data.passive_bonus_avoid += AVOID_BOOST
		else:
			ally.character_data.passive_bonus_avoid -= AVOID_PENALTY


func _appreciates_banter(data: CharacterData) -> bool:
	for passive_name: String in HUMOR_PASSIVES:
		if data.has_equipped_passive(passive_name):
			return true
	return false
