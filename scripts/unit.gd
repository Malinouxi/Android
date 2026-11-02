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

var _attack_cooldown := 0.0
var _chase_cell := Vector2i(-1, -1)
var _strike_timer := 0.0
var _strike_offset := Vector2.ZERO


## Quand l'unité entre dans la scène, on la range dans un « groupe » selon son camp.
## Ainsi chacun peut retrouver ses ennemis avec get_nodes_in_group().
func _ready() -> void:
	add_to_group(_group_name(team))


## À appeler juste après la création de l'unité.
func setup(dungeon_map: DungeonMap, cell: Vector2i) -> void:
	map = dungeon_map
	position = map.cell_to_world(cell)


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


## Avance un peu le long du chemin. Renvoie true quand on est arrivé au bout.
func move_along_path(delta: float) -> bool:
	if path.is_empty():
		return true
	var next_position := map.cell_to_world(path[0])
	position = position.move_toward(next_position, speed * delta)
	if position == next_position:
		path.remove_at(0)
	return path.is_empty()


# ---------------------------------------------------------------------------
# Combat
# ---------------------------------------------------------------------------

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
func fight(target: Unit, delta: float) -> bool:
	if not is_instance_valid(target) or target.is_dead():
		path.clear()
		return false
	if position.distance_to(target.position) <= attack_range:
		path.clear()
		if _attack_cooldown <= 0.0:
			_attack_cooldown = attack_interval
			show_strike(target.position)
			target.take_damage(attack_damage)
		return true
	# Pas encore à portée : on recalcule le chemin seulement si la cible a changé de case.
	var target_cell := target.current_cell()
	if target_cell != _chase_cell or path.is_empty():
		_chase_cell = target_cell
		if not go_to(target_cell):
			return false
	move_along_path(delta)
	return true


## Affiche un trait d'attaque vers une position pendant un court instant.
func show_strike(world_position: Vector2) -> void:
	_strike_timer = 0.12
	_strike_offset = world_position - position


# ---------------------------------------------------------------------------
# Affichage (utilisé par les _draw() des classes filles)
# ---------------------------------------------------------------------------

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
