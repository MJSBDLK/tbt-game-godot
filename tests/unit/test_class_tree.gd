## The promotion tree in Enums.CLASS_INFO (promotes_to). The art board draws
## it; the class-choice screen will read it. Design:
## data/design/class-and-promotion.md.
extends GutTest


func test_every_promotion_goes_up_exactly_one_tier() -> void:
	for character_class: Enums.CharacterClass in Enums.CLASS_INFO:
		for promotion: Enums.CharacterClass in Enums.CLASS_INFO[character_class].get("promotes_to", []):
			assert_eq(Enums.get_class_tier(promotion), Enums.get_class_tier(character_class) + 1,
					"%s promotes into %s" % [Enums.get_class_display_name(character_class),
						Enums.get_class_display_name(promotion)])


func test_tier_three_is_the_top() -> void:
	for character_class: Enums.CharacterClass in Enums.CLASS_INFO:
		if Enums.get_class_tier(character_class) == 3:
			assert_eq(Enums.CLASS_INFO[character_class].get("promotes_to", []), [],
					Enums.get_class_display_name(character_class))
