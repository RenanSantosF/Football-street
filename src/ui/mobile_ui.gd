class_name MobileUI
extends CanvasLayer
## Interface de celular: analógico, botões, placar, mensagens e barra de força.

@export var human_input: HumanInput

@onready var score_label: Label = $Score
@onready var message_label: Label = $Message
@onready var charge_bar: ProgressBar = $ChargeBar

var _message_timer := 0.0


func _ready() -> void:
	GameEvents.score_changed.connect(_on_score_changed)
	GameEvents.match_message.connect(_on_message)
	if human_input != null:
		human_input.charge_changed.connect(_on_charge_changed)
	charge_bar.visible = false
	message_label.visible = false
	_on_score_changed(0, 0)


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			message_label.visible = false


func _on_score_changed(a: int, b: int) -> void:
	score_label.text = "%s  %d  x  %d  %s" % [Team.NAMES[Team.SHIRTS], a, b, Team.NAMES[Team.SKINS]]


func _on_message(text: String, duration: float) -> void:
	message_label.text = text
	message_label.visible = true
	_message_timer = duration


func _on_charge_changed(value: float, kind: StringName) -> void:
	charge_bar.visible = kind != &""
	charge_bar.value = value * 100.0
