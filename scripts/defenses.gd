class_name Defenses
## Le catalogue des défenses : pièges et portes, posés sur le sol des couloirs.
## Pour ajouter une défense : un nom dans Type et une entrée dans INFO.

enum Type {
	SPIKES, ## Pointes : blessent un héros qui marche dessus, puis se réarment.
	RUNE,   ## Rune explosive : explose au passage d'un héros, puis disparaît.
	DOOR,   ## Porte : les héros doivent la casser, tes unités passent librement.
	ALTAR,  ## Autel de sacrifice : les prisonniers y sont sacrifiés contre de l'or.
	BRAZIER, ## Brasero : le feu rouge du cœur, éclaire et apaise les créatures proches.
}

## "build_time" : secondes de travail d'un ouvrier pour l'installer.
const INFO := {
	Type.SPIKES: {"name": "Pointes", "cost": 80, "damage": 30.0, "rearm_time": 2.5, "build_time": 4.0},
	Type.RUNE: {"name": "Rune", "cost": 120, "damage": 90.0, "radius": 56.0, "build_time": 6.0},
	Type.DOOR: {"name": "Porte", "cost": 100, "hp": 300.0, "build_time": 8.0},
	Type.ALTAR: {"name": "Autel", "cost": 150, "build_time": 12.0},
	# Le brasero ne sort pas de l'Atelier : il s'achète avec de l'or ("gold": true).
	Type.BRAZIER: {"name": "Brasero", "cost": 80, "build_time": 6.0, "gold": true},
}


static func display_name(type: int) -> String:
	return INFO[type]["name"]


static func build_time(type: int) -> float:
	return INFO[type]["build_time"] * Rules.BUILD_TIME_FACTOR


## Vrai si la défense s'achète avec de l'or (au lieu de venir du stock de l'Atelier).
static func bought_with_gold(type: int) -> bool:
	return INFO[type].get("gold", false)


static func cost(type: int) -> int:
	return INFO[type]["cost"]
