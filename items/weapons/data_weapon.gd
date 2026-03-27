class_name DataWeapon
extends DataItem

@export_group("Melee")
@export var power: int = 1 ## The value this entity subtracts from another entity's HP when it attacks.
@export var speed: float = 0.5 ## Affects the cooldown time between attacks.
@export_group("Ranged")
@export var can_shoot := true
@export var shot_damage := 2
@export var shot_speed := 520.0
@export var shot_cooldown := 0.2
@export var magazine_size := 10
@export var reserve_ammo := 40
@export var reload_time := 1.0
@export var infinite_ammo := false
