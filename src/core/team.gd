class_name Team
extends RefCounted
## Identificadores dos dois times da pelada.

const SHIRTS := 0  ## Time "com camisa" (ataca para +X).
const SKINS := 1   ## Time "sem camisa" (ataca para -X).

const NAMES: Array[String] = ["COM CAMISA", "SEM CAMISA"]


static func other(team: int) -> int:
	return 1 - team
