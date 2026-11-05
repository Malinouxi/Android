class_name Levels
## Les niveaux de la campagne, et la progression du joueur (niveaux débloqués, étoiles).
##
## Chaque niveau est un dictionnaire de réglages. Le plus important est le
## « goal » (objectif) :
##   {"type": "gold", "amount": N}        amasser N pièces d'or
##   {"type": "survive", "waves": N}      repousser N vagues de héros
##   {"type": "creatures", "count": N, "level": L}   avoir N créatures de niveau L ou plus
##   {"type": "research", "count": N}     faire N découvertes à la Bibliothèque
##   {"type": "prisoners", "count": N}    avoir N héros en Prison en même temps
##   {"type": "rival"}                    détruire le cœur du maître rival
## Les autres réglages ont une valeur par défaut (voir main.gd) s'ils sont absents.

const PROGRESS_PATH := "user://progress.cfg"

## Le niveau choisi dans le menu (0 = partie libre, sans objectif).
static var current_id := 0

const FREE_PLAY := {
	"id": 0, "name": "Partie libre", "seed": 0,
	"intro": "Pas d'objectif : creuse, bâtis et tiens le plus longtemps possible !",
}

const CAMPAIGN := [
	{
		"id": 1, "name": "Premiers coups de pioche", "seed": 1101,
		"intro": "Apprends les bases : creuse les filons, construis un Trésor et amasse 1500 pièces d'or.",
		"goal": {"type": "gold", "amount": 1500},
		"start_gold": 300, "first_wave": 420.0, "wave_interval": 180.0,
	},
	{
		"id": 2, "name": "La première invasion", "seed": 2202,
		"intro": "Des héros ont repéré ton donjon. Attire des créatures et repousse 3 vagues.",
		"goal": {"type": "survive", "waves": 3},
		"start_gold": 300, "first_wave": 200.0, "wave_interval": 120.0,
	},
	{
		"id": 3, "name": "Une armée digne de ce nom", "seed": 3303,
		"intro": "Entraîne tes troupes : aie 5 créatures de niveau 2 ou plus.",
		"goal": {"type": "creatures", "count": 5, "level": 2},
		"start_gold": 400, "first_wave": 240.0, "wave_interval": 150.0,
	},
	{
		"id": 4, "name": "Le savoir est une arme", "seed": 4404,
		"intro": "Construis une Bibliothèque et fais 5 découvertes.",
		"goal": {"type": "research", "count": 5},
		"start_gold": 400, "first_wave": 240.0, "wave_interval": 140.0,
	},
	{
		"id": 5, "name": "Les geôles", "seed": 5505,
		"intro": "Découvre la Prison et garde 3 héros prisonniers en même temps.",
		"goal": {"type": "prisoners", "count": 3},
		"start_gold": 450, "first_wave": 220.0, "wave_interval": 120.0,
	},
	{
		"id": 6, "name": "Le maître voisin", "seed": 6606,
		"intro": "Un maître rival a creusé son donjon tout près (cœur bleu). Détruis son cœur !",
		"goal": {"type": "rival"}, "rival": true, "rival_hp": 1200.0, "rival_interval": 80.0,
		"start_gold": 500, "first_wave": 360.0, "wave_interval": 200.0,
	},
	{
		"id": 7, "name": "Le siège", "seed": 7707,
		"intro": "Le royaume envoie ses meilleurs héros. Tiens bon pendant 8 vagues.",
		"goal": {"type": "survive", "waves": 8},
		"start_gold": 500, "first_wave": 180.0, "wave_interval": 100.0,
	},
	{
		"id": 8, "name": "Le dernier rival", "seed": 8808,
		"intro": "Le plus puissant des maîtres rivaux veut ton territoire. Détruis son cœur !",
		"goal": {"type": "rival"}, "rival": true, "rival_hp": 2200.0, "rival_interval": 60.0,
		"start_gold": 600, "first_wave": 300.0, "wave_interval": 150.0,
	},
	{
		"id": 9, "name": "Le Champion du royaume", "seed": 9909,
		"intro": "Le roi envoie son Champion. Prépare ton donjon : il mènera la 3e vague. Abats-le !",
		"goal": {"type": "champion"}, "champion_wave": 3,
		"start_gold": 700, "first_wave": 240.0, "wave_interval": 150.0,
	},
]


static func get_level(id: int) -> Dictionary:
	for level in CAMPAIGN:
		if level["id"] == id:
			return level
	return FREE_PLAY


static func current() -> Dictionary:
	return get_level(current_id)


static func has_next(id: int) -> bool:
	return id > 0 and id < CAMPAIGN.size()


## Texte court de l'objectif, par exemple « Amasse 1500 or ».
static func goal_text(level: Dictionary) -> String:
	if not level.has("goal"):
		return "Partie libre"
	var goal: Dictionary = level["goal"]
	match goal["type"]:
		"gold":
			return "Amasse %d or" % goal["amount"]
		"survive":
			return "Repousse %d vagues" % goal["waves"]
		"creatures":
			return "%d créatures niv. %d+" % [goal["count"], goal["level"]]
		"research":
			return "Fais %d découvertes" % goal["count"]
		"prisoners":
			return "Garde %d prisonniers" % goal["count"]
		"rival":
			return "Détruis le cœur rival"
		"champion":
			return "Abats le Champion"
	return ""


# ---------------------------------------------------------------------------
# Progression (fichier user://progress.cfg)
# ---------------------------------------------------------------------------

## Le plus haut niveau débloqué (le niveau 1 l'est toujours).
static func unlocked_level() -> int:
	var config := ConfigFile.new()
	config.load(PROGRESS_PATH)
	return int(config.get_value("campaign", "unlocked", 1))


static func stars(id: int) -> int:
	var config := ConfigFile.new()
	config.load(PROGRESS_PATH)
	return int(config.get_value("campaign", "stars_%d" % id, 0))


## Enregistre une victoire : garde le meilleur nombre d'étoiles, débloque le suivant.
static func record_victory(id: int, new_stars: int) -> void:
	if id <= 0:
		return
	var config := ConfigFile.new()
	config.load(PROGRESS_PATH)
	var key := "stars_%d" % id
	config.set_value("campaign", key, maxi(new_stars, int(config.get_value("campaign", key, 0))))
	var unlocked := int(config.get_value("campaign", "unlocked", 1))
	config.set_value("campaign", "unlocked", maxi(unlocked, mini(id + 1, CAMPAIGN.size())))
	config.save(PROGRESS_PATH)
