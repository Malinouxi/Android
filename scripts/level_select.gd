extends Control
## L'écran de choix d'un niveau de la campagne (ouvert depuis le menu principal).

const GAME_SCENE := "res://scenes/main.tscn"
const MENU_SCENE := "res://scenes/menu.tscn"


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("1d1916")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	# Un ScrollContainer : si l'écran est petit, on peut faire défiler la liste.
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)
	column.add_child(_make_label("Campagne", 44, Color("ffd54a")))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	column.add_child(grid)

	var unlocked := Levels.unlocked_level()
	for level in Levels.CAMPAIGN:
		grid.add_child(_make_level_button(level, level["id"] <= unlocked))

	var back := Button.new()
	back.text = "Retour"
	back.custom_minimum_size = Vector2(300, 64)
	back.add_theme_font_size_override("font_size", 26)
	back.pressed.connect(func() -> void:
		Sound.play("click")
		get_tree().change_scene_to_file(MENU_SCENE))
	column.add_child(back)


func _make_level_button(level: Dictionary, unlocked: bool) -> Button:
	var id: int = level["id"]
	var earned := Levels.stars(id)
	var button := Button.new()
	button.custom_minimum_size = Vector2(440, 96)
	button.add_theme_font_size_override("font_size", 20)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if unlocked:
		var star_text := "étoiles : %d / 3" % earned if earned > 0 else "pas encore réussi"
		button.text = "%d. %s\n%s  (%s)" % [id, level["name"], Levels.goal_text(level), star_text]
		button.pressed.connect(func() -> void:
			Sound.play("click")
			Levels.current_id = id
			SaveGame.load_requested = false
			get_tree().change_scene_to_file(GAME_SCENE))
	else:
		button.text = "%d. Verrouillé\nTermine le niveau précédent" % id
		button.disabled = true
	return button


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	return label
