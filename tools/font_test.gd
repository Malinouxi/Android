extends SceneTree
## Compare les polices de l'interface (actuelles / Grenze), côte à côte.
##   godot --path . -s res://tools/font_test.gd
## L'image va dans SCREENSHOT_DIR (ou user://screens).

const SETS := [
	["Actuelles : Cinzel + Alegreya", "res://assets/fonts/Cinzel.ttf", 700, "res://assets/fonts/Alegreya.ttf", 560],
	["Grenze Gotisch + Grenze", "res://assets/fonts/GrenzeGotisch.ttf", 800, "res://assets/fonts/Grenze.ttf", 600],
]

var _out := ""


func _initialize() -> void:
	_out = OS.get_environment("SCREENSHOT_DIR")
	if _out == "":
		_out = OS.get_user_data_dir().path_join("screens")
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _font(path: String, weight: int) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = load(path)
	font.variation_opentype = {"wght": weight}
	return font


func _label(text: String, font: Font, size: int, color: Color, wrap := true) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("shadow_offset_y", 2)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 560
	return label


func _run() -> void:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var back := ColorRect.new()
	back.color = Color(0.1, 0.06, 0.05)
	back.size = Vector2(1280, 720)
	layer.add_child(back)
	var row := HBoxContainer.new()
	row.position = Vector2(16, 16)
	row.size = Vector2(1248, 688)
	row.add_theme_constant_override("separation", 16)
	layer.add_child(row)
	var ui: Node = root.get_node_or_null("Ui")
	for set: Array in SETS:
		var title_font := _font(set[1], set[2])
		var body_font := _font(set[3], set[4])
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if ui != null:
			panel.add_theme_stylebox_override("panel", ui.hd_frame("panel", 18))
		row.add_child(panel)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 10)
		panel.add_child(column)
		column.add_child(_label(set[0], body_font, 16, Color("bcaaa4")))
		column.add_child(_label("Seigneur des Profondeurs", title_font, 44, Color("e53935"), false))
		var button := Button.new()
		button.text = "Continuer — Partie libre, vague 1"
		button.add_theme_font_override("font", body_font)
		button.add_theme_font_size_override("font_size", 26)
		column.add_child(button)
		var counters := HBoxContainer.new()
		counters.add_theme_constant_override("separation", 28)
		counters.add_child(_label("300", body_font, 30, Color("ffd54a"), false))
		counters.add_child(_label("60 / 200", body_font, 28, Color("82b1ff"), false))
		counters.add_child(_label("Cœur 1000 / 1000", body_font, 20, Color.WHITE, false))
		column.add_child(counters)
		column.add_child(_label("Le but du jeu", title_font, 32, Color("ffd54a")))
		column.add_child(_label("Tu es un Seigneur des Profondeurs. Ton cœur est au centre de ton donjon : s'il est détruit, la partie est perdue. Creuse, récolte de l'or, construis des salles pour attirer des créatures, et défends-toi contre les héros.",
				body_font, 24, Color("efe6d8")))
		column.add_child(_label("Vague 1 : 418 s   ·   Paie 88 s : -40 / +25 or   ·   Faim 20 %   Énergie 94 %",
				body_font, 17, Color("d7ccc8")))
		column.add_child(_label("Ça ne me plaît pas... Des intrus ! Qu'ils périssent !", title_font, 26, Color("ffcc80")))
	for i in 20:
		await process_frame
	var path := _out.path_join("polices.png")
	root.get_texture().get_image().save_png(path)
	print("CAPTURE ", path)
	quit()
