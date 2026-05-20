## enemy_technician.gd
## Field engineer that buffs and repairs other enemies.
## Signature ability: Overclock Beacon — briefly doubles the speed of a nearby ally.
##                   Repair Drone    — deploys a drone that follows and repairs a nearby Tank/Boss.
##                   Tower Hack      — on reaching a tower's range, attempts to reduce its damage.
class_name EnemyTechnician
extends EnemyBase

@export_group("Technician Stats")
@export var max_health:      float = 55.0
@export var move_speed:      float = 70.0
@export var point_value:     int   = 5
@export var damage_on_reach: float = 5.0

@export_group("Overclock Beacon")
@export var overclock_radius:   float = 130.0
@export var overclock_boost:    float = 1.0   ## Added to target speed_multiplier (so ×2 total)
@export var overclock_duration: float = 3.0
@export var overclock_cooldown: float = 6.0

@export_group("Repair Drone")
@export var drone_repair_rate:  float = 8.0   ## HP/s repaired to attached target
@export var drone_range:        float = 180.0
@export var drone_cooldown:     float = 10.0

@export_group("Tower Hack")
@export var hack_range:         float = 120.0
@export var hack_debuff:        float = 0.4    ## Towers deal 40% less damage while hacked
@export var hack_duration:      float = 5.0
@export var hack_cooldown:      float = 12.0

var _overclock_timer: float = overclock_cooldown * 0.4
var _drone_timer:     float = drone_cooldown * 0.6
var _hack_timer:      float = hack_cooldown
var _drone_target:    EnemyBase = null

func _on_ready() -> void:
	if sprite:
		sprite.play("walk")
	add_to_group("enemies")

func _on_physics_process(delta: float) -> void:
	_overclock_timer -= delta
	if _overclock_timer <= 0.0:
		_do_overclock()
		_overclock_timer = overclock_cooldown

	_drone_timer -= delta
	if _drone_timer <= 0.0:
		_do_repair_drone(delta)
		_drone_timer = drone_cooldown

	# Continuous passive drone repair
	if is_instance_valid(_drone_target) and not _drone_target.is_dead:
		_drone_target.heal(drone_repair_rate * delta)
	else:
		_drone_target = null

	_hack_timer -= delta
	if _hack_timer <= 0.0:
		_do_hack()
		_hack_timer = hack_cooldown

# ── Overclock ──────────────────────────────────────────────────────────────
func _do_overclock() -> void:
	var allies := get_tree().get_nodes_in_group("enemies")
	var best:  EnemyBase = null
	var best_dist: float = overclock_radius

	for node in allies:
		if node == self or not node is EnemyBase:
			continue
		var dist := node.global_position.distance_to(global_position)
		if dist < best_dist:
			best_dist = dist
			best = node as EnemyBase

	if best:
		best.apply_status("haste", overclock_duration, overclock_boost)

# ── Repair Drone ───────────────────────────────────────────────────────────
func _do_repair_drone(_delta: float) -> void:
	if is_instance_valid(_drone_target) and not _drone_target.is_dead:
		return  # Already have a target

	var allies := get_tree().get_nodes_in_group("enemies")
	var best:   EnemyBase = null
	var lowest_hp: float  = 1.0  ## lowest percentage

	for node in allies:
		if node == self or not node is EnemyBase:
			continue
		if node.global_position.distance_to(global_position) > drone_range:
			continue
		var pct := (node as EnemyBase).get_health_percent()
		if pct < lowest_hp:
			lowest_hp = pct
			best      = node as EnemyBase

	if best:
		_drone_target = best

# ── Tower Hack ─────────────────────────────────────────────────────────────
func _do_hack() -> void:
	var towers := get_tree().get_nodes_in_group("towers")
	for tower in towers:
		if tower.global_position.distance_to(global_position) <= hack_range:
			if tower.has_method("apply_hack"):
				tower.apply_hack(hack_debuff, hack_duration)
			break  # Hack one tower per activation

func _on_die() -> void:
	_drone_target = null
