## enemy_cyborg.gd
## Half-organic, half-machine. Adapts mid-fight: switches between an armoured
## mechanical phase (damage reduction) and a fast organic phase.
## Signature ability: Phase Shift — toggles between MECH and BIO modes every few seconds.
##                   EMP Pulse  — on low HP, emits an EMP that briefly disables nearby towers.
class_name EnemyCyborg
extends EnemyBase

enum Phase { MECH, BIO }

@export_group("Cyborg Stats")
@export var max_health:      float = 120.0
@export var move_speed:      float = 85.0
@export var point_value:     int   = 6
@export var damage_on_reach: float = 15.0

@export_group("Phase Shift")
@export var mech_duration:          float = 3.5
@export var bio_duration:           float = 2.0
@export var mech_damage_reduction:  float = 0.5
@export var bio_speed_multiplier:   float = 1.6

@export_group("EMP Pulse (low HP)")
@export var emp_hp_threshold:       float = 0.3    ## Triggers below 30% HP
@export var emp_radius:             float = 140.0
@export var emp_disable_duration:   float = 1.8
@export var emp_cooldown:           float = 12.0

var _current_phase: Phase = Phase.MECH
var _phase_timer:   float = mech_duration
var _emp_ready:     bool  = true
var _emp_timer:     float = 0.0

func _on_ready() -> void:
	_enter_mech_phase()
	if sprite:
		sprite.play("mech_walk")
	add_to_group("enemies")

func _on_physics_process(delta: float) -> void:
	# Phase cycling
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		_toggle_phase()

	# EMP cooldown
	if not _emp_ready:
		_emp_timer -= delta
		if _emp_timer <= 0.0:
			_emp_ready = true

func _toggle_phase() -> void:
	if _current_phase == Phase.MECH:
		_enter_bio_phase()
	else:
		_enter_mech_phase()

func _enter_mech_phase() -> void:
	_current_phase    = Phase.MECH
	_phase_timer      = mech_duration
	_speed_multiplier = 1.0
	if sprite:
		sprite.modulate = Color(0.6, 0.8, 1.0)
		sprite.play("mech_walk")

func _enter_bio_phase() -> void:
	_current_phase    = Phase.BIO
	_phase_timer      = bio_duration
	_speed_multiplier = bio_speed_multiplier
	if sprite:
		sprite.modulate = Color(0.9, 1.0, 0.6)
		sprite.play("bio_run")

func take_damage(amount: float, source: Node = null) -> void:
	var actual := amount * (1.0 - mech_damage_reduction) if _current_phase == Phase.MECH else amount
	super.take_damage(actual, source)
	# Trigger EMP if HP drops below threshold
	if _emp_ready and get_health_percent() < emp_hp_threshold:
		_fire_emp()

func _fire_emp() -> void:
	_emp_ready = false
	_emp_timer = emp_cooldown
	## Signal nearby towers (they must be in group "towers")
	var towers := get_tree().get_nodes_in_group("towers")
	for tower in towers:
		if tower.global_position.distance_to(global_position) <= emp_radius:
			if tower.has_method("apply_emp"):
				tower.apply_emp(emp_disable_duration)
	if sprite:
		sprite.modulate = Color(1.0, 1.0, 0.0)
		await get_tree().create_timer(0.3).timeout
		if is_instance_valid(self) and sprite:
			sprite.modulate = Color.WHITE

func _on_die() -> void:
	pass
