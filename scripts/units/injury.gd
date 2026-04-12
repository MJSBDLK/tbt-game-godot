## Runtime instance of an injury on a unit.
## Created by InjurySystem when a unit is killed and then committed to
## CharacterData.current_injuries at mission end.
class_name Injury
extends RefCounted


var injury_id: String = ""
var severity: Enums.InjurySeverity = Enums.InjurySeverity.MINOR
var battles_remaining: int = 0


## Number of injury slots this instance occupies (1 for Minor, 2 for Major).
func slots_occupied() -> int:
	return 2 if severity == Enums.InjurySeverity.MAJOR else 1


## Returns the matching InjuryData template, or null if unknown.
func get_data() -> InjuryData:
	return InjuryDatabase.get_injury_by_id(injury_id)


## The mechanic-relevant magnitude for this injury's current severity.
func magnitude() -> float:
	var data: InjuryData = get_data()
	if data == null:
		return 0.0
	return data.major_magnitude if severity == Enums.InjurySeverity.MAJOR else data.minor_magnitude
