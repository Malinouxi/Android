extends Node
## Le style de l'interface (autoload « Ui », voir project.godot).
##
## Un Theme Godot regroupe la police et l'apparence de chaque type de contrôle
## (Button, PanelContainer, Label...). On le pose sur la fenêtre principale :
## tous les écrans du jeu (menus, interface en jeu) l'utilisent automatiquement.
##
## La police est « Pixelify Sans » (licence libre OFL, voir assets/fonts/OFL.txt).

const FONT := preload("res://assets/fonts/PixelifySans-Regular.ttf")

const TEXT_COLOR := Color("efe6d8")
const GOLD := Color("ffd54a")
const STONE := Color("3e3530")
const STONE_LIGHT := Color("54483f")
const STONE_DARK := Color("1d1916")
const WOOD := Color("6d4c41")


func _ready() -> void:
	get_tree().root.theme = build_theme()


func build_theme() -> Theme:
	# Police nette, sans lissage : elle reste « pixel » comme les images du jeu.
	FONT.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	FONT.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED

	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 18

	# Les panneaux : fond sombre, bordure de bois.
	theme.set_stylebox("panel", "PanelContainer", _box(Color(0.11, 0.09, 0.08, 0.92), WOOD, 2, 8))

	# Les boutons : des dalles de pierre avec un bord inférieur plus épais (effet de relief).
	theme.set_stylebox("normal", "Button", _box(STONE, STONE_DARK, 2, 6, 5))
	theme.set_stylebox("hover", "Button", _box(STONE_LIGHT, STONE_DARK, 2, 6, 5))
	# Enfoncé (ou outil sélectionné) : bordure dorée bien visible.
	theme.set_stylebox("pressed", "Button", _box(WOOD, GOLD, 3, 6, 3))
	theme.set_stylebox("hover_pressed", "Button", _box(WOOD.lightened(0.1), GOLD, 3, 6, 3))
	theme.set_stylebox("disabled", "Button", _box(Color("2a2522"), STONE_DARK, 2, 6, 2))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", TEXT_COLOR)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", GOLD)
	theme.set_color("font_hover_pressed_color", "Button", GOLD)
	theme.set_color("font_focus_color", "Button", TEXT_COLOR)
	theme.set_color("font_disabled_color", "Button", Color("7a6f66"))
	theme.set_color("icon_disabled_color", "Button", Color(1, 1, 1, 0.35))
	theme.set_constant("h_separation", "Button", 8) # Espace entre l'icône et le texte.
	theme.set_constant("icon_max_width", "Button", 34)

	theme.set_color("font_color", "Label", TEXT_COLOR)
	return theme


## Une boîte de couleur avec bordure et coins arrondis.
## bottom : épaisseur de la bordure du bas (plus épaisse = effet de relief).
func _box(background: Color, border: Color, border_width: int, margin: int, bottom := -1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(border_width)
	if bottom >= 0:
		box.border_width_bottom = bottom
	box.set_corner_radius_all(4)
	box.content_margin_left = margin
	box.content_margin_right = margin
	box.content_margin_top = margin * 0.6
	box.content_margin_bottom = margin * 0.6
	return box
