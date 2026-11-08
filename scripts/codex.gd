class_name Codex
extends Control
## Le CODEX : les règles du jeu, à consulter depuis le menu principal ou la pause.
##
## À gauche, la liste des articles ; à droite, l'article choisi. Les articles
## viennent de deux sources :
##   - les textes écrits à la main (scripts/codex_content.gd) ;
##   - des tableaux construits AUTOMATIQUEMENT à partir des catalogues du jeu :
##     ajoute une créature dans creatures.gd, elle apparaît toute seule ici.
##   - les nouveautés des règles (scripts/rules.gd, CHANGELOG).
## Usage : var codex := Codex.new() ; add_child(codex) ; codex.closed.connect(...)

signal closed

var _articles: Array = []
var _text: RichTextLabel
var _text_scroll: ScrollContainer

## Taille des images dans le texte (les images font 32 x 32 : x2 pour bien les voir).
const IMAGE_SIZE := 48
const TABLE_IMAGE_SIZE := 40


func _ready() -> void:
	# Le codex marche aussi pendant la pause (ouvert depuis le menu de pause).
	process_mode = Node.PROCESS_MODE_ALWAYS
	# « and_offsets » : prend vraiment tout l'écran. (set_anchors_preset seul garde
	# la taille actuelle d'un contrôle déjà affiché, ici zéro !)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = get_tree().root.theme
	_articles = _build_articles()

	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.75)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 30
	panel.offset_top = 24
	panel.offset_right = -30
	panel.offset_bottom = -24
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	# En-tête : titre, version des règles, bouton Fermer.
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "Codex des règles  (version %s)" % Rules.VERSION
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Ui.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "Fermer"
	close.custom_minimum_size = Vector2(150, 50)
	close.add_theme_font_size_override("font_size", 22)
	close.pressed.connect(func() -> void:
		Sound.play("click")
		closed.emit()
		queue_free())
	header.add_child(close)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	column.add_child(body)

	# La liste des articles, regroupés par catégorie (défilable).
	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(300, 0)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.scroll_deadzone = 12 # Un doigt qui glisse fait défiler, au lieu d'appuyer.
	body.add_child(list_scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(list)
	var group := ButtonGroup.new()
	var current_category := ""
	for i in _articles.size():
		var article: Dictionary = _articles[i]
		if article["category"] != current_category:
			current_category = article["category"]
			var category_label := Label.new()
			category_label.text = current_category
			category_label.add_theme_color_override("font_color", Color("a1887f"))
			category_label.add_theme_font_size_override("font_size", 16)
			list.add_child(category_label)
		var button := Button.new()
		button.text = article["title"]
		button.toggle_mode = true
		button.button_group = group
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 44)
		button.add_theme_font_size_override("font_size", 18)
		# PASS : le bouton laisse aussi le glissement du doigt à la liste, qui peut
		# alors défiler dans les deux sens (avec STOP, les boutons bloquaient tout).
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.pressed.connect(_show_article.bind(i))
		list.add_child(button)
		if i == 0:
			button.button_pressed = true

	# L'article choisi : un texte enrichi dans un ScrollContainer (qui sait défiler
	# au doigt, ce que le RichTextLabel seul fait mal sur téléphone).
	_text_scroll = ScrollContainer.new()
	_text_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_text_scroll.scroll_deadzone = 12
	body.add_child(_text_scroll)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true     # Le texte prend toute sa hauteur : c'est le ScrollContainer qui défile.
	_text.scroll_active = false
	_text.mouse_filter = Control.MOUSE_FILTER_PASS
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", 19)
	_text.add_theme_font_size_override("bold_font_size", 19)
	_text.add_theme_constant_override("table_h_separation", 18)
	_text.add_theme_constant_override("table_v_separation", 6)
	_text_scroll.add_child(_text)
	_show_article(0)


func _show_article(index: int) -> void:
	var article: Dictionary = _articles[index]
	var images := ""
	for path: String in article.get("images", []):
		images += _img(path, IMAGE_SIZE) + "  "
	if images != "":
		images = "[center]%s[/center]\n" % images
	_text.text = "[font_size=26][color=#ffd54a]%s[/color][/font_size]\n\n%s%s" % [
			article["title"], images, article["text"]]
	_text_scroll.set_deferred("scroll_vertical", 0) # On revient en haut de l'article.


## Une image dans le texte (balise BBCode [img]).
func _img(path: String, size: int) -> String:
	return "[img=%dx%d]%s[/img]" % [size, size, path]


## L'image d'un personnage (sa première image de respiration).
func _unit_img(sprite: String) -> String:
	return _img("res://assets/units/%s_idle_0.png" % sprite, TABLE_IMAGE_SIZE)


## L'image du meuble d'une salle.
func _room_img(type: int) -> String:
	var texture: Texture2D = Art.ROOM_PROPS.get(type, null)
	match type:
		Rooms.Type.TREASURY:
			texture = Art.CHESTS[3]
		Rooms.Type.LAIR:
			texture = Art.BED
		Rooms.Type.FARM:
			texture = Art.MUSHROOM
		Rooms.Type.PRISON:
			texture = Art.PRISON_BARS
	if texture == null:
		return "" # Pas d'image pour cette salle : on laisse la case vide.
	return _img(texture.resource_path, TABLE_IMAGE_SIZE)


func _defense_img(type: int) -> String:
	if type == Defenses.Type.BRAZIER:
		return _img("res://assets/icons_hd/brazier.png", TABLE_IMAGE_SIZE)
	var texture: Texture2D = [Art.SPIKES_UP, Art.RUNE, Art.DOOR, Art.SACRIFICE_ALTAR][type]
	return _img(texture.resource_path, TABLE_IMAGE_SIZE)


func _spell_img(type: int) -> String:
	var icon: String = ["heal", "bolt", "haste"][type]
	return _img("res://assets/icons/%s.png" % icon, TABLE_IMAGE_SIZE)


# ---------------------------------------------------------------------------
# Les articles
# ---------------------------------------------------------------------------

func _build_articles() -> Array:
	var articles: Array = CodexContent.ARTICLES.duplicate()
	articles.append({"category": "Catalogues", "title": "Créatures", "text": _creatures_table()})
	articles.append({"category": "Catalogues", "title": "Traits des créatures", "text": _traits_table()})
	articles.append({"category": "Catalogues", "title": "Héros", "text": _heroes_table()})
	articles.append({"category": "Catalogues", "title": "Salles", "text": _rooms_table()})
	articles.append({"category": "Catalogues", "title": "Défenses", "text": _defenses_table()})
	articles.append({"category": "Catalogues", "title": "Combos de pièges", "text": _combos_table()})
	articles.append({"category": "Catalogues", "title": "Sorts", "text": _spells_table()})
	articles.append({"category": "Catalogues", "title": "Recherche", "text": _research_table()})
	articles.append({"category": "Règles", "title": "Nouveautés", "text": _changelog()})
	return articles


func _header(columns: Array) -> String:
	var text := ""
	for column in columns:
		text += "[cell][color=#ffd54a]%s[/color][/cell]" % column
	return text


func _cell(value) -> String:
	return "[cell]%s[/cell]" % str(value)


## Le texte des capacités spéciales (voir unit.gd, load_abilities).
func _abilities(info: Dictionary) -> String:
	var parts: Array[String] = []
	if info.has("armor"):
		parts.append("armure -%d %%" % roundi(info["armor"] * 100))
	if info.has("lifesteal"):
		parts.append("vol de vie %d %%" % roundi(info["lifesteal"] * 100))
	if info.has("splash"):
		parts.append("ricochet")
	if info.has("regen"):
		parts.append("+%d PV/s" % info["regen"])
	if info.has("slow"):
		parts.append("ralentit")
	if info.has("dig_speed"):
		parts.append("creuse x%d" % info["dig_speed"])
	if info.has("door_damage"):
		parts.append("portes x%d" % info["door_damage"])
	if info.get("catcher", false):
		parts.append("capture les héros")
	if info.get("stealth", false):
		parts.append("discrète, vole l'or")
	if info.get("liberator", false):
		parts.append("libère les prisonniers")
	if info.get("keen_nose", false):
		parts.append("flaire les voleuses")
	if info.has("guard"):
		parts.append("garde le %s" % Rooms.display_name(info["guard"]))
	if info.has("war_cry"):
		parts.append("cri de guerre")
	if info.get("guardian", false):
		parts.append("garde sa caverne")
	if info["range"] > 50.0:
		parts.append("à distance")
	return ", ".join(parts) if not parts.is_empty() else "-"


func _creatures_table() -> String:
	var text := "[table=7]" + _header(["", "Créature", "Il faut", "Salaire", "Vie", "Dégâts", "Capacités"])
	for type: int in Creatures.INFO:
		var info: Dictionary = Creatures.INFO[type]
		var requires: Array[String] = []
		for room: int in info["requires"]:
			var amount: int = info["requires"][room]
			if room == Rooms.Type.LAIR:
				requires.append("%d lit%s" % [amount, "s" if amount > 1 else ""])
			elif room == Rooms.Type.FARM:
				requires.append("%d champignon%s" % [amount, "s" if amount > 1 else ""])
			else:
				requires.append("%d %s" % [amount, Rooms.display_name(room)])
		if info.has("limit_room"):
			var each: float = info["limit_each"]
			var per := ("%d par %s" % [roundi(each), Rooms.display_name(info["limit_room"])]) if each >= 1.0 \
					else ("1 pour %d %s" % [roundi(1.0 / each), Rooms.display_name(info["limit_room"])])
			requires.append("max %s (%d en tout)" % [per, info["limit_max"]])
		if info.get("ancient", false):
			requires.append("vaincre le Colosse endormi")
		text += _cell(_unit_img(info["sprite"])) + _cell(info["name"]) + _cell(", ".join(requires)) + _cell(info["salary"]) \
				+ _cell(roundi(info["hp"])) + _cell(roundi(info["damage"])) + _cell(_abilities(info))
	return text + "[/table]"


func _heroes_table() -> String:
	var text := "[table=6]" + _header(["", "Héros", "Dès la vague", "Vie", "Dégâts", "Capacités"])
	for type: int in Heroes.INFO:
		var info: Dictionary = Heroes.INFO[type]
		var wave: String = "rival" if info.get("rival", false) else str(info["first_wave"])
		if info.get("boss", false):
			wave = "1 vague sur %d" % Heroes.CHAMPION_EVERY
		elif info.get("no_capture", false):
			wave = "profondeurs"
		text += _cell(_unit_img(info["sprite"])) + _cell(info["name"]) + _cell(wave) + _cell(roundi(info["hp"])) \
				+ _cell(roundi(info["damage"])) + _cell(_abilities(info))
	return text + "[/table]"


func _traits_table() -> String:
	var text := "Chaque créature arrive avec 1 trait de caractère (une fois sur deux, 2). Touche-la avec l'outil Creuser pour voir les siens.\n\n"
	text += "[table=2]" + _header(["Trait", "Effet"])
	for id: String in Traits.INFO:
		text += _cell("[color=#ffd54a]%s[/color]" % Traits.INFO[id]["name"]) + _cell(Traits.INFO[id]["text"])
	return text + "[/table]"


## Les combos SECRETS : un indice tant qu'on ne les a pas déclenchés.
func _combos_table() -> String:
	var text := "Certaines défenses se renforcent quand on les combine. Découvertes : %d / %d.\n\n" % [
			Combos.discovered_count(), Combos.INFO.size()]
	text += "[table=3]" + _header(["", "Combo", "Effet"])
	for id: String in Combos.INFO:
		var info: Dictionary = Combos.INFO[id]
		if Combos.is_discovered(id):
			var images := ""
			for path: String in info["images"]:
				images += _img(path, TABLE_IMAGE_SIZE)
			text += _cell(images) + _cell("[color=#ffd54a]%s[/color]" % info["name"]) + _cell(info["text"])
		else:
			text += _cell("?") + _cell("???") + _cell("[i]Indice : %s[/i]" % info["hint"])
	return text + "[/table]"


func _rooms_table() -> String:
	var text := "[table=5]" + _header(["", "Salle", "Prix", "Construction", "Objet"])
	for type: int in Rooms.INFO:
		var size := Rooms.footprint(type)
		text += _cell(_room_img(type)) + _cell(Rooms.display_name(type)) + _cell("%d or" % Rooms.cost(type)) \
				+ _cell("%d s" % roundi(Rooms.build_time(type) * size.x * size.y)) \
				+ _cell("%s (%d x %d)" % [Rooms.INFO[type].get("object", ""), size.x, size.y])
	return text + "[/table]\n\nChaque salle se construit d'un seul bloc, de la taille indiquée (droite ou tournée), pour le prix indiqué. La durée est celle d'un seul ouvrier : à plusieurs, ça va plus vite. Un Trésor range %d or par case." % Rooms.TREASURY_CAPACITY


func _defenses_table() -> String:
	var text := "[table=4]" + _header(["", "Défense", "Fabrication (Atelier)", "Installation"])
	for type: int in Defenses.INFO:
		var price := ("%d or" % Defenses.cost(type)) if Defenses.bought_with_gold(type) else str(Defenses.cost(type))
		text += _cell(_defense_img(type)) + _cell(Defenses.display_name(type)) + _cell(price) \
				+ _cell("%d s" % roundi(Defenses.build_time(type)))
	return text + "[/table]"


func _spells_table() -> String:
	var text := "[table=3]" + _header(["", "Sort", "Mana"])
	for type: int in Spells.INFO:
		text += _cell(_spell_img(type)) + _cell(Spells.display_name(type)) + _cell(Spells.mana_cost(type))
	return text + "[/table]\n\nLa mana se recharge plus vite avec un grand territoire (%d au maximum)." % Spells.MAX_MANA


func _research_table() -> String:
	var text := "Dans l'ordre des découvertes :\n\n[table=3]" + _header(["", "Découverte", "Points de recherche"])
	for item in Research.ITEMS:
		var image := ""
		match item["kind"]:
			"room":
				image = _room_img(item["id"])
			"defense":
				image = _defense_img(item["id"])
			"spell":
				image = _spell_img(item["id"])
		text += _cell(image) + _cell(item["name"]) + _cell(item["points"])
	return text + "[/table]"


func _changelog() -> String:
	var text := ""
	for entry in Rules.CHANGELOG:
		text += "[color=#ffd54a][b]Version %s[/b][/color]\n" % entry["version"]
		for change in entry["changes"]:
			text += "- %s\n" % change
		text += "\n"
	return text
