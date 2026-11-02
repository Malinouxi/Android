class_name CameraController
extends Camera2D
## Caméra pilotée au doigt :
##   - glisser un doigt  -> déplacer la vue ;
##   - pincer deux doigts -> zoomer ;
##   - toucher brièvement -> signal « tapped » (sert à marquer une case).
## Sur ordinateur, la souris imite un doigt (réglage du projet) et la molette zoome.

## Émis lors d'un toucher bref (pas un glissement).
signal tapped(screen_position: Vector2, world_position: Vector2)

const MIN_ZOOM := 0.5
const MAX_ZOOM := 3.0
## Au-delà de cette distance (pixels), un toucher devient un glissement.
const TAP_MAX_DISTANCE := 14.0

## Zone dans laquelle la caméra a le droit de se déplacer.
var bounds := Rect2()

var _touches: Dictionary = {}  # numéro du doigt -> position à l'écran
var _drag_distance := 0.0
var _pinch_start_distance := 0.0
var _pinch_start_zoom := 1.0


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


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			_drag_distance = 0.0
		elif _touches.size() == 2:
			_drag_distance = INF # Deux doigts : ce ne sera pas un « tap ».
			_pinch_start_distance = _pinch_distance()
			_pinch_start_zoom = zoom.x
	else:
		var was_single_finger := _touches.size() == 1
		_touches.erase(event.index)
		if was_single_finger and _drag_distance < TAP_MAX_DISTANCE:
			tapped.emit(event.position, screen_to_world(event.position))


func _on_drag(event: InputEventScreenDrag) -> void:
	_touches[event.index] = event.position
	if _touches.size() == 1:
		_drag_distance += event.relative.length()
		# On divise par le zoom pour que la carte suive exactement le doigt.
		position -= event.relative / zoom
		_clamp_position()
	elif _touches.size() == 2 and _pinch_start_distance > 0.0:
		_set_zoom(_pinch_start_zoom * _pinch_distance() / _pinch_start_distance)


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
