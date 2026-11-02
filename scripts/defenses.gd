class_name Defenses
## Le catalogue des défenses : pièges et portes, posés sur le sol des couloirs.
## Pour ajouter une défense : un nom dans Type et une entrée dans INFO.

enum Type {
	SPIKES, ## Pointes : blessent un héros qui marche dessus, puis se réarment.
	RUNE,   ## Rune explosive : explose au passage d'un héros, puis disparaît.
	DOOR,   ## Porte : les héros doivent la casser, tes unités passent librement.
}

const INFO := {
	Type.SPIKES: {"name": "Pointes", "cost": 80, "damage": 30.0, "rearm_time": 2.5},
	Type.RUNE: {"name": "Rune", "cost": 120, "damage": 90.0, "radius": 56.0},
	Type.DOOR: {"name": "Porte", "cost": 100, "hp": 300.0},
}


static func display_name(type: int) -> String:
	return INFO[type]["name"]


static func cost(type: int) -> int:
	return INFO[type]["cost"]
