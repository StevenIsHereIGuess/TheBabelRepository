## enemy_speed.gd
## Glass cannon — low health, very fast, applies pressure before towers can react.
## Signature ability: Afterburn Dash — a short-cooldown burst of speed.
class_name EnemySpeed
extends EnemyBase

@export_group("Speed Stats")
@export var max_health:      float = 25.0
@export var move_speed:      float = 170.0
@export var point_value:     int   = 2
@export var damage_on_reach: float = 8.0

@export_group("Dash Ability")
@export var dash_speed_multiplier: float = 2.5   ## Speed × this during dash
@export var dash_duration:         float = 0.35  ## Seconds the dash lasts
@export var dash_cooldown:         float = 4.0   ## Seconds between dashes

var _dash_timer:     float = 0.0
var _cooldown_timer: float = 1.5  ## Start with a short delay so enemies don't all dash at once
var _is_dashing:     bool  = false

func _on_ready() -> void:
	if sprite:
		sprite.play("run")

func _on_physics_process(delta: float) -> void:
	if _is_dashing:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			_end_dash()
	else:
		_cooldown_timer -= delta
		if _cooldown_timer <= 0.0:
			_start_dash()

func _start_dash() -> void:
	_is_dashing    = true
	_dash_timer    = dash_duration
	_speed_multiplier = dash_speed_multiplier
	if sprite:
		sprite.play("dash")
	if status_particles:
		status_particles.emitting = true

func _end_dash() -> void:
	_is_dashing       = false
	_speed_multiplier = 1.0
	_cooldown_timer   = dash_cooldown
	if sprite:
		sprite.play("run")
	if status_particles:
		status_particles.emitting = false

func _on_die() -> void:
	# Speed enemies explode into a tiny burst
	pass
