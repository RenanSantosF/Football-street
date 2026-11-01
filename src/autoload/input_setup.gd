extends Node
## Registra as ações de entrada no InputMap (autoload "InputSetup").
##
## Os botões da tela de toque acionam estas mesmas ações, então o jogo funciona
## igual com toque, teclado (testes no PC) ou controle Bluetooth no Android.
## Registrar por código evita editar manualmente o Input Map no editor do celular.

const KEYS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"sprint": [KEY_SHIFT],
	"pass": [KEY_J],
	"shoot": [KEY_K],
	"dribble": [KEY_L],
	"switch_player": [KEY_Q],
}

const JOY_BUTTONS := {
	"pass": JOY_BUTTON_A,
	"shoot": JOY_BUTTON_B,
	"dribble": JOY_BUTTON_X,
	"switch_player": JOY_BUTTON_LEFT_SHOULDER,
	"sprint": JOY_BUTTON_RIGHT_SHOULDER,
}

## ação -> [eixo, direção]
const JOY_AXES := {
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"move_up": [JOY_AXIS_LEFT_Y, -1.0],
	"move_down": [JOY_AXIS_LEFT_Y, 1.0],
}


func _enter_tree() -> void:
	for action: String in KEYS:
		_ensure_action(action)
		for key: int in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	for action: String in JOY_BUTTONS:
		_ensure_action(action)
		var jb := InputEventJoypadButton.new()
		jb.button_index = JOY_BUTTONS[action]
		InputMap.action_add_event(action, jb)
	for action: String in JOY_AXES:
		_ensure_action(action)
		var jm := InputEventJoypadMotion.new()
		jm.axis = JOY_AXES[action][0]
		jm.axis_value = JOY_AXES[action][1]
		InputMap.action_add_event(action, jm)


func _ensure_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.15)
