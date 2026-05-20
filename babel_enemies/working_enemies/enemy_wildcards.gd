## enemy_wildcards.gd
## Four distinct Wildcard variants — each is a standalone class.
## Wildcards appear in the Advanced phase (waves 11–20) and Chaos theme.
## They are unpredictable, high-cost, and force players to react.

# ══════════════════════════════════════════════════════════════════════════════
##  WILDCARD A — Phantom
##  Becomes untargetable for short windows while keeping full movement.
##  Low health, medium speed. Frustrates tower fire.
# ══════════════════════════════════════════════════════════════════════════════
class_name WildcardPhantom
extends EnemyBase

@export_group("Phantom Stats")
@export var max_health:      float = 35.0
@export var move_speed:      float = 95.0
@export var point_value:     int   = 5
@export var damage_on_reach: float = 8.0

@export_group("Phase-Out")
@export var phased_duration:  float = 1.8   ## Invisible / untargetable window
@export var visible_duration: float = 3.2   ## Visible and targetable window

var _is_phased:      bool  = false
var _phase_timer:    float = visible_duration * 0.5

const PHASED_ALPHA: float = 0.15

func _on_ready() -> void:
	add_to_group("enemies")
	if sprite:
		sprite.play("walk")

func _on_physics_process(delta: float) -> void:
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		_toggle_phase()

func _toggle_phase() -> void:
	_is_phased = not _is_phased
	_phase_timer = phased_duration if _is_phased else visible_duration
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "modulate:a",
			PHASED_ALPHA if _is_phased else 1.0, 0.25)
	## Add to / remove from a "targetable" group so towers can check
	if _is_phased:
		remove_from_group("targetable_enemies")
	else:
		add_to_group("targetable_enemies")

func take_damage(amount: float, source: Node = null) -> void:
	if _is_phased:
		return  # Immune while phased
	super.take_damage(amount, source)


# ══════════════════════════════════════════════════════════════════════════════
##  WILDCARD B — Splitter
##  On death, splits into two weaker Basics (once per enemy — no chain split).
# ══════════════════════════════════════════════════════════════════════════════
class_name WildcardSplitter
extends EnemyBase

@export_group("Splitter Stats")
@export var max_health:      float = 80.0
@export var move_speed:      float = 68.0
@export var point_value:     int   = 4
@export var damage_on_reach: float = 10.0

@export_group("Split")
@export var spawn_count:    int   = 2
@export var spawn_hp_ratio: float = 0.35   ## Spawns have 35% of parent's max HP
## Assign in the inspector or via code before spawning
@export var basic_enemy_scene: PackedScene

var _is_child_splitter: bool = false  ## Set to true on spawned copies

func _on_ready() -> void:
	add_to_group("enemies")
	if sprite:
		sprite.play("walk")

func _on_die() -> void:
	if _is_child_splitter or not basic_enemy_scene:
		return
	for i in spawn_count:
		var child: EnemyBase = basic_enemy_scene.instantiate()
		get_parent().add_child(child)
		child.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		child.max_health  = max_health * spawn_hp_ratio
		child.set_path(current_path.slice(path_index))
		if child.has_method("set"):
			child.set("_is_child_splitter", true)


# ══════════════════════════════════════════════════════════════════════════════
##  WILDCARD C — Berserker
##  Gets faster and deals more contact damage the lower its health drops.
# ══════════════════════════════════════════════════════════════════════════════
class_name WildcardBerserker
extends EnemyBase

@export_group("Berserker Stats")
@export var max_health:      float = 90.0
@export var move_speed:      float = 70.0
@export var point_value:     int   = 5
@export var damage_on_reach: float = 12.0

@export_group("Rage Scaling")
@export var max_speed_bonus:   float = 1.8   ## Speed multiplier at 0 HP (capped)
@export var max_damage_bonus:  float = 3.0   ## Damage multiplier at 0 HP

func _on_ready() -> void:
	add_to_group("enemies")
	if sprite:
		sprite.play("walk")

func _on_physics_process(_delta: float) -> void:
	var rage_factor: float = 1.0 - get_health_percent()  ## 0 at full HP → 1 at 0 HP
	_speed_multiplier = 1.0 + (max_speed_bonus - 1.0) * rage_factor
	_tint_by_rage(rage_factor)

func _tint_by_rage(t: float) -> void:
	if sprite:
		sprite.modulate = Color(1.0, lerpf(1.0, 0.2, t), lerpf(1.0, 0.2, t))

func get_contact_damage() -> float:
	var rage_factor := 1.0 - get_health_percent()
	return damage_on_reach * (1.0 + (max_damage_bonus - 1.0) * rage_factor)


# ══════════════════════════════════════════════════════════════════════════════
##  WILDCARD D — Mimic
##  Copies the stats of the last enemy type it passed near.
##  Starts as a mid-tier unit; upgrades itself once on its way through.
# ══════════════════════════════════════════════════════════════════════════════
class_name WildcardMimic
extends EnemyBase

@export_group("Mimic Stats")
@export var max_health:      float = 65.0
@export var move_speed:      float = 80.0
@export var point_value:     int   = 6
@export var damage_on_reach: float = 10.0

@export_group("Mimic Behaviour")
@export var mimic_radius:     float = 100.0
@export var mimic_scan_delay: float = 2.0   ## How often it scans for a nearby target to copy

var _scan_timer:   float = mimic_scan_delay
var _has_mimicked: bool  = false   ## Only mimics once per life

func _on_ready() -> void:
	add_to_group("enemies")
	if sprite:
		sprite.play("walk")

func _on_physics_process(delta: float) -> void:
	if _has_mimicked:
		return
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_try_mimic()
		_scan_timer = mimic_scan_delay

func _try_mimic() -> void:
	var allies := get_tree().get_nodes_in_group("enemies")
	for node in allies:
		if node == self or not node is EnemyBase:
			continue
		if node.global_position.distance_to(global_position) > mimic_radius:
			continue
		_copy_stats_from(node as EnemyBase)
		_has_mimicked = true
		return

func _copy_stats_from(source: EnemyBase) -> void:
	## Copy move_speed and point_value; cap health to avoid runaway scaling
	move_speed   = source.move_speed * 0.9
	point_value  = source.point_value
	## Heal to new max
	var hp_ratio := get_health_percent()
	max_health    = source.max_health * 0.75
	current_health = max_health * hp_ratio
	if sprite:
		## Briefly flash to signal the copy
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color(1.5, 1.5, 0.5), 0.15)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
