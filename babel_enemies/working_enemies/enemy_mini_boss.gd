## enemy_mini_boss.gd
## A mid-tier threat that arrives on mini-boss waves (~50% of wave budget).
## Signature abilities:
##   Shielded Charge — rushes forward at speed, knocking back enemies in its path (and dealing
##                     a burst of damage to any tower it passes under).
##   Fortify         — roots itself, becomes near-immune, regenerates HP, then resumes.
##   Summon Pack     — once per life, spawns 2 Basic enemies from its position.
class_name EnemyMiniBoss
extends EnemyBase

@export_group("Mini-Boss Stats")
@export var max_health:      float = 500.0
@export var move_speed:      float = 55.0
@export var point_value:     int   = 12
@export var damage_on_reach: float = 40.0

# ── Shielded Charge ──────────────────────────────────────────────────────────
@export_group("Shielded Charge")
@export var charge_speed:         float = 260.0
@export var charge_duration:      float = 0.7
@export var charge_cooldown:      float = 9.0
@export var charge_damage_reduction: float = 0.9  ## Nearly immune mid-charge
@export var charge_tower_damage:  float = 30.0

# ── Fortify ──────────────────────────────────────────────────────────────────
@export_group("Fortify")
@export var fortify_duration:       float = 3.5
@export var fortify_regen_per_sec:  float = 25.0
@export var fortify_reduction:      float = 0.95   ## 95% damage reduction while fortified
@export var fortify_cooldown:       float = 18.0
@export var fortify_hp_trigger:     float = 0.4    ## Auto-triggers below 40% HP

# ── Summon Pack ──────────────────────────────────────────────────────────────
@export_group("Summon Pack")
@export var summon_scene:        PackedScene
@export var summon_count:        int   = 2
@export var summon_hp_trigger:   float = 0.6   ## Triggers once at 60% HP

# ─────────────────────────────────────────────────────────────────────────────
var _charge_active:   bool  = false
var _charge_timer:    float = 0.0
var _charge_cooldown: float = charge_cooldown * 0.5
var _charge_dir:      Vector2 = Vector2.ZERO

var _fortify_active:   bool  = false
var _fortify_timer:    float = 0.0
var _fortify_cooldown: float = fortify_cooldown
var _fortify_used_auto: bool = false

var _summoned:         bool  = false

func _on_ready() -> void:
	add_to_group("enemies")
	if sprite:
		sprite.play("walk")

func _on_physics_process(delta: float) -> void:
	# Fortify takes priority
	if _fortify_active:
		_tick_fortify(delta)
		return

	if _charge_active:
		_tick_charge(delta)
		return

	_charge_cooldown -= delta
	if _charge_cooldown <= 0.0:
		_start_charge()

	_fortify_cooldown -= delta

func take_damage(amount: float, source: Node = null) -> void:
	var actual := amount
	if _fortify_active:
		actual *= (1.0 - fortify_reduction)
	elif _charge_active:
		actual *= (1.0 - charge_damage_reduction)
	super.take_damage(actual, source)

	# Auto-fortify on low HP
	if not _fortify_active and not _fortify_used_auto and get_health_percent() < fortify_hp_trigger:
		_fortify_used_auto = true
		_start_fortify()

	# Summon pack once
	if not _summoned and get_health_percent() < summon_hp_trigger:
		_summoned = true
		_summon_pack()

# ── Shielded Charge ──────────────────────────────────────────────────────────
func _start_charge() -> void:
	_charge_active   = true
	_charge_timer    = charge_duration
	_charge_cooldown = charge_cooldown
	# Direction = toward next path node
	if path_index < current_path.size():
		_charge_dir = (current_path[path_index] - global_position).normalized()
	else:
		_charge_dir = Vector2.RIGHT
	if sprite:
		sprite.play("charge")

func _tick_charge(delta: float) -> void:
	velocity = _charge_dir * charge_speed
	move_and_slide()
	_charge_timer -= delta
	if _charge_timer <= 0.0:
		_end_charge()

func _end_charge() -> void:
	_charge_active = false
	if sprite:
		sprite.play("walk")

# ── Fortify ──────────────────────────────────────────────────────────────────
func _start_fortify() -> void:
	_fortify_active  = true
	_fortify_timer   = fortify_duration
	_fortify_cooldown = fortify_cooldown
	velocity = Vector2.ZERO
	if sprite:
		sprite.play("fortify")
		sprite.modulate = Color(0.5, 0.5, 1.0)

func _tick_fortify(delta: float) -> void:
	heal(fortify_regen_per_sec * delta)
	_fortify_timer -= delta
	if _fortify_timer <= 0.0:
		_end_fortify()

func _end_fortify() -> void:
	_fortify_active = false
	if sprite:
		sprite.modulate = Color.WHITE
		sprite.play("walk")

# ── Summon Pack ──────────────────────────────────────────────────────────────
func _summon_pack() -> void:
	if not summon_scene:
		return
	for i in summon_count:
		var enemy: EnemyBase = summon_scene.instantiate()
		get_parent().add_child(enemy)
		enemy.global_position = global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
		enemy.set_path(current_path.slice(path_index))

func _on_die() -> void:
	pass
