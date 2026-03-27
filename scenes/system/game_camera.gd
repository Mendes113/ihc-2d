## Handle main camera movement and target following.  
class_name GameCamera
extends Camera2D

@export var target_manager: TargetManager

var _shake_strength := 0.0
var _shake_duration := 0.0
var _shake_time_left := 0.0

func _ready() -> void:
	_enable_smoothing(false)
	target_manager.target_reached.connect(_init_camera)

func _process(delta: float) -> void:
	_update_shake(delta)

func _physics_process(_delta: float) -> void:
	_follow_target()

##internal - When transitioning between levels, the camera will be activated upon completing the transfer.
func _init_camera():
	_enable_smoothing(true)

func _enable_smoothing(value):
	position_smoothing_enabled = value
		
##internal - Manages camera tracking of the assigned target.
func _follow_target():
	if target_manager:
		global_position = target_manager.get_target_position()

func shake(strength := 4.0, duration := 0.12):
	if duration <= 0.0 or strength <= 0.0:
		return
	_shake_strength = maxf(_shake_strength, strength)
	_shake_duration = maxf(_shake_duration, duration)
	_shake_time_left = maxf(_shake_time_left, duration)

func _update_shake(delta: float):
	if _shake_time_left <= 0.0:
		offset = Vector2.ZERO
		_shake_strength = 0.0
		_shake_duration = 0.0
		return
	_shake_time_left = maxf(_shake_time_left - delta, 0.0)
	var ratio := _shake_time_left / maxf(_shake_duration, 0.001)
	var current := _shake_strength * ratio
	offset = Vector2(randf_range(-current, current), randf_range(-current, current))
