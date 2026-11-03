class_name Unit
extends Node2D
## Base commune à tout ce qui marche dans le donjon : ouvriers, créatures, héros.
##
## C'est de l'HÉRITAGE : worker.gd, creature.gd et hero.gd commencent par
## « extends Unit ». Ils reçoivent donc automatiquement tout ce qui est écrit
## ici (suivre un chemin, points de vie, attaquer...) sans le recopier.

## Émis quand l'unité meurt, juste avant de disparaître.
signal died(unit: Unit)

## Dans quel camp est l'unité.
enum Team { DUNGEON, HEROES }

var map: DungeonMap
var team: Team = Team.DUNGEON
## Vitesse de marche, en pixels par seconde.
var speed := 90.0
## Cases qu'il reste à parcourir.
var path: Array[Vector2i] = []

## Combat.
var max_hp := 50.0
var hp := 50.0
var attack_damage := 0.0
var attack_range := 26.0     ## Distance d'attaque, en pixels (une case = 32).
var attack_interval := 1.0   ## Secondes entre deux coups.

## Vrai pendant que le joueur tient l'unité dans sa « main ».
var in_hand := false

var _attack_cooldown := 0.0
var _chase_cell := Vector2i(-1, -1)
var _strike_timer := 0.0
var _strike_offset := Vector2.ZERO
## Regarde vers la gauche (l'image est alors retournée en miroir).
var _facing_left := false
## Secondes de « Hâte » restantes (sort du maître) : l'unité court plus vite.
var _haste_left := 0.0
const HASTE_SPEED_FACTOR := 1.8


## Quand l'unité entre dans la scène, on la range dans un « groupe » selon son camp.
## Ainsi chacun peut retrouver ses ennemis avec get_nodes_in_group().
func _ready() -> void:
	add_to_group(_group_name(team))


## À appeler juste après la création de l'unité.
func setup(dungeon_map: DungeonMap, cell: Vector2i) -> void:
	map = dungeon_map
	position = map.cell_to_world(cell)


## Nom affiché dans les messages. Chaque classe fille le remplace par le sien.
func display_name() -> String:
	return "Unité"


func current_cell() -> Vector2i:
	return map.world_to_cell(position)


# ---------------------------------------------------------------------------
# Déplacement
# ---------------------------------------------------------------------------

## Suit un chemin déjà calculé (par exemple par map.find_dig_job).
func follow_path(new_path: Array[Vector2i]) -> void:
	path.assign(new_path) # Copie du chemin.
	if not path.is_empty():
		path.remove_at(0) # La première case est celle où l'on se trouve déjà.


## Calcule un chemin vers une case et commence à le suivre.
## Renvoie false si la case est inaccessible.
func go_to(cell: Vector2i) -> bool:
	var new_path := map.find_path(current_cell(), cell)
	if new_path.is_empty():
		return false
	follow_path(new_path)
	return true


## Vrai si l'unité ne peut pas entrer dans cette case. Par défaut, rien ne bloque :
## hero.gd remplace cette fonction pour que les portes arrêtent les héros.
func _is_blocked(_cell: Vector2i) -> bool:
	return false


## Avance un peu le long du chemin. Renvoie true quand on est arrivé au bout.
## Si la case suivante est bloquée (voir _is_blocked), on n'avance pas.
func move_along_path(delta: float) -> bool:
	if path.is_empty():
		return true
	if _is_blocked(path[0]):
		return false
	var next_position := map.cell_to_world(path[0])
	if next_position.x < position.x - 0.5:
		_facing_left = true
	elif next_position.x > position.x + 0.5:
		_facing_left = false
	var current_speed := speed * (HASTE_SPEED_FACTOR if _haste_left > 0.0 else 1.0)
	position = position.move_toward(next_position, current_speed * delta)
	if position == next_position:
		path.remove_at(0)
	return path.is_empty()


# ---------------------------------------------------------------------------
# La main du maître : ramasser et déposer
# ---------------------------------------------------------------------------

## Les classes filles peuvent refuser (une créature qui s'en va, par exemple).
func can_be_picked_up() -> bool:
	return not is_dead() and not in_hand


## Retire l'unité du jeu sans la détruire : invisible, figée, et les ennemis
## ne la voient plus (on la retire de son groupe).
func pick_up() -> void:
	in_hand = true
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	remove_from_group(_group_name(team))
	path.clear()
	_on_picked_up()


## Remet l'unité dans le jeu, sur une case.
func drop_at(cell: Vector2i) -> void:
	in_hand = false
	position = map.cell_to_world(cell)
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	add_to_group(_group_name(team))
	_attack_cooldown = 0.5 # Un petit temps pour se remettre de la chute.
	# Effet « plop » : elle apparaît un peu grosse puis reprend sa taille.
	scale = Vector2(1.6, 1.6)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.2)
	_on_dropped()


## À compléter dans les classes filles (on remet l'IA à zéro, par exemple).
func _on_picked_up() -> void:
	pass


func _on_dropped() -> void:
	pass


# ---------------------------------------------------------------------------
# Combat
# ---------------------------------------------------------------------------

## À appeler à chaque image par toutes les unités : fait s'écouler les effets des sorts.
func update_effects(delta: float) -> void:
	_haste_left = maxf(0.0, _haste_left - delta)


func apply_haste(duration: float) -> void:
	_haste_left = duration


func heal(amount: float) -> void:
	if not is_dead():
		hp = minf(max_hp, hp + amount)


## Appelée chaque fois que l'unité touche un ennemi. Les créatures s'en servent
## pour gagner de l'expérience (voir creature.gd).
func _on_hit_landed(_damage: float) -> void:
	pass


func is_dead() -> bool:
	return hp <= 0.0


func take_damage(amount: float) -> void:
	if is_dead():
		return
	hp -= amount
	# Petit flash blanc : un « Tween » fait revenir la couleur normale en douceur.
	modulate = Color(2.5, 2.5, 2.5)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.2)
	if hp <= 0.0:
		hp = 0.0
		die()


## Les classes filles peuvent compléter die() (libérer un lit...) puis appeler super().
func die() -> void:
	Sound.play("death", position, -2.0)
	remove_from_group(_group_name(team))
	died.emit(self)
	queue_free()


## À appeler à chaque image par les unités qui se battent.
func update_attack_cooldown(delta: float) -> void:
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_strike_timer -= delta


## L'ennemi vivant le plus proche dans un rayon (en pixels), ou null.
func find_nearest_enemy(radius: float) -> Unit:
	var enemy_group := _group_name(Team.HEROES if team == Team.DUNGEON else Team.DUNGEON)
	var best: Unit = null
	var best_distance := radius
	for node in get_tree().get_nodes_in_group(enemy_group):
		var unit := node as Unit
		if unit == null or unit.is_dead():
			continue
		var distance := position.distance_to(unit.position)
		if distance <= best_distance:
			best = unit
			best_distance = distance
	return best


## Poursuit une cible et la frappe dès qu'elle est à portée.
## Renvoie false si la cible est morte ou inaccessible (le combat est fini).
##
## Attention : la cible a pu mourir et être détruite entre-temps (« previously freed »).
## On ne donne donc pas de type au paramètre : Godot refuserait l'objet détruit
## avant même d'entrer dans la fonction. On vérifie d'abord avec is_instance_valid().
func fight(target_object, delta: float) -> bool:
	if not is_instance_valid(target_object):
		path.clear()
		return false
	var target := target_object as Unit
	if target == null or target.is_dead() or target.in_hand:
		path.clear()
		return false
	if position.distance_to(target.position) <= attack_range:
		path.clear()
		if _attack_cooldown <= 0.0:
			_attack_cooldown = attack_interval
			show_strike(target.position)
			target.take_damage(attack_damage)
			_on_hit_landed(attack_damage)
			Sound.play(_attack_sound(), position)
		return true
	# Pas encore à portée : on recalcule le chemin seulement si la cible a changé de case.
	var target_cell := target.current_cell()
	if target_cell != _chase_cell or path.is_empty():
		_chase_cell = target_cell
		if not go_to(target_cell):
			return false
	move_along_path(delta)
	return true


## Le son d'une attaque : magie à distance, épée des héros ou coup des créatures.
func _attack_sound() -> String:
	if attack_range > 50.0:
		return "zap"
	return "sword" if team == Team.HEROES else "punch"


## Affiche un trait d'attaque vers une position pendant un court instant.
func show_strike(world_position: Vector2) -> void:
	_strike_timer = 0.12
	_strike_offset = world_position - position


# ---------------------------------------------------------------------------
# Affichage (utilisé par les _draw() des classes filles)
# ---------------------------------------------------------------------------

## Dessine le personnage : une ombre au sol, puis l'image (32 x 32 à l'échelle 1).
## frames = les images d'animation (voir Art.UNITS). On alterne entre elles
## quand l'unité marche, et on retourne l'image quand elle va vers la gauche.
func draw_sprite(frames: Array, sprite_scale := 1.0) -> void:
	var frame: Texture2D = frames[0]
	if not path.is_empty():
		frame = frames[int(Time.get_ticks_msec() / 150.0) % frames.size()]

	# L'ombre : un cercle aplati. Bleue sous les héros, pour les repérer d'un coup d'œil.
	var shadow := Color(0.2, 0.45, 1.0, 0.6) if team == Team.HEROES else Color(0, 0, 0, 0.35)
	draw_set_transform(Vector2(0, 11 * sprite_scale), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 10.0 * sprite_scale, shadow)

	# draw_set_transform avec une échelle de -1 en x = effet miroir.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0 if _facing_left else 1.0, 1.0))
	var size := Vector2(32, 32) * sprite_scale
	draw_texture_rect(frame, Rect2(-size / 2 - Vector2(0, 2), size), false)
	if _haste_left > 0.0:
		# Un cercle bleu clair autour d'une unité accélérée.
		draw_arc(Vector2.ZERO, 14.0 * sprite_scale, 0.0, TAU, 20, Color(0.3, 0.9, 1.0, 0.8), 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Barre de vie rouge, affichée seulement si l'unité est blessée.
func draw_health_bar(y: float) -> void:
	if hp >= max_hp:
		return
	var width := 20.0
	draw_rect(Rect2(-width / 2, y, width, 3), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(-width / 2, y, width * hp / max_hp, 3), Color("e53935"))


func draw_strike() -> void:
	if _strike_timer > 0.0:
		draw_line(Vector2.ZERO, _strike_offset, Color(1, 1, 0.8, 0.9), 2.0)


static func _group_name(unit_team: Team) -> String:
	return "dungeon" if unit_team == Team.DUNGEON else "heroes"
