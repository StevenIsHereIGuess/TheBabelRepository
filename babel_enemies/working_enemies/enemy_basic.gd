## enemy_basic.gd
## The bread-and-butter enemy. Cheap, plentiful, predictable.
## Appears in all wave phases. Forms the backbone of Swarm themes.
class_name EnemyBasic
extends EnemyBase

@export_group("Basic Stats")
@export var max_health:      float = 40.0
@export var move_speed:      float = 75.0
@export var point_value:     int   = 1
@export var damage_on_reach: float = 5.0

func _on_ready() -> void:
	if sprite:
		sprite.play("walk")

func _on_die() -> void:
	# Spawn a small death puff particle / sound here
	pass
