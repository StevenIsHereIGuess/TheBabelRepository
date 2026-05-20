## enemy_manager.gd
## Implements the full Point-Based Wave System from the flowchart:
##   budget → phase gate → special wave check → theme → spawn pattern → pacing
##
## Attach to a Node in your scene. Set waypoints and PackedScenes in the inspector.
## Enemies walk from waypoints[0] → waypoints[-1]; the final waypoint is the goal.

extends Node

# ─────────────────────────────────────────────────────────────────────────────
#  Signals
# ─────────────────────────────────────────────────────────────────────────────
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal enemy_died(enemy: EnemyBase)
signal enemy_reached_goal(enemy: EnemyBase)
signal all_waves_completed()
signal base_damaged(amount: float, current_hp: float)

# ─────────────────────────────────────────────────────────────────────────────
#  Wave Configuration — matches flowchart budget formula: 5 + (wave × 3)
# ─────────────────────────────────────────────────────────────────────────────
@export_group("Wave Settings")
@export var starting_wave:   int   = 1
@export var total_waves:     int   = 20
@export var budget_base:     int   = 5    ## Flowchart: points = 5 + (wave × 3)
@export var budget_per_wave: int   = 3

# ─────────────────────────────────────────────────────────────────────────────
#  Special Wave Thresholds — matches flowchart
# ─────────────────────────────────────────────────────────────────────────────
@export_group("Special Waves")
@export var boss_wave_interval:      int   = 10   ## Every 10th wave is a boss wave
@export var mini_boss_wave_interval: int   = 5    ## Every 5th wave (not boss) is mini-boss

# ─────────────────────────────────────────────────────────────────────────────
#  Spawn Timing — matches flowchart: max(0.5, 2 - wave × 0.05)
# ─────────────────────────────────────────────────────────────────────────────
@export_group("Spawn Timing")
@export var spawn_delay_base:   float = 2.0
@export var spawn_delay_scale:  float = 0.05
@export var spawn_delay_min:    float = 0.5
@export var time_between_waves: float = 4.0   ## Pause between waves

# ─────────────────────────────────────────────────────────────────────────────
#  Base (Goal) HP
# ─────────────────────────────────────────────────────────────────────────────
@export_group("Base")
@export var base_max_hp: float = 100.0

# ─────────────────────────────────────────────────────────────────────────────
#  Waypoints — assign Vector2 markers in the inspector, or set via code
#  These become the shared path every enemy follows.
# ─────────────────────────────────────────────────────────────────────────────
@export_group("Path")
@export var waypoint_nodes: Array[Node2D] = []   ## Drag Marker2D nodes here
## Or provide raw positions directly (takes precedence if non-empty)
@export var waypoints: Array[Vector2] = []

# ─────────────────────────────────────────────────────────────────────────────
#  Enemy Scenes — assign PackedScenes in the inspector
# ─────────────────────────────────────────────────────────────────────────────
@export_group("Enemy Scenes")
@export var scene_basic:      PackedScene
@export var scene_speed:      PackedScene
@export var scene_tank:       PackedScene
@export var scene_healer:     PackedScene
@export var scene_cyborg:     PackedScene
@export var scene_technician: PackedScene
@export var scene_phantom:    PackedScene
@export var scene_splitter:   PackedScene
@export var scene_berserker:  PackedScene
@export var scene_mimic:      PackedScene
@export var scene_mini_boss:  PackedScene
@export var scene_boss:       PackedScene

# ─────────────────────────────────────────────────────────────────────────────
#  Enums — match flowchart labels exactly
# ─────────────────────────────────────────────────────────────────────────────
enum WavePhase   { EARLY, MID, ADVANCED }
enum WaveTheme   { NONE, SWARM, FORTRESS, CHAOS }
enum SpawnPattern{ SWARM, FLANK, ANCHOR, BOSS_ARENA }
enum SpecialType { NORMAL, MINI_BOSS, BOSS }

# ─────────────────────────────────────────────────────────────────────────────
#  Runtime State
# ─────────────────────────────────────────────────────────────────────────────
var current_wave:    int   = 0
var base_hp:         float
var active_enemies:  Array[EnemyBase] = []
var _spawn_queue:    Array[PackedScene] = []
var _spawn_timer:    float = 0.0
var _wave_running:   bool  = false
var _between_waves:  bool  = false
var _between_timer:  float = 0.0
var _resolved_path:  Array[Vector2] = []

# ─────────────────────────────────────────────────────────────────────────────
#  Lifecycle
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	base_hp = base_max_hp
	_resolve_path()
	current_wave = starting_wave - 1
	_begin_next_wave()

func _process(delta: float) -> void:
	if _between_waves:
		_between_timer -= delta
		if _between_timer <= 0.0:
			_between_waves = false
			_begin_next_wave()
		return

	if not _wave_running:
		return

	# Spawn queue drain
	if not _spawn_queue.is_empty():
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_next()
			_spawn_timer = _get_spawn_delay()

	# Wave complete when queue empty and no active enemies remain
	if _spawn_queue.is_empty() and active_enemies.is_empty():
		_on_wave_complete()

# ─────────────────────────────────────────────────────────────────────────────
#  Path Resolution
# ─────────────────────────────────────────────────────────────────────────────
func _resolve_path() -> void:
	if not waypoints.is_empty():
		_resolved_path = waypoints.duplicate()
		return
	_resolved_path.clear()
	for node in waypoint_nodes:
		if is_instance_valid(node):
			_resolved_path.append(node.global_position)

## Call this at runtime if you move waypoints after _ready
func refresh_path() -> void:
	_resolve_path()

# ─────────────────────────────────────────────────────────────────────────────
#  Wave Flow  (follows flowchart top-to-bottom)
# ─────────────────────────────────────────────────────────────────────────────
func _begin_next_wave() -> void:
	current_wave += 1
	if current_wave > total_waves:
		all_waves_completed.emit()
		return

	# ── 1. Calculate budget ──────────────────────────────────────────────────
	var budget: int = budget_base + (current_wave * budget_per_wave)

	# ── 2. Special wave check ────────────────────────────────────────────────
	var special := _get_special_type(current_wave)

	# ── 3. Phase gate ────────────────────────────────────────────────────────
	var phase := _get_phase(current_wave)

	# ── 4. Theme selection ───────────────────────────────────────────────────
	var theme := _pick_theme(phase, special)

	# ── 5. Build spawn queue from budget ────────────────────────────────────
	_spawn_queue = _build_wave(budget, phase, theme, special)

	# ── 6. Choose spawn pattern ──────────────────────────────────────────────
	# (Pattern affects future position offsets — stored for use in _spawn_next)
	_current_pattern = _pick_spawn_pattern(theme, special)

	# ── 7. Kick off spawning ─────────────────────────────────────────────────
	_wave_running = true
	_spawn_timer  = 0.0   ## Spawn first enemy immediately
	wave_started.emit(current_wave)

	_log("Wave %d | budget=%d | phase=%s | special=%s | theme=%s | pattern=%s | enemies=%d" % [
		current_wave, budget,
		WavePhase.keys()[phase], SpecialType.keys()[special],
		WaveTheme.keys()[theme], SpawnPattern.keys()[_current_pattern],
		_spawn_queue.size()
	])

var _current_pattern: SpawnPattern = SpawnPattern.SWARM

func _on_wave_complete() -> void:
	_wave_running = false
	wave_completed.emit(current_wave)
	if current_wave >= total_waves:
		all_waves_completed.emit()
		return
	_between_waves = true
	_between_timer = time_between_waves

# ─────────────────────────────────────────────────────────────────────────────
#  Budget → Spawn Queue  (flowchart: "Pick enemy from phase pool → Can afford?")
# ─────────────────────────────────────────────────────────────────────────────
func _build_wave(budget: int, phase: WavePhase, theme: WaveTheme, special: SpecialType) -> Array[PackedScene]:
	var queue:     Array[PackedScene] = []
	var remaining: int                = budget

	# ── Special waves consume most of the budget upfront ────────────────────
	match special:
		SpecialType.BOSS:
			var boss := _get_scene("boss")
			if boss:
				queue.append(boss)
				remaining -= _cost("boss")
			# Light support with leftover budget
			_fill_from_pool(queue, remaining, _pool_for_theme(WaveTheme.NONE, phase))
			return queue

		SpecialType.MINI_BOSS:
			var mb := _get_scene("mini_boss")
			if mb:
				queue.append(mb)
				remaining -= _cost("mini_boss")
			# ~50% of remaining budget on support (flowchart rule)
			_fill_from_pool(queue, remaining / 2, _pool_for_theme(WaveTheme.NONE, phase))
			return queue

	# ── Normal waves: theme → pool → fill ───────────────────────────────────
	var pool := _pool_for_theme(theme, phase)
	_fill_from_pool(queue, remaining, pool)
	return queue

func _fill_from_pool(queue: Array[PackedScene], budget: int, pool: Array) -> void:
	var remaining := budget
	var attempts  := 0
	while remaining > 0 and attempts < 200:
		attempts += 1
		if pool.is_empty():
			break
		var entry = pool[randi() % pool.size()]   ## [key: String, cost: int]
		var key:  String = entry[0]
		var cost: int    = entry[1]
		if cost > remaining:
			# Try to find something cheaper
			var cheap := pool.filter(func(e): return e[1] <= remaining)
			if cheap.is_empty():
				break
			entry = cheap[randi() % cheap.size()]
			key   = entry[0]
			cost  = entry[1]
		var scene := _get_scene(key)
		if scene:
			queue.append(scene)
			remaining -= cost

# ─────────────────────────────────────────────────────────────────────────────
#  Phase Pools  (flowchart phase gates)
#  Each entry: [scene_key, budget_cost]
# ─────────────────────────────────────────────────────────────────────────────
func _pool_for_theme(theme: WaveTheme, phase: WavePhase) -> Array:
	var base_pool: Array = []

	match phase:
		WavePhase.EARLY:
			# Basic + Speed (low % Speed)
			base_pool = [
				["basic", 1], ["basic", 1], ["basic", 1],
				["speed", 2],
			]
		WavePhase.MID:
			# Add Tank + Healer
			base_pool = [
				["basic",  1], ["basic",  1],
				["speed",  2],
				["tank",   5],
				["healer", 4],
			]
		WavePhase.ADVANCED:
			# Add Technician, Cyborg, Wildcards
			base_pool = [
				["basic",      1], ["basic",      1],
				["speed",      2],
				["tank",       5],
				["healer",     4],
				["technician", 5],
				["cyborg",     6],
				["phantom",    5],
				["splitter",   4],
				["berserker",  5],
				["mimic",      6],
			]

	# ── Theme overrides pool weighting (flowchart) ───────────────────────────
	match theme:
		WaveTheme.SWARM:
			# Force Basic + Speed only
			return [["basic", 1], ["basic", 1], ["basic", 1], ["speed", 2]]
		WaveTheme.FORTRESS:
			# Force Tank + Healer only
			return [["tank", 5], ["healer", 4], ["healer", 4]]
		WaveTheme.CHAOS:
			# Force Technician + Wildcards only
			return [
				["technician", 5],
				["phantom",    5],
				["splitter",   4],
				["berserker",  5],
				["mimic",      6],
			]

	return base_pool

# ─────────────────────────────────────────────────────────────────────────────
#  Theme & Pattern Pickers  (flowchart: "Apply wave theme (optional)")
# ─────────────────────────────────────────────────────────────────────────────
func _pick_theme(phase: WavePhase, special: SpecialType) -> WaveTheme:
	if special != SpecialType.NORMAL:
		return WaveTheme.NONE
	# Themes only start appearing in mid phase
	if phase == WavePhase.EARLY:
		return WaveTheme.NONE
	# 40% chance of a theme wave in MID, 60% in ADVANCED
	var chance := 0.4 if phase == WavePhase.MID else 0.6
	if randf() > chance:
		return WaveTheme.NONE
	# Pick a theme valid for this phase
	var choices := [WaveTheme.SWARM, WaveTheme.FORTRESS]
	if phase == WavePhase.ADVANCED:
		choices.append(WaveTheme.CHAOS)
	return choices[randi() % choices.size()]

func _pick_spawn_pattern(theme: WaveTheme, special: SpecialType) -> SpawnPattern:
	if special == SpecialType.BOSS or special == SpecialType.MINI_BOSS:
		return SpawnPattern.BOSS_ARENA
	match theme:
		WaveTheme.SWARM:    return SpawnPattern.SWARM
		WaveTheme.FORTRESS: return SpawnPattern.ANCHOR
		WaveTheme.CHAOS:    return SpawnPattern.FLANK
	# Default: random between Swarm and Flank
	return SpawnPattern.SWARM if randf() < 0.5 else SpawnPattern.FLANK

# ─────────────────────────────────────────────────────────────────────────────
#  Spawning  (flowchart: "Spawn enemies at interval → Follow pattern timing")
# ─────────────────────────────────────────────────────────────────────────────
func _spawn_next() -> void:
	if _spawn_queue.is_empty():
		return

	var scene: PackedScene = _spawn_queue.pop_front()
	if not scene:
		return

	var enemy: EnemyBase = scene.instantiate()
	add_child(enemy)

	enemy.global_position = _spawn_position_for_pattern(_current_pattern)
	enemy.set_path(_resolved_path.duplicate())
	enemy.add_to_group("enemies")
	enemy.add_to_group("targetable_enemies")

	enemy.died.connect(_on_enemy_died)
	enemy.reached_goal.connect(_on_enemy_reached_goal.bind(enemy))

	active_enemies.append(enemy)

func _spawn_position_for_pattern(pattern: SpawnPattern) -> Vector2:
	var origin: Vector2 = _resolved_path[0] if not _resolved_path.is_empty() else Vector2.ZERO
	match pattern:
		SpawnPattern.SWARM:
			## All enemies cluster tightly at the start point
			return origin + Vector2(randf_range(-16, 16), randf_range(-16, 16))
		SpawnPattern.FLANK:
			## Alternate left/right offsets perpendicular to the path
			var offset := 60.0 * (1 if _spawn_queue.size() % 2 == 0 else -1)
			return origin + Vector2(0, offset)
		SpawnPattern.ANCHOR:
			## Staggered along the path — heavy units anchor, support fills behind
			var along := float(_spawn_queue.size()) * 24.0
			return origin + Vector2(-along, randf_range(-10, 10))
		SpawnPattern.BOSS_ARENA:
			## Boss spawns exactly at the start; supports spread nearby
			return origin + Vector2(randf_range(-30, 30), randf_range(-30, 30))
	return origin

func _get_spawn_delay() -> float:
	## Flowchart formula: max(0.5, 2 - wave × 0.05)
	return maxf(spawn_delay_min, spawn_delay_base - current_wave * spawn_delay_scale)

# ─────────────────────────────────────────────────────────────────────────────
#  Enemy Event Handlers
# ─────────────────────────────────────────────────────────────────────────────
func _on_enemy_died(enemy: EnemyBase) -> void:
	active_enemies.erase(enemy)
	enemy_died.emit(enemy)

func _on_enemy_reached_goal(enemy: EnemyBase) -> void:
	active_enemies.erase(enemy)
	_damage_base(enemy.damage_on_reach)
	enemy_reached_goal.emit(enemy)

func _damage_base(amount: float) -> void:
	base_hp = maxf(0.0, base_hp - amount)
	base_damaged.emit(amount, base_hp)
	if base_hp <= 0.0:
		_log("Base destroyed — game over!")
		## Emit your own game_over signal here or call GameManager

# ─────────────────────────────────────────────────────────────────────────────
#  Phase & Special Helpers
# ─────────────────────────────────────────────────────────────────────────────
func _get_phase(wave: int) -> WavePhase:
	if wave <= 5:  return WavePhase.EARLY
	if wave <= 10: return WavePhase.MID
	return WavePhase.ADVANCED

func _get_special_type(wave: int) -> SpecialType:
	if wave % boss_wave_interval == 0:     return SpecialType.BOSS
	if wave % mini_boss_wave_interval == 0: return SpecialType.MINI_BOSS
	return SpecialType.NORMAL

# ─────────────────────────────────────────────────────────────────────────────
#  Scene & Cost Lookup
# ─────────────────────────────────────────────────────────────────────────────
func _get_scene(key: String) -> PackedScene:
	match key:
		"basic":      return scene_basic
		"speed":      return scene_speed
		"tank":       return scene_tank
		"healer":     return scene_healer
		"cyborg":     return scene_cyborg
		"technician": return scene_technician
		"phantom":    return scene_phantom
		"splitter":   return scene_splitter
		"berserker":  return scene_berserker
		"mimic":      return scene_mimic
		"mini_boss":  return scene_mini_boss
		"boss":       return scene_boss
	return null

func _cost(key: String) -> int:
	match key:
		"basic":      return 1
		"speed":      return 2
		"healer":     return 4
		"splitter":   return 4
		"tank":       return 5
		"technician": return 5
		"phantom":    return 5
		"berserker":  return 5
		"cyborg":     return 6
		"mimic":      return 6
		"mini_boss":  return 12
		"boss":       return 30
	return 1

# ─────────────────────────────────────────────────────────────────────────────
#  Public API
# ─────────────────────────────────────────────────────────────────────────────

## Manually trigger the next wave (e.g. player presses "Start Wave" button)
func start_next_wave() -> void:
	if not _wave_running and not _between_waves:
		_begin_next_wave()

## Kill all active enemies immediately (e.g. cheat / debug)
func clear_enemies() -> void:
	for enemy in active_enemies.duplicate():
		if is_instance_valid(enemy):
			enemy.queue_free()
	active_enemies.clear()
	_spawn_queue.clear()

## Returns the number of enemies still alive this wave
func get_active_count() -> int:
	return active_enemies.size()

## Returns current base HP as a 0–1 ratio
func get_base_hp_ratio() -> float:
	return base_hp / base_max_hp

# ─────────────────────────────────────────────────────────────────────────────
#  Debug
# ─────────────────────────────────────────────────────────────────────────────
func _log(msg: String) -> void:
	print("[EnemyManager] ", msg)
