class_name Spells
## Le catalogue des sorts du maître. Ils coûtent de la MANA, qui se recharge
## toute seule, d'autant plus vite que ton territoire est grand.

enum Type {
	HEAL,      ## Soin : soigne tes unités dans une zone.
	LIGHTNING, ## Éclair : foudroie les héros dans une petite zone.
	HASTE,     ## Hâte : une de tes unités court beaucoup plus vite un moment.
}

const INFO := {
	Type.HEAL: {"name": "Soin", "mana": 30, "radius": 56.0, "amount": 60.0, "color": Color(0.3, 1.0, 0.4, 0.6)},
	Type.LIGHTNING: {"name": "Éclair", "mana": 40, "radius": 32.0, "damage": 70.0, "color": Color(0.6, 0.85, 1.0, 0.8)},
	Type.HASTE: {"name": "Hâte", "mana": 25, "duration": 15.0, "color": Color(0.3, 0.9, 1.0, 0.6)},
}

const MAX_MANA := 200.0
const START_MANA := 60.0
## Mana regagnée par seconde, plus 1 par tranche de TILES_PER_REGEN cases revendiquées,
## sans jamais dépasser MAX_REGEN par seconde.
const BASE_REGEN := 0.25
const TILES_PER_REGEN := 120
const MAX_REGEN := 1.5


static func display_name(type: int) -> String:
	return INFO[type]["name"]


static func mana_cost(type: int) -> int:
	return INFO[type]["mana"]


static func regen_per_second(claimed_tiles: int) -> float:
	return minf(MAX_REGEN, BASE_REGEN + float(claimed_tiles) / TILES_PER_REGEN)
