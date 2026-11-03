class_name Minimap
extends Control
## La mini-carte, en bas à gauche : toute la carte en petit (3 pixels par case),
## tes unités en vert, les ennemis en rouge, et un cadre blanc pour la zone
## visible à l'écran. Toucher (ou glisser sur) la mini-carte déplace la vue.
##
## L'image de la carte est une Image de 48 x 32 pixels (un pixel par case),
## recalculée deux fois par seconde puis affichée agrandie.

const CELL := 3 ## Taille d'une case sur la mini-carte, en pixels.
const COLORS := {
	DungeonMap.Tile.EARTH: Color("6b4a2f"),
	DungeonMap.Tile.GOLD: Color("d4a82a"),
	DungeonMap.Tile.ROCK: Color("2e2e34"),
	DungeonMap.Tile.FLOOR: Color("4a423b"),
	DungeonMap.Tile.HEART: Color("ff3030"),
	DungeonMap.Tile.PORTAL: Color("b040ff"),
	DungeonMap.Tile.ENTRANCE: Color("cfd8dc"),
	DungeonMap.Tile.RIVAL_HEART: Color("40a0ff"),
}
const CLAIMED_COLOR := Color("8a3442")

var map: DungeonMap
var camera: CameraController
var _image: Image
var _texture: ImageTexture
var _refresh_timer := 0.0


func setup(dungeon_map: DungeonMap, game_camera: CameraController) -> void:
	map = dungeon_map
	camera = game_camera
	custom_minimum_size = Vector2(DungeonMap.WIDTH, DungeonMap.HEIGHT) * CELL
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_image = Image.create(DungeonMap.WIDTH, DungeonMap.HEIGHT, false, Image.FORMAT_RGBA8)
	_texture = ImageTexture.create_from_image(_image)
	_refresh_image()


func _process(delta: float) -> void:
	if map == null:
		return
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.5
		_refresh_image()
	queue_redraw() # Les unités et le cadre bougent : on redessine à chaque image.


func _refresh_image() -> void:
	for y in DungeonMap.HEIGHT:
		for x in DungeonMap.WIDTH:
			var cell := Vector2i(x, y)
			var tile := map.get_tile(cell)
			var color: Color = COLORS.get(tile, Color.BLACK)
			if tile == DungeonMap.Tile.FLOOR:
				if map.rooms.has(cell):
					color = Rooms.color(map.rooms[cell]).lightened(0.25)
				elif map.is_claimed(cell):
					color = CLAIMED_COLOR
				elif map.rival_claimed.has(cell):
					color = Color("2a4a8a")
			_image.set_pixel(x, y, color)
	_texture.update(_image)


func _draw() -> void:
	if map == null:
		return
	var area := Rect2(Vector2.ZERO, size)
	draw_rect(area.grow(3), Color(0, 0, 0, 0.75))
	draw_texture_rect(_texture, area, false)

	var scale_factor := float(CELL) / DungeonMap.TILE_SIZE
	for node in get_tree().get_nodes_in_group("dungeon"):
		draw_rect(Rect2((node as Node2D).position * scale_factor - Vector2.ONE, Vector2(2, 2)), Color("76ff03"))
	for node in get_tree().get_nodes_in_group("heroes"):
		draw_rect(Rect2((node as Node2D).position * scale_factor - Vector2.ONE, Vector2(3, 3)), Color("ff1744"))

	# Le cadre de ce qui est visible à l'écran. En vue isométrique, l'écran
	# (un rectangle) correspond à un losange sur la carte vue de dessus.
	var half := get_viewport_rect().size / camera.zoom / 2
	var to_map := camera.world_transform.affine_inverse()
	var outline := PackedVector2Array()
	for corner in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y),
			Vector2(-half.x, half.y), Vector2(-half.x, -half.y)]:
		var map_point: Vector2 = to_map * (camera.position + corner)
		outline.append((map_point * scale_factor).clamp(Vector2.ZERO, size))
	draw_polyline(outline, Color.WHITE, 1.0)


func _gui_input(event: InputEvent) -> void:
	# « : bool » obligatoire : Godot ne peut pas deviner le type de event.pressed
	# (event est un InputEvent général), donc on le lui indique.
	var touched: bool = (event is InputEventScreenTouch and event.pressed) or event is InputEventScreenDrag \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if touched and camera != null:
		camera.center_on(event.position / CELL * DungeonMap.TILE_SIZE)
		accept_event()
