extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
var GRAVITY = 1000

#	Jump Buffer
var jump_buffer_tf = false
var jump_buffer = 0.1
var since_jump_input = 0

#	Custom Speed System
var DECAY_TIMER = 1.0
var current_timer = 0
var record_speed = 0
var current_speed = abs(velocity.x)

var flip = false

#	Wall Detection
var Coyote_Left := false
var Top_Left := false
var Mid_Left := false
var Bottom_Left := false

var Coyote_Right := false
var Top_Right := false
var Mid_Right := false
var Bottom_Right := false

var touching_left_wall_all := false
var touching_left_wall_bottom_half := false
var touching_right_wall_all := false
var touching_right_wall_bottom_half := false

enum PlayerState
{
	#Idle & Starting States
	IDLE,
	JUMP_SQUAT, #Transition between idle & jumping
	MOVE_START, #Transition between idle & moving
	
	#Grounded Movement
	SPEED1, #Different lvls of speed
	SPEED2,
	SPEED3,
	SKID, #When velocity & direction are not the same slows down player
	TURN, #When in skid & velocity = 0, if direction is not 0 turn, if 0 then back to idle
	
	#Aerial Movement
	JUMP, #Rising upward (Just in case yall dont know how to jump, gotchu Angel)
	FALL,
	
	#Crouching & Sliding
	CROUCH, #Idle to crouching transition
	CROUCHING, #Activley crouching (did I spell that right?)
	SLIDING, 
	SLIDE_END, 
	
	#Wall Mechanics
	WALL_CLING_L,
	WALL_CLING_R, #Its more like a wall slide
	WALL_CLIMB, #Holding jump on a wall will have you climb for a short while
	WALL_JUMP_L,
	WALL_JUMP_R, #Pressing jump for 
	VAULT, #Don't worry abt these for rn, I'll get to it
	MANTLE, #Same goes for this one
	SWING, #Swing on monkey bars or other objects
	ROLL, #Cancel fall damage
}

var _state: PlayerState = PlayerState.IDLE


func _physics_process(delta: float) -> void:
	constant(delta) #Things running at all times
	state_runner(delta) #Grabs the repective states funciton when called
	move_and_slide()

func _ready() -> void:
	starting_state()

func starting_state(): #just the state the player starts in
	set_state(PlayerState.IDLE)

func constant(delta):
		# Add the gravity.
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	
	decay_speed()
	
	speed_peak()
	
	wall_detection()
	
	#flip_function()
	
	#jump_buffer_thing()
	

func state_runner(delta): #Grabs the function for the current state
	match _state:
		#Basic Movement
		PlayerState.IDLE:
			idle_state(delta)
		PlayerState.MOVE_START:
			move_start_state(delta)
		PlayerState.JUMP_SQUAT:
			jump_squat_state(delta)
		PlayerState.CROUCH:
			crouch_state(delta)
		PlayerState.SPEED1:
			speed1_state(delta)
		PlayerState.SPEED2:
			speed2_state(delta)
		PlayerState.SPEED3:
			pass
		PlayerState.SKID:
			skid_state(delta)
		PlayerState.JUMP:
			jump_state(delta)
		PlayerState.FALL:
			fall_state(delta)
		PlayerState.CROUCHING:
			crouching_state(delta)
		PlayerState.SLIDING:
			sliding_state(delta)
		PlayerState.WALL_CLING_L:
			wall_cling_state_l(delta)
		PlayerState.WALL_CLING_R:
			wall_cling_state_r(delta)
		PlayerState.WALL_CLIMB:
			pass
		PlayerState.WALL_JUMP_L:
			wall_jump_state_l(delta)
		PlayerState.WALL_JUMP_R:
			wall_jump_state_r(delta)
		PlayerState.VAULT:
			pass
		PlayerState.MANTLE:
			pass
		
	

func set_state(new_state: PlayerState) -> void:
	if new_state == _state:
		return
	
	_state = new_state
	
	match _state:
		PlayerState.IDLE:
			print("IDLE")
		PlayerState.MOVE_START:
			print("MOVE START")
		PlayerState.SPEED1:
			print("SPEED1")
		PlayerState.SPEED2:
			print("SPEED2")
		PlayerState.SPEED3:
			print("SPEED3")
		PlayerState.SKID:
			print("SKID")
		PlayerState.TURN:
			print("TURN")
		PlayerState.JUMP_SQUAT:
			print("JUMP SQUAT")
		PlayerState.JUMP:
			print("JUMP")
		PlayerState.FALL:
			print("FALL")
		PlayerState.CROUCH:
			print("CROUCH")
		PlayerState.CROUCHING:
			print("CROUCHING")
		PlayerState.SLIDING:
			print("SLIDING")
		PlayerState.SLIDE_END:
			print("SLIDE END")
		PlayerState.WALL_CLING_R:
			print("WALL RIGHT")
		PlayerState.WALL_CLING_L:
			print("WALL LEFT")
		PlayerState.WALL_JUMP_R:
			print("WALL JUMP")
		PlayerState.WALL_JUMP_L:
			print("WALL JUMP")
		PlayerState.WALL_CLIMB:
			print("WALL CLIMB")
		PlayerState.VAULT:
			print("VAULT")
		PlayerState.MANTLE:
			print("MANTLE")
		
	

#	Miscellaneous

func decay_speed():
	if abs(record_speed) >= abs(SPEED):
		if (current_timer < DECAY_TIMER):
			current_timer += get_process_delta_time()
		elif (current_timer >= DECAY_TIMER):
			current_timer = 0
			record_speed -= 7
	

func speed_peak():
	if abs(record_speed) < abs(current_speed):
		record_speed = current_speed
	

func flip_function(): #also work in progress
	#rotation = PI
	var velocity_direction = sign(velocity.x)
	
	if velocity_direction > 0:
		rotation_degrees = 0
		scale.y = 1
		flip = false
	elif velocity_direction < 0:
		rotation_degrees = 180
		scale.y = -1
		flip = true
	elif velocity_direction == 0:
		return
	

func jump_buffer_thing(): #work in progress
	if Input.is_action_just_pressed("Jump"):
		if (since_jump_input < jump_buffer):
			jump_buffer_tf = true
			since_jump_input += get_process_delta_time()
		elif (since_jump_input > jump_buffer):
			jump_buffer_tf = false
			since_jump_input = 0
	return

func wall_detection():
	
	Coyote_Left = $Raycasts/CoyoteLeft.is_colliding()
	Top_Left = $Raycasts/TopLeft.is_colliding()
	Mid_Left = $Raycasts/MidLeft.is_colliding()
	Bottom_Left = $Raycasts/BottomLeft.is_colliding()
	
	Coyote_Right = $Raycasts/CoyoteRight.is_colliding()
	Top_Right = $Raycasts/TopRight.is_colliding()
	Mid_Right = $Raycasts/MidRight.is_colliding()
	Bottom_Right = $Raycasts/BottomRight.is_colliding()
	
	var bottom_3_detection_left := false
	var bottom_2_detection_left := false
	var bottom_1_detection_left := false
	
	var bottom_3_detection_right := false
	var bottom_2_detection_right := false
	var bottom_1_detection_right := false
	
	if !Coyote_Left and Top_Left and Mid_Left and Bottom_Left:
		bottom_3_detection_left = true
	else:
		bottom_3_detection_left = false
	
	if !Coyote_Left and !Top_Left and Mid_Left and Bottom_Left:
		bottom_2_detection_left = true
	else:
		bottom_2_detection_left = false
	
	if !Coyote_Left and !Top_Left and !Mid_Left and Bottom_Left:
		bottom_1_detection_left = true
	else:
		bottom_1_detection_left = false
	
	if !Coyote_Right and Top_Right and Mid_Right and Bottom_Right:
		bottom_3_detection_right = true
	else:
		bottom_3_detection_right = false
	
	if !Coyote_Right and !Top_Right and Mid_Right and Bottom_Right:
		bottom_2_detection_right = true
	else:
		bottom_2_detection_right = false
	
	if !Coyote_Right and !Top_Right and !Mid_Right and Bottom_Right:
		bottom_1_detection_right = true
	else:
		bottom_1_detection_right = false
	
	if Coyote_Left and Top_Left and Mid_Left and Bottom_Left:
		touching_left_wall_all = true
	elif !Coyote_Left and !Top_Left and !Mid_Left and !Bottom_Left:
		touching_left_wall_all = false
	
	if Coyote_Right and Top_Right and Mid_Right and Bottom_Right:
		touching_right_wall_all = true
	elif !Coyote_Right and !Top_Right and !Mid_Right and !Bottom_Right:
		touching_right_wall_all = false
	
	if bottom_3_detection_left == true or bottom_2_detection_left == true or bottom_1_detection_left == true:
		touching_left_wall_bottom_half = true
	else:
		touching_left_wall_bottom_half = false
	
	if bottom_3_detection_right == true or bottom_2_detection_right == true or bottom_1_detection_right == true:
		touching_right_wall_bottom_half = true
	else:
		touching_right_wall_bottom_half = false
	

#	States

#	Basic Movement (Left & Right, Jumping, Sliding etc.)

func idle_state(delta):
	var direction = Input.get_axis("ui_left", "ui_right")
	
	if !is_on_floor():
		set_state(PlayerState.FALL)
	elif jump_buffer_tf == true:
		set_state(PlayerState.JUMP_SQUAT)
	elif Input.is_action_just_pressed("Jump"):
		set_state(PlayerState.JUMP_SQUAT)
	elif Input.is_action_just_pressed("ui_down"):
		set_state(PlayerState.CROUCH)
	elif direction != 0:
		set_state(PlayerState.MOVE_START)
	elif velocity.x != 0:
		set_state(PlayerState.SKID)


func move_start_state(delta):
	var direction = Input.get_axis("ui_left", "ui_right")
	
	if !is_on_floor():
		set_state(PlayerState.FALL)
	elif Input.is_action_just_pressed("Jump"):
		set_state(PlayerState.JUMP)
	elif Input.is_action_just_pressed("ui_down"):
		set_state(PlayerState.SLIDING)
	elif direction != 0:
		set_state(PlayerState.SPEED1)
	elif direction == 0:
		set_state(PlayerState.IDLE)
	

func speed1_state(delta): 
	var direction = Input.get_axis("ui_left", "ui_right")
	var velocity_direction = sign(velocity.x)
	
	velocity.x += direction * SPEED
	velocity.x = clamp(velocity.x, -SPEED, SPEED)
	
	if velocity.x > abs(SPEED):
		set_state(PlayerState.SPEED2)
	elif !is_on_floor():
		set_state(PlayerState.FALL)
	elif Input.is_action_just_pressed("Jump"):
		set_state(PlayerState.JUMP_SQUAT)
	elif Input.is_action_just_pressed("ui_down"):
		set_state(PlayerState.SLIDING)
	elif direction == 0 or direction != velocity_direction:
		set_state(PlayerState.SKID)
	

func speed2_state(delta):
	var direction = Input.get_axis("ui_left", "ui_right")
	var velocity_direction = sign(velocity.x)
	
	velocity.x += direction * record_speed
	velocity.x = clamp(velocity.x, -900, 900)
	
	if !is_on_floor():
		set_state(PlayerState.FALL)
	elif Input.is_action_just_pressed("Jump"):
		set_state(PlayerState.JUMP_SQUAT)
	elif velocity.x <= 300:
		set_state(PlayerState.SPEED1)
	elif direction == 0 or direction != velocity_direction:
		set_state(PlayerState.SKID)
	elif velocity.x > abs(9000):
		set_state(PlayerState.SPEED3)

func skid_state(delta):
	var direction = Input.get_axis("ui_left", "ui_right")
	var velocity_direction = sign(velocity.x)
	
	if velocity_direction == 1:
		velocity.x = move_toward(velocity.x, 0.0, 50)
	elif velocity_direction == -1:
		velocity.x = move_toward(velocity.x, 0.0, 50)
	
	if Input.is_action_just_pressed("Jump"):
		set_state(PlayerState.JUMP_SQUAT)
	elif direction == velocity_direction:
		set_state(PlayerState.SPEED1)
	elif velocity.x == 0: # add "and direction == 0" later 
		set_state(PlayerState.IDLE)
	elif direction == 0 or direction != velocity_direction:
		pass
	

func jump_squat_state(delta):
	set_state(PlayerState.JUMP)
	velocity.y = JUMP_VELOCITY

func jump_state(delta):
	var direction = Input.get_axis("ui_left", "ui_right")
	
	velocity.x += direction * 50
	velocity.x = clamp(velocity.x, -SPEED, SPEED)

	if Input.is_action_just_released("Jump"):
		velocity.y = velocity.y * 0.4
		set_state(PlayerState.FALL)
		return
	elif velocity.y >= 0:
		set_state(PlayerState.FALL)
		return
	elif touching_right_wall_all == true:
		set_state(PlayerState.WALL_CLING_R)
	elif touching_left_wall_all == true:
		set_state(PlayerState.WALL_CLING_L)
	

func fall_state(delta):
	var direction = Input.get_axis("ui_left", "ui_right")
	
	velocity.x += direction * 50
	velocity.x = clamp(velocity.x, -SPEED, SPEED)
	
	if touching_right_wall_all == true:
		set_state(PlayerState.WALL_CLING_R)
	elif touching_left_wall_all == true:
		set_state(PlayerState.WALL_CLING_L)
	elif is_on_floor():
		set_state(PlayerState.IDLE)
	elif jump_buffer_tf == true:
		jump_buffer_thing()
		return 
	

func crouch_state(delta): 
	set_state(PlayerState.CROUCHING)

func crouching_state(delta): #Later, hitboxes & hurtboxes should be defined for each and every state
	var direction := Input.get_axis("ui_left", "ui_right") #Also add a "can stand" var later
	
	if Input.is_action_pressed("ui_down"):
		$StantdingCollisionShape.disabled = true
		$CrouchCollisionShape.disabled = false
	if Input.is_action_just_released("ui_down") or !Input.is_action_pressed("ui_down"):
		$CrouchCollisionShape.disabled = true
		$StantdingCollisionShape.disabled = false
		set_state(PlayerState.IDLE)
		return
	

func sliding_state(delta): #Not finished
	var direction = Input.get_axis("ui_left", "ui_right")
	var velocity_direction = sign(velocity.x)
	
	velocity.x = direction *  1000
	
	if Input.is_action_pressed("ui_down"):
		$StantdingCollisionShape.disabled = true
		$SlidingCollisionShape.disabled = false
	if Input.is_action_just_released("ui_down") or !Input.is_action_pressed("ui_down"):
		$SlidingCollisionShape.disabled = true
		$StantdingCollisionShape.disabled = false

	if Input.is_action_just_released("ui_down"):
		set_state(PlayerState.SPEED2)
	

#	Wall Mechanics

func wall_cling_state_r(delta):
	
	GRAVITY = 400
	
	if is_on_floor():
		set_state(PlayerState.IDLE)
		GRAVITY = 1000
	elif !touching_right_wall_all:
		set_state(PlayerState.FALL)
		GRAVITY = 1000
	elif Input.is_action_just_pressed("ui_down"):
		set_state(PlayerState.FALL)
		GRAVITY = 1000
	elif Input.is_action_just_pressed("Jump") and !Input.is_action_pressed("ui_up"):
		velocity.x = -400
		velocity.y = -400
		GRAVITY = 1000
		set_state(PlayerState.WALL_JUMP_R)
	elif Input.is_action_just_pressed("Jump") and Input.is_action_pressed("ui_up"):
		set_state(PlayerState.WALL_CLIMB)
		GRAVITY = 1000

func wall_cling_state_l(delta):
	
	GRAVITY = 400
	
	if is_on_floor():
		set_state(PlayerState.IDLE)
		GRAVITY = 1000
	elif !touching_left_wall_all:
		set_state(PlayerState.FALL)
		GRAVITY = 1000
	elif Input.is_action_just_pressed("ui_down"):
		set_state(PlayerState.FALL)
		GRAVITY = 1000
	elif Input.is_action_just_pressed("Jump") and !Input.is_action_pressed("ui_up"):
		GRAVITY = 1000
		velocity.x = 400
		velocity.y = -400
		set_state(PlayerState.WALL_JUMP_L)
	elif Input.is_action_just_pressed("Jump") and Input.is_action_pressed("ui_up"):
		set_state(PlayerState.WALL_CLIMB)
		GRAVITY = 1000
	

func wall_climb_state(delta):
	pass

func wall_jump_state_r(delta):
	var direction = Input.get_axis("ui_left", "ui_right")
	
	velocity.x += direction * 20
	velocity.x = clamp(velocity.x, -SPEED, SPEED)
	
	if is_on_floor():
		set_state(PlayerState.IDLE)
	elif velocity.y == 0 and !is_on_floor():
		set_state(PlayerState.FALL)

func wall_jump_state_l(delta):
	var direction = Input.get_axis("ui_left", "ui_right")
	
	velocity.x += direction * 20
	velocity.x = clamp(velocity.x, -SPEED, SPEED)
	
	if is_on_floor():
		set_state(PlayerState.IDLE)
	elif velocity.y == 0 and !is_on_floor():
		set_state(PlayerState.FALL)

#	Vaulting & Mantling

func vault_state(delta):
	pass

func mantle_state(delta):
	pass

#	Dropping/Ground Pound



#	Grappling Hook



#	Attacking & Health



#	Slope Physics
