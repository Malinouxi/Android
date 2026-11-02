class_name Hud
extends CanvasLayer
## L'interface affichée par-dessus le jeu : or, ouvriers, bouton d'invocation.
## Un CanvasLayer ne bouge pas avec la caméra : parfait pour une interface.
## Tout est construit par code, pour que tu voies comment ça marche.

signal summon_pressed

var _panel: PanelContainer
var _gold_label: Label
var _workers_label: Label
var _summon_button: Button
var _message_label: Label
var _message_timer: SceneTreeTimer


func _ready() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(12, 12)
	add_child(_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	_panel.add_child(row)

	_gold_label = _make_label(28)
	row.add_child(_gold_label)
	_workers_label = _make_label(28)
	row.add_child(_workers_label)

	_summon_button = Button.new()
	_summon_button.add_theme_font_size_override("font_size", 24)
	# Un bouton de 64 px de haut est facile à toucher avec le doigt.
	_summon_button.custom_minimum_size = Vector2(0, 64)
	_summon_button.pressed.connect(func() -> void: summon_pressed.emit())
	row.add_child(_summon_button)

	_message_label = _make_label(22)
	# Ancré en bas de l'écran, sur toute la largeur.
	_message_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_message_label.offset_top = -70
	_message_label.offset_bottom = -20
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_message_label)


func set_gold(amount: int) -> void:
	_gold_label.text = "Or : %d" % amount


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


## Vrai si cette position de l'écran est sur le panneau du haut
## (pour ne pas creuser la case cachée sous un bouton).
func is_over_ui(screen_position: Vector2) -> bool:
	return _panel.get_global_rect().has_point(screen_position)


func _make_label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	return label
