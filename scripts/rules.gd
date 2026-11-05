class_name Rules
## LES RÈGLES DU JEU EN UN SEUL ENDROIT.
##
## Ce fichier regroupe les principaux réglages de jeu, pour pouvoir les ajuster
## facilement selon les retours des joueurs. Les autres scripts lisent ces
## valeurs (par exemple main.gd écrit WORKER_COST := Rules.WORKER_COST).
##
## Pour faire évoluer les règles :
##   1. change un chiffre ci-dessous ;
##   2. ajoute une ligne dans CHANGELOG, et augmente VERSION ;
##   3. si besoin, mets à jour l'article du codex (scripts/codex_content.gd).
## Les créatures, héros, salles, pièges et sorts ont leurs propres catalogues
## (creatures.gd, heroes.gd, rooms.gd, defenses.gd, spells.gd, research.gd) :
## le codex du jeu les affiche automatiquement.

## Version des règles (affichée dans le codex).
const VERSION := "1.3"

## Les nouveautés, de la plus récente à la plus ancienne (affichées dans le codex).
const CHANGELOG := [
	{"version": "1.3", "changes": [
		"Nouvelle salle : le Cimetière (recherche). Les héros morts y sont enterrés et se relèvent en Revenants.",
		"Nouveau héros : le Champion du royaume, qui mène une vague sur 5 et accélère les héros par son cri de guerre.",
		"Nouveau niveau de campagne : « Le Champion du royaume ».",
		"Décor animé : flammes, portail, enclume, autels, mannequins, tombes, et cœur qui bat.",
	]},
	{"version": "1.2", "changes": [
		"Nouvelle créature : l'Attrapeur de cauchemar. Les héros vaincus tombent assommés, et les Attrapeurs les emmènent en prison.",
		"Sacrifices : l'Atelier fabrique des Autels de sacrifice. Outil Sacrifier : un prisonnier conduit à l'autel rapporte 3 fois sa rançon.",
		"Ajout du codex des règles.",
	]},
	{"version": "1.1", "changes": [
		"Recharge de la mana ralentie (0,25/s + 1/s par 120 cases de territoire, 1,5/s au maximum).",
	]},
	{"version": "1.0", "changes": [
		"Première version : creuser, salles, créatures, héros, pièges, sorts, campagne et maître rival.",
	]},
]

# --- Économie -------------------------------------------------------------
const START_WORKERS := 3          ## Ouvriers au début d'une partie.
const WORKER_COST := 100          ## Prix d'un ouvrier en plus.
const PAYDAY_INTERVAL := 90.0     ## Secondes entre deux jours de paie.

# --- Créatures ----------------------------------------------------------------
const CREATURE_ARRIVAL_DELAY := 20.0 ## Secondes entre deux arrivées par le portail.

# --- Prison et sacrifices ------------------------------------------------------
## Secondes pendant lesquelles un héros assommé attend un Attrapeur avant de mourir.
const CAPTURE_WINDOW := 30.0
## Points de recherche par seconde qu'apporte chaque prisonnier interrogé.
const PRISONER_RESEARCH := 1.0
## Un sacrifice rapporte la rançon du héros multipliée par ce nombre.
const SACRIFICE_GOLD_MULTIPLIER := 3
## Nombre maximum d'autels de sacrifice (posés + en stock) que l'Atelier fabrique.
const MAX_ALTARS := 2

# --- Cimetière ----------------------------------------------------------------------
## Secondes entre l'enterrement d'un héros et le moment où il se relève en Revenant
## (il faut aussi un lit libre au Repaire).
const REVENANT_RISE_TIME := 60.0

# --- Atelier ----------------------------------------------------------------------
## L'Atelier arrête de fabriquer des pièges quand le stock total atteint ce nombre.
const MAX_TRAP_STOCK := 9

# --- Divers -----------------------------------------------------------------------
const AUTOSAVE_INTERVAL := 60.0   ## Secondes entre deux sauvegardes automatiques.
