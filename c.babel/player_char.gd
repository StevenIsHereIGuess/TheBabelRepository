extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const GRAVITY = 300

enum PlayerState
{
	IDLE,
	JUMP_SQUAT,
	MOVE_START,
	MOVE1, 
	MOVE2,
	MOVE3,
	SKID,
	TURN,
	JUMP,
	FALL,
	IDLE_CROUCH,
	CROUCH,
	SLIDING,
}

var _state: PlayerState = PlayerState.IDLE


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	state_machine_thingie()
	jump()
	move()
	crouch()
	move_and_slide()

func state_machine_thingie():
	if is_on_floor():
		if velocity.x == 0:
			set_state(PlayerState.IDLE)
		else:
			set_state(PlayerState.MOVE1)
	else:
		if velocity.y > 0:
			set_state(PlayerState.FALL)
		else:
			set_state(PlayerState.JUMP)
	if crouch():
		set_state(PlayerState.CROUCH)

func set_state(new_state: PlayerState) -> void:
	if new_state == _state:
		return
	
	_state = new_state
	
	match _state:
		PlayerState.IDLE:
			print("IDLE")
		PlayerState.MOVE1:
			print("MOVE")
		PlayerState.FALL:
			print("FALL")
		PlayerState.JUMP:
			print("JUMP")
		PlayerState.CROUCH:
			print("CROUCH")

func jump():
	if Input.is_action_just_pressed("ui_up") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	if Input.is_action_just_released("ui_up") and !is_on_floor():
		velocity.y = velocity.y * 0.4
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
func move():
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
func crouch():
	if Input.is_action_just_pressed("ui_down") and is_on_floor():
		$StantdingCollisionShape.disabled = true
		$CrouchCollisionShape.disabled = false
	if Input.is_action_just_released("ui_down"):
		$CrouchCollisionShape.disabled = true
		$StantdingCollisionShape.disabled = false
