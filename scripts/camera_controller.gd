class_name CameraController
extends Camera2D
## Caméra et gestes tactiles. Deux façons de fonctionner :
##
## Mode normal (main, sorts, pièges) :
##   - glisser un doigt  -> déplacer la vue ;
##   - pincer deux doigts -> zoomer ;
##   - toucher brièvement -> signal « tapped ».
##
## Mode PEINTURE (creuser, construire, démolir ; main.gd l'active selon l'outil) :
##   - glisser un doigt  -> « peint » toutes les cases survolées (signaux paint_*) ;
##   - glisser deux doigts -> déplacer la vue (et pincer pour zoomer).
##
## Sur ordinateur : la souris imite un doigt, la molette zoome, et le clic DROIT
## (ou la molette enfoncée) maintenu permet de déplacer la vue.

## Émis lors d'un toucher bref (mode normal).
signal tapped(screen_position: Vector2, world_position: Vector2)
## Mode peinture : le doigt se pose, glisse, puis se lève.
signal paint_started(screen_position: Vector2, world_position: Vector2)
signal painted(world_position: Vector2)
signal paint_ended

const MIN_ZOOM := 0.5
const MAX_ZOOM := 3.0
## Au-delà de cette distance (pixels), un toucher devient un glissement.
const TAP_MAX_DISTANCE := 14.0

## Zone dans laquelle la caméra a le droit de se déplacer.
var bounds := Rect2()
## Mode peinture activé ou non (voir plus haut).
var paint_mode := false
## La transformation de la carte vers l'écran (la vue isométrique, voir iso.gd).
var world_transform := Transform2D.IDENTITY

var _shake_strength := 0.0
var _shake_time := 0.0

var _touches: Dictionary = {}  # numéro du doigt -> position à l'écran
var _drag_distance := 0.0
var _pinch_start_distance := 0.0
var _pinch_start_zoom := 1.0
var _painting := false


## _unhandled_input reçoit seulement les événements que l'interface (boutons...)
## n'a pas déjà utilisés.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(zoom.x * 1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(zoom.x / 1.1)
	elif event is InputEventMouseMotion:
		# Clic droit ou molette enfoncés : on déplace la vue (pratique sur PC).
		if event.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE):
			move_by(event.relative)


## Déplace la vue comme si on faisait glisser la carte de `screen_relative` pixels.
func move_by(screen_relative: Vector2) -> void:
	# On divise par le zoom pour que la carte suive exactement le doigt.
	position -= screen_relative / zoom
	_clamp_position()


## Centre la vue sur un point de la carte (utilisé par la mini-carte).
func center_on(map_position: Vector2) -> void:
	position = world_transform * map_position
	_clamp_position()


## Tremblement d'écran : on décale la vue au hasard pendant un court instant.
func shake(strength: float, duration: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)
	_shake_time = maxf(_shake_time, duration)


func _process(delta: float) -> void:
	if _shake_time > 0.0:
		_shake_time -= delta
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_strength
		if _shake_time <= 0.0:
			_shake_strength = 0.0
			offset = Vector2.ZERO


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			_drag_distance = 0.0
			if paint_mode:
				_painting = true
				paint_started.emit(event.position, screen_to_world(event.position))
		elif _touches.size() == 2:
			_stop_painting() # Deuxième doigt : on passe en déplacement / zoom.
			_drag_distance = INF # Deux doigts : ce ne sera pas un « tap ».
			_pinch_start_distance = _pinch_distance()
			_pinch_start_zoom = zoom.x
	else:
		var was_single_finger := _touches.size() == 1
		_touches.erase(event.index)
		if _painting:
			_stop_painting()
		elif was_single_finger and not paint_mode and _drag_distance < TAP_MAX_DISTANCE:
			tapped.emit(event.position, screen_to_world(event.position))


func _on_drag(event: InputEventScreenDrag) -> void:
	_touches[event.index] = event.position
	if _touches.size() == 1:
		_drag_distance += event.relative.length()
		if _painting:
			painted.emit(screen_to_world(event.position))
		else:
			move_by(event.relative)
	elif _touches.size() == 2:
		# Chaque doigt envoie son propre glissement : on fait la moyenne des deux.
		move_by(event.relative / 2.0)
		if _pinch_start_distance > 0.0:
			_set_zoom(_pinch_start_zoom * _pinch_distance() / _pinch_start_distance)


func _stop_painting() -> void:
	if _painting:
		_painting = false
		paint_ended.emit()


func screen_to_world(screen_position: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_position


func _pinch_distance() -> float:
	var points := _touches.values()
	return points[0].distance_to(points[1])


func _set_zoom(value: float) -> void:
	value = clampf(value, MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2(value, value)


func _clamp_position() -> void:
	if bounds.has_area():
		position = position.clamp(bounds.position, bounds.end)
