class_name Iso
## La vue ISOMÉTRIQUE (en losanges, avec des murs en relief).
##
## Astuce importante : tout le jeu (chemins, combats, sauvegarde...) continue de
## raisonner en coordonnées « vues de dessus » : une case = un carré de 32 x 32.
## Seul l'AFFICHAGE est transformé : le nœud « World » (voir main.gd) reçoit la
## transformation TRANSFORM, qui incline ces carrés en losanges de 64 x 32.
##
## Une transformation 2D, c'est deux vecteurs (où vont l'axe x et l'axe y) :
##   axe x -> (1, 0.5) : un pas vers la droite descend en diagonale vers la droite ;
##   axe y -> (-1, 0.5) : un pas vers le bas descend en diagonale vers la gauche.
## Le sol est donc « couché ». Mais les personnages, eux, doivent rester debout :
## ils se dessinent avec UNSKEW, la transformation inverse, qui annule l'inclinaison.

const TRANSFORM := Transform2D(Vector2(1, 0.5), Vector2(-1, 0.5), Vector2.ZERO)
## L'inverse exact de TRANSFORM (calculé à la main : son déterminant vaut 1).
const UNSKEW := Transform2D(Vector2(0.5, -0.5), Vector2(1, 1), Vector2.ZERO)

## Hauteur des murs à l'écran, en pixels.
const WALL_HEIGHT := 20.0
## Pour monter de 1 pixel à l'écran, il faut aller de (-1, -1) en coordonnées de la carte.
const UP := Vector2(-1, -1)


## Transformation qui dessine « debout » (sans inclinaison) à un point de la carte.
## Utilisée pour les objets posés au sol (cœur, lits, portes...) et les personnages.
static func billboard(origin: Vector2, screen_offset := Vector2.ZERO) -> Transform2D:
	return Transform2D(UNSKEW.x, UNSKEW.y, origin + UNSKEW.basis_xform(screen_offset))


## Un déplacement sur la carte, vu à l'écran (par exemple la direction d'un coup).
static func to_screen_vector(map_vector: Vector2) -> Vector2:
	return TRANSFORM.basis_xform(map_vector)


## Ordre d'affichage : ce qui est plus « devant » (x + y plus grand) passe par-dessus.
## Les murs d'une diagonale utilisent 4 * d + 2, les personnages 4 * d + 3.
static func depth_z(map_position: Vector2, tile_size: int) -> int:
	return int((map_position.x + map_position.y) / tile_size) * 4 + 3
