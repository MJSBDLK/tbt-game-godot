## Minimal Node2D stand-in for unit-test code paths that read fields off
## a Unit via duck-typing (`unit.get("...")`).
##
## Only declare fields the code under test actually reads — leaning on this
## as a shape contract for what the system expects from a Unit. If a test
## needs a new field, add it here so other tests get it for free.
class_name TestFakeUnit
extends Node2D


var character_data: CharacterData = null
var unit_name: String = "FakeUnit"
var last_killing_source: Dictionary = {}
var last_damage_overkill: int = 0
var faction: Enums.UnitFaction = Enums.UnitFaction.PLAYER
var current_hp: int = 0
var active_status_effects: Array = []
var current_tile: Tile = null
var can_act: bool = true
var can_move: bool = true
var pending_crit: bool = false
var attacks_this_turn: int = 0


## Mirrors Unit.is_defeated() — MoveTargeting.is_valid_target reads it.
func is_defeated() -> bool:
	return current_hp <= 0


## Mirror Unit's VOID-lock queries. PassiveRegistry.get_handlers_for(data, unit)
## skips locked passive slots, and move-selection consults the move variant, so
## fake units used in those paths need both.
func is_move_index_locked(index: int) -> bool:
	return StatusEffectSystem.is_move_locked(self, index)


func is_passive_index_locked(index: int) -> bool:
	return StatusEffectSystem.is_passive_locked(self, index)
