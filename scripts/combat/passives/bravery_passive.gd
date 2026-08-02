## Bravery: mechanical courage without the Chivalric type. The unit counts as
## brave for the whole fear cluster — Roar challenges it instead of rattling
## it, Shriek of the Damned passes it over — but it keeps its own type chart
## (none of Chivalric's weaknesses or resistances). Pure marker passive; all
## consumers go through CombatPredicates.is_brave.
class_name BraveryPassive
extends CombatEffect


func grants_bravery() -> bool:
	return true
