## StatusEffectData's shipped configs — the table every status icon, name and
## stat hook is read from. Pins the one thing that has already bitten in a
## build: a config pointing at art that isn't on disk (Hasted, RQD's log
## 2026-09-10) logs a resource error on every refresh of every indicator.
extends GutTest


func test_every_shipped_config_has_its_icon_on_disk() -> void:
	var configs: Dictionary = StatusEffectData.get_default_configs()
	assert_gt(configs.size(), 0, "there are configs")
	for effect_type: String in configs:
		var config: StatusEffectData = configs[effect_type]
		if config.icon_path == "":
			continue
		assert_true(ResourceLoader.exists(config.icon_path),
				"%s → %s is missing — mint a placeholder (tools/art/placeholder_status_icon.gd) or fix the path"
				% [effect_type, config.icon_path])


func test_hasted_has_an_icon() -> void:
	# The specific miss: the whole buff family shipped icons except Hasted.
	var config: StatusEffectData = StatusEffectData.get_default_configs().get("HASTED")
	assert_not_null(config)
	assert_true(ResourceLoader.exists(config.icon_path), "placeholder until Lawrence's lands")
	var texture: Texture2D = load(config.icon_path) as Texture2D
	assert_not_null(texture)
	assert_eq(texture.get_size(), Vector2(6, 6), "the 6×6 status-icon contract")
