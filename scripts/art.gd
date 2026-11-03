class_name Art
## Toutes les images du jeu, chargées une seule fois.
##
## preload() charge l'image dès que le jeu démarre. Les images viennent du
## dossier assets/ : elles sont générées par tools/generate_art.py, mais tu peux
## remplacer n'importe quel PNG par ton propre dessin (16 x 16 pixels).
## Elles sont affichées 2 fois plus grandes (une case = 32 pixels à l'écran).

# --- Tuiles (plusieurs variantes, pour que le sol ne soit pas trop répétitif) ---
const EARTH := [
	preload("res://assets/tiles/earth_0.png"),
	preload("res://assets/tiles/earth_1.png"),
	preload("res://assets/tiles/earth_2.png"),
]
const GOLD := [
	preload("res://assets/tiles/gold_0.png"),
	preload("res://assets/tiles/gold_1.png"),
]
const ROCK := [
	preload("res://assets/tiles/rock_0.png"),
	preload("res://assets/tiles/rock_1.png"),
]
const FLOOR := [
	preload("res://assets/tiles/floor_0.png"),
	preload("res://assets/tiles/floor_1.png"),
	preload("res://assets/tiles/floor_2.png"),
]
const ROOM_FLOORS := {
	Rooms.Type.TREASURY: preload("res://assets/tiles/room_treasury.png"),
	Rooms.Type.LAIR: preload("res://assets/tiles/room_lair.png"),
	Rooms.Type.FARM: preload("res://assets/tiles/room_farm.png"),
	Rooms.Type.LIBRARY: preload("res://assets/tiles/room_library.png"),
	Rooms.Type.WORKSHOP: preload("res://assets/tiles/room_workshop.png"),
	Rooms.Type.TRAINING: preload("res://assets/tiles/room_training.png"),
	Rooms.Type.PRISON: preload("res://assets/tiles/room_prison.png"),
	Rooms.Type.TEMPLE: preload("res://assets/tiles/room_temple.png"),
}
## Le sol revendiqué par ton donjon.
const CLAIMED := [
	preload("res://assets/tiles/claimed_0.png"),
	preload("res://assets/tiles/claimed_1.png"),
	preload("res://assets/tiles/claimed_2.png"),
]
## Le meuble posé sur chaque case de ces salles.
const ROOM_PROPS := {
	Rooms.Type.LIBRARY: preload("res://assets/props/bookshelf.png"),
	Rooms.Type.WORKSHOP: preload("res://assets/props/anvil.png"),
	Rooms.Type.TRAINING: preload("res://assets/props/dummy.png"),
	Rooms.Type.TEMPLE: preload("res://assets/props/altar.png"),
}
## Les barreaux, dessinés par-dessus un héros prisonnier.
const PRISON_BARS := preload("res://assets/props/prison_bars.png")

# --- Objets et décor ---
const HEART := preload("res://assets/props/heart.png")
const PORTAL := preload("res://assets/props/portal.png")
const ENTRANCE := preload("res://assets/props/entrance.png")
const BED := preload("res://assets/props/bed.png")
const MUSHROOM := preload("res://assets/props/mushroom.png")
# --- Défenses ---
const SPIKES_DOWN := preload("res://assets/props/spikes_down.png")
const SPIKES_UP := preload("res://assets/props/spikes_up.png")
const RUNE := preload("res://assets/props/rune.png")
const DOOR := preload("res://assets/props/door.png")

## Tas d'or du trésor, de 1 à 5 pièces.
const GOLD_PILES := [
	preload("res://assets/props/gold_pile_1.png"),
	preload("res://assets/props/gold_pile_2.png"),
	preload("res://assets/props/gold_pile_3.png"),
	preload("res://assets/props/gold_pile_4.png"),
	preload("res://assets/props/gold_pile_5.png"),
]

# --- Personnages : 2 images chacun pour l'animation de marche ---
const UNITS := {
	"worker": [preload("res://assets/units/worker_0.png"), preload("res://assets/units/worker_1.png")],
	"kobold": [preload("res://assets/units/kobold_0.png"), preload("res://assets/units/kobold_1.png")],
	"orc": [preload("res://assets/units/orc_0.png"), preload("res://assets/units/orc_1.png")],
	"warlock": [preload("res://assets/units/warlock_0.png"), preload("res://assets/units/warlock_1.png")],
	"adventurer": [preload("res://assets/units/adventurer_0.png"), preload("res://assets/units/adventurer_1.png")],
	"thief": [preload("res://assets/units/thief_0.png"), preload("res://assets/units/thief_1.png")],
	"knight": [preload("res://assets/units/knight_0.png"), preload("res://assets/units/knight_1.png")],
	"spider": [preload("res://assets/units/spider_0.png"), preload("res://assets/units/spider_1.png")],
	"demon": [preload("res://assets/units/demon_0.png"), preload("res://assets/units/demon_1.png")],
	"cleric": [preload("res://assets/units/cleric_0.png"), preload("res://assets/units/cleric_1.png")],
	"archer": [preload("res://assets/units/archer_0.png"), preload("res://assets/units/archer_1.png")],
}


## Choisit une variante « au hasard » mais toujours la même pour une case donnée
## (sinon le sol changerait à chaque redessin !).
static func pick(variants: Array, cell: Vector2i) -> Texture2D:
	var hash_value := absi(cell.x * 73856093 ^ cell.y * 19349663)
	return variants[hash_value % variants.size()]
