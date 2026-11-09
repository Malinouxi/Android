extends Node
## Le son du jeu : effets sonores et musique gothique.
##
## Ce script est un « AUTOLOAD » (voir project.godot, section [autoload]) :
## Godot le crée une seule fois au démarrage et le garde entre les scènes.
## N'importe quel script peut donc écrire :
##     Sound.play("dig", position)   # un son à un endroit de la carte
##     Sound.play("click")           # un son d'interface (sans position)
##     Sound.play_music("combat")    # change de musique (en fondu enchaîné)
##
## Les sons « à un endroit » utilisent AudioStreamPlayer2D : plus ils sont loin
## du centre de l'écran, moins on les entend. Les sons viennent du dossier
## assets/sounds/, générés par tools/generate_sounds.py.
##
## La musique est ADAPTATIVE : un morceau pour le menu, un morceau calme pendant
## qu'on construit, un morceau de combat quand des héros sont dans le donjon,
## et deux courts morceaux de victoire et de défaite. Deux lecteurs jouent à
## tour de rôle : pendant que l'un s'éteint doucement, l'autre monte (fondu
## enchaîné). Les morceaux viennent de assets/music/, composés par
## tools/generate_music.py (orgue, chœur, cordes, cloches, timbales...).

const SETTINGS_PATH := "user://settings.cfg"
## Nombre de sons qui peuvent jouer en même temps.
const WORLD_PLAYERS := 16
const UI_PLAYERS := 4
## Volume de la musique (en décibels : 0 = normal, -10 = nettement moins fort).
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
	"sacrifice": [preload("res://assets/sounds/sacrifice.wav")],
}

## La musique : nom -> morceau.
const MUSIC := {
	"menu": preload("res://assets/music/menu.ogg"),     # Le Trône des Profondeurs
	"calm": preload("res://assets/music/calm.ogg"),     # Les Galeries
	"combat": preload("res://assets/music/combat.ogg"), # L'Assaut
	"victory": preload("res://assets/music/victory.ogg"),
	"defeat": preload("res://assets/music/defeat.ogg"),
}
## Les morceaux qui tournent en boucle (les autres sont joués une fois).
const MUSIC_LOOPS := ["menu", "calm", "combat"]
## Quand un morceau joué une fois se termine, on enchaîne sur celui-ci.
const MUSIC_AFTER := {"victory": "menu", "defeat": "menu"}
## Durée du fondu (en secondes) pour arriver sur un morceau.
const MUSIC_FADE := {"combat": 1.5, "victory": 0.3, "defeat": 0.3}
const DEFAULT_MUSIC_FADE := 3.0
## La voix du Seigneur (voir LordPortrait.say) : volume, et musique baissée pendant qu'il parle.
const VOICE_VOLUME_DB := 2.0
const MUSIC_DUCK := 0.5

## Délai minimum (millisecondes) entre deux fois le même son : sans ça, dix
## ouvriers qui creusent ensemble feraient un vacarme.
const MIN_INTERVAL_MS := {
	"dig": 70, "punch": 60, "sword": 60, "zap": 80, "claim": 150, "gold": 80,
	"heart_hit": 400, "door_hit": 120, "spikes": 80,
}
const DEFAULT_INTERVAL_MS := 40

var music_enabled := true
var sfx_enabled := true
## Réglage graphique (rangé ici avec les autres réglages) : éclairage dynamique.
var lighting_enabled := true
## Vue 3D (sinon : la vue isométrique 2D d'origine).
var view_3d_enabled := true
## Du sang au sol et sur les murs pendant les combats.
var blood_enabled := true
## Transformation carte -> écran (vue isométrique) pour placer les sons ; main.gd la règle.
var world_transform := Transform2D.IDENTITY

var _world_players: Array[AudioStreamPlayer2D] = []
var _ui_players: Array[AudioStreamPlayer] = []
## Les deux lecteurs de musique (pour les fondus enchaînés).
var _music_players: Array[AudioStreamPlayer] = []
var _music_active := 0
## Le morceau demandé (même si la musique est coupée dans les réglages).
var _music_name := ""
## Fondus en cours : lecteur -> {from, to, start, duration} (volumes de 0 à 1, temps en ms).
var _music_fades := {}
## Volume de chaque lecteur de musique (0 à 1), avant la baisse pendant la voix.
var _music_levels := {}
var _music_duck := 1.0
var _last_tick := 0

## La voix du Seigneur passe par son propre bus, avec un analyseur de spectre :
## le portrait s'en sert pour ouvrir la mâchoire en rythme.
var _voice: AudioStreamPlayer
var _voice_spectrum: AudioEffectSpectrumAnalyzerInstance
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

	for track: String in MUSIC:
		var stream: AudioStreamOggVorbis = MUSIC[track]
		stream.loop = track in MUSIC_LOOPS
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.finished.connect(_on_music_finished.bind(player))
		add_child(player)
		_music_players.append(player)

	var bus := AudioServer.bus_count
	AudioServer.add_bus(bus)
	AudioServer.set_bus_name(bus, "Voice")
	AudioServer.set_bus_send(bus, "Master")
	AudioServer.add_bus_effect(bus, AudioEffectSpectrumAnalyzer.new())
	_voice_spectrum = AudioServer.get_bus_effect_instance(bus, 0) as AudioEffectSpectrumAnalyzerInstance
	_voice = AudioStreamPlayer.new()
	_voice.bus = "Voice"
	_voice.volume_db = VOICE_VOLUME_DB
	add_child(_voice)

	_load_settings()


## Les fondus de la musique avancent en temps réel (même en pause ou en accéléré).
func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var real_delta := (now - _last_tick) / 1000.0 if _last_tick > 0 else 0.0
	_last_tick = now
	# Pendant que le Seigneur parle, la musique se fait plus discrète.
	var duck := MUSIC_DUCK if _voice.playing else 1.0
	if not is_equal_approx(_music_duck, duck):
		_music_duck = move_toward(_music_duck, duck, real_delta * 2.5)
		for player in _music_players:
			_set_music_level(player, _music_levels.get(player, 0.0))
	for player: AudioStreamPlayer in _music_fades.keys():
		var fade: Dictionary = _music_fades[player]
		var progress := clampf(float(now - fade["start"]) / fade["duration"], 0.0, 1.0)
		_set_music_level(player, lerpf(fade["from"], fade["to"], progress))
		if progress >= 1.0:
			_music_fades.erase(player)
			if fade["to"] <= 0.0:
				player.stop()


## Change de musique, en fondu enchaîné. Ne fait rien si ce morceau joue déjà.
func play_music(track: String) -> void:
	if not MUSIC.has(track):
		push_warning("Musique inconnue : " + track)
		return
	if track == _music_name:
		return
	_music_name = track
	if music_enabled:
		_start_music(track)


func _start_music(track: String) -> void:
	var fade_time: float = MUSIC_FADE.get(track, DEFAULT_MUSIC_FADE)
	var old := _music_players[_music_active]
	if old.playing:
		_fade_music(old, 0.0, maxf(fade_time, 1.0))
	_music_active = 1 - _music_active
	var player := _music_players[_music_active]
	player.stream = MUSIC[track]
	_set_music_level(player, 0.0)
	player.play()
	_fade_music(player, 1.0, fade_time)


func _fade_music(player: AudioStreamPlayer, to: float, seconds: float) -> void:
	_music_fades[player] = {
		"from": _music_levels.get(player, 0.0),
		"to": to, "start": Time.get_ticks_msec(), "duration": maxf(seconds * 1000.0, 1.0),
	}


## level : 0 = muet, 1 = volume normal de la musique.
func _set_music_level(player: AudioStreamPlayer, level: float) -> void:
	_music_levels[player] = level
	player.volume_db = linear_to_db(maxf(level * _music_duck, 0.0001) * db_to_linear(MUSIC_VOLUME_DB))


## Le Seigneur dit une réplique (coupe la précédente). Rend sa durée en secondes
## (0 si rien n'est joué : effets sonores coupés, ou pas de voix pour ce texte).
func play_voice(stream: AudioStream) -> float:
	if stream == null or not sfx_enabled:
		return 0.0
	_voice.stream = stream
	_voice.play()
	return stream.get_length()


## Le volume de la voix en ce moment, de 0 (silence) à 1 (il crie).
func voice_level() -> float:
	if not _voice.playing:
		return 0.0
	var magnitude := _voice_spectrum.get_magnitude_for_frequency_range(60.0, 1500.0).length()
	return clampf((linear_to_db(magnitude) + 48.0) / 36.0, 0.0, 1.0)


## Un morceau joué une seule fois (victoire, défaite) est fini : on enchaîne.
func _on_music_finished(player: AudioStreamPlayer) -> void:
	if player == _music_players[_music_active] and MUSIC_AFTER.has(_music_name):
		play_music(MUSIC_AFTER[_music_name])


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
		var map_position: Vector2 = world_position
		player.global_position = world_transform * map_position
		player.stream = stream
		player.volume_db = volume_db
		player.pitch_scale = pitch
		player.play()


func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	if enabled and _music_name != "" and not _music_players[_music_active].playing:
		_start_music(_music_name)
	elif not enabled:
		_music_fades.clear()
		for player in _music_players:
			player.stop()
	_save_settings()


func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled
	if not enabled:
		for player in _world_players:
			player.stop()
		for player in _ui_players:
			player.stop()
		_voice.stop()
	_save_settings()


## Deux boutons « Musique : oui/non » et « Effets sonores : oui/non », pour les menus.
func make_settings_buttons() -> Array[Button]:
	return [
		_make_toggle("Musique", func() -> bool: return music_enabled, set_music_enabled),
		_make_toggle("Effets sonores", func() -> bool: return sfx_enabled, set_sfx_enabled),
		_make_toggle("Éclairage", func() -> bool: return lighting_enabled, set_lighting_enabled),
		_make_toggle("Vue 3D", func() -> bool: return view_3d_enabled, set_view_3d_enabled),
		_make_toggle("Sang", func() -> bool: return blood_enabled, set_blood_enabled),
	]


func set_view_3d_enabled(enabled: bool) -> void:
	view_3d_enabled = enabled
	_save_settings()


func set_blood_enabled(enabled: bool) -> void:
	blood_enabled = enabled
	_save_settings()


func set_lighting_enabled(enabled: bool) -> void:
	lighting_enabled = enabled
	_save_settings()


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
		lighting_enabled = config.get_value("graphics", "lighting", true)
		view_3d_enabled = config.get_value("graphics", "view_3d", true)
		blood_enabled = config.get_value("graphics", "blood", true)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music", music_enabled)
	config.set_value("audio", "sfx", sfx_enabled)
	config.set_value("graphics", "lighting", lighting_enabled)
	config.set_value("graphics", "view_3d", view_3d_enabled)
	config.set_value("graphics", "blood", blood_enabled)
	config.save(SETTINGS_PATH)
