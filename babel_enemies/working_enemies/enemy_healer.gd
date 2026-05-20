## enemy_healer.gd
## Support unit that keeps its allies alive. Must be prioritised.
## Signature ability: Pulse Heal — periodically heals nearby enemies.
##                   Rally Aura — on-death, gives a final burst of healing to all nearby allies.
class_name EnemyHealer
extends EnemyBase

@export_group("Healer Stats")
@export var max_health:      float = 60.0
@export var move_speed:      float = 65.0
@export var point_value:     int   = 4
@export var damage_on_reach: float = 5.0

@export_group("Pulse Heal")
@export var heal_radius:     float = 150.0
@export var heal_per_pulse:  float = 15.0   ## HP restored per nearby enemy per pulse
@export var pulse_interval:  float = 3.5
@export var max_targets:     int   = 4      ## Max enemies healed per pulse

@export_group("Rally (on-death burst)")
@export var rally_heal:      float = 30.0
@export var rally_radius:    float = 200.0

var _pulse_timer: float = pulse_interval * 0.5  ## First heal mid-delay

func _on_ready() -> void:
	if sprite:
		sprite.play("float")

func _on_physics_process(delta: float) -> void:
	_pulse_timer -= delta
	if _pulse_timer <= 0.0:
		_do_pulse()
		_pulse_timer = pulse_interval

func _do_pulse() -> void:
	var targets := _get_nearby_enemies(heal_radius, max_targets)
	for enemy in targets:
		enemy.heal(heal_per_pulse)
	if status_particles and not targets.is_empty():
		status_particles.emitting = true
		await get_tree().create_timer(0.4).timeout
		if is_instance_valid(self) and status_particles:
			status_particles.emitting = false

func _on_die() -> void:
	# Final burst heal
	var targets := _get_nearby_enemies(rally_radius, 16)
	for enemy in targets:
		enemy.heal(rally_heal)

func _get_nearby_enemies(radius: float, limit: int) -> Array:
	var result: Array = []
	## Walk the scene tree looking for EnemyBase nodes within range
	## A proper project would use a Group or Area2D for performance
	var all := get_tree().get_nodes_in_group("enemies")
	for node in all:
		if node == self or not node is EnemyBase:
			continue
		if (node as EnemyBase).is_dead:
			continue
		if node.global_position.distance_to(global_position) <= radius:
			result.append(node)
			if result.size() >= limit:
				break
	return result
