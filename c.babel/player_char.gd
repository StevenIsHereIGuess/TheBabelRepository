extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const GRAVITY = 300

#IMPORTANT FOR LATER REMEMBER ABSOLUTE VALUE abs(), -100 = 100 and 12.2 = 12.2

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
	state_runner(delta) #Grabs the repective states funciton when called
	move_and_slide()

func _ready() -> void:
	starting_state()

func constant(delta):
		# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

func starting_state(): #just the state the player starts in
	set_state(PlayerState.IDLE)

func state_runner(delta): #Grabs the function for the current state
	match _state:
		PlayerState.IDLE:
			print("IDLE")
			idle_state(delta)
		PlayerState.MOVE_START:
			print("MOVE_START")
			move_start_state(delta)
		PlayerState.SPEED1:
			print("SPEED1")
			speed1_state(delta)
		PlayerState.SKID:
			print("SKID")
			skid_state(delta)

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
		
	

# Right side is working as intended but left isn't (its lowkey freaing out :sob:)

func idle_state(delta):
	var direction = Input.get_axis("ui_left", "ui_right")

	if velocity.x == 0 and direction == 0:
		pass
	if Input.is_action_just_pressed("ui_up"):
		set_state(PlayerState.JUMP_SQUAT)
	if direction != 0:
		set_state(PlayerState.MOVE_START)

func move_start_state(delta):
	var direction = Input.get_axis("ui_left", "ui_right")
	
	if direction != 0:
		set_state(PlayerState.SPEED1)
	else:
		set_state(PlayerState.IDLE)
	

func speed1_state(delta): 
	var direction = Input.get_axis("ui_left", "ui_right")
	var velocity_direction = velocity.x / abs(velocity.x)
	
	velocity.x += direction * SPEED
	
	if direction != 0 and velocity.x > 0 and velocity_direction != 0:
		pass
	if direction == 0 or direction != velocity_direction:
		set_state(PlayerState.SKID)
	

func skid_state(delta): #currently debugging ts (its probably really simple and I just don't know it)
	var direction = Input.get_axis("ui_left", "ui_right")
	var velocity_direction = velocity.x / abs(velocity.x)
	
	velocity.x == 0
	
	if direction == 0 or direction != velocity_direction and velocity.x > 0:
		pass
	if direction == velocity_direction and velocity.x > 0:
		set_state(PlayerState.SPEED1)
	if direction == 0 and velocity.x == 0:
		set_state(PlayerState.IDLE)

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
