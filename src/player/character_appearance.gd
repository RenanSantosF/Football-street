class_name CharacterAppearance
extends Resource
## Aparência de um adolescente (pele, cabelo, roupa, altura).
##
## Todos os personagens compartilham o MESMO esqueleto humanoide e as mesmas
## animações; só esta "receita" muda. Na Etapa 2 ela é aplicada ao modelo real
## (troca de materiais/malhas de cabelo e roupa). Na Etapa 1 colore o manequim.

@export var skin_color := Color(0.62, 0.43, 0.30)
@export var hair_color := Color(0.08, 0.06, 0.05)
@export_range(0, 4) var hair_style := 0
@export var has_shirt := true
@export var shirt_color := Color(0.85, 0.85, 0.82)
@export var shorts_color := Color(0.15, 0.17, 0.25)
@export var shoes_color := Color(0.9, 0.9, 0.9)
@export_range(0.0, 1.0) var dirt := 0.3
@export_range(0.9, 1.08) var height_scale := 1.0
## Corpo base (HumanoidCharacter.BASES); vazio = padrão.
@export var base_id: StringName = &""
## -1 franzino … +1 mais forte (ombros/tronco).
@export_range(-1.0, 1.0) var build := 0.0
## Joga descalço (comum na rua).
@export var barefoot := false
## Mantém a bermuda original da textura do corpo base (ex.: jeans).
@export var keep_original_shorts := false

## Tons de pele variados (brasileiros), do mais claro ao mais escuro.
const SKIN_TONES: Array[Color] = [
	Color(0.93, 0.76, 0.62), Color(0.85, 0.65, 0.50), Color(0.76, 0.55, 0.40),
	Color(0.64, 0.44, 0.30), Color(0.52, 0.34, 0.22), Color(0.40, 0.26, 0.17),
	Color(0.30, 0.19, 0.12),
]
const HAIR_COLORS: Array[Color] = [
	Color(0.05, 0.04, 0.03), Color(0.12, 0.08, 0.05), Color(0.25, 0.16, 0.09),
	Color(0.45, 0.32, 0.18), Color(0.70, 0.55, 0.32),
]
## Camisetas comuns de pelada: lisas, desbotadas, nenhuma de clube.
const SHIRT_COLORS: Array[Color] = [
	Color(0.88, 0.87, 0.83), Color(0.70, 0.12, 0.12), Color(0.15, 0.30, 0.55),
	Color(0.25, 0.25, 0.27), Color(0.85, 0.70, 0.20), Color(0.20, 0.45, 0.30),
]
const SHORTS_COLORS: Array[Color] = [
	Color(0.12, 0.13, 0.18), Color(0.20, 0.25, 0.40), Color(0.30, 0.30, 0.30),
	Color(0.35, 0.28, 0.20), Color(0.55, 0.12, 0.12), Color(0.80, 0.80, 0.78),
]
const SHOE_COLORS: Array[Color] = [
	Color(0.9, 0.9, 0.88), Color(0.1, 0.1, 0.1), Color(0.75, 0.2, 0.15),
	Color(0.2, 0.3, 0.6),
]


static func random_for_team(team: int, rng: RandomNumberGenerator) -> CharacterAppearance:
	var a := CharacterAppearance.new()
	a.skin_color = SKIN_TONES[rng.randi_range(0, SKIN_TONES.size() - 1)]
	a.hair_color = HAIR_COLORS[rng.randi_range(0, HAIR_COLORS.size() - 1)]
	a.hair_style = rng.randi_range(0, 4)
	a.has_shirt = team == Team.SHIRTS
	a.shirt_color = SHIRT_COLORS[rng.randi_range(0, SHIRT_COLORS.size() - 1)]
	a.shorts_color = SHORTS_COLORS[rng.randi_range(0, SHORTS_COLORS.size() - 1)]
	a.shoes_color = SHOE_COLORS[rng.randi_range(0, SHOE_COLORS.size() - 1)]
	a.dirt = rng.randf_range(0.15, 0.6)
	a.height_scale = rng.randf_range(0.94, 1.05)
	a.build = rng.randf_range(-1.0, 1.0)
	a.barefoot = rng.randf() < 0.25
	a.keep_original_shorts = rng.randf() < 0.3
	return a
