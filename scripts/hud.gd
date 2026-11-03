class_name Hud
extends CanvasLayer
## L'interface affichée par-dessus le jeu :
##   - en haut : or, trésor, ouvriers, créatures, bouton d'invocation ;
##     et en dessous : vie du cœur, jour de paie, prochaine vague de héros ;
##   - à droite : la barre d'outils (creuser, construire une salle, démolir) ;
##   - à gauche : la mana, les sorts et la recherche en cours ;
##   - en bas : les messages.
## Un CanvasLayer ne bouge pas avec la caméra : parfait pour une interface.
## Tout est construit par code, pour que tu voies comment ça marche.

signal summon_pressed
signal restart_pressed
signal pause_pressed
signal resume_pressed
signal save_pressed
signal menu_pressed
signal next_level_pressed
signal tool_selected(tool: int)

## Ce que fait un toucher sur la carte.
enum Tool { DIG, TREASURY, LAIR, FARM, DEMOLISH, HAND, SPIKES, RUNE, DOOR,
		LIBRARY, WORKSHOP, TRAINING, SPELL_HEAL, SPELL_LIGHTNING, SPELL_HASTE, PRISON, TEMPLE }

var _top_panel: PanelContainer
var _tool_panel: PanelContainer
var _gold_label: Label
var _treasury_label: Label
var _workers_label: Label
var _creatures_label: Label
var _payday_label: Label
var _heart_label: Label
var _wave_label: Label
var _summon_button: Button
var _message_label: Label
var _message_timer: SceneTreeTimer
var _hand_label: Label
var _pause_panel: Control
var _spell_panel: PanelContainer
var _mana_label: Label
var _research_label: Label
var _goal_label: Label
## Tous les boutons d'outils : Tool -> Button (main.gd change leur texte).
var _tool_buttons: Dictionary = {}
var _minimap: Minimap
var _speed_button: Button
## Vitesses de jeu proposées par le bouton « Vitesse ».
const SPEEDS := [1.0, 2.0, 3.0]
## Un seul bouton enfoncé à la fois, entre la barre d'outils ET les sorts.
var _tool_group := ButtonGroup.new()


func _ready() -> void:
	# L'interface continue de marcher quand le jeu est en pause (écran de défaite).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_top_panel()
	_build_tool_panel()
	_build_spell_panel()

	_message_label = _make_label(22)
	# Ancré en bas de l'écran, sur toute la largeur.
	_message_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_message_label.offset_top = -70
	_message_label.offset_bottom = -20
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_message_label)


func _build_top_panel() -> void:
	_top_panel = PanelContainer.new()
	_top_panel.position = Vector2(12, 12)
	add_child(_top_panel)

	var rows := VBoxContainer.new()
	_top_panel.add_child(rows)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	rows.add_child(row)
	var second_row := HBoxContainer.new()
	second_row.add_theme_constant_override("separation", 20)
	rows.add_child(second_row)

	_gold_label = _make_label(24)
	row.add_child(_gold_label)
	_treasury_label = _make_label(18)
	row.add_child(_treasury_label)
	_workers_label = _make_label(24)
	row.add_child(_workers_label)
	_creatures_label = _make_label(24)
	row.add_child(_creatures_label)
	_heart_label = _make_label(20)
	second_row.add_child(_heart_label)
	_payday_label = _make_label(20)
	second_row.add_child(_payday_label)
	_wave_label = _make_label(20)
	second_row.add_child(_wave_label)
	var pause_button := Button.new()
	pause_button.text = "Pause"
	pause_button.custom_minimum_size = Vector2(110, 44)
	pause_button.add_theme_font_size_override("font_size", 20)
	pause_button.pressed.connect(func() -> void:
		Sound.play("click")
		pause_pressed.emit())
	second_row.add_child(pause_button)

	# Accélérer le temps : Engine.time_scale multiplie le « delta » de tout le jeu.
	_speed_button = Button.new()
	_speed_button.custom_minimum_size = Vector2(90, 44)
	_speed_button.add_theme_font_size_override("font_size", 20)
	_speed_button.pressed.connect(func() -> void:
		Sound.play("click")
		var index := SPEEDS.find(Engine.time_scale)
		set_speed(SPEEDS[(index + 1) % SPEEDS.size()]))
	second_row.add_child(_speed_button)
	set_speed(1.0)

	_summon_button = Button.new()
	_summon_button.add_theme_font_size_override("font_size", 22)
	# Un bouton de 64 px de haut est facile à toucher avec le doigt.
	_summon_button.custom_minimum_size = Vector2(0, 64)
	_summon_button.pressed.connect(func() -> void:
		Sound.play("click")
		summon_pressed.emit())
	row.add_child(_summon_button)


func _build_tool_panel() -> void:
	_tool_panel = PanelContainer.new()
	# Collé au bord droit, et il s'agrandit vers la gauche selon son contenu.
	_tool_panel.anchor_left = 1.0
	_tool_panel.anchor_right = 1.0
	_tool_panel.offset_left = -12
	_tool_panel.offset_right = -12
	_tool_panel.offset_top = 130
	_tool_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(_tool_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_tool_panel.add_child(column)
	# Une grille de 2 colonnes : tous les boutons tiennent sur l'écran.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	column.add_child(grid)

	var tools := [
		[Tool.DIG, "Creuser"],
		[Tool.HAND, "Main"],
		[Tool.TREASURY, _room_label(Rooms.Type.TREASURY)],
		[Tool.LAIR, _room_label(Rooms.Type.LAIR)],
		[Tool.FARM, _room_label(Rooms.Type.FARM)],
		[Tool.LIBRARY, _room_label(Rooms.Type.LIBRARY)],
		[Tool.WORKSHOP, _room_label(Rooms.Type.WORKSHOP)],
		[Tool.TRAINING, _room_label(Rooms.Type.TRAINING)],
		[Tool.PRISON, _room_label(Rooms.Type.PRISON)],
		[Tool.TEMPLE, _room_label(Rooms.Type.TEMPLE)],
		[Tool.SPIKES, _defense_label(Defenses.Type.SPIKES)],
		[Tool.RUNE, _defense_label(Defenses.Type.RUNE)],
		[Tool.DOOR, _defense_label(Defenses.Type.DOOR)],
		[Tool.DEMOLISH, "Démolir"],
	]
	for entry in tools:
		grid.add_child(_make_tool_button(entry[0], entry[1]))

	# Ce que le joueur tient dans sa main.
	_hand_label = _make_label(18)
	_hand_label.custom_minimum_size = Vector2(346, 0)
	_hand_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hand_label)
	set_hand([], 0)


## Le panneau de gauche : mana, boutons de sorts, recherche en cours.
func _build_spell_panel() -> void:
	_spell_panel = PanelContainer.new()
	_spell_panel.position = Vector2(12, 130)
	add_child(_spell_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_spell_panel.add_child(column)

	_goal_label = _make_label(16)
	_goal_label.add_theme_color_override("font_color", Color("ffd54a"))
	_goal_label.custom_minimum_size = Vector2(170, 0)
	_goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_goal_label)
	_mana_label = _make_label(20)
	column.add_child(_mana_label)
	for tool in [Tool.SPELL_HEAL, Tool.SPELL_LIGHTNING, Tool.SPELL_HASTE]:
		column.add_child(_make_tool_button(tool, ""))
	_research_label = _make_label(16)
	_research_label.custom_minimum_size = Vector2(170, 0)
	_research_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_research_label)


func _make_tool_button(tool: int, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_group = _tool_group
	button.button_pressed = tool == Tool.DIG
	button.custom_minimum_size = Vector2(170, 50)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(func() -> void:
		Sound.play("click")
		tool_selected.emit(tool))
	_tool_buttons[tool] = button
	return button


## Change le texte d'un outil, et le grise s'il n'est pas encore découvert.
func set_tool_state(tool: int, text: String, locked: bool) -> void:
	var button: Button = _tool_buttons[tool]
	button.text = text
	button.disabled = locked


func set_speed(speed: float) -> void:
	Engine.time_scale = speed
	_speed_button.text = "x%d" % speed


## Crée la mini-carte en bas à gauche (appelé par main.gd, qui connaît la carte).
func add_minimap(map: DungeonMap, camera: CameraController) -> void:
	_minimap = Minimap.new()
	add_child(_minimap)
	_minimap.setup(map, camera)
	_minimap.anchor_top = 1.0
	_minimap.anchor_bottom = 1.0
	_minimap.offset_left = 14
	_minimap.offset_right = 14 + _minimap.size.x
	_minimap.offset_top = -14 - _minimap.size.y
	_minimap.offset_bottom = -14


func set_mana(mana: float, max_mana: float) -> void:
	_mana_label.text = "Mana : %d / %d" % [mana, max_mana]


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
	_gold_label.text = "Or : %d" % total
	_treasury_label.text = "Trésor : %d / %d" % [stored, capacity]


func set_workers(count: int) -> void:
	_workers_label.text = "Ouvriers : %d" % count


## count = créatures présentes, beds = nombre de lits (cases de Repaire).
func set_creatures(count: int, beds: int) -> void:
	_creatures_label.text = "Créatures : %d / %d lits" % [count, beds]


func set_payday(seconds_left: int) -> void:
	_payday_label.text = "Paie dans %d s" % seconds_left


func set_heart(hp: float, max_hp: float) -> void:
	_heart_label.text = "Cœur : %d / %d" % [hp, max_hp]


## wave = numéro de la prochaine vague, seconds_left = temps avant son arrivée.
func set_next_wave(wave: int, seconds_left: int) -> void:
	_wave_label.text = "Vague %d dans %d s" % [wave, seconds_left]


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
	add_child(panel)

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
	_summon_button.text = "+ Ouvrier (%d or)" % cost


## Affiche un message en bas de l'écran pendant quelques secondes.
func show_message(text: String, duration := 3.0) -> void:
	_message_label.text = text
	_message_timer = get_tree().create_timer(duration)
	var this_timer := _message_timer
	await this_timer.timeout
	if _message_timer == this_timer: # Pas remplacé entre-temps par un autre message.
		_message_label.text = ""


func hide_message() -> void:
	_message_label.text = ""


## Vrai si cette position de l'écran est sur un panneau de l'interface
## (pour ne pas agir sur la case cachée sous un bouton).
func is_over_ui(screen_position: Vector2) -> bool:
	return _top_panel.get_global_rect().has_point(screen_position) \
			or _tool_panel.get_global_rect().has_point(screen_position) \
			or _spell_panel.get_global_rect().has_point(screen_position) \
			or (_minimap != null and _minimap.get_global_rect().grow(4).has_point(screen_position))


func _defense_label(type: int) -> String:
	return "%s (%d)" % [Defenses.display_name(type), Defenses.cost(type)]


func _room_label(type: int) -> String:
	return "%s (%d)" % [Rooms.display_name(type), Rooms.cost(type)]


func _make_label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	return label
