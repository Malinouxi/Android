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

## Capacités spéciales (lues dans les catalogues par load_abilities) :
var armor := 0.0          ## Part des dégâts ignorés (0.3 = -30 % de dégâts reçus).
var lifesteal := 0.0      ## Part des dégâts infligés regagnée en vie.
var splash_radius := 0.0  ## Les coups touchent aussi les ennemis à cette distance de la cible.
var regen := 0.0          ## Vie regagnée par seconde.
var slow_on_hit := 0.0    ## Secondes de ralentissement infligées à la cible.
var attack_sound := ""    ## Son d'attaque particulier (sinon choisi automatiquement).
var stealthy := false     ## Discrète : on ne la repère que de tout près (la Voleuse).
var keen_nose := false    ## Flaire les unités discrètes de loin (le Cerbère).
const SPLASH_FACTOR := 0.5 ## Les ennemis touchés par ricochet prennent 50 % des dégâts.

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
## Animation d'attaque : secondes restantes, et durée totale (élan puis frappe).
var _attack_animation_left := 0.0
const ATTACK_ANIMATION_TIME := 0.3
var _animation_offset := 0.0
## La dernière image dessinée (pour l'effet de chute à la mort, voir die()).
var _last_frame: Texture2D
var _last_scale := 1.0
const HASTE_SPEED_FACTOR := 1.8
## Secondes de ralentissement restantes (morsure d'araignée).
var _slow_left := 0.0
const SLOW_SPEED_FACTOR := 0.5
## Brûlure (combos de pièges, voir combos.gd) : secondes restantes, dégâts par seconde.
var _burn_left := 0.0
var _burn_dps := 0.0
var _burn_tick := 0.0
const BURN_TICK := 0.5

# --- Les sorts du maître (voir spells.gd) ---------------------------------------
## Résistance à la magie (les héros, voir hero.gd) : dégâts des sorts et durée des
## envoûtements réduits d'autant (0.3 = -30 %).
var spell_resist := 0.0
## Toile du maître : englué (ralenti, et les Runes le retiennent : combo « Rune engluée »).
var _web_left := 0.0
## Sanctuaire : dégâts reçus réduits de _ward_amount pendant _ward_left secondes.
var _ward_left := 0.0
var _ward_amount := 0.0
## Fouet : travaille plus vite pendant _whip_left secondes.
var _whip_left := 0.0
var _whip_factor := 1.0
## Œil du maître : une unité discrète démasquée se voit de loin pendant ce temps.
var _unmasked_left := 0.0
## Une unité TEMPORAIRE (ouvrier invoqué, Revenant relevé) disparaît au bout de
## lifetime secondes (-1 : pour toujours).
var lifetime := -1.0


## Quand l'unité entre dans la scène, on la range dans un « groupe » selon son camp.
## Ainsi chacun peut retrouver ses ennemis avec get_nodes_in_group().
func _ready() -> void:
	add_to_group(_group_name(team))
	# Chaque unité a son propre rythme : elles ne respirent pas toutes en même temps.
	_animation_offset = randf() * 4.0


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
	if _slow_left > 0.0:
		current_speed *= SLOW_SPEED_FACTOR
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
	# Ordre d'affichage selon la position (voir iso.gd) : devant/derrière les murs.
	z_index = Iso.depth_z(position, DungeonMap.TILE_SIZE)
	_haste_left = maxf(0.0, _haste_left - delta)
	_attack_animation_left = maxf(0.0, _attack_animation_left - delta)
	_slow_left = maxf(0.0, _slow_left - delta)
	_web_left = maxf(0.0, _web_left - delta)
	_ward_left = maxf(0.0, _ward_left - delta)
	_whip_left = maxf(0.0, _whip_left - delta)
	_unmasked_left = maxf(0.0, _unmasked_left - delta)
	if lifetime > 0.0:
		lifetime -= delta
		if lifetime <= 0.0:
			vanish()
			return
	if regen > 0.0:
		heal(regen * delta)
	if _burn_left > 0.0:
		# La brûlure fait ses dégâts par petits coups (toutes les BURN_TICK secondes).
		_burn_left -= delta
		_burn_tick -= delta
		if _burn_tick <= 0.0:
			_burn_tick = BURN_TICK
			Fx.burst("sparks", position, Color("ff7a1a"))
			take_damage(_burn_dps * BURN_TICK)


func apply_haste(duration: float) -> void:
	_haste_left = duration


func heal(amount: float) -> void:
	if not is_dead():
		hp = minf(max_hp, hp + amount)


## Appelée chaque fois que l'unité touche un ennemi. Les créatures s'en servent
## pour gagner de l'expérience (voir creature.gd).
func _on_hit_landed(_target: Unit, _damage: float) -> void:
	pass


func apply_slow(duration: float) -> void:
	_slow_left = maxf(_slow_left, duration)


func is_slowed() -> bool:
	return _slow_left > 0.0


# ---------------------------------------------------------------------------
# Les sorts du maître
# ---------------------------------------------------------------------------

## La durée d'un envoûtement, raccourcie par la résistance à la magie.
func resisted(duration: float) -> float:
	return duration * (1.0 - spell_resist)


## Les sorts auxquels cette unité est insensible (les héros, voir heroes.gd).
func is_immune(_spell: String) -> bool:
	return false


## Toile du maître : englué et ralenti. Renvoie false s'il y est insensible.
func apply_web(duration: float) -> bool:
	if is_immune("web"):
		return false
	_web_left = maxf(_web_left, resisted(duration))
	apply_slow(_web_left)
	return true


func is_webbed() -> bool:
	return _web_left > 0.0


## Sanctuaire : dégâts reçus réduits de amount (0.4 = -40 %).
func apply_ward(duration: float, amount: float) -> void:
	_ward_left = maxf(_ward_left, duration)
	_ward_amount = amount


func is_warded() -> bool:
	return _ward_left > 0.0


## Fouet : le travail va factor fois plus vite.
func apply_whip(duration: float, factor: float) -> void:
	_whip_left = maxf(_whip_left, duration)
	_whip_factor = factor


func is_whipped() -> bool:
	return _whip_left > 0.0


## Le travail (creuser, construire, étudier...) va d'autant plus vite.
func work_factor() -> float:
	return _whip_factor if _whip_left > 0.0 else 1.0


## Œil du maître : une unité discrète est repérée de loin pendant duration secondes.
func unmask(duration: float) -> void:
	_unmasked_left = maxf(_unmasked_left, duration)


## Vraiment discrète en ce moment (pas démasquée par l'Œil du maître).
func is_stealthy() -> bool:
	return stealthy and _unmasked_left <= 0.0


## L'Exorciste DISSIPE la magie : il retire les sorts du maître (bons ou mauvais pour
## l'unité). Renvoie true s'il y avait quelque chose à dissiper.
func dispel() -> bool:
	var had := _haste_left > 0.0 or _web_left > 0.0 or _ward_left > 0.0 or _whip_left > 0.0
	if team == Team.DUNGEON:
		_haste_left = 0.0
		_ward_left = 0.0
		_whip_left = 0.0
	else:
		if _web_left > 0.0:
			_slow_left = 0.0
		_web_left = 0.0
	return had


## Une unité temporaire dont le temps est écoulé : elle s'efface (les classes filles
## libèrent d'abord ce qu'elles tenaient).
func vanish() -> void:
	Fx.burst("smoke", position, Color(0.6, 1.0, 0.6, 0.6))
	remove_from_group(_group_name(team))
	queue_free()


## Le chemin passe par une case qui vient de se boucher (Effondrement) : on oublie le
## chemin (les classes filles abandonnent aussi leur tâche).
func on_path_blocked() -> void:
	path.clear()


## Met le feu à l'unité : dps dégâts par seconde pendant duration secondes.
func apply_burn(duration: float, dps: float) -> void:
	if _burn_left <= 0.0:
		_burn_tick = BURN_TICK
		_burn_dps = 0.0
	_burn_left = maxf(_burn_left, duration)
	_burn_dps = maxf(_burn_dps, dps)


func is_burning() -> bool:
	return _burn_left > 0.0


## Une cible valable : vivante, pas dans la main du maître, pas prisonnière
## (une unité retirée de son groupe ne compte plus comme ennemie).
func is_targetable() -> bool:
	return not is_dead() and not in_hand and is_in_group(_group_name(team))


func is_dead() -> bool:
	return hp <= 0.0


## Lit les capacités spéciales facultatives d'une entrée de catalogue
## (voir creatures.gd et heroes.gd). Une capacité absente vaut 0.
func load_abilities(info: Dictionary) -> void:
	armor = info.get("armor", 0.0)
	lifesteal = info.get("lifesteal", 0.0)
	splash_radius = info.get("splash", 0.0)
	regen = info.get("regen", 0.0)
	slow_on_hit = info.get("slow", 0.0)
	attack_sound = info.get("attack_sound", "")
	stealthy = info.get("stealth", false)
	keen_nose = info.get("keen_nose", false)


## source : l'unité qui frappe (null pour un piège ou un sort).
func take_damage(amount: float, source: Unit = null) -> void:
	if is_dead():
		return
	var damage_taken := amount * (1.0 - armor)
	if _ward_left > 0.0:
		damage_taken *= 1.0 - _ward_amount # Sanctuaire.
	hp -= damage_taken
	# Du sang au sol (les morts-vivants et les spectres ne saignent pas : voir bleeds()).
	if bleeds() and map != null:
		map.add_blood(position, damage_taken)
	if source != null:
		_on_damaged(source, damage_taken)
	Fx.number(position, damage_taken, Color("ff8a80") if team == Team.DUNGEON else Color.WHITE)
	# Petit flash blanc : un « Tween » fait revenir la couleur normale en douceur.
	modulate = Color(2.5, 2.5, 2.5)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.2)
	if hp <= 0.0:
		hp = 0.0
		die()


## Saigne-t-elle quand on la blesse ? (Les classes filles disent non pour les
## morts-vivants, la pierre et les esprits.)
func bleeds() -> bool:
	return true


## Vrai si les unités du camp adverse ne doivent pas s'en prendre d'elles-mêmes à
## celle-ci (hero.gd : le Colosse, tant que le maître n'a pas ordonné l'assaut).
func ignored_as_enemy() -> bool:
	return false


## Appelée quand une unité ennemie nous frappe (les créatures Rancunières et les
## héros s'en souviennent, voir creature.gd et hero.gd).
func _on_damaged(_source: Unit, _amount: float) -> void:
	pass


## Les dégâts d'un coup porté à cette cible. Les classes filles les modifient
## (traits des créatures, rancune des héros vétérans).
func damage_against(_target: Unit) -> float:
	return attack_damage


## Les classes filles peuvent compléter die() (libérer un lit...) puis appeler super().
func die() -> void:
	Sound.play("death", position, -2.0)
	# Le personnage bascule et s'efface (une copie de sa dernière image, voir fx.gd).
	Fx.death_fall(position, _last_frame, _last_scale, _facing_left, self_modulate)
	Fx.burst("smoke", position, Color(0.5, 0.45, 0.5, 0.7))
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
		if unit.is_stealthy() and not keen_nose and distance > Rules.STEALTH_RADIUS:
			continue # Trop discrète pour être repérée d'ici.
		if unit.ignored_as_enemy():
			continue # Le Colosse endormi : on ne l'attaque que sur ordre du maître.
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
	if target == null or not target.is_targetable():
		path.clear()
		return false
	if position.distance_to(target.position) <= attack_range:
		path.clear()
		if _attack_cooldown <= 0.0:
			_attack_cooldown = attack_interval
			show_strike(target.position)
			var damage := damage_against(target)
			target.take_damage(damage, self)
			_on_hit_landed(target, damage)
			_apply_hit_abilities(target)
			Fx.burst("sparks", target.position)
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
## Effets des capacités spéciales quand on touche une cible.
func _apply_hit_abilities(target: Unit) -> void:
	if lifesteal > 0.0:
		heal(attack_damage * lifesteal)
	if slow_on_hit > 0.0:
		target.apply_slow(slow_on_hit)
	if splash_radius > 0.0:
		# Les autres ennemis autour de la cible prennent une partie des dégâts.
		var enemy_group := _group_name(Team.HEROES if team == Team.DUNGEON else Team.DUNGEON)
		for node in get_tree().get_nodes_in_group(enemy_group):
			var other := node as Unit
			if other != null and other != target and other.is_targetable() and not other.ignored_as_enemy() \
					and other.position.distance_to(target.position) <= splash_radius:
				other.take_damage(attack_damage * SPLASH_FACTOR, self)
		map.add_effect(target.position, splash_radius, Color(1.0, 0.5, 0.1, 0.6))


func _attack_sound() -> String:
	if attack_sound != "":
		return attack_sound
	if attack_range > 50.0:
		return "arrow" if team == Team.HEROES else "zap"
	return "sword" if team == Team.HEROES else "punch"


## Affiche un trait d'attaque vers une position pendant un court instant.
func show_strike(world_position: Vector2) -> void:
	_strike_timer = 0.12
	_strike_offset = world_position - position
	play_attack()


## Joue l'animation d'attaque (élan puis frappe).
func play_attack() -> void:
	_attack_animation_left = ATTACK_ANIMATION_TIME


# ---------------------------------------------------------------------------
# Affichage (utilisé par les _draw() des classes filles)
# ---------------------------------------------------------------------------

## Dessine le personnage : une ombre au sol, puis l'image de l'animation en cours
## (32 x 32 à l'échelle 1). L'animation dépend de ce que fait l'unité :
##   - « attack » pendant un coup (voir play_attack) ;
##   - « walk » quand elle marche (4 images, 8 par seconde) ;
##   - « idle » à l'arrêt (2 images, elle respire doucement).
## L'image est retournée en miroir quand l'unité va vers la gauche.
func draw_sprite(sprite_name: String, sprite_scale := 1.0) -> void:
	var time := Time.get_ticks_msec() / 1000.0 + _animation_offset
	var frame := animation_frame(sprite_name)
	_last_frame = frame
	_last_scale = sprite_scale

	# 1. L'ombre, posée AU SOL : un cercle dans l'espace de la carte, que la vue
	#    isométrique aplatit toute seule en ellipse. Bleue sous les ennemis.
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var shadow := Color(0.2, 0.45, 1.0, 0.6) if team == Team.HEROES else Color(0, 0, 0, 0.4)
	draw_circle(Vector2.ZERO, 9.0 * sprite_scale, shadow)
	if _haste_left > 0.0:
		# Un anneau bleu clair au sol autour d'une unité accélérée.
		draw_arc(Vector2.ZERO, 13.0 * sprite_scale, 0.0, TAU, 24, Color(0.3, 0.9, 1.0, 0.8), 1.5)

	# 2. Le personnage, DEBOUT : on annule l'inclinaison (Iso.UNSKEW), et une
	#    échelle de -1 en x le retourne en miroir quand il va vers la gauche.
	var flip := Transform2D(0.0, Vector2(-1.0 if _facing_left else 1.0, 1.0), 0.0, Vector2.ZERO)
	draw_set_transform_matrix(Iso.billboard(Vector2.ZERO) * flip)
	var size := Vector2(32, 32) * sprite_scale
	draw_texture_rect(frame, Rect2(-size.x / 2, -size.y + 4, size.x, size.y), false)
	if _haste_left > 0.0 and not path.is_empty():
		# Accélérée et en marche : des traits de vitesse filent derrière elle.
		for i in 3:
			var y := -size.y * (0.25 + 0.2 * i)
			var start := -size.x * 0.45 - fmod(time * 60.0 + i * 7.0, 10.0)
			draw_line(Vector2(start, y), Vector2(start - 8.0, y), Color(0.6, 0.95, 1.0, 0.8), 1.5)

	# 3. Pour la suite (barres, textes...), l'origine est placée au centre du
	#    personnage, comme avant la vue isométrique.
	draw_set_transform_matrix(Iso.billboard(Vector2.ZERO, Vector2(0, -size.y / 2 + 4)))


## L'image d'animation à afficher maintenant (attaque, marche ou respiration).
## Sert au dessin 2D (draw_sprite) et à la vue 3D (view_3d.gd).
func animation_frame(sprite_name: String) -> Texture2D:
	var time := Time.get_ticks_msec() / 1000.0 + _animation_offset
	var animation := "idle"
	var index := int(time * 2.0) % 2
	if _attack_animation_left > 0.0:
		animation = "attack"
		index = 0 if _attack_animation_left > ATTACK_ANIMATION_TIME * 0.5 else 1
	elif not path.is_empty():
		animation = "walk"
		index = int(time * 8.0) % 4
	return Art.unit_frames(sprite_name, animation)[index]


## Le nom de l'image du personnage et sa taille (1 = 32 pixels). Les classes
## filles (worker.gd, creature.gd, hero.gd) donnent les leurs.
func sprite_info() -> Array:
	return ["worker", 1.0]


func is_facing_left() -> bool:
	return _facing_left


## Pour la vue 3D : l'unité marche-t-elle ? Où en est son coup (1 -> 0, ou 0) ?
func is_walking() -> bool:
	return not path.is_empty()


func attack_progress() -> float:
	return _attack_animation_left / ATTACK_ANIMATION_TIME


func is_hasted() -> bool:
	return _haste_left > 0.0


## Barre de vie rouge, affichée seulement si l'unité est blessée.
func draw_health_bar(y: float) -> void:
	if hp >= max_hp:
		return
	var width := 20.0
	draw_rect(Rect2(-width / 2, y, width, 3), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(-width / 2, y, width * hp / max_hp, 3), Color("e53935"))


func draw_strike() -> void:
	if _strike_timer > 0.0:
		# Le coup part du centre du personnage vers celui de la cible, à l'écran.
		draw_line(Vector2.ZERO, Iso.to_screen_vector(_strike_offset), Color(1, 1, 0.8, 0.9), 2.0)


static func _group_name(unit_team: Team) -> String:
	return "dungeon" if unit_team == Team.DUNGEON else "heroes"
