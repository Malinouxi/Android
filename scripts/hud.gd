class_name Hud
extends CanvasLayer
## L'interface affichée par-dessus le jeu :
##   - en haut, une grande barre : emblème, or, mana, créatures, ouvriers, vie du
##     cœur, prochaine vague, paie, invocation d'ouvrier, vitesse et pause ;
##   - en haut à droite : la mini-carte, dans un cadre ;
##   - à gauche : l'objectif, les sorts (icônes) et la recherche ;
##   - en bas à gauche : la fiche de la créature touchée (portrait, vie, humeur...) ;
##   - en bas au centre : la barre d'outils en icônes, rangée par onglets ;
##   - en bas à droite : le journal des messages (les alertes en rouge).
## Un CanvasLayer ne bouge pas avec la caméra : parfait pour une interface.
## Tout est construit par code, pour que tu voies comment ça marche.

signal summon_pressed
signal restart_pressed
signal pause_pressed
signal resume_pressed
signal save_pressed
signal menu_pressed
signal next_level_pressed
signal codex_pressed
signal tool_selected(tool: int)

## Ce que fait un toucher sur la carte.
enum Tool { DIG, TREASURY, LAIR, FARM, DEMOLISH, HAND, SPIKES, RUNE, DOOR,
		LIBRARY, WORKSHOP, TRAINING, SPELL_HEAL, SPELL_LIGHTNING, SPELL_HASTE, PRISON, TEMPLE,
		ALTAR, SACRIFICE, GRAVEYARD }

var _top_panel: PanelContainer
var _tool_panel: PanelContainer
var _spell_panel: PanelContainer
var _log_panel: PanelContainer
var _unit_panel: PanelContainer
var _minimap_frame: PanelContainer
var _gold_label: Label
var _treasury_label: Label
var _workers_label: Label
var _creatures_label: Label
var _payday_label: Label
var _heart_bar: ProgressBar
var _heart_label: Label
var _wave_label: Label
var _summon_button: Button
var _mana_label: Label
var _research_label: Label
var _goal_label: Label
var _tool_name_label: Label
var _hand_label: Label
var _log_box: VBoxContainer
var _pause_panel: Control
## Un Control qui couvre l'écran et contient toute l'interface. Il porte le thème
## (police pixel, boutons en pierre) : un CanvasLayer ne le reçoit pas tout seul.
var _root: Control
## Tous les boutons d'outils : Tool -> Button (main.gd change leur texte).
var _tool_buttons: Dictionary = {}
## Le texte complet de chaque outil (« Trésor (25) ») : affiché quand on le choisit.
var _tool_texts: Dictionary = {}
var _current_tool: int = Tool.DIG
var _minimap: Minimap
var _speed_button: Button
## Les onglets de la barre d'outils : nom -> grille de boutons.
var _tabs: Dictionary = {}
var _tab_buttons: Dictionary = {}
## La créature dont la fiche est affichée (ou null).
var _selected: Creature = null
var _unit_portrait: TextureRect
var _unit_name: Label
var _unit_hp: ProgressBar
var _unit_mood: ProgressBar
var _unit_details: Label
var _refresh_timer := 0.0

const RED := Color("c62828")
const LOG_LINES := 4 ## Nombre de messages gardés dans le journal.
const TOP_HEIGHT := 64

## L'icône de chaque outil et sort (des images 16 x 16, agrandies sur les boutons).
const TOOL_ICONS := {
	Tool.DIG: preload("res://assets/icons/pickaxe.png"),
	Tool.HAND: preload("res://assets/icons/hand.png"),
	Tool.DEMOLISH: preload("res://assets/icons/hammer.png"),
	Tool.TREASURY: preload("res://assets/props/gold_pile_3.png"),
	Tool.LAIR: preload("res://assets/props/bed.png"),
	Tool.FARM: preload("res://assets/props/mushroom.png"),
	Tool.LIBRARY: preload("res://assets/props/bookshelf.png"),
	Tool.WORKSHOP: preload("res://assets/props/anvil.png"),
	Tool.TRAINING: preload("res://assets/props/dummy.png"),
	Tool.PRISON: preload("res://assets/props/prison_bars.png"),
	Tool.TEMPLE: preload("res://assets/props/altar.png"),
	Tool.GRAVEYARD: preload("res://assets/props/tomb_empty.png"),
	Tool.SPIKES: preload("res://assets/props/spikes_up.png"),
	Tool.RUNE: preload("res://assets/props/rune.png"),
	Tool.DOOR: preload("res://assets/props/door.png"),
	Tool.ALTAR: preload("res://assets/props/sacrifice_altar.png"),
	Tool.SACRIFICE: preload("res://assets/icons/dagger.png"),
	Tool.SPELL_HEAL: preload("res://assets/icons/heal.png"),
	Tool.SPELL_LIGHTNING: preload("res://assets/icons/bolt.png"),
	Tool.SPELL_HASTE: preload("res://assets/icons/haste.png"),
}
## Les onglets de la barre d'outils, et leurs outils.
const TABS := {
	"Actions": [Tool.DIG, Tool.HAND, Tool.DEMOLISH, Tool.SACRIFICE],
	"Salles": [Tool.TREASURY, Tool.LAIR, Tool.FARM, Tool.LIBRARY, Tool.WORKSHOP, Tool.TRAINING,
			Tool.PRISON, Tool.TEMPLE, Tool.GRAVEYARD],
	"Défenses": [Tool.SPIKES, Tool.RUNE, Tool.DOOR, Tool.ALTAR],
}
## Vitesses de jeu proposées par le bouton « Vitesse ».
const SPEEDS := [1.0, 2.0, 3.0]
## Un seul bouton enfoncé à la fois, entre la barre d'outils ET les sorts.
var _tool_group := ButtonGroup.new()


func _ready() -> void:
	# L'interface continue de marcher quand le jeu est en pause (écran de défaite).
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10 # Au-dessus des particules (voir la couche FxLayer de main.tscn).
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE # Laisse passer les touchers vers la carte.
	_root.theme = get_tree().root.theme
	add_child(_root)
	# Le codex s'ouvre par-dessus tout (il marche aussi pendant la pause).
	codex_pressed.connect(func() -> void: _root.add_child(Codex.new()))
	_build_top_panel()
	_build_spell_panel()
	_build_tool_panel()
	_build_log_panel()
	_build_unit_panel()


func _process(delta: float) -> void:
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.25
		_refresh_unit_panel()


# ---------------------------------------------------------------------------
# Les cadres : pierre sombre, liseré rouge (comme une forteresse infernale)
# ---------------------------------------------------------------------------

func _frame_style(border := Color("6d2a20"), alpha := 0.94) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.09, 0.07, 0.065, alpha)
	box.border_color = border
	box.set_border_width_all(3)
	box.set_corner_radius_all(3)
	box.shadow_color = Color(0, 0, 0, 0.5)
	box.shadow_size = 4
	box.set_content_margin_all(8)
	return box


func _framed_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _frame_style())
	_root.add_child(panel)
	return panel


## Une case « compteur » de la barre du haut : icône + valeur, dans un creux sombre.
func _counter(texture: Texture2D, label: Label, min_width := 0.0) -> PanelContainer:
	var slot := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.02, 0.02, 0.85)
	style.border_color = Color("3e2a22")
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 10
	slot.add_theme_stylebox_override("panel", style)
	slot.custom_minimum_size.x = min_width
	slot.add_child(_with_icon(texture, label))
	return slot


func _build_top_panel() -> void:
	_top_panel = _framed_panel()
	_top_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_top_panel.offset_bottom = TOP_HEIGHT
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_top_panel.add_child(row)

	# L'emblème du maître : le cœur du donjon dans un médaillon.
	var emblem := TextureRect.new()
	emblem.texture = preload("res://assets/props/heart.png")
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.custom_minimum_size = Vector2(44, 44)
	row.add_child(emblem)

	_gold_label = _make_label(22)
	_gold_label.add_theme_color_override("font_color", Ui.GOLD)
	row.add_child(_counter(preload("res://assets/props/gold_pile_3.png"), _gold_label, 120))
	_treasury_label = _make_label(13)
	_treasury_label.add_theme_color_override("font_color", Color("bcaaa4"))
	row.add_child(_treasury_label)
	_mana_label = _make_label(20)
	_mana_label.add_theme_color_override("font_color", Color("64b5f6"))
	row.add_child(_counter(preload("res://assets/icons/mana.png"), _mana_label, 110))
	_creatures_label = _make_label(20)
	row.add_child(_counter(preload("res://assets/units/kobold_idle_0.png"), _creatures_label, 120))
	_workers_label = _make_label(20)
	row.add_child(_counter(preload("res://assets/units/worker_idle_0.png"), _workers_label, 60))

	# La vie du cœur : une grande barre rouge, avec sa valeur par-dessus.
	var heart_box := HBoxContainer.new()
	heart_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heart_box.add_theme_constant_override("separation", 4)
	var heart_icon := TextureRect.new()
	heart_icon.texture = preload("res://assets/props/heart.png")
	heart_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	heart_icon.custom_minimum_size = Vector2(28, 28)
	heart_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heart_box.add_child(heart_icon)
	_heart_bar = _make_bar(RED, 22)
	_heart_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_heart_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heart_box.add_child(_heart_bar)
	_heart_label = _make_label(14)
	_heart_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_heart_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heart_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_heart_bar.add_child(_heart_label)
	row.add_child(heart_box)

	var times := VBoxContainer.new()
	times.add_theme_constant_override("separation", 0)
	_wave_label = _make_label(15)
	_wave_label.add_theme_color_override("font_color", Color("ef9a9a"))
	times.add_child(_wave_label)
	_payday_label = _make_label(13)
	_payday_label.add_theme_color_override("font_color", Color("bcaaa4"))
	times.add_child(_payday_label)
	row.add_child(times)

	_summon_button = Button.new()
	_summon_button.custom_minimum_size = Vector2(0, 46)
	_summon_button.add_theme_font_size_override("font_size", 16)
	_summon_button.icon = preload("res://assets/units/worker_idle_0.png")
	_summon_button.expand_icon = true
	_summon_button.pressed.connect(func() -> void:
		Sound.play("click")
		summon_pressed.emit())
	row.add_child(_summon_button)

	# Accélérer le temps : Engine.time_scale multiplie le « delta » de tout le jeu.
	_speed_button = Button.new()
	_speed_button.custom_minimum_size = Vector2(56, 46)
	_speed_button.add_theme_font_size_override("font_size", 18)
	_speed_button.pressed.connect(func() -> void:
		Sound.play("click")
		var index := SPEEDS.find(Engine.time_scale)
		set_speed(SPEEDS[(index + 1) % SPEEDS.size()]))
	row.add_child(_speed_button)
	set_speed(1.0)

	var pause_button := Button.new()
	pause_button.text = "II"
	pause_button.tooltip_text = "Pause"
	pause_button.custom_minimum_size = Vector2(52, 46)
	pause_button.add_theme_font_size_override("font_size", 20)
	pause_button.pressed.connect(func() -> void:
		Sound.play("click")
		pause_pressed.emit())
	row.add_child(pause_button)


## Une barre de progression colorée (vie, humeur...).
func _make_bar(color: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(60, height)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.05, 0.02, 0.02, 0.9)
	back.border_color = Color("3e2a22")
	back.set_border_width_all(2)
	back.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.border_color = color.lightened(0.3)
	fill.border_width_top = 2
	fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


## La colonne de gauche : objectif, mana, sorts en icônes, recherche.
func _build_spell_panel() -> void:
	_spell_panel = _framed_panel()
	_spell_panel.position = Vector2(8, TOP_HEIGHT + 8)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_spell_panel.add_child(column)
	_goal_label = _make_label(13)
	_goal_label.add_theme_color_override("font_color", Ui.GOLD)
	_goal_label.custom_minimum_size = Vector2(150, 0)
	_goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_goal_label)
	for tool in [Tool.SPELL_HEAL, Tool.SPELL_LIGHTNING, Tool.SPELL_HASTE]:
		var button := _make_tool_button(tool)
		button.custom_minimum_size = Vector2(150, 50)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.add_theme_font_size_override("font_size", 15)
		column.add_child(button)
	_research_label = _make_label(12)
	_research_label.add_theme_color_override("font_color", Color("b39ddb"))
	_research_label.custom_minimum_size = Vector2(150, 0)
	_research_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_research_label)


## La barre d'outils en bas au centre : des onglets, et une grille d'icônes.
func _build_tool_panel() -> void:
	_tool_panel = _framed_panel()
	_tool_panel.anchor_left = 0.5
	_tool_panel.anchor_right = 0.5
	_tool_panel.anchor_top = 1.0
	_tool_panel.anchor_bottom = 1.0
	_tool_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_tool_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_tool_panel.offset_bottom = -6
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_tool_panel.add_child(column)

	# En tête : les onglets, puis l'outil choisi et ce que tient la Main.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	column.add_child(header)
	var tab_group := ButtonGroup.new()
	for tab_name: String in TABS:
		var tab := Button.new()
		tab.text = tab_name
		tab.toggle_mode = true
		tab.button_group = tab_group
		tab.custom_minimum_size = Vector2(0, 34)
		tab.add_theme_font_size_override("font_size", 15)
		tab.pressed.connect(func() -> void:
			Sound.play("click")
			_show_tab(tab_name))
		header.add_child(tab)
		_tab_buttons[tab_name] = tab
	_tool_name_label = _make_label(14)
	_tool_name_label.add_theme_color_override("font_color", Ui.GOLD)
	_tool_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tool_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_tool_name_label)

	for tab_name: String in TABS:
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		for tool: int in TABS[tab_name]:
			grid.add_child(_make_tool_button(tool))
		column.add_child(grid)
		_tabs[tab_name] = grid
	_hand_label = _make_label(13)
	_hand_label.add_theme_color_override("font_color", Color("d7ccc8"))
	column.add_child(_hand_label)
	set_hand([], 0)
	_show_tab("Actions")
	_tab_buttons["Actions"].button_pressed = true
	_update_tool_name()


func _show_tab(tab_name: String) -> void:
	for tab_key: String in _tabs:
		_tabs[tab_key].visible = tab_key == tab_name


## Le journal des messages, en bas à droite : les derniers messages, les alertes en rouge.
func _build_log_panel() -> void:
	_log_panel = _framed_panel()
	_log_panel.anchor_left = 1.0
	_log_panel.anchor_right = 1.0
	_log_panel.anchor_top = 1.0
	_log_panel.anchor_bottom = 1.0
	_log_panel.offset_left = -440
	_log_panel.offset_right = -6
	_log_panel.offset_top = -190
	_log_panel.offset_bottom = -6
	_log_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_log_box = VBoxContainer.new()
	_log_box.add_theme_constant_override("separation", 2)
	_log_box.alignment = BoxContainer.ALIGNMENT_END
	_log_panel.add_child(_log_box)


## La fiche de la créature touchée, en bas à gauche (cachée au départ).
func _build_unit_panel() -> void:
	_unit_panel = _framed_panel()
	_unit_panel.anchor_top = 1.0
	_unit_panel.anchor_bottom = 1.0
	_unit_panel.offset_left = 6
	_unit_panel.offset_right = 330
	_unit_panel.offset_top = -150
	_unit_panel.offset_bottom = -6
	_unit_panel.visible = false
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_unit_panel.add_child(row)
	_unit_portrait = TextureRect.new()
	_unit_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_unit_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_unit_portrait.custom_minimum_size = Vector2(96, 96)
	_unit_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_unit_portrait)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 3)
	row.add_child(column)
	var title := HBoxContainer.new()
	column.add_child(title)
	_unit_name = _make_label(18)
	_unit_name.add_theme_color_override("font_color", Ui.GOLD)
	_unit_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(_unit_name)
	var close := Button.new()
	close.text = "X"
	close.custom_minimum_size = Vector2(34, 30)
	close.pressed.connect(func() -> void:
		Sound.play("click")
		select_unit(null))
	title.add_child(close)
	_unit_hp = _make_bar(RED, 14)
	column.add_child(_unit_hp)
	_unit_mood = _make_bar(Color("43a047"), 10)
	column.add_child(_unit_mood)
	_unit_details = _make_label(12)
	_unit_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_unit_details)
	# La minimap est en haut à droite : la fiche peut prendre le coin en bas à gauche.


## Affiche la fiche d'une créature (null pour la cacher).
func select_unit(creature: Creature) -> void:
	_selected = creature
	_unit_panel.visible = creature != null
	_refresh_unit_panel()


func _refresh_unit_panel() -> void:
	if _selected == null:
		return
	if not is_instance_valid(_selected) or _selected.is_queued_for_deletion():
		select_unit(null)
		return
	var info := _selected.sprite_info()
	_unit_portrait.texture = Art.unit_frames(info[0], "idle")[0]
	_unit_name.text = "%s  niv. %d" % [_selected.display_name(), _selected.level]
	_unit_hp.max_value = _selected.max_hp
	_unit_hp.value = _selected.hp
	_unit_mood.value = _selected.happiness
	var details := "Vie %d / %d   Humeur %d %%\n" % [_selected.hp, _selected.max_hp, _selected.happiness]
	if not _selected.is_undead():
		details += "Faim %d %%   Énergie %d %%\n" % [_selected.hunger, _selected.energy]
	details += "Tâche : %s\nSalaire : %d or" % [_selected.activity_text(), _selected.salary()]
	_unit_details.text = details


# ---------------------------------------------------------------------------
# Petits outils
# ---------------------------------------------------------------------------

## Une petite icône suivie d'un texte (pour les compteurs du haut).
func _with_icon(texture: Texture2D, label: Label) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var picture := TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = Vector2(28, 28)
	box.add_child(picture)
	box.add_child(label)
	return box


## Un bouton d'outil carré : l'icône en haut, le prix (ou le stock) en dessous.
func _make_tool_button(tool: int) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.button_group = _tool_group
	button.button_pressed = tool == Tool.DIG
	button.custom_minimum_size = Vector2(64, 64)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_constant_override("icon_max_width", 40)
	button.pressed.connect(func() -> void:
		Sound.play("click")
		_current_tool = tool
		_update_tool_name()
		tool_selected.emit(tool))
	_tool_buttons[tool] = button
	if TOOL_ICONS.has(tool):
		button.icon = TOOL_ICONS[tool]
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	return button


## Change le texte d'un outil, et le grise s'il n'est pas encore découvert.
## Sur les boutons carrés, on n'affiche que le prix (« 25 ») ou le stock (« x3 ») ;
## le nom complet s'affiche au-dessus de la barre quand on choisit l'outil.
func set_tool_state(tool: int, text: String, locked: bool) -> void:
	var button: Button = _tool_buttons[tool]
	_tool_texts[tool] = text
	button.tooltip_text = text
	button.disabled = locked
	var short := text
	if locked:
		short = "?"
	elif text.contains("(") and text.contains(")"):
		short = text.get_slice("(", 1).get_slice(")", 0)
	elif text.contains(" x"):
		short = "x" + text.get_slice(" x", 1)
	if button.custom_minimum_size.x <= 64.0:
		button.text = short # Les boutons carrés de la barre du bas.
	else:
		button.text = text  # Les sorts, à gauche, gardent leur nom.
	if tool == _current_tool:
		_update_tool_name()


func _update_tool_name() -> void:
	var names := {Tool.DIG: "Creuser", Tool.HAND: "Main", Tool.DEMOLISH: "Démolir", Tool.SACRIFICE: "Sacrifier"}
	_tool_name_label.text = _tool_texts.get(_current_tool, names.get(_current_tool, ""))


func set_speed(speed: float) -> void:
	Engine.time_scale = speed
	_speed_button.text = "x%d" % speed


## Crée la mini-carte en haut à droite, dans un cadre (appelé par main.gd).
func add_minimap(map: DungeonMap, camera: CameraController) -> void:
	_minimap_frame = _framed_panel()
	_minimap_frame.anchor_left = 1.0
	_minimap_frame.anchor_right = 1.0
	_minimap_frame.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_minimap_frame.offset_right = -6
	_minimap_frame.offset_left = -6
	_minimap_frame.offset_top = TOP_HEIGHT + 6
	_minimap = Minimap.new()
	_minimap_frame.add_child(_minimap)
	_minimap.setup(map, camera)


func set_mana(mana: float, max_mana: float) -> void:
	_mana_label.text = "%d / %d" % [mana, max_mana]


func set_goal(text: String) -> void:
	_goal_label.text = text


func set_research(text: String) -> void:
	_research_label.text = text


## names = noms des unités tenues, la dernière ramassée en dernier.
func set_hand(names: Array[String], capacity: int) -> void:
	if names.is_empty():
		_hand_label.text = "Main : vide"
	else:
		_hand_label.text = "Main (%d/%d) : %s" % [names.size(), capacity, ", ".join(names)]


func set_gold(total: int, stored: int, capacity: int) -> void:
	_gold_label.text = "%d" % total
	_treasury_label.text = "Trésor\n%d / %d" % [stored, capacity]


func set_workers(count: int) -> void:
	_workers_label.text = "%d" % count


## count = créatures présentes, beds = nombre de lits (cases de Repaire).
func set_creatures(count: int, beds: int) -> void:
	_creatures_label.text = "%d / %d lits" % [count, beds]


func set_payday(seconds_left: int) -> void:
	_payday_label.text = "Paie dans %d s" % seconds_left


func set_heart(hp: float, max_hp: float) -> void:
	_heart_bar.max_value = max_hp
	_heart_bar.value = hp
	_heart_label.text = "Cœur %d / %d" % [hp, max_hp]


## wave = numéro de la prochaine vague, seconds_left = temps avant son arrivée.
func set_next_wave(wave: int, seconds_left: int) -> void:
	_wave_label.text = "Vague %d : %d s" % [wave, seconds_left]


## Écran de fin de partie, avec un bouton pour rejouer.
func show_game_over(waves_survived: int) -> void:
	var column := _make_center_panel("Ton cœur a été détruit !")
	var details := _make_label(24)
	details.text = "Vagues repoussées : %d" % waves_survived
	details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(details)
	column.add_child(_make_big_button("Rejouer", restart_pressed))
	column.add_child(_make_big_button("Menu principal", menu_pressed))


## L'écran de victoire, avec les étoiles gagnées.
func show_victory(level_name: String, stars: int, has_next: bool) -> void:
	var column := _make_center_panel("Victoire !")
	var details := _make_label(26)
	details.text = "%s\nÉtoiles : %d / 3 (selon l'état de ton cœur)" % [level_name, stars]
	details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(details)
	if has_next:
		column.add_child(_make_big_button("Niveau suivant", next_level_pressed))
	column.add_child(_make_big_button("Rejouer", restart_pressed))
	column.add_child(_make_big_button("Menu principal", menu_pressed))


## Le menu de pause (le jeu est arrêté pendant ce temps, voir main.gd).
func show_pause_menu() -> void:
	if _pause_panel != null:
		return
	var column := _make_center_panel("Pause")
	_pause_panel = column.get_parent() as Control
	column.add_child(_make_big_button("Reprendre", resume_pressed))
	column.add_child(_make_big_button("Sauvegarder", save_pressed))
	column.add_child(_make_big_button("Codex des règles", codex_pressed))
	column.add_child(_make_big_button("Sauvegarder et quitter", menu_pressed))
	for button in Sound.make_settings_buttons():
		column.add_child(button)


func hide_pause_menu() -> void:
	if _pause_panel != null:
		_pause_panel.queue_free()
		_pause_panel = null


## Un panneau au centre de l'écran avec un titre. Renvoie la colonne où ajouter des boutons.
func _make_center_panel(title_text: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)

	var title := _make_label(40)
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	return column


## Un grand bouton qui émet un signal quand on le touche.
func _make_big_button(text: String, on_pressed: Signal) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320, 72)
	button.add_theme_font_size_override("font_size", 28)
	button.pressed.connect(func() -> void:
		Sound.play("click")
		on_pressed.emit())
	return button


func set_summon_cost(cost: int) -> void:
	_summon_button.text = "+%d" % cost
	_summon_button.tooltip_text = "Un ouvrier de plus (%d or)" % cost


## Les sortes de messages du journal : mots-clés -> couleur et petite pastille.
## Le premier groupe dont un mot apparaît dans le message gagne.
const MESSAGE_KINDS := [
	{"words": ["attaqu", "héros", "vague", "champion", "voleuse", "moine", "pillé", "enfui", "enfoncé",
			"détruit", "mort au combat", "tué"], "color": Color("ff5a5a"), "mark": "!"},
	{"words": ["pas assez", "impossible", "plein", "aucun", "aucune", "touche ", "construis", "dépose",
			"attend", "sans lit", "mécontent", "quitte"], "color": Color("ffa94d"), "mark": "?"},
	{"words": ["découvert", "découverte", "recherche", "fabriqu", "atelier", "bibliothèque"],
			"color": Color("b388ff"), "mark": "*"},
	{"words": [" or", "rançon", "sacrifi", "trésor", "paie", "pièces"], "color": Color("ffd54a"), "mark": "$"},
	{"words": ["arrive", "niveau", "revenant", "créature", "relève", "renvoyé", "capturé", "prison",
			"enterré", "attrapeur"], "color": Color("8bd17c"), "mark": "+"},
]


## Ajoute un message au journal (en bas à droite), coloré selon sa sorte :
## rouge = attaque, orange = conseil ou erreur, violet = savoir et fabrication,
## or = argent, vert = tes créatures. (duration : gardé pour compatibilité.)
func show_message(text: String, _duration := 3.0) -> void:
	if text == "":
		return
	var lower := text.to_lower()
	var color := Color("efe6d8")
	var mark := "-"
	for kind: Dictionary in MESSAGE_KINDS:
		var found := false
		for word: String in kind["words"]:
			if lower.contains(word):
				found = true
				break
		if found:
			color = kind["color"]
			mark = kind["mark"]
			break
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	var badge := _make_label(18)
	badge.text = mark
	badge.custom_minimum_size = Vector2(16, 0)
	badge.add_theme_color_override("font_color", color)
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	line.add_child(badge)
	var label := _make_label(18)
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(390, 0)
	label.add_theme_color_override("font_color", color)
	line.add_child(label)
	_log_box.add_child(line)
	while _log_box.get_child_count() > LOG_LINES:
		var oldest := _log_box.get_child(0)
		_log_box.remove_child(oldest)
		oldest.queue_free()
	# Les anciens messages pâlissent ; le nouveau brille un instant.
	var count := _log_box.get_child_count()
	for i in count:
		(_log_box.get_child(i) as Control).modulate.a = 0.5 + 0.5 * float(i + 1) / count
	line.modulate = Color(1.6, 1.6, 1.6)
	line.create_tween().tween_property(line, "modulate", Color.WHITE, 0.6)


## Fondu au noir qui s'éclaircit au début de la partie.
func fade_in() -> void:
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(black)
	var tween := black.create_tween()
	tween.tween_property(black, "color:a", 0.0, 0.8)
	tween.tween_callback(black.queue_free)


func hide_message() -> void:
	pass # Le journal garde les messages.


## Vrai si cette position de l'écran est sur un panneau de l'interface
## (pour ne pas agir sur la case cachée sous un bouton).
func is_over_ui(screen_position: Vector2) -> bool:
	for panel: Control in [_top_panel, _tool_panel, _spell_panel, _unit_panel, _minimap_frame, _log_panel]:
		if panel != null and panel.visible and panel.get_global_rect().has_point(screen_position):
			return true
	return false


func _make_label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	return label
