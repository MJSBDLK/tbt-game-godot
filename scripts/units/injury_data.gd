## Template configuration for an injury type.
## Looked up in InjuryDatabase by (element, damage_type) -> InjuryData.
## A single InjuryData defines both Minor and Major variants of the same injury.
class_name InjuryData
extends RefCounted


var injury_id: String = ""
var display_name: String = ""
var description: String = ""

# Element and damage_type the injury is sourced from. Used by InjuryDatabase
# for the (element, damage_type) -> InjuryData lookup. damage_type may be NONE
# to indicate "any damage type for this element."
var source_element: Enums.ElementalType = Enums.ElementalType.NONE
var source_damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL
var matches_any_damage_type: bool = false

# How the injury affects the unit. Dispatches to a code path in InjurySystem.
var mechanic: Enums.InjuryMechanic = Enums.InjuryMechanic.STAT_PCT

# For STAT_PCT: which stat field is reduced ("strength", "agility", etc.).
var affected_stat: String = ""

# Magnitude per severity. Interpretation depends on mechanic:
#   STAT_PCT, MAX_HP_PCT, HEALING_REDUCED, LUCK_PCT  → percentage as a positive float (10.0 = 10%)
#   MOVE_DISTANCE                                     → integer move distance lost
#   TURN_SKIP_CHANCE, FACTION_FLIP                    → probability percentage (6.25 = 6.25%)
#   MOVE_LOCK                                         → integer count of move/passive slots locked
#   HIDE_HEALTH                                       → HP fraction threshold above which the bar is hidden (0.5 = "shown only below 50%")
#   REMOVE_TYPE                                       → integer count of types removed (1 = primary only, 2 = both)
var minor_magnitude: float = 0.0
var major_magnitude: float = 0.0

# Recovery
var minor_recovery_battles: int = 4
var major_recovery_battles: int = 8

# Display
var icon_path: String = ""
