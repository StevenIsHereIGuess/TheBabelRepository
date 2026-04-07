extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const GRAVITY = 300

enum PlayerState
{
	IDLE,
	JUMP_SQUAT, #Transition between idle & jumping
	MOVE_START, #Transition between idle & moving
	SPEED1, #Different lvls of speed
	SPEED2,
	SPEED3,
	SKID, #When velocity & direction are not the same slows down player
	TURN, #When in skid & velocity = 0, if direction is not 0 turn, if 0 then back to idle
	JUMP, #Rising upward (Just in case yall dont know how to jump, gotchu Angel)
	FALL,
	CROUCH, #Idle to crouching transition
	CROUCHING, #Activley crouching (did I spell that right?)
	SLIDING, 
	SLIDE_END, 
	WALL_CLING, #Its more like a wall slide
	WALL_CLIMB, #Holding jump on a wall will have you climb for a short while
	WALL_JUMP, #Pressing jump for 
	VAULT, #Don't worry abt these for rn, I'll get to it
	MANTLE, #Same goes for this one
}

var _state: PlayerState = PlayerState.IDLE


func _physics_process(delta: float) -> void:
	constant(delta) #Its literaly just gravity, maybe add interaction w/ slopes later
	state_switcher(delta) #Decides what the player state SHOULD be
	state_runner(delta) #Decides what the player can & cant do in said state
	move_and_slide()

func constant(delta):
		# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

func state_switcher(delta):
	var direction := Input.get_axis("ui_left", "ui_right")

	if direction == 0 and velocity.x == 0 and is_on_floor():
		set_state(PlayerState.IDLE)
	
	if direction != 0 and velocity.x == 0 and is_on_floor():
		set_state(PlayerState.MOVE_START)
	
	#if direction != 0 and velocity.x > 0 and velocity.x < 300 and is_on_floor():
		#set_state(PlayerState.SPEED1)
	
	if direction != 0 and velocity.x > 300 and velocity.x < 600 and is_on_floor():
		set_state(PlayerState.SPEED2)
	
	if direction != 0 and velocity.x > 600 and is_on_floor():
		set_state(PlayerState.SPEED3)

func state_runner(delta):
	match _state:
		PlayerState.IDLE:
			print("IDLE")
		PlayerState.MOVE_START:
			print("MOVE_START")
			state_move_start(delta)
		PlayerState.SPEED1:
			print("SPEED1")
			state_speed1(delta)

func set_state(new_state: PlayerState) -> void:
	if new_state == _state:
		return
	
	_state = new_state
	
	match _state:
		PlayerState.IDLE:
			print("IDLE")
		PlayerState.SPEED1:
			print("MOVE")
		PlayerState.FALL:
			print("FALL")
		PlayerState.JUMP:
			print("JUMP")
		PlayerState.CROUCH:
			print("CROUCH")
		
	
func state_idle(delta):
	if Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("ui_right"):
		pass
		#set_state(PlayerState.SPEED1)

func state_move_start(delta):
	if PlayerState.MOVE_START and Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right"):
		set_state(PlayerState.SPEED1)
		velocity.x = 100

func state_speed1(delta):
	var direction = Input.get_axis("ui_left", "ui_right")
	velocity.x = direction * SPEED


func jump():
	if Input.is_action_just_pressed("ui_up") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	if Input.is_action_just_released("ui_up") and !is_on_floor():
		velocity.y = velocity.y * 0.4
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.

func crouch():
	var direction := Input.get_axis("ui_left", "ui_right")
	if Input.is_action_just_pressed("ui_down") and is_on_floor():
		$StantdingCollisionShape.disabled = true
		$CrouchCollisionShape.disabled = false
	if Input.is_action_just_released("ui_down"):
		$CrouchCollisionShape.disabled = true
		$StantdingCollisionShape.disabled = false
