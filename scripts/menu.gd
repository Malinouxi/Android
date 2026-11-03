extends Control
## Le menu principal : c'est la première scène lancée (voir project.godot).

const GAME_SCENE := "res://scenes/main.tscn"


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("1d1916")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	center.add_child(column)

	var title := _make_label("Seigneur des Profondeurs", 52, Color("ffd54a"))
	column.add_child(title)
	column.add_child(_make_label("Creuse, bâtis, et défends ton cœur contre les héros.", 22, Color("d7ccc8")))
	column.add_child(_make_gallery())

	var save := SaveGame.read()
	var continue_button := _make_button("Continuer", _on_continue_pressed)
	if save.is_empty():
		continue_button.disabled = true
	else:
		var summary: Dictionary = save.get("summary", {})
		continue_button.text = "Continuer  (vague %d, %d or)" % [
			int(summary.get("wave", 1)), int(summary.get("gold", 0))]
		continue_button.tooltip_text = "Sauvegardé le %s" % summary.get("date", "?")
	column.add_child(continue_button)
	column.add_child(_make_button("Nouvelle partie", _on_new_game_pressed))
	column.add_child(_make_button("Quitter", func() -> void: get_tree().quit()))
	# Réglages du son, côte à côte.
	var sound_row := HBoxContainer.new()
	sound_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sound_row.add_theme_constant_override("separation", 12)
	for button in Sound.make_settings_buttons():
		button.custom_minimum_size = Vector2(250, 56)
		button.add_theme_font_size_override("font_size", 20)
		sound_row.add_child(button)
	column.add_child(sound_row)

	if not save.is_empty():
		var date_label := _make_label("Dernière sauvegarde : %s" % save.get("summary", {}).get("date", "?"),
				16, Color("a1887f"))
		column.add_child(date_label)


## Une rangée de personnages en pixel art, pour décorer.
func _make_gallery() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var images: Array = [Art.UNITS["worker"][0], Art.UNITS["kobold"][0], Art.UNITS["orc"][0],
			Art.HEART, Art.UNITS["warlock"][0], Art.UNITS["knight"][0], Art.UNITS["thief"][0]]
	for texture in images:
		var picture := TextureRect.new()
		picture.texture = texture
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size = Vector2(64, 64)
		row.add_child(picture)
	return row


func _on_continue_pressed() -> void:
	SaveGame.load_requested = true
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_new_game_pressed() -> void:
	SaveGame.load_requested = false
	get_tree().change_scene_to_file(GAME_SCENE)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	return label


func _make_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(420, 72)
	button.add_theme_font_size_override("font_size", 28)
	button.pressed.connect(func() -> void: Sound.play("click"))
	button.pressed.connect(action)
	return button
