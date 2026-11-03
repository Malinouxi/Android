extends Node
## Le son du jeu : effets sonores et ambiance musicale.
##
## Ce script est un « AUTOLOAD » (voir project.godot, section [autoload]) :
## Godot le crée une seule fois au démarrage et le garde entre les scènes.
## N'importe quel script peut donc écrire :
##     Sound.play("dig", position)   # un son à un endroit de la carte
##     Sound.play("click")           # un son d'interface (sans position)
##
## Les sons « à un endroit » utilisent AudioStreamPlayer2D : plus ils sont loin
## du centre de l'écran, moins on les entend. Les sons viennent du dossier
## assets/sounds/, générés par tools/generate_sounds.py.

const SETTINGS_PATH := "user://settings.cfg"
## Nombre de sons qui peuvent jouer en même temps.
const WORLD_PLAYERS := 16
const UI_PLAYERS := 4
## Volume de l'ambiance (en décibels : 0 = normal, -10 = nettement moins fort).
const MUSIC_VOLUME_DB := -6.0

## Tous les sons : nom -> liste de variantes (une est choisie au hasard).
const SOUNDS := {
	"dig": [preload("res://assets/sounds/dig_0.wav"), preload("res://assets/sounds/dig_1.wav"),
			preload("res://assets/sounds/dig_2.wav")],
	"gold": [preload("res://assets/sounds/gold.wav")],
	"coins": [preload("res://assets/sounds/coins.wav")],
	"claim": [preload("res://assets/sounds/claim.wav")],
	"build": [preload("res://assets/sounds/build.wav")],
	"trap_place": [preload("res://assets/sounds/trap_place.wav")],
	"portal": [preload("res://assets/sounds/portal.wav")],
	"leave": [preload("res://assets/sounds/leave.wav")],
	"level_up": [preload("res://assets/sounds/level_up.wav")],
	"punch": [preload("res://assets/sounds/punch_0.wav"), preload("res://assets/sounds/punch_1.wav")],
	"sword": [preload("res://assets/sounds/sword_0.wav"), preload("res://assets/sounds/sword_1.wav")],
	"zap": [preload("res://assets/sounds/zap.wav")],
	"death": [preload("res://assets/sounds/death.wav")],
	"spikes": [preload("res://assets/sounds/spikes.wav")],
	"explosion": [preload("res://assets/sounds/explosion.wav")],
	"door_hit": [preload("res://assets/sounds/door_hit.wav")],
	"door_break": [preload("res://assets/sounds/door_break.wav")],
	"heart_hit": [preload("res://assets/sounds/heart_hit.wav")],
	"horn": [preload("res://assets/sounds/horn.wav")],
	"discovery": [preload("res://assets/sounds/discovery.wav")],
	"heal": [preload("res://assets/sounds/heal.wav")],
	"lightning": [preload("res://assets/sounds/lightning.wav")],
	"haste": [preload("res://assets/sounds/haste.wav")],
	"error": [preload("res://assets/sounds/error.wav")],
	"pickup": [preload("res://assets/sounds/pickup.wav")],
	"drop": [preload("res://assets/sounds/drop.wav")],
	"click": [preload("res://assets/sounds/click.wav")],
	"game_over": [preload("res://assets/sounds/game_over.wav")],
	"arrow": [preload("res://assets/sounds/arrow.wav")],
	"capture": [preload("res://assets/sounds/capture.wav")],
}
const AMBIENCE := preload("res://assets/sounds/ambience.wav")

## Délai minimum (millisecondes) entre deux fois le même son : sans ça, dix
## ouvriers qui creusent ensemble feraient un vacarme.
const MIN_INTERVAL_MS := {
	"dig": 70, "punch": 60, "sword": 60, "zap": 80, "claim": 150, "gold": 80,
	"heart_hit": 400, "door_hit": 120, "spikes": 80,
}
const DEFAULT_INTERVAL_MS := 40

var music_enabled := true
var sfx_enabled := true

var _world_players: Array[AudioStreamPlayer2D] = []
var _ui_players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _next_world := 0
var _next_ui := 0
var _last_played := {}


func _ready() -> void:
	# Le son continue pendant la pause (clics du menu de pause...).
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in WORLD_PLAYERS:
		var player := AudioStreamPlayer2D.new()
		player.max_distance = 1100.0 # Au-delà (en pixels), on n'entend plus rien.
		player.attenuation = 1.5
		add_child(player)
		_world_players.append(player)
	for i in UI_PLAYERS:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_ui_players.append(player)

	_music = AudioStreamPlayer.new()
	_music.stream = AMBIENCE
	_music.volume_db = MUSIC_VOLUME_DB
	_music.finished.connect(_music.play) # Quand l'ambiance se termine, on la relance.
	add_child(_music)

	_load_settings()
	if music_enabled:
		_music.play()


## Joue un son. Sans position, c'est un son d'interface (même volume partout).
## volume_db : 0 = normal, négatif = moins fort. Le ton varie un peu à chaque
## fois (pitch) pour que les sons répétés ne soient pas lassants.
func play(sound_name: String, world_position: Variant = null, volume_db := 0.0) -> void:
	if not sfx_enabled:
		return
	if not SOUNDS.has(sound_name):
		push_warning("Son inconnu : " + sound_name)
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sound_name, -100000)) < MIN_INTERVAL_MS.get(sound_name, DEFAULT_INTERVAL_MS):
		return
	_last_played[sound_name] = now

	var stream: AudioStream = SOUNDS[sound_name].pick_random()
	var pitch := randf_range(0.93, 1.07)
	if world_position == null:
		var player := _ui_players[_next_ui]
		_next_ui = (_next_ui + 1) % _ui_players.size()
		player.stream = stream
		player.volume_db = volume_db
		player.pitch_scale = pitch
		player.play()
	else:
		var player := _world_players[_next_world]
		_next_world = (_next_world + 1) % _world_players.size()
		player.global_position = world_position
		player.stream = stream
		player.volume_db = volume_db
		player.pitch_scale = pitch
		player.play()


func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	if enabled and not _music.playing:
		_music.play()
	elif not enabled:
		_music.stop()
	_save_settings()


func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled
	if not enabled:
		for player in _world_players:
			player.stop()
		for player in _ui_players:
			player.stop()
	_save_settings()


## Baisse ou remonte l'ambiance (par exemple à la défaite).
func set_music_volume(volume_db: float) -> void:
	_music.volume_db = volume_db


func reset_music_volume() -> void:
	_music.volume_db = MUSIC_VOLUME_DB


## Deux boutons « Musique : oui/non » et « Effets sonores : oui/non », pour les menus.
func make_settings_buttons() -> Array[Button]:
	return [
		_make_toggle("Musique", func() -> bool: return music_enabled, set_music_enabled),
		_make_toggle("Effets sonores", func() -> bool: return sfx_enabled, set_sfx_enabled),
	]


func _make_toggle(label: String, is_on: Callable, set_on: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(320, 60)
	button.add_theme_font_size_override("font_size", 24)
	var refresh := func() -> void:
		button.text = "%s : %s" % [label, "oui" if is_on.call() else "non"]
	refresh.call()
	button.pressed.connect(func() -> void:
		set_on.call(not is_on.call())
		play("click")
		refresh.call())
	return button


# Les réglages sont rangés dans un petit fichier (ConfigFile : format « .ini »).
func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		music_enabled = config.get_value("audio", "music", true)
		sfx_enabled = config.get_value("audio", "sfx", true)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music", music_enabled)
	config.set_value("audio", "sfx", sfx_enabled)
	config.save(SETTINGS_PATH)
