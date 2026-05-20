## enemy_base.gd
## Base class for all enemies. Extend this for every enemy type.
## Handles: movement, health, death, player detection, status effects, signals.
class_name EnemyBase
extends CharacterBody2D

# ─────────────────────────────────────────────
#  Signals
# ─────────────────────────────────────────────
signal died(enemy)
signal health_changed(current_hp, max_hp)
signal reached_goal()
signal status_applied(effect_name: String)

# ─────────────────────────────────────────────
#  Core Stats (override in subclass or inspector)
# ─────────────────────────────────────────────
@export_group("Core Stats")
@export var max_health: float      = 50.0
@export var move_speed: float      = 80.0
@export var point_value: int       = 1      ## Wave-budget points refunded on kill
@export var damage_on_reach: float = 10.0  ## Damage dealt when reaching the goal

# ─────────────────────────────────────────────
#  Internal State
# ─────────────────────────────────────────────
var current_health: float
var is_dead:        bool  = false
var current_path:   Array = []
var path_index:     int   = 0
var _base_speed:    float          ## Cached so speed buffs/debuffs can be reset

# ─────────────────────────────────────────────
#  Status Effect Tracking
# ─────────────────────────────────────────────
var _status_timers: Dictionary = {}  ## { effect_name: remaining_seconds }
var _speed_multiplier: float   = 1.0

# ─────────────────────────────────────────────
#  Node References (assign in scene)
# ─────────────────────────────────────────────
@onready var health_bar:        ProgressBar  = $HealthBar if has_node("HealthBar") else null
@onready var sprite:            AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var hitbox:            Area2D       = $Hitbox if has_node("Hitbox") else null
@onready var status_particles:  GPUParticles2D = $StatusParticles if has_node("StatusParticles") else null

# ─────────────────────────────────────────────
#  Lifecycle
# ─────────────────────────────────────────────
func _ready() -> void:
	current_health = max_health
	_base_speed    = move_speed
	_update_health_bar()
	_on_ready()  # subclass hook

## Override in subclass for extra _ready logic (no need to call super)
func _on_ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_tick_status_effects(delta)
	_move_along_path(delta)
	_on_physics_process(delta)

## Override for subclass per-frame logic
func _on_physics_process(_delta: float) -> void:
	pass

# ─────────────────────────────────────────────
#  Pathfinding
# ─────────────────────────────────────────────
func set_path(new_path: Array) -> void:
	current_path = new_path
	path_index   = 0

func _move_along_path(delta: float) -> void:
	if current_path.is_empty() or path_index >= current_path.size():
		return

	var target:    Vector2 = current_path[path_index]
	var direction: Vector2 = (target - global_position)
	var distance:  float   = direction.length()
	var effective_speed: float = move_speed * _speed_multiplier

	if distance < 4.0:
		path_index += 1
		if path_index >= current_path.size():
			_on_reach_goal()
		return

	velocity = direction.normalized() * effective_speed
	move_and_slide()
	if sprite:
		sprite.flip_h = velocity.x < 0

# ─────────────────────────────────────────────
#  Health & Damage
# ─────────────────────────────────────────────
func take_damage(amount: float, source: Node = null) -> void:
	if is_dead:
		return
	current_health -= amount
	health_changed.emit(current_health, max_health)
	_update_health_bar()
	_on_take_damage(amount, source)

	if current_health <= 0.0:
		_die()

## Override for on-hit reactions (flash, sound, etc.)
func _on_take_damage(_amount: float, _source: Node) -> void:
	pass

func heal(amount: float) -> void:
	current_health = minf(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)
	_update_health_bar()

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	_on_die()
	died.emit(self)
	queue_free()

## Override for death effects, drops, etc.
func _on_die() -> void:
	pass

func _on_reach_goal() -> void:
	reached_goal.emit()
	queue_free()

# ─────────────────────────────────────────────
#  Status Effects
# ─────────────────────────────────────────────
func apply_status(effect: String, duration: float, intensity: float = 1.0) -> void:
	_status_timers[effect] = duration
	status_applied.emit(effect)
	match effect:
		"slow":
			_speed_multiplier = minf(_speed_multiplier, 1.0 - intensity)
		"burn":
			pass  # handled in _tick_status_effects
		"stun":
			_speed_multiplier = 0.0
		"haste":
			_speed_multiplier = maxf(_speed_multiplier, 1.0 + intensity)

func has_status(effect: String) -> bool:
	return _status_timers.has(effect) and _status_timers[effect] > 0.0

func _tick_status_effects(delta: float) -> void:
	var to_remove: Array[String] = []
	for effect in _status_timers:
		_status_timers[effect] -= delta
		match effect:
			"burn":
				take_damage(5.0 * delta)  # 5 dps
		if _status_timers[effect] <= 0.0:
			to_remove.append(effect)
	for effect in to_remove:
		_status_timers.erase(effect)
		_on_status_expired(effect)

func _on_status_expired(effect: String) -> void:
	match effect:
		"slow", "stun":
			_speed_multiplier = 1.0
		"haste":
			_speed_multiplier = 1.0

# ─────────────────────────────────────────────
#  Helpers
# ─────────────────────────────────────────────
func _update_health_bar() -> void:
	if health_bar:
		health_bar.value = current_health / max_health * 100.0

func get_health_percent() -> float:
	return current_health / max_health
