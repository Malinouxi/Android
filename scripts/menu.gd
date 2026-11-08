extends Node2D
## Le menu principal : c'est la première scène lancée (voir project.godot).
##
## En arrière-plan, un VRAI petit donjon en vue isométrique : une carte au
## hasard, des ouvriers qui creusent, la lumière du cœur et des torches, et une
## caméra qui dérive doucement. Par-dessus, dans un CanvasLayer (qui ne bouge
## pas avec la caméra) : le titre et les boutons.

const GAME_SCENE := "res://scenes/main.tscn"
const LEVELS_SCENE := "res://scenes/level_select.tscn"
const PANEL_WIDTH := 440.0
## Le maître des lieux sur son trône (illustration fournie par l'auteur du jeu).
const THRONE := preload("res://assets/menu/throne.png")

var _world: Node2D
var _map: DungeonMap
var _camera: Camera2D
var _heart_light: PointLight2D
var _time := 0.0
var _settings_overlay: Control
var _ui_root: Control
## Le fond en 3D (si « Vue 3D » est activée dans les réglages), sinon null.
var _view3d: View3D


func _ready() -> void:
	Engine.time_scale = 1.0
	Sound.play_music("menu")
	_build_background()
	_build_ui()


# ---------------------------------------------------------------------------
# Le donjon en arrière-plan
# ---------------------------------------------------------------------------

func _build_background() -> void:
	_world = Node2D.new()
	_world.transform = Iso.TRANSFORM
	add_child(_world)
	_map = DungeonMap.new() # Son _ready() génère une carte au hasard.
	_world.add_child(_map)
	Sound.world_transform = Iso.TRANSFORM
	Fx.world = _world

	# Quelques ouvriers, et de la terre marquée autour du cœur pour qu'ils creusent.
	var workers := Node2D.new()
	_world.add_child(workers)
	for i in 3:
		var worker := Worker.new()
		worker.setup(_map, _map.get_spawn_cell())
		workers.add_child(worker)
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			var cell := _map.heart_cell + Vector2i(dx, dy)
			if _map.is_diggable(cell) and randf() < 0.45:
				_map.set_mark(cell, true)

	_camera = Camera2D.new()
	_camera.zoom = Vector2(1.3, 1.3)
	add_child(_camera)
	_camera.make_current()

	if Sound.view_3d_enabled:
		# Le même donjon vivant, montré en 3D (voir view_3d.gd) : on cache la 2D.
		_world.visible = false
		_view3d = View3D.new()
		add_child(_view3d)
		_view3d.setup(_map, [workers] as Array[Node])
		_view3d.set_zoom(1.25)
		# Le cœur un peu à droite, pour être visible à côté du panneau de gauche.
		_view3d.pan(Vector2(120, 0)) # Le cœur entre le trône (à gauche) et le menu (à droite).
		Fx.view3d = _view3d
		return
	Fx.view3d = null

	# La pénombre et les lumières (si l'éclairage est activé dans les réglages).
	if Sound.lighting_enabled:
		if Fx.light_texture == null:
			Fx.light_texture = Fx.make_light_texture()
		var darkness := CanvasModulate.new()
		darkness.color = Color(0.42, 0.38, 0.48)
		add_child(darkness)
		_heart_light = _make_light(_map.cell_to_world(_map.heart_cell), Color(1.0, 0.4, 0.35), 280.0, 1.3)
		var torches := {}
		for corner in [Vector2i(-2, -2), Vector2i(2, -2), Vector2i(-2, 2), Vector2i(2, 2)]:
			var cell: Vector2i = _map.heart_cell + corner
			torches[cell] = true
			_make_light(_map.cell_to_world(cell), Color(1.0, 0.72, 0.4), 150.0, 0.9)
		_map.set_torches(torches)


func _make_light(map_position: Vector2, color: Color, radius: float, energy: float) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = Fx.light_texture
	light.texture_scale = radius / 128.0
	light.color = color
	light.energy = energy
	light.position = map_position
	_world.add_child(light)
	return light


func _process(delta: float) -> void:
	_time += delta
	if _view3d != null:
		_view3d.rotate_view(delta * 0.07) # La caméra tourne lentement autour du donjon.
		return
	# La caméra dérive lentement. Le cœur est décalé vers la droite, pour être
	# visible à côté du panneau de gauche.
	var heart_screen := _world.to_global(_map.cell_to_world(_map.heart_cell))
	var drift := Vector2(sin(_time * 0.11) * 120.0, cos(_time * 0.08) * 60.0)
	_camera.position = heart_screen + Vector2(-120, 0) + drift
	if _heart_light != null:
		_heart_light.energy = 1.2 + 0.3 * sin(_time * 3.0)


# ---------------------------------------------------------------------------
# Le panneau du menu
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = get_tree().root.theme
	layer.add_child(root)
	_ui_root = root

	# À gauche : le maître sur son trône. Au milieu : le donjon vivant (en fond).
	var throne := TextureRect.new()
	throne.texture = THRONE
	throne.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR # Une peinture, pas du pixel art.
	throne.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	throne.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	throne.anchor_bottom = 1.0
	throne.offset_right = 690
	throne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(throne)
	# Le diable « respire » : sa lueur monte et descend doucement.
	var glow := throne.create_tween().set_loops()
	glow.tween_property(throne, "modulate", Color(1.12, 1.05, 1.0), 1.6).set_trans(Tween.TRANS_SINE)
	glow.tween_property(throne, "modulate", Color.WHITE, 1.6).set_trans(Tween.TRANS_SINE)

	# En bas à gauche : la phrase d'accroche, dans un cadre de pierre.
	var tagline := PanelContainer.new()
	tagline.add_theme_stylebox_override("panel", _stone_style(Color(0.07, 0.05, 0.04, 0.9), 3))
	tagline.anchor_top = 1.0
	tagline.anchor_bottom = 1.0
	tagline.offset_left = 30
	tagline.offset_right = 460
	tagline.offset_top = -96
	tagline.offset_bottom = -22
	root.add_child(tagline)
	tagline.add_child(_make_label("Creuse, bâtis, règne...\nsur les profondeurs !", 22, Color("f2b632"), 6))

	# À droite : le panneau du menu.
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _stone_style(Color(0.08, 0.04, 0.035, 0.9), 3))
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -PANEL_WIDTH - 16
	panel.offset_right = -16
	panel.offset_top = 16
	panel.offset_bottom = -16
	root.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	panel.add_child(column)

	var title := _make_label("Seigneur\ndes Profondeurs", 44, Color("e53935"), 12)
	title.add_theme_color_override("font_outline_color", Color("2a0505"))
	title.add_theme_font_override("font", Ui.title_font())
	column.add_child(title)
	column.add_child(_make_label("Creuse, bâtis, et défends ton cœur contre les héros.", 16, Color("d7ccc8"), 6))

	var save := SaveGame.read()
	var continue_button := _make_button("Continuer", Art.HEART, _on_continue_pressed)
	if save.is_empty():
		continue_button.disabled = true
	else:
		var summary: Dictionary = save.get("summary", {})
		continue_button.text = "Continuer\n%s, vague %d" % [summary.get("level_name", "Partie libre"),
				int(summary.get("wave", 1))]
		continue_button.custom_minimum_size.y = 68
		continue_button.add_theme_stylebox_override("normal", Ui.primary_button_style())
	column.add_child(continue_button)
	column.add_child(_make_button("Campagne", Art.ENTRANCE, func() -> void:
		get_tree().change_scene_to_file(LEVELS_SCENE)))
	column.add_child(_make_button("Partie libre", preload("res://assets/icons/pickaxe.png"), _on_new_game_pressed))
	column.add_child(_make_button("Codex des règles", Art.ROOM_PROPS[Rooms.Type.LIBRARY], func() -> void:
		_ui_root.add_child(Codex.new())))
	column.add_child(_make_button("Réglages", Art.ROOM_PROPS[Rooms.Type.WORKSHOP], func() -> void:
		_settings_overlay.visible = true))
	column.add_child(_make_button("Quitter", Art.DOOR, func() -> void: get_tree().quit()))

	# Le bas du panneau : date de la sauvegarde et crédits.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	if not save.is_empty():
		column.add_child(_make_label("Dernière sauvegarde : %s" % save.get("summary", {}).get("date", "?"),
				14, Color("a1887f"), 4))
	column.add_child(_make_label("Fait avec Godot  -  Polices Grenze et Grenze Gotisch (OFL)", 13, Color("8d7f74"), 4))

	_settings_overlay = _make_settings_overlay()
	root.add_child(_settings_overlay)


## Les personnages sautillent chacun à leur tour.
func _make_gallery() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	var names := ["worker", "kobold", "orc", "warlock", "vampire", "golem"]
	for i in names.size():
		# Un cadre fixe (géré par le conteneur) avec l'image dedans, libre de bouger.
		var frame := Control.new()
		frame.custom_minimum_size = Vector2(52, 56)
		row.add_child(frame)
		var picture := TextureRect.new()
		picture.texture = Art.unit_frames(names[i], "idle")[0]
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.size = Vector2(48, 48)
		picture.position = Vector2(0, 8)
		frame.add_child(picture)
		var tween := picture.create_tween().set_loops()
		tween.tween_interval(i * 0.15)
		tween.tween_property(picture, "position:y", 0.0, 0.25).set_trans(Tween.TRANS_SINE)
		tween.tween_property(picture, "position:y", 8.0, 0.25).set_trans(Tween.TRANS_SINE)
		tween.tween_interval(1.2 - i * 0.15)
	return row


## La fenêtre des réglages (cachée au départ) : un voile sombre et un panneau.
func _make_settings_overlay() -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	column.add_child(_make_label("Réglages", 34, Ui.GOLD, 8))
	for button in Sound.make_settings_buttons():
		column.add_child(button)
	column.add_child(_make_label("L'éclairage et la vue 3D s'appliquent à la prochaine partie.", 14, Color("a1887f"), 4))
	column.add_child(_make_button("Fermer", null, func() -> void: overlay.visible = false))
	return overlay


func _on_continue_pressed() -> void:
	SaveGame.load_requested = true
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_new_game_pressed() -> void:
	Levels.current_id = 0 # Partie libre : pas d'objectif.
	SaveGame.load_requested = false
	get_tree().change_scene_to_file(GAME_SCENE)


## Un cadre de pierre sombre, au liseré rouge sang.
func _stone_style(background: Color, border: int) -> StyleBox:
	var hd := Ui.hd_frame("panel", 22) # Le cadre « caverne » de Blender, s'il existe.
	if hd != null:
		return hd
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color("7a1f14")
	style.set_border_width_all(border)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 8
	style.set_content_margin_all(18)
	return style


func _make_label(text: String, font_size: int, color: Color, outline: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", outline)
	return label


func _make_button(text: String, icon_texture: Texture2D, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 54)
	button.add_theme_font_size_override("font_size", 23)
	if icon_texture != null:
		button.icon = icon_texture
		button.expand_icon = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(func() -> void: Sound.play("click"))
	button.pressed.connect(action)
	return button
