class_name Fx
## Les effets visuels : particules, chiffres de dégâts, tremblement d'écran,
## éclairs de lumière. Tout est en fonctions « static » : n'importe quel script
## peut écrire Fx.burst("dust", position) sans rien préparer.
##
## main.gd remplit les trois variables ci-dessous au démarrage d'une partie.
## Dans le menu, elles sont vides : les effets ne font alors simplement rien.

## Le conteneur des particules et des chiffres (dans l'espace de l'écran, pas incliné).
static var layer: Node2D
## Le nœud « World » incliné (voir iso.gd) : sert à placer les effets au bon endroit.
static var world: Node2D
static var camera: CameraController
## Texture ronde et floue, partagée par toutes les lumières.
static var light_texture: Texture2D
## La vue 3D, si le jeu est en 3D (sinon null) : elle place les effets à l'écran.
static var view3d = null

## Réglages de chaque type de particules : couleur, nombre, vitesse, gravité, durée, taille.
const BURSTS := {
	"dust": {"color": Color("8d6e4a"), "amount": 10, "speed": 60.0, "gravity": 180.0, "life": 0.5, "size": 3.0},
	"coins": {"color": Color("ffd54a"), "amount": 8, "speed": 90.0, "gravity": 260.0, "life": 0.6, "size": 3.0},
	"sparks": {"color": Color("fff3c4"), "amount": 6, "speed": 110.0, "gravity": 120.0, "life": 0.25, "size": 2.0},
	"smoke": {"color": Color(0.35, 0.33, 0.35, 0.8), "amount": 22, "speed": 70.0, "gravity": -40.0, "life": 1.0, "size": 6.0},
	"claim": {"color": Color("ff4d6a"), "amount": 10, "speed": 40.0, "gravity": -60.0, "life": 0.7, "size": 2.0},
	"magic": {"color": Color("b388ff"), "amount": 16, "speed": 80.0, "gravity": -30.0, "life": 0.7, "size": 3.0},
	"heal": {"color": Color("69f0ae"), "amount": 14, "speed": 35.0, "gravity": -110.0, "life": 0.9, "size": 3.0},
	"haste": {"color": Color("80deea"), "amount": 18, "speed": 140.0, "gravity": 0.0, "life": 0.35, "size": 2.0},
}


static func is_ready() -> bool:
	return layer != null and is_instance_valid(layer) and world != null and is_instance_valid(world)


## Position à l'écran d'un point de la carte.
static func to_screen(map_position: Vector2) -> Vector2:
	if view3d != null and is_instance_valid(view3d):
		return view3d.unproject(map_position, 0.4)
	return world.to_global(map_position)


## Une gerbe de particules. color remplace la couleur par défaut si on la donne.
static func burst(kind: String, map_position: Vector2, color := Color(0, 0, 0, 0)) -> void:
	if not is_ready() or not BURSTS.has(kind):
		return
	var settings: Dictionary = BURSTS[kind]
	var particles := CPUParticles2D.new()
	particles.position = to_screen(map_position)
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = settings["amount"]
	particles.lifetime = settings["life"]
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = settings["speed"] * 0.5
	particles.initial_velocity_max = settings["speed"]
	particles.gravity = Vector2(0, settings["gravity"])
	particles.scale_amount_min = settings["size"] * 0.6
	particles.scale_amount_max = settings["size"]
	particles.color = color if color.a > 0.0 else settings["color"]
	# Les particules s'effacent en fin de vie.
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	particles.color_ramp = fade
	layer.add_child(particles)
	particles.emitting = true
	layer.get_tree().create_timer(settings["life"] + 0.3).timeout.connect(particles.queue_free)


## Un nombre qui s'envole et s'efface (dégâts, soins, or...).
static func number(map_position: Vector2, value: float, color := Color.WHITE) -> void:
	if not is_ready() or value < 1.0:
		return
	var label := Label.new()
	label.text = str(roundi(value))
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	label.position = to_screen(map_position) + Vector2(randf_range(-10, 0), -40)
	layer.add_child(label)
	var tween := label.create_tween()
	tween.set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 28.0, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)


## Un personnage qui meurt : sa dernière image bascule sur le côté, tombe et s'efface.
static func death_fall(map_position: Vector2, texture: Texture2D, sprite_scale: float, facing_left: bool,
		tint: Color) -> void:
	if not is_ready() or texture == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.offset = Vector2(0, -12) # On pivote autour des pieds.
	sprite.scale = Vector2(-1.0 if facing_left else 1.0, 1.0) * sprite_scale
	sprite.position = to_screen(map_position) + Vector2(0, 2)
	sprite.modulate = tint
	layer.add_child(sprite)
	var tween := sprite.create_tween()
	tween.set_parallel()
	tween.tween_property(sprite, "rotation", PI / 2 * (-1.0 if facing_left else 1.0), 0.35) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "position:y", sprite.position.y + 6.0, 0.35)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.6).set_delay(0.5)
	tween.chain().tween_callback(sprite.queue_free)


## Un éclair qui tombe du ciel sur un point de la carte : une ligne brisée au
## hasard (deux couches : un halo bleu et un cœur blanc), qui s'efface très vite.
static func lightning(map_position: Vector2) -> void:
	if not is_ready():
		return
	var target := to_screen(map_position) + Vector2(0, -10)
	var points := PackedVector2Array()
	var steps := 7
	for i in steps + 1:
		var t := float(i) / steps
		var wobble := 0.0 if i == 0 or i == steps else randf_range(-16.0, 16.0)
		points.append(target + Vector2(wobble + (1.0 - t) * 30.0, -260.0 * (1.0 - t)))
	for layer_settings in [[9.0, Color(0.55, 0.8, 1.0, 0.6)], [3.0, Color(1, 1, 1, 1)]]:
		var line := Line2D.new()
		line.points = points
		line.width = layer_settings[0]
		line.default_color = layer_settings[1]
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		layer.add_child(line)
		var tween := line.create_tween()
		tween.tween_property(line, "modulate:a", 0.0, 0.35).set_delay(0.08)
		tween.tween_callback(line.queue_free)
	burst("sparks", map_position, Color("b3e5fc"))


## Fait trembler l'écran (strength en pixels).
static func shake(strength: float, duration := 0.25) -> void:
	if camera != null and is_instance_valid(camera):
		camera.shake(strength, duration)


## Un éclair de lumière bref (explosion, sort), si l'éclairage est activé.
static func flash_light(map_position: Vector2, color: Color, radius := 120.0, duration := 0.35) -> void:
	if view3d != null and is_instance_valid(view3d):
		view3d.flash(map_position, color, radius, duration)
		return
	if not is_ready() or light_texture == null or not Sound.lighting_enabled:
		return
	var light := PointLight2D.new()
	light.texture = light_texture
	light.texture_scale = radius / 128.0
	light.color = color
	light.energy = 1.6
	light.position = map_position
	world.add_child(light)
	var tween := light.create_tween()
	tween.tween_property(light, "energy", 0.0, duration)
	tween.tween_callback(light.queue_free)


## Crée (une seule fois) la texture des lumières : un disque blanc qui s'estompe vers le bord.
static func make_light_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	return texture
