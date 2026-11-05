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
	Rooms.Type.GRAVEYARD: preload("res://assets/tiles/room_graveyard.png"),
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
	Rooms.Type.GRAVEYARD: preload("res://assets/props/tomb_empty.png"),
}
## Une tombe libre du Cimetière (les tombes occupées sont animées : « tomb_full »).
const TOMB_EMPTY := preload("res://assets/props/tomb_empty.png")
## Les barreaux, dessinés par-dessus un héros prisonnier.
const PRISON_BARS := preload("res://assets/props/prison_bars.png")

# --- Objets et décor ---
const HEART := preload("res://assets/props/heart.png")
const PORTAL := preload("res://assets/props/portal.png")
const ENTRANCE := preload("res://assets/props/entrance.png")
const BED := preload("res://assets/props/bed.png")
const MUSHROOM := preload("res://assets/props/mushroom.png")
const TORCH := preload("res://assets/props/torch.png")
# --- Défenses ---
const SPIKES_DOWN := preload("res://assets/props/spikes_down.png")
const SPIKES_UP := preload("res://assets/props/spikes_up.png")
const RUNE := preload("res://assets/props/rune.png")
const DOOR := preload("res://assets/props/door.png")
const SACRIFICE_ALTAR := preload("res://assets/props/sacrifice_altar.png")

## Les coffres du Trésor : fermé (vide), puis de plus en plus plein.
const CHESTS := [
	preload("res://assets/props/chest_0.png"),
	preload("res://assets/props/chest_1.png"),
	preload("res://assets/props/chest_2.png"),
	preload("res://assets/props/chest_3.png"),
]

## Tas d'or (icônes de l'interface), de 1 à 5 pièces.
const GOLD_PILES := [
	preload("res://assets/props/gold_pile_1.png"),
	preload("res://assets/props/gold_pile_2.png"),
	preload("res://assets/props/gold_pile_3.png"),
	preload("res://assets/props/gold_pile_4.png"),
	preload("res://assets/props/gold_pile_5.png"),
]

# --- Le décor animé ---
## Pour chaque objet animé : [nombre d'images, lenteur]. Le décor change d'image
## DungeonMap.ANIM_FPS fois par seconde ; une lenteur de 2 divise cette vitesse par 2.
## Fichiers : assets/props/<nom>_<numéro>.png (voir tools/art32.py, ANIMATED_PROPS).
const ANIMATED_PROPS := {
	"torch": [4, 1], "portal": [4, 1], "anvil": [3, 2], "altar": [4, 2],
	"sacrifice_altar": [2, 3], "dummy": [4, 2], "tomb_full": [4, 2],
}
static var _prop_cache := {}


## L'image d'un objet animé au « tic » d'animation donné (voir dungeon_map.gd).
static func prop_frame(prop: String, tick: int) -> Texture2D:
	if not _prop_cache.has(prop):
		var frames := []
		for i in ANIMATED_PROPS[prop][0]:
			frames.append(load("res://assets/props/%s_%d.png" % [prop, i]))
		_prop_cache[prop] = frames
	var list: Array = _prop_cache[prop]
	return list[(tick / int(ANIMATED_PROPS[prop][1])) % list.size()]


# --- Personnages : leurs animations ---
## Nombre d'images de chaque animation (voir tools/art32.py, ANIMATIONS).
## Fichiers : assets/units/<nom>_<animation>_<numéro>.png
const ANIMATION_FRAMES := {"walk": 4, "idle": 2, "attack": 2}
## Les images déjà chargées : "<nom>/<animation>" -> liste d'images.
static var _unit_cache := {}


## Les images d'une animation d'un personnage, par exemple unit_frames("knight", "walk").
## Elles sont chargées la première fois qu'on les demande, puis gardées en mémoire.
static func unit_frames(sprite: String, animation: String) -> Array:
	var key := sprite + "/" + animation
	if not _unit_cache.has(key):
		var frames := []
		for i in ANIMATION_FRAMES[animation]:
			frames.append(load("res://assets/units/%s_%s_%d.png" % [sprite, animation, i]))
		_unit_cache[key] = frames
	return _unit_cache[key]


## Choisit une variante « au hasard » mais toujours la même pour une case donnée
## (sinon le sol changerait à chaque redessin !).
static func pick(variants: Array, cell: Vector2i) -> Texture2D:
	var hash_value := absi(cell.x * 73856093 ^ cell.y * 19349663)
	return variants[hash_value % variants.size()]
