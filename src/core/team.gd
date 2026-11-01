class_name Team
extends RefCounted
## Identificadores dos dois times da pelada.

const SHIRTS := 0  ## Time "com camisa" (ataca para +X).
const SKINS := 1   ## Time "sem camisa" (ataca para -X).

const NAMES: Array[String] = ["RUA DE CIMA", "RUA DE BAIXO"]
## Cor de cada time (placar, minimapa e o disco discreto sob os pés).
const COLORS: Array[Color] = [Color(0.98, 0.55, 0.12), Color(0.2, 0.62, 0.98)]


static func other(team: int) -> int:
	return 1 - team
