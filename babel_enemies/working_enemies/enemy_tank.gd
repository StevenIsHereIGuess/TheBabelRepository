## enemy_tank.gd
## Slow, massive, and stubborn. High health pool with damage reduction.
## Signature ability: Iron Shell — periodic damage reduction bursts.
##                   Shockwave — on-death AoE that staggers nearby enemies, resetting their hitboxes.
class_name EnemyTank
extends EnemyBase

@export_group("Tank Stats")
@export var max_health:      float = 300.0
@export var move_speed:      float = 40.0
@export var point_value:     int   = 5
@export var damage_on_reach: float = 25.0

@export_group("Iron Shell")
@export var shell_damage_reduction: float = 0.6   ## Take 40% damage during shell
@export var shell_duration:         float = 2.5
@export var shell_cooldown:         float = 8.0

@export_group("Shockwave")
@export var shockwave_radius:       float = 120.0
@export var shockwave_stun_time:    float = 0.4

var _shell_active:  bool  = false
var _shell_timer:   float = 0.0
var _cooldown_timer:float = 3.0  ## First shell slightly delayed

func _on_ready() -> void:
	if sprite:
		sprite.play("walk")

func _on_physics_process(delta: float) -> void:
	if _shell_active:
		_shell_timer -= delta
		if _shell_timer <= 0.0:
			_end_shell()
	else:
		_cooldown_timer -= delta
		if _cooldown_timer <= 0.0:
			_start_shell()

func _start_shell() -> void:
	_shell_active = true
	_shell_timer  = shell_duration
	# Visual: flash silver / opaque overlay
	if sprite:
		sprite.modulate = Color(0.8, 0.8, 1.0, 1.0)

func _end_shell() -> void:
	_shell_active   = false
	_cooldown_timer = shell_cooldown
	if sprite:
		sprite.modulate = Color.WHITE

func take_damage(amount: float, source: Node = null) -> void:
	var actual := amount * (1.0 - shell_damage_reduction) if _shell_active else amount
	super.take_damage(actual, source)

func _on_die() -> void:
	_do_shockwave()

func _do_shockwave() -> void:
	## Stun all EnemyBase nodes within shockwave_radius
	var space  := get_world_2d().direct_space_state
	var query  := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius  = shockwave_radius
	query.shape    = circle
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = collision_layer  # only hit enemies on same layer

	var results := space.intersect_shape(query, 16)
	for result in results:
		var body := result.get("collider")
		if body is EnemyBase and body != self:
			body.apply_status("stun", shockwave_stun_time)
