class_name Hud
extends CanvasLayer
## L'interface affichée par-dessus le jeu :
##   - en haut : or, place dans le trésor, ouvriers, bouton d'invocation ;
##   - à droite : la barre d'outils (creuser, construire une salle, démolir) ;
##   - en bas : les messages.
## Un CanvasLayer ne bouge pas avec la caméra : parfait pour une interface.
## Tout est construit par code, pour que tu voies comment ça marche.

signal summon_pressed
signal tool_selected(tool: int)

## Ce que fait un toucher sur la carte.
enum Tool { DIG, TREASURY, LAIR, FARM, DEMOLISH }

var _top_panel: PanelContainer
var _tool_panel: PanelContainer
var _gold_label: Label
var _treasury_label: Label
var _workers_label: Label
var _summon_button: Button
var _message_label: Label
var _message_timer: SceneTreeTimer


func _ready() -> void:
	_build_top_panel()
	_build_tool_panel()

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

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	_top_panel.add_child(row)

	_gold_label = _make_label(28)
	row.add_child(_gold_label)
	_treasury_label = _make_label(20)
	row.add_child(_treasury_label)
	_workers_label = _make_label(28)
	row.add_child(_workers_label)

	_summon_button = Button.new()
	_summon_button.add_theme_font_size_override("font_size", 24)
	# Un bouton de 64 px de haut est facile à toucher avec le doigt.
	_summon_button.custom_minimum_size = Vector2(0, 64)
	_summon_button.pressed.connect(func() -> void: summon_pressed.emit())
	row.add_child(_summon_button)


func _build_tool_panel() -> void:
	_tool_panel = PanelContainer.new()
	# Collé au bord droit, et il s'agrandit vers la gauche selon son contenu.
	_tool_panel.anchor_left = 1.0
	_tool_panel.anchor_right = 1.0
	_tool_panel.offset_left = -12
	_tool_panel.offset_right = -12
	_tool_panel.offset_top = 110
	_tool_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(_tool_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_tool_panel.add_child(column)

	# Un ButtonGroup fait qu'un seul bouton peut être enfoncé à la fois.
	var group := ButtonGroup.new()
	var tools := [
		[Tool.DIG, "Creuser"],
		[Tool.TREASURY, _room_label(Rooms.Type.TREASURY)],
		[Tool.LAIR, _room_label(Rooms.Type.LAIR)],
		[Tool.FARM, _room_label(Rooms.Type.FARM)],
		[Tool.DEMOLISH, "Démolir"],
	]
	for entry in tools:
		var tool: int = entry[0]
		var button := Button.new()
		button.text = entry[1]
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = tool == Tool.DIG
		button.custom_minimum_size = Vector2(240, 60)
		button.add_theme_font_size_override("font_size", 22)
		button.pressed.connect(func() -> void: tool_selected.emit(tool))
		column.add_child(button)


func set_gold(total: int, stored: int, capacity: int) -> void:
	_gold_label.text = "Or : %d" % total
	_treasury_label.text = "Trésor : %d / %d" % [stored, capacity]


func set_workers(count: int) -> void:
	_workers_label.text = "Ouvriers : %d" % count


func set_summon_cost(cost: int) -> void:
	_summon_button.text = "Invoquer un ouvrier (%d or)" % cost


## Affiche un message en bas de l'écran pendant quelques secondes.
func show_message(text: String, duration := 3.0) -> void:
	_message_label.text = text
	_message_timer = get_tree().create_timer(duration)
	var this_timer := _message_timer
	await this_timer.timeout
	if _message_timer == this_timer: # Pas remplacé entre-temps par un autre message.
		_message_label.text = ""


## Vrai si cette position de l'écran est sur un panneau de l'interface
## (pour ne pas agir sur la case cachée sous un bouton).
func is_over_ui(screen_position: Vector2) -> bool:
	return _top_panel.get_global_rect().has_point(screen_position) \
			or _tool_panel.get_global_rect().has_point(screen_position)


func _room_label(type: int) -> String:
	return "%s (%d)" % [Rooms.display_name(type), Rooms.cost(type)]


func _make_label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	return label
