## This script is attached to the Player node and is specifically designed to represent player entities in the game.
## The Player node serves as the foundation for creating main playable characters.
class_name PlayerEntity
extends CharacterEntity

@export_group("States")
@export var on_transfer_start: State ## State to enable when player starts transfering.
@export var on_transfer_end: State ## State to enable when player ends transfering.
@export var on_shoot: State ## State to enable when player shoots (animation only, no impulse).
@export_group("Aim")
@export var snap_facing_to_cardinal := true
@export var snap_shot_direction_to_cardinal := true
@export var aim_from_velocity_when_moving := false
@export var aim_velocity_threshold := 8.0
@export_group("Shooting")
@export var projectile_scene: PackedScene = preload("res://entities/projectiles/projectile.tscn")
@export var shoot_damage := 2
@export var shoot_speed := 520.0
@export var shoot_cooldown := 0.2
@export var default_magazine_size := 10
@export var default_reserve_ammo := 40
@export var default_reload_time := 1.0
@export var default_infinite_ammo := false
@export var use_directional_shoot_offsets := true
@export var shoot_spawn_distance := 14.0
@export var shoot_spawn_y_offset := -8.0
@export var shoot_offset_right := Vector2(14, -8)
@export var shoot_offset_left := Vector2(-14, -8)
@export var shoot_offset_up := Vector2(0, -18)
@export var shoot_offset_down := Vector2(0, -2)
@export var shoot_offset_up_right := Vector2(12, -14)
@export var shoot_offset_up_left := Vector2(-12, -14)
@export var shoot_offset_down_right := Vector2(12, -4)
@export var shoot_offset_down_left := Vector2(-12, -4)
@export_group("Head Indicators")
@export var head_indicator_size := Vector2(24, 4)
@export var head_indicator_offset := Vector2(0, -28)
@export var head_indicator_bg_color := Color(0.08, 0.08, 0.08, 0.75)
@export var head_cooldown_color := Color(0.95, 0.36, 0.11, 0.95)
@export var head_reload_color := Color(0.2, 0.82, 0.39, 0.95)
@export var head_ammo_text_offset := Vector2(0, -38)
@export var head_ammo_text_color := Color(1, 1, 1, 0.96)
@export var head_ammo_shadow_color := Color(0, 0, 0, 0.75)
@export var head_ammo_font_size := 10
@export_group("Combat Feedback")
@export var hit_camera_shake_strength := 2.8
@export var hit_camera_shake_duration := 0.08
@export var hurt_camera_shake_strength := 4.0
@export var hurt_camera_shake_duration := 0.12
@export var hit_feedback_sfx: AudioStream
@export var hurt_feedback_sfx: AudioStream
@export_group("Checkpoint")
@export var checkpoint_update_interval := 0.4
@export var respawn_delay := 1.0
@export var respawn_hp := 8
@export var respawn_invulnerability := 1.0

var player_id: int = 1 ## A unique id that is assigned to the player on creation. Player 1 will have player_id = 1 and each additional player will have an incremental id, 2, 3, 4, and so on.
var equipped = 0 ## The id of the weapon equipped by the player.
var shoot_cooldown_timer: Timer
var reload_timer: Timer
var feedback_sfx_player: AudioStreamPlayer2D
var checkpoint_position := Vector2.ZERO
var checkpoint_facing := Vector2.DOWN
var has_checkpoint := false
var checkpoint_time := 0.0
var respawn_in_progress := false
var last_known_hp := -1
var last_move_input := Vector2.ZERO
var is_reloading := false
var can_shoot_weapon := true
var shoot_damage_current := 2
var shoot_speed_current := 520.0
var shoot_cooldown_current := 0.2
var magazine_size_current := 10
var reload_time_current := 1.0
var infinite_ammo_current := false
var shoot_action_locked := false
var ammo_in_mag := 0
var ammo_reserve := 0

func _ready():
	super._ready()
	update_facing_with_movement = false
	_init_shoot_timer()
	_init_reload_timer()
	_sync_ranged_profile_from_weapon(true)
	_init_feedback_hooks()
	Globals.transfer_start.connect(func(): 
		on_transfer_start.enable()
	)
	Globals.transfer_complete.connect(func(): on_transfer_end.enable())
	Globals.destination_found.connect(func(destination_path): _move_to_destination(destination_path))
	receive_data(DataManager.get_player_data(player_id))
	_sync_cardinal_facing_from_intent(true)
	_set_checkpoint(global_position, facing)

func _process(delta):
	super._process(delta)
	if shoot_action_locked and !Input.is_action_pressed("shoot"):
		shoot_action_locked = false
	queue_redraw()

func _physics_process(delta):
	super._physics_process(delta)
	_sync_cardinal_facing_from_intent()
	_update_checkpoint(delta)

func move(direction: Vector2):
	last_move_input = direction.normalized() if direction != Vector2.ZERO else Vector2.ZERO
	if snap_facing_to_cardinal and last_move_input != Vector2.ZERO:
		facing = _snap_direction_to_cardinal(last_move_input)
	super.move(direction)

func _init_shoot_timer():
	shoot_cooldown_timer = Timer.new()
	shoot_cooldown_timer.one_shot = true
	add_child(shoot_cooldown_timer)

func _init_reload_timer():
	reload_timer = Timer.new()
	reload_timer.one_shot = true
	add_child(reload_timer)

func _set_weapon(_weapon: DataWeapon):
	super._set_weapon(_weapon)
	_sync_ranged_profile_from_weapon(true)

func _sync_ranged_profile_from_weapon(reset_ammo := false):
	can_shoot_weapon = true
	shoot_damage_current = shoot_damage
	shoot_speed_current = shoot_speed
	shoot_cooldown_current = shoot_cooldown
	magazine_size_current = max(default_magazine_size, 1)
	reload_time_current = max(default_reload_time, 0.01)
	infinite_ammo_current = default_infinite_ammo
	if reset_ammo:
		ammo_in_mag = magazine_size_current
		ammo_reserve = max(default_reserve_ammo, 0)
	if weapon:
		can_shoot_weapon = weapon.can_shoot
		shoot_damage_current = weapon.shot_damage
		shoot_speed_current = weapon.shot_speed
		shoot_cooldown_current = weapon.shot_cooldown
		magazine_size_current = max(weapon.magazine_size, 1)
		reload_time_current = max(weapon.reload_time, 0.01)
		infinite_ammo_current = weapon.infinite_ammo
		if reset_ammo:
			ammo_in_mag = magazine_size_current
			ammo_reserve = max(weapon.reserve_ammo, 0)

func _init_feedback_hooks():
	hit.connect(_on_successful_hit)
	if health_controller:
		last_known_hp = health_controller.hp
		health_controller.hp_changed.connect(_on_hp_changed)
	feedback_sfx_player = AudioStreamPlayer2D.new()
	feedback_sfx_player.bus = "SFX"
	add_child(feedback_sfx_player)

##Get the player data to save.
func get_data():
	var data = DataPlayer.new()
	var player_data = DataManager.get_player_data(player_id)
	if player_data:
		data = player_data
	data.position = position
	data.facing = facing
	data.hp = health_controller.hp
	data.max_hp = health_controller.max_hp
	data.inventory = inventory.items if inventory else []
	data.equipped = equipped
	data.ammo_in_mag = ammo_in_mag
	data.ammo_reserve = ammo_reserve
	data.ammo_initialized = true
	return data

##Handle the received player data (from a save file or when moving to another level).
func receive_data(data):
	if data:
		global_position = data.position
		if data.facing != Vector2.ZERO:
			facing = _snap_direction_to_cardinal(data.facing) if snap_facing_to_cardinal else data.facing.normalized()
		health_controller.hp = data.hp
		health_controller.max_hp = data.max_hp
		if inventory:
			inventory.items = data.inventory
		equipped = data.equipped
		if data.ammo_initialized:
			ammo_in_mag = clampi(data.ammo_in_mag, 0, magazine_size_current)
			ammo_reserve = max(data.ammo_reserve, 0)

func _move_to_destination(destination_path: String):
	if !destination_path:
		return
	var destination = get_tree().root.get_node(destination_path)
	if !destination:
		return
	var direction = facing
	if destination is Transfer and destination.direction:
		direction = destination.direction.to_vector
	DataManager.save_player_data(player_id, {
		position = destination.global_position,
		facing = direction
	})

func shoot():
	if !projectile_scene or !input_enabled:
		return
	if !can_shoot_weapon:
		return
	if Input.is_action_pressed("shoot"):
		if shoot_action_locked:
			return
		shoot_action_locked = true
	if is_jumping or is_hurting or is_falling or is_attacking or is_reloading:
		return
	if shoot_cooldown_timer and shoot_cooldown_timer.time_left > 0:
		return
	if !infinite_ammo_current and ammo_in_mag <= 0:
		reload()
		return
	var direction := _get_shoot_direction()
	facing = direction
	if on_shoot:
		enable_state(on_shoot)
	else:
		stop()
	var projectile = projectile_scene.instantiate()
	if !projectile:
		return
	var spawn_position = global_position + _get_shoot_offset(direction)
	var scene_root: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	scene_root.add_child(projectile)
	projectile.global_position = spawn_position
	if projectile.has_method("setup"):
		var shot_layer = hit_box.collision_layer if hit_box else 16
		projectile.call("setup", direction, shoot_damage_current, shoot_speed_current, shot_layer, self)
	if !infinite_ammo_current:
		ammo_in_mag = maxi(ammo_in_mag - 1, 0)
	if shoot_cooldown_timer:
		shoot_cooldown_timer.start(shoot_cooldown_current)
	if !infinite_ammo_current and ammo_in_mag == 0 and ammo_reserve > 0:
		reload()

func get_shoot_cooldown_ratio() -> float:
	if !shoot_cooldown_timer or shoot_cooldown_current <= 0.0:
		return 0.0
	return clampf(shoot_cooldown_timer.time_left / shoot_cooldown_current, 0.0, 1.0)

func get_reload_ratio() -> float:
	if !reload_timer or !is_reloading or reload_time_current <= 0.0:
		return 0.0
	return clampf(reload_timer.time_left / reload_time_current, 0.0, 1.0)

func reload():
	if !can_shoot_weapon or infinite_ammo_current:
		return
	if is_reloading:
		return
	if ammo_in_mag >= magazine_size_current:
		return
	if ammo_reserve <= 0:
		return
	if is_jumping or is_hurting or is_falling:
		return
	is_reloading = true
	reload_timer.start(reload_time_current)
	await reload_timer.timeout
	if !is_inside_tree():
		is_reloading = false
		return
	if !is_reloading:
		return
	var needed = magazine_size_current - ammo_in_mag
	var moved = mini(needed, ammo_reserve)
	ammo_in_mag += moved
	ammo_reserve -= moved
	is_reloading = false

func _get_shoot_direction() -> Vector2:
	var base_dir := facing if facing != Vector2.ZERO else Vector2.DOWN
	if last_move_input != Vector2.ZERO:
		base_dir = last_move_input
	elif aim_from_velocity_when_moving and velocity.length() >= aim_velocity_threshold:
		base_dir = velocity.normalized()
	if snap_shot_direction_to_cardinal:
		return _snap_direction_to_cardinal(base_dir)
	return base_dir.normalized()

func _sync_cardinal_facing_from_intent(force_current := false):
	if !snap_facing_to_cardinal:
		return
	if last_move_input != Vector2.ZERO:
		facing = _snap_direction_to_cardinal(last_move_input)
		return
	if velocity.length() >= aim_velocity_threshold:
		facing = _snap_direction_to_cardinal(velocity.normalized())
		return
	if facing == Vector2.ZERO:
		return
	if force_current or (absf(facing.x) > 0.001 and absf(facing.y) > 0.001):
		facing = _snap_direction_to_cardinal(facing)

func _snap_direction_to_cardinal(direction: Vector2) -> Vector2:
	if direction == Vector2.ZERO:
		return facing if facing != Vector2.ZERO else Vector2.DOWN
	var dir := direction.normalized()
	if absf(dir.x) >= absf(dir.y):
		return Vector2.RIGHT if dir.x > 0.0 else Vector2.LEFT
	return Vector2.DOWN if dir.y > 0.0 else Vector2.UP

func _draw():
	var cooldown_ratio := get_shoot_cooldown_ratio()
	var reload_ratio := get_reload_ratio()
	var scale_factor := _get_visual_scale()
	var has_bar := cooldown_ratio > 0.0 or reload_ratio > 0.0
	if has_bar:
		var bar_size := head_indicator_size * scale_factor
		var bar_origin := (head_indicator_offset * scale_factor) - Vector2(bar_size.x * 0.5, bar_size.y)
		draw_rect(Rect2(bar_origin, bar_size), head_indicator_bg_color, true)
		var fill_ratio := cooldown_ratio
		var fill_color := head_cooldown_color
		if is_reloading:
			fill_ratio = 1.0 - reload_ratio
			fill_color = head_reload_color
		fill_ratio = clampf(fill_ratio, 0.0, 1.0)
		var inner_pos := bar_origin + Vector2.ONE
		var inner_size := Vector2(maxf((bar_size.x - 2.0) * fill_ratio, 0.0), maxf(bar_size.y - 2.0, 0.0))
		draw_rect(Rect2(inner_pos, inner_size), fill_color, true)
	_draw_ammo_indicator(scale_factor)

func _draw_ammo_indicator(scale_factor: float):
	var ammo_text := _get_ammo_indicator_text()
	if ammo_text.is_empty():
		return
	var font := ThemeDB.fallback_font
	if !font:
		return
	var font_size := maxi(roundi(head_ammo_font_size * scale_factor), 8)
	var text_size := font.get_string_size(ammo_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var text_pos := (head_ammo_text_offset * scale_factor) - Vector2(text_size.x * 0.5, 0.0)
	draw_string(font, text_pos + Vector2.ONE, ammo_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, head_ammo_shadow_color)
	draw_string(font, text_pos, ammo_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, head_ammo_text_color)

func _get_ammo_indicator_text() -> String:
	if !can_shoot_weapon:
		return ""
	if infinite_ammo_current:
		return "INF/%d" % magazine_size_current
	return "%d/%d" % [ammo_in_mag, magazine_size_current]

func _get_shoot_offset(direction: Vector2) -> Vector2:
	var dir := direction.normalized() if direction != Vector2.ZERO else Vector2.DOWN
	if !use_directional_shoot_offsets:
		return dir * shoot_spawn_distance + Vector2(0, shoot_spawn_y_offset)
	var base_offset := shoot_offset_down
	var diagonal_limit := 0.35
	if absf(dir.x) > diagonal_limit and absf(dir.y) > diagonal_limit:
		if dir.x > 0.0 and dir.y < 0.0:
			base_offset = shoot_offset_up_right
		elif dir.x < 0.0 and dir.y < 0.0:
			base_offset = shoot_offset_up_left
		elif dir.x > 0.0 and dir.y > 0.0:
			base_offset = shoot_offset_down_right
		else:
			base_offset = shoot_offset_down_left
	elif absf(dir.x) >= absf(dir.y):
		base_offset = shoot_offset_right if dir.x >= 0.0 else shoot_offset_left
	else:
		base_offset = shoot_offset_down if dir.y >= 0.0 else shoot_offset_up
	return base_offset * _get_visual_scale()

func _get_visual_scale() -> float:
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	return maxf(sprite.scale.x, 0.001) if sprite else 1.0

func _set_checkpoint(new_position: Vector2, new_facing := facing):
	checkpoint_position = new_position
	has_checkpoint = true
	if new_facing != Vector2.ZERO:
		checkpoint_facing = _snap_direction_to_cardinal(new_facing) if snap_facing_to_cardinal else new_facing.normalized()

func _update_checkpoint(delta: float):
	if respawn_in_progress or !health_controller:
		return
	if health_controller.hp <= 0 or is_jumping or is_falling or is_hurting:
		checkpoint_time = 0.0
		return
	if fall_detector and fall_detector.is_colliding():
		checkpoint_time = 0.0
		return
	checkpoint_time += delta
	if checkpoint_time >= checkpoint_update_interval and velocity.length() > 8.0:
		_set_checkpoint(global_position, facing)
		checkpoint_time = 0.0

func _on_successful_hit():
	_trigger_combat_feedback(hit_camera_shake_strength, hit_camera_shake_duration, hit_feedback_sfx)

func _on_hp_changed(new_hp: int):
	if last_known_hp < 0:
		last_known_hp = new_hp
		return
	if new_hp < last_known_hp:
		_trigger_combat_feedback(hurt_camera_shake_strength, hurt_camera_shake_duration, hurt_feedback_sfx)
	if new_hp == 0:
		_start_respawn()
	last_known_hp = new_hp

func _trigger_combat_feedback(shake_strength: float, shake_duration: float, stream: AudioStream):
	var camera := get_viewport().get_camera_2d()
	if camera and camera.has_method("shake"):
		camera.call("shake", shake_strength, shake_duration)
	if stream and feedback_sfx_player:
		feedback_sfx_player.stream = stream
		feedback_sfx_player.pitch_scale = randf_range(0.96, 1.04)
		feedback_sfx_player.play()

func _start_respawn():
	if respawn_in_progress or !health_controller:
		return
	respawn_in_progress = true
	await get_tree().create_timer(respawn_delay).timeout
	if !is_inside_tree():
		respawn_in_progress = false
		return
	if has_checkpoint:
		global_position = checkpoint_position
	if checkpoint_facing != Vector2.ZERO:
		facing = checkpoint_facing
	velocity = Vector2.ZERO
	is_attacking = false
	is_hurting = false
	is_falling = false
	is_reloading = false
	visible = true
	collision_layer = 2
	collision_mask = 7
	health_controller.hp = clampi(respawn_hp, 1, health_controller.max_hp)
	health_controller.immortal = true
	var state_machine := get_node_or_null("StateMachine") as StateMachine
	if state_machine:
		state_machine.enable_state_by_name("move")
	input_enabled = true
	last_known_hp = health_controller.hp
	if respawn_invulnerability > 0.0:
		await get_tree().create_timer(respawn_invulnerability).timeout
	if health_controller:
		health_controller.immortal = false
	respawn_in_progress = false

func disable_entity(value: bool, delay = 0.0):
	await get_tree().create_timer(delay).timeout
	stop()
	input_enabled = !value
