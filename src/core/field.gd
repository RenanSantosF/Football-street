class_name Field
extends RefCounted
## Medidas da rua/campo, em metros. Fonte única de verdade para cenário,
## regras, IA e câmera. O comprimento do campo fica no eixo X (gols em ±X),
## a largura no eixo Z. A câmera fica do lado +Z olhando para -Z.

const HALF_LENGTH := 14.0          ## Linha de fundo em x = ±14 (campo de 28 m).
## Não há linha lateral pintada: o limite é o MEIO-FIO (z = ±5, rua de 10 m).
## Bola rasteira bate no meio-fio e volta; só é lateral se passar por cima
## e cair na calçada (|z| > HALF_WIDTH + SIDELINE_OUT_MARGIN).
const HALF_WIDTH := 5.0
const ASPHALT_HALF_WIDTH := 5.0
const SIDELINE_OUT_MARGIN := 0.35
const SIDEWALK_WIDTH := 2.2
const CURB_HEIGHT := 0.2
const STREET_HALF_LENGTH := 30.0   ## Fim da rua em x = ±30.

const GOAL_HALF_WIDTH := 0.8       ## Trave pequena de 1,6 m (sem goleiro)...
const GOAL_HEIGHT := 0.95          ## ...por 0,95 m de altura.
const GOAL_DEPTH := 0.7
const POST_RADIUS := 0.035


## +1 se o time ataca para +X, -1 se ataca para -X.
static func attack_sign(team: int) -> float:
	return 1.0 if team == Team.SHIRTS else -1.0


## Posição X da linha do gol que [param defending_team] defende.
static func goal_line_x(defending_team: int) -> float:
	return -HALF_LENGTH * attack_sign(defending_team)


static func goal_center(defending_team: int) -> Vector3:
	return Vector3(goal_line_x(defending_team), 0.0, 0.0)


static func is_inside(p: Vector3, margin := 0.0) -> bool:
	return absf(p.x) <= HALF_LENGTH - margin and absf(p.z) <= HALF_WIDTH - margin


static func clamp_inside(p: Vector3, margin := 0.0) -> Vector3:
	return Vector3(
		clampf(p.x, -HALF_LENGTH + margin, HALF_LENGTH - margin),
		p.y,
		clampf(p.z, -HALF_WIDTH + margin, HALF_WIDTH - margin))
