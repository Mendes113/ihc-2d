class_name Projectile
extends HitBox

@export var speed := 520.0
@export var lifetime := 1.6
@export var world_collision_mask := 7

var direction := Vector2.RIGHT
var source: Node = null

func _ready():
	monitoring = true
	collision_mask = world_collision_mask
	rotation = direction.angle()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta):
	global_position += direction * speed * delta

func setup(shot_direction: Vector2, damage: int, shot_speed: float, shot_layer: int, shooter: Node):
	direction = shot_direction.normalized() if shot_direction != Vector2.ZERO else Vector2.RIGHT
	hp_change = -abs(damage)
	speed = shot_speed
	collision_layer = shot_layer
	source = shooter

func _on_body_entered(body: Node2D):
	if body == source:
		return
	if body is CharacterEntity:
		return
	queue_free()

func _on_area_entered(area: Area2D):
	if source and area.owner == source:
		return
	if area is HurtBox:
		queue_free()

func _on_hurt_box_hit(hurt_box: HurtBox):
	if source and hurt_box and hurt_box.owner == source:
		return
	queue_free()
