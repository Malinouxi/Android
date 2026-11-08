class_name Combos
## LES COMBOS DE PIÈGES : des défenses (ou des sorts, ou une créature) qui se
## renforcent quand on les combine. Ils sont SECRETS : le codex n'en montre
## qu'un indice tant que tu ne les as pas déclenchés une première fois.
## Les combos découverts sont gardés dans user://combos.cfg, pour toutes les parties.
##
## Où ils sont déclenchés : dungeon_map.gd (_update_traps, _explode, damage_door,
## ignite_runes), main.gd (_cast_spell, pour la Détonation) et creature.gd (Traînée
## de feu). Les chiffres sont dans rules.gd (« Combos »).

const INFO := {
	"rune_feu": {"name": "Rune de feu", "images": ["res://assets/props/rune.png", "res://assets/icons_hd/brazier.png"],
		"hint": "Une rune n'aime pas la chaleur...",
		"text": "Une Rune qui explose à moins de 2 cases d'un Brasero : explosion 50 % plus large, et le sol brûle 6 s. Les héros qui y passent prennent feu."},
	"reaction_chaine": {"name": "Réaction en chaîne", "images": ["res://assets/props/rune.png", "res://assets/props/rune.png"],
		"hint": "Une explosion peut en cacher une autre.",
		"text": "L'explosion d'une Rune fait sauter les autres Runes qu'elle touche, chacune 25 % plus fort que la précédente."},
	"pointes_ardentes": {"name": "Pointes ardentes", "images": ["res://assets/props/spikes_up.png", "res://assets/icons_hd/brazier.png"],
		"hint": "Le fer chauffé au rouge mord plus fort.",
		"text": "Des Pointes à moins de 2 cases d'un Brasero : +50 % de dégâts, et le héros prend feu pendant 3 s."},
	"empalement": {"name": "Empalement", "images": ["res://assets/props/spikes_up.png", "res://assets/units/spider_idle_0.png"],
		"hint": "Un héros englué dans la toile ne saute pas par-dessus les pointes.",
		"text": "Un héros ralenti (morsure d'Araignée) qui marche sur des Pointes prend le double de dégâts."},
	"detonation": {"name": "Détonation", "images": ["res://assets/icons/bolt.png", "res://assets/props/rune.png"],
		"hint": "La foudre du maître réveille la magie des runes...",
		"text": "Un Éclair lancé sur une Rune la fait exploser aussitôt, 50 % plus fort. L'éclair n'a même pas besoin de toucher un héros."},
	"porte_herissee": {"name": "Porte hérissée", "images": ["res://assets/props/spikes_up.png", "res://assets/props/door.png"],
		"hint": "Celui qui frappe une porte regarde-t-il où il met les pieds ?",
		"text": "Des Pointes collées à une Porte se réarment deux fois plus vite."},
	"porte_electrifiee": {"name": "Porte électrifiée", "images": ["res://assets/icons/bolt.png", "res://assets/props/door.png"],
		"hint": "Le bois mouillé conduit bien la foudre...",
		"text": "Un Éclair lancé sur une Porte la charge pendant 20 s : chaque héros qui la frappe prend une décharge de 12 dégâts."},
	"rune_engluee": {"name": "Rune engluée", "images": ["res://assets/icons_hd/web.png", "res://assets/props/rune.png"],
		"hint": "Un héros collé au sol ne s'écarte pas de ce qui va exploser.",
		"text": "Un héros pris dans la Toile du maître qui déclenche une Rune prend 60 % de dégâts en plus."},
	"brasier_runique": {"name": "Brasier runique", "images": ["res://assets/icons_hd/firestorm.png", "res://assets/props/rune.png"],
		"hint": "Les runes craignent le feu... même celui du maître.",
		"text": "Le sort Brasier fait exploser les Runes de sa zone en Runes de feu : explosion plus large, et le sol brûle."},
	"trainee_de_feu": {"name": "Traînée de feu", "images": ["res://assets/icons/haste.png", "res://assets/icons_hd/demon.png"],
		"hint": "Un démon pressé laisse des traces brûlantes.",
		"text": "Un Démon sous Hâte enflamme le sol derrière lui : les héros qui le suivent prennent feu."},
}

const SAVE_PATH := "user://combos.cfg"

## Les combos déjà découverts : id -> true.
static var _discovered := {}
static var _loaded := false


static func is_discovered(id: String) -> bool:
	_load()
	return _discovered.has(id)


static func discovered_count() -> int:
	_load()
	return _discovered.size()


## Note un combo comme découvert. Renvoie true si c'est la première fois.
static func discover(id: String) -> bool:
	_load()
	if _discovered.has(id) or not INFO.has(id):
		return false
	_discovered[id] = true
	var config := ConfigFile.new()
	config.load(SAVE_PATH) # (S'il n'existe pas encore, on part d'un fichier vide.)
	config.set_value("combos", id, true)
	config.save(SAVE_PATH)
	return true


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK or not config.has_section("combos"):
		return
	for id in config.get_section_keys("combos"):
		_discovered[id] = true
