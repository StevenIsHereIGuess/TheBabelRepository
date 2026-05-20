## enemy_boss.gd
## The wave climax. Consumes nearly the full boss-wave budget.
## Has three distinct phases, each unlocking new abilities.
##
## Phase 1 (100% → 70% HP) — ASSAULT
##   • Volley Slam: fires a slow projectile spread at the player's base direction
##   • Summons Basic support at 80% HP
##
## Phase 2 (70% → 35% HP) — SIEGE
##   • Shield Wall: reflects a portion of incoming damage back to towers
##   • Calls Healer support at 50% HP
##   • Ground Slam AoE — knocks back / stuns nearby allies (friendly fire for drama)
##
## Phase 3 (35% → 0% HP) — BERSERKER
##   • All abilities accelerate
##   • Enrage: speed × 2, damage reduction 30%
##   • Final Roar: on death, buffs all remaining enemies with haste + regen
class_name EnemyBoss
extends EnemyBase

enum BossPhase { ASSAULT, SIEGE, BERSERKER }

# ── Core Stats ───────────────────────────────────────────────────────────────
@export_group("Boss Stats")
@export var max_health:      float = 2000.0
@export var move_speed:      float = 35.0
@export var point_value:     int   = 30
@export var damage_on_reach: float = 100.0

# ── Phase Thresholds ─────────────────────────────────────────────────────────
@export_group("Phase Thresholds")
@export var phase2_threshold: float = 0.70
@export var phase3_threshold: float = 0.35

# ── Volley Slam (Phase 1) ─────────────────────────────────────────────────────
@export_group("Volley Slam")
@export var volley_cooldown:  float = 5.0
@export var volley_count:     int   = 5
@export var volley_scene:     PackedScene   ## A projectile PackedScene

# ── Shield Wall (Phase 2) ─────────────────────────────────────────────────────
@export_group("Shield Wall")
@export var shield_reflect_ratio:  float = 0.25  ## 25% of damage reflected to nearest tower
@export var shield_duration:       float = 4.0
@export var shield_cooldown:       float = 10.0

# ── Ground Slam (Phase 2) ─────────────────────────────────────────────────────
@export_group("Ground Slam")
@export var slam_radius:     float = 130.0
@export var slam_stun_time:  float = 0.6
@export var slam_cooldown:   float = 7.0

# ── Enrage (Phase 3) ─────────────────────────────────────────────────────────
@export_group("Enrage")
@export var enrage_speed_mult:    float = 2.0
@export var enrage_dmg_reduction: float = 0.30

# ── Summons ───────────────────────────────────────────────────────────────────
@export_group("Summons")
@export var basic_scene:   PackedScene
@export var healer_scene:  PackedScene

# ─────────────────────────────────────────────────────────────────────────────
var _current_phase: BossPhase = BossPhase.ASSAULT
var _phase_announced: Dictionary = { BossPhase.ASSAULT: false, BossPhase.SIEGE: false, BossPhase.BERSERKER: false }

var _volley_timer:  float = volley_cooldown * 0.6
var _shield_active: bool  = false
var _shield_timer:  float = 0.0
var _shield_cd:     float = shield_cooldown
var _slam_timer:    float = slam_cooldown * 0.5
var _enraged:       bool  = false

var _summoned_basic:  bool = false
var _summoned_healer: bool = false

func _on_ready() -> void:
	add_to_group("enemies")
	if sprite:
		sprite.play("walk")
	_announce_phase(BossPhase.ASSAULT)

# ─────────────────────────────────────────────────────────────────────────────
#  Per-frame
# ─────────────────────────────────────────────────────────────────────────────
func _on_physics_process(delta: float) -> void:
	_check_phase_transition()

	match _current_phase:
		BossPhase.ASSAULT:
			_tick_assault(delta)
		BossPhase.SIEGE:
			_tick_siege(delta)
		BossPhase.BERSERKER:
			_tick_berserker(delta)

# ─────────────────────────────────────────────────────────────────────────────
#  Phase Transitions
# ─────────────────────────────────────────────────────────────────────────────
func _check_phase_transition() -> void:
	var hp := get_health_percent()
	if _current_phase == BossPhase.ASSAULT and hp <= phase2_threshold:
		_enter_siege()
	elif _current_phase == BossPhase.SIEGE and hp <= phase3_threshold:
		_enter_berserker()

func _enter_siege() -> void:
	_current_phase = BossPhase.SIEGE
	_announce_phase(BossPhase.SIEGE)
	if sprite:
		sprite.modulate = Color(1.0, 0.6, 0.3)

func _enter_berserker() -> void:
	_current_phase    = BossPhase.BERSERKER
	_enraged          = true
	_speed_multiplier = enrage_speed_mult
	_announce_phase(BossPhase.BERSERKER)
	if sprite:
		sprite.modulate = Color(1.0, 0.2, 0.2)

func _announce_phase(phase: BossPhase) -> void:
	if _phase_announced[phase]:
		return
	_phase_announced[phase] = true
	## Hook this up to your UI / event system to show a phase banner
	print("[BOSS] Entering phase: ", BossPhase.keys()[phase])

# ─────────────────────────────────────────────────────────────────────────────
#  Phase 1 — Assault
# ─────────────────────────────────────────────────────────────────────────────
func _tick_assault(delta: float) -> void:
	_volley_timer -= delta
	if _volley_timer <= 0.0:
		_fire_volley()
		_volley_timer = volley_cooldown

	if not _summoned_basic and get_health_percent() < 0.80:
		_summoned_basic = true
		_spawn_support(basic_scene, 3)

# ─────────────────────────────────────────────────────────────────────────────
#  Phase 2 — Siege
# ─────────────────────────────────────────────────────────────────────────────
func _tick_siege(delta: float) -> void:
	# Volley still fires, faster
	_volley_timer -= delta
	if _volley_timer <= 0.0:
		_fire_volley()
		_volley_timer = volley_cooldown * 0.75

	# Shield Wall
	if _shield_active:
		_shield_timer -= delta
		if _shield_timer <= 0.0:
			_end_shield()
	else:
		_shield_cd -= delta
		if _shield_cd <= 0.0:
			_start_shield()

	# Ground Slam
	_slam_timer -= delta
	if _slam_timer <= 0.0:
		_do_slam()
		_slam_timer = slam_cooldown

	if not _summoned_healer and get_health_percent() < 0.50:
		_summoned_healer = true
		_spawn_support(healer_scene, 1)

# ─────────────────────────────────────────────────────────────────────────────
#  Phase 3 — Berserker
# ─────────────────────────────────────────────────────────────────────────────
func _tick_berserker(delta: float) -> void:
	# Everything at maximum frequency
	_volley_timer -= delta
	if _volley_timer <= 0.0:
		_fire_volley()
		_volley_timer = volley_cooldown * 0.5

	_slam_timer -= delta
	if _slam_timer <= 0.0:
		_do_slam()
		_slam_timer = slam_cooldown * 0.6

# ─────────────────────────────────────────────────────────────────────────────
#  Abilities
# ─────────────────────────────────────────────────────────────────────────────
func _fire_volley() -> void:
	if not volley_scene:
		return
	var base_angle: float = global_position.angle_to_point(Vector2.ZERO)  ## Aim toward origin
	var spread: float     = deg_to_rad(45.0)
	for i in volley_count:
		var t: float   = float(i) / (volley_count - 1) if volley_count > 1 else 0.5
		var angle: float = base_angle - spread * 0.5 + spread * t
		var proj        = volley_scene.instantiate()
		get_parent().add_child(proj)
		proj.global_position = global_position
		if proj.has_method("launch"):
			proj.launch(Vector2(cos(angle), sin(angle)))

func _start_shield() -> void:
	_shield_active = true
	_shield_timer  = shield_duration
	_shield_cd     = shield_cooldown
	if sprite:
		sprite.modulate = Color(0.6, 0.8, 1.0)

func _end_shield() -> void:
	_shield_active = false
	if sprite:
		sprite.modulate = Color(1.0, 0.6, 0.3) if _current_phase == BossPhase.SIEGE else Color(1.0, 0.2, 0.2)

func _do_slam() -> void:
	var allies := get_tree().get_nodes_in_group("enemies")
	for node in allies:
		if node == self or not node is EnemyBase:
			continue
		if node.global_position.distance_to(global_position) <= slam_radius:
			(node as EnemyBase).apply_status("stun", slam_stun_time)

func _spawn_support(scene: PackedScene, count: int) -> void:
	if not scene:
		return
	for i in count:
		var enemy: EnemyBase = scene.instantiate()
		get_parent().add_child(enemy)
		enemy.global_position = global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))
		enemy.set_path(current_path.slice(path_index))

# ─────────────────────────────────────────────────────────────────────────────
#  Damage Override (Shield Wall reflection)
# ─────────────────────────────────────────────────────────────────────────────
func take_damage(amount: float, source: Node = null) -> void:
	var actual := amount * (1.0 - enrage_dmg_reduction) if _enraged else amount

	if _shield_active and source != null:
		# Reflect to nearest tower
		var reflected: float = actual * shield_reflect_ratio
		var towers := get_tree().get_nodes_in_group("towers")
		var nearest: Node = null
		var nearest_dist: float = INF
		for tower in towers:
			var d := tower.global_position.distance_to(global_position)
			if d < nearest_dist:
				nearest_dist = d
				nearest = tower
		if nearest and nearest.has_method("take_damage"):
			nearest.take_damage(reflected)

	super.take_damage(actual, source)

# ─────────────────────────────────────────────────────────────────────────────
#  Death — Final Roar
# ─────────────────────────────────────────────────────────────────────────────
func _on_die() -> void:
	var allies := get_tree().get_nodes_in_group("enemies")
	for node in allies:
		if node is EnemyBase and not (node as EnemyBase).is_dead:
			(node as EnemyBase).apply_status("haste", 5.0, 0.5)
			(node as EnemyBase).heal(30.0)
	print("[BOSS] Final Roar — all remaining enemies buffed!")
