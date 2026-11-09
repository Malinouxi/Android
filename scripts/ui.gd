extends Node
## Le style de l'interface (autoload « Ui », voir project.godot).
##
## Un Theme Godot regroupe la police et l'apparence de chaque type de contrôle
## (Button, PanelContainer, Label...). On le pose sur la fenêtre principale :
## tous les écrans du jeu (menus, interface en jeu) l'utilisent automatiquement.
##
## Le thème « Seigneur des Profondeurs » : pierre volcanique, liserés de braise, or.
## Polices (licence libre OFL, voir assets/fonts/) :
##   - Grenze pour les textes : un dessin médiéval, en gras, qui reste lisible ;
##   - Grenze Gotisch pour les titres et les répliques du Seigneur : une gothique
##     « à pointes », très grasse (Black).
## Ce sont des polices « variables » : un seul fichier, toutes les graisses (wght).

const FONT := preload("res://assets/fonts/Grenze.ttf")
const TITLE_FONT := preload("res://assets/fonts/GrenzeGotisch.ttf")
const FONT_WEIGHT := 700        ## Graisse des textes (Bold).
const TITLE_WEIGHT := 900       ## Graisse des titres (Black).
const EMBER := Color("c2410c")   ## Le liseré de braise des cadres.
const BLOOD := Color("8b1a1a")

const TEXT_COLOR := Color("efe6d8")
const GOLD := Color("ffd54a")
const STONE := Color("2b2220")
const STONE_LIGHT := Color("3d2f2b")
const STONE_DARK := Color("140f0e")
const WOOD := Color("7a2e1c")

## Les cadres HD « pierre et braise » (pierre fissurée, liseré rouge, cornes), calculés
## par tools/hud_gothic.py. Les images sont deux fois trop grandes : on les affiche à
## moitié de leur taille, pour qu'elles restent nettes sur un écran de téléphone.
const HD_UI := "res://assets/ui_hd/%s.png"
## Les marges « 9 zones » de chaque cadre, en pixels de l'image (MARGINS de hud_gothic.py).
const HD_MARGINS := {"panel": 64, "slot": 32, "button": 32, "bubble": 32}
## Les cadres dont les bords se RÉPÈTENT (motif de roches périodique) au lieu de s'étirer.
const HD_TILED := ["panel", "slot", "bubble", "button"]

var _hd_textures := {}


func _ready() -> void:
	get_tree().root.theme = build_theme()


func build_theme() -> Theme:
	# Une version un peu plus grasse de la police, plus lisible sur un petit écran.
	var font := FontVariation.new()
	font.base_font = FONT
	font.variation_opentype = {"wght": FONT_WEIGHT}

	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 24

	# Les panneaux : pierre volcanique, liseré de braise (le cadre HD de Blender s'il existe).
	theme.set_stylebox("panel", "PanelContainer", _or(hd_frame("panel", 22),
			_box(Color(0.07, 0.05, 0.05, 0.94), EMBER.darkened(0.3), 3, 10)))

	# Les boutons : des dalles de pierre avec un bord inférieur plus épais (effet de relief).
	theme.set_stylebox("normal", "Button", _or(hd_frame("button_normal", 8), _box(STONE, WOOD, 2, 6, 4, true)))
	theme.set_stylebox("hover", "Button", _or(hd_frame("button_hover", 8),
			_box(STONE_LIGHT, WOOD.lightened(0.2), 2, 6, 4, true)))
	# Enfoncé (ou outil sélectionné) : bordure dorée bien visible.
	theme.set_stylebox("pressed", "Button", _or(hd_frame("button_pressed", 8), _box(WOOD, GOLD, 3, 6, 3)))
	theme.set_stylebox("hover_pressed", "Button", _or(hd_frame("button_pressed", 8),
			_box(WOOD.lightened(0.1), GOLD, 3, 6, 3)))
	theme.set_stylebox("disabled", "Button", _or(hd_frame("button_disabled", 8),
			_box(Color("2a2522"), STONE_DARK, 2, 6, 2)))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", TEXT_COLOR)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", GOLD)
	theme.set_color("font_hover_pressed_color", "Button", GOLD)
	theme.set_color("font_focus_color", "Button", TEXT_COLOR)
	theme.set_color("font_disabled_color", "Button", Color("7a6f66"))
	theme.set_color("icon_disabled_color", "Button", Color(1, 1, 1, 0.35))
	theme.set_constant("h_separation", "Button", 8) # Espace entre l'icône et le texte.
	theme.set_constant("icon_max_width", "Button", 48)

	theme.set_color("font_color", "Label", TEXT_COLOR)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.6))
	theme.set_constant("shadow_offset_y", "Label", 2)
	return theme


## Une boîte de couleur avec bordure et coins arrondis.
## bottom : épaisseur de la bordure du bas (plus épaisse = effet de relief).
## shadow : une petite ombre portée sous la boîte (effet de relief).
## Un cadre HD (voir HD_UI) en « 9 zones » : les coins restent nets, les bords et le
## centre s'étirent. content_margin : l'espace autour du contenu (-1 : les bords du
## cadre). Renvoie null si l'image n'existe pas (on garde alors les cadres dessinés).
func hd_frame(frame_name: String, content_margin := -1.0) -> StyleBoxTexture:
	var texture := hd_texture(frame_name)
	if texture == null:
		return null
	var box := StyleBoxTexture.new()
	box.texture = texture
	var kind := frame_name.get_slice("_", 0)
	box.set_texture_margin_all(HD_MARGINS.get(kind, 16) / 2.0)
	if kind in HD_TILED:
		box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	if content_margin >= 0.0:
		box.set_content_margin_all(content_margin)
	return box


## Une image HD affichée à moitié de sa taille (null si elle n'existe pas).
func hd_texture(image_name: String) -> Texture2D:
	if _hd_textures.has(image_name):
		return _hd_textures[image_name]
	var file := HD_UI % image_name
	var texture: ImageTexture = null
	if ResourceLoader.exists(file):
		var source: Texture2D = load(file)
		texture = ImageTexture.create_from_image(source.get_image())
		texture.set_size_override(source.get_size() / 2)
	_hd_textures[image_name] = texture
	return texture


func _or(preferred: StyleBox, fallback: StyleBox) -> StyleBox:
	return preferred if preferred != null else fallback


## Le style d'un bouton important (bordure dorée), par exemple « Continuer ».
func primary_button_style() -> StyleBox:
	return _or(hd_frame("button_pressed", 8), _box(Color("4e3b2a"), GOLD, 2, 6, 4, true))


func _box(background: Color, border: Color, border_width: int, margin: int, bottom := -1,
		shadow := false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(border_width)
	if bottom >= 0:
		box.border_width_bottom = bottom
	box.set_corner_radius_all(4)
	if shadow:
		box.shadow_color = Color(0, 0, 0, 0.45)
		box.shadow_size = 1
		box.shadow_offset = Vector2(0, 3)
	box.content_margin_left = margin
	box.content_margin_right = margin
	box.content_margin_top = margin * 0.6
	box.content_margin_bottom = margin * 0.6
	return box


## La police des titres (Grenze Gotisch), très grasse.
func title_font() -> FontVariation:
	var font := FontVariation.new()
	font.base_font = TITLE_FONT
	font.variation_opentype = {"wght": TITLE_WEIGHT}
	return font
