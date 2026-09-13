# Battle animations — LANDED (2026-09-09)

The plan that produced the Fire Emblem 7-style combat scene lived here from
2026-09-07 to 2026-09-09 and landed from `rqd--battle-animations`. Its decision
log (D1–D8, edge cases, art asks, build phases, RQD's eyeball rounds) is kept
verbatim in [todo-archive.md](todo-archive.md) under "Battle animations plan".

Where the truth lives now:

- `scripts/combat/presenter/combat_presenter.gd` — the living map: beats,
  rules, MapPresenter / ScenePresenter / RecordingPresenter.
- `scripts/units/unit_animation_resolver.gd` — clip vocabulary, intent,
  chains, overrides.
- `scripts/combat/scene/combat_scene.gd` — the stage: spacing, HUD, backdrop
  slots, every eyeball knob.
- `data/design/combat-system.md` §Combat Animations — the player-facing
  description and the rules art is drawn against.
- `art/backdrops/combat_test/README.md` — Lawrence's backdrop brief.
- `todo.md` "# Combat scene — follow-ups" — what is still open.

Naming: `battle_scene.gd` / `.tscn` is THE MAP; the FE7 view is `CombatScene`.
