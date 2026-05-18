extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
var GRAVITY = 1000
var next_wall_climb := 0.0

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

#The GOAT

var start_action := false
var timer_variable = 0

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
	WALL_CLIMB_L,
	WALL_CLIMB_L2,
	WALL_CLIMB_L3,
	WALL_CLIMB_R,
	WALL_CLIMB_R2,
	WALL_CLIMB_R3, #Holding jump on a wall will have you climb for a short while
	WALL_JUMP_L,
	WALL_JUMP_R, #Pressing jump for 
	VAULT_L,
	VAULT_R, #Don't worry abt these for rn, I'll get to it
	MANTLE_L,
	MANTLE_R, #Same goes for this one
	SWING, #Swing on monkey bars or other objects
	ROLL, #Cancel fall damage
	
	#Grappling
	GRAPPLE_START,
	GRAPPLE_DETECT_R,
	GRAPPLE_DETECT_L,
	GRAPPLE_DETECT_U,
	GRAPPLE_DETECT_D,
	GRAPPLE_DETECT_RD,
	GRAPPLE_DETECT_LD,
	GRAPPLE_DETECT_LU,
	GRAPPLE_DETECT_RU,
	GRAPPLE_ZIP,
	GRAPPLE_SWING,
	GRAPPLE_MISS,
	
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
		PlayerState.WALL_CLIMB_L:
			wall_climb_state_l1(delta)
		PlayerState.WALL_CLIMB_L2:
			wall_climb_state_l2(delta)
		PlayerState.WALL_CLIMB_L3:
			wall_climb_state_l3(delta)
		PlayerState.WALL_CLIMB_R:
			wall_climb_state_r1(delta)
		PlayerState.WALL_CLIMB_R2:
			wall_climb_state_r2(delta)
		PlayerState.WALL_CLIMB_R3:
			wall_climb_state_r3(delta)
		PlayerState.WALL_JUMP_L:
			wall_jump_state_l(delta)
		PlayerState.WALL_JUMP_R:
			wall_jump_state_r(delta)
		PlayerState.VAULT_L:
			vault_state_l(delta)
		PlayerState.VAULT_R:
			vault_state_r(delta)
		PlayerState.MANTLE_L:
			mantle_state_l(delta)
		PlayerState.MANTLE_R:
			mantle_state_r(delta)
		PlayerState.GRAPPLE_START:
			grapple_start_state(delta)
		PlayerState.GRAPPLE_DETECT_R:
			grapple_detection_r(delta)
		PlayerState.GRAPPLE_DETECT_L:
			grapple_detection_l(delta)
		PlayerState.GRAPPLE_DETECT_U:
			grapple_detection_u(delta)
		PlayerState.GRAPPLE_DETECT_D:
			grapple_detection_d(delta)
		PlayerState.GRAPPLE_DETECT_RD:
			grapple_detection_rd(delta)
		PlayerState.GRAPPLE_DETECT_LD:
			grapple_detection_ld(delta)
		PlayerState.GRAPPLE_DETECT_LU:
			grapple_detection_lu(delta)
		PlayerState.GRAPPLE_DETECT_RU:
			grapple_detection_ru(delta)
		PlayerState.GRAPPLE_ZIP:
			grapple_zip_state(delta)
		
	

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
		PlayerState.WALL_CLIMB_L:
			print("WALL CLIMB")
		PlayerState.WALL_CLIMB_R:
			print("WALL CLIMB")
		PlayerState.VAULT_L:
			print("VAULT")
		PlayerState.VAULT_R:
			print("VAULT")
		PlayerState.MANTLE_L:
			print("MANTLE")
		PlayerState.MANTLE_R:
			print("MANTLE")
		PlayerState.GRAPPLE_ZIP:
			print("GRAPPLE")
		
	

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
	elif Input.is_action_pressed("Grapple"):
		set_state(PlayerState.GRAPPLE_START)
	

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
	elif Input.is_action_just_pressed("Grapple"):
		set_state(PlayerState.GRAPPLE_START)
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
		GRAVITY = 1000
		start_action = true
		set_state(PlayerState.WALL_CLIMB_R)
		

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
		GRAVITY = 1000
		start_action = true
		set_state(PlayerState.WALL_CLIMB_L)
		
	

func wall_climb_state_l1(delta):
	velocity.x = 0
	
	if start_action == true:
		velocity.y = -500
		start_action = false
	
	if touching_left_wall_all:
		if (next_wall_climb < 0.5):
			next_wall_climb += get_process_delta_time()
		elif (next_wall_climb >= 0.5):
			next_wall_climb = 0
			start_action = true
			set_state(PlayerState.WALL_CLIMB_L2)
	elif touching_left_wall_bottom_half:
		set_state(PlayerState.VAULT_L)
	elif !touching_left_wall_all and !touching_left_wall_bottom_half:
		set_state(PlayerState.FALL)

func wall_climb_state_l2(delta):
	velocity.x = 0
	
	if start_action == true:
		velocity.y = -500
		start_action = false
	
	if touching_left_wall_all:
		if (next_wall_climb < 0.5):
			next_wall_climb += get_process_delta_time()
		elif (next_wall_climb >= 0.5):
			next_wall_climb = 0
			start_action = true
			set_state(PlayerState.WALL_CLIMB_L3)
	elif touching_left_wall_bottom_half:
		set_state(PlayerState.VAULT_L)
	elif !touching_left_wall_all and !touching_left_wall_bottom_half:
		set_state(PlayerState.FALL)

func wall_climb_state_l3(delta):
	velocity.x = 0
	
	if start_action == true:
		velocity.y = -500
		start_action = false
	
	if touching_left_wall_all:
		if (next_wall_climb < 0.5):
			next_wall_climb += get_process_delta_time()
		elif (next_wall_climb >= 0.5):
			next_wall_climb = 0
			start_action = true
			set_state(PlayerState.FALL)
	elif touching_left_wall_bottom_half:
		set_state(PlayerState.VAULT_L)
	elif !touching_left_wall_all and !touching_left_wall_bottom_half:
		set_state(PlayerState.FALL)

func wall_climb_state_r1(delta):
	velocity.x = 0
	
	if start_action == true:
		velocity.y = -500
		start_action = false
	
	if touching_right_wall_all:
		if (next_wall_climb < 0.5):
			next_wall_climb += get_process_delta_time()
		elif (next_wall_climb >= 0.5):
			next_wall_climb = 0
			start_action = true
			set_state(PlayerState.WALL_CLIMB_R2)
	elif touching_right_wall_bottom_half:
		set_state(PlayerState.VAULT_R)
	elif !touching_right_wall_all and !touching_right_wall_bottom_half:
		set_state(PlayerState.FALL)

func wall_climb_state_r2(delta):
	velocity.x = 0
	
	if start_action == true:
		velocity.y = -500
		start_action = false
	
	if touching_right_wall_all:
		if (next_wall_climb < 0.5):
			next_wall_climb += get_process_delta_time()
		elif (next_wall_climb >= 0.5):
			next_wall_climb = 0
			start_action = true
			set_state(PlayerState.WALL_CLIMB_R3)
	elif touching_right_wall_bottom_half:
		set_state(PlayerState.VAULT_R)
	elif !touching_right_wall_all and !touching_right_wall_bottom_half:
		set_state(PlayerState.FALL)

func wall_climb_state_r3(delta):
	velocity.x = 0
	
	if start_action == true:
		velocity.y = -500
		start_action = false
	
	if touching_right_wall_all:
		if (next_wall_climb < 0.5):
			next_wall_climb += get_process_delta_time()
		elif (next_wall_climb >= 0.5):
			next_wall_climb = 0
			start_action = true
			set_state(PlayerState.FALL)
	elif touching_right_wall_bottom_half:
		set_state(PlayerState.FALL)
	elif !touching_right_wall_all and !touching_right_wall_bottom_half:
		set_state(PlayerState.FALL)

func wall_climb_state1(delta):
	velocity.y += -400
	velocity.x = 0
	
	if is_on_floor():
		set_state(PlayerState.IDLE)
	if !Input.is_action_pressed("Jump"):
		set_state(PlayerState.FALL)
	elif touching_left_wall_bottom_half:
		set_state(PlayerState.VAULT_L)
	elif touching_right_wall_bottom_half:
		set_state(PlayerState.VAULT_R)
	elif Input.is_action_just_pressed("Jump") and touching_left_wall_all:
		set_state(PlayerState.WALL_JUMP_L)
	elif Input.is_action_just_pressed("Jump") and touching_right_wall_all:
		set_state(PlayerState.WALL_JUMP_R)
	elif !Input.is_action_pressed("ui_up"):
		set_state(PlayerState.FALL)
	elif Input.is_action_pressed("ui_up"):
		pass
		#velocity.y = -400
	

func wall_jump_state_r(delta):
	var direction = Input.get_axis("ui_left", "ui_right")
	
	velocity.x += direction * 20
	velocity.x = clamp(velocity.x, -SPEED, SPEED)
	
	if touching_right_wall_all == true:
		set_state(PlayerState.WALL_CLING_R)
	elif touching_left_wall_all == true:
		set_state(PlayerState.WALL_CLING_L)
	elif is_on_floor():
		set_state(PlayerState.IDLE)
	elif velocity.y == 0 and !is_on_floor():
		set_state(PlayerState.FALL)

func wall_jump_state_l(delta):
	var direction = Input.get_axis("ui_left", "ui_right")
	
	velocity.x += direction * 20
	velocity.x = clamp(velocity.x, -SPEED, SPEED)
	
	if touching_right_wall_all == true:
		set_state(PlayerState.WALL_CLING_R)
	elif touching_left_wall_all == true:
		set_state(PlayerState.WALL_CLING_L)
	elif is_on_floor():
		set_state(PlayerState.IDLE)
	elif velocity.y == 0 and !is_on_floor():
		set_state(PlayerState.FALL)
	

#	Vaulting & Mantling

func vault_state_l(delta):
	pass

func vault_state_r(delta):
	pass

func mantle_state_l(delta):
	pass

func mantle_state_r(delta):
	pass

#	Grappling Hook

func grapple_start_state(delta):
	var right_pressed = Input.is_action_pressed("ui_right")
	var left_pressed = Input.is_action_pressed("ui_left")
	var up_pressed = Input.is_action_pressed("ui_up")
	var down_pressed = Input.is_action_pressed("ui_down")
	
	
	if right_pressed and !left_pressed and !up_pressed and !down_pressed:
		set_state(PlayerState.GRAPPLE_DETECT_R)
	elif left_pressed and !right_pressed and !up_pressed and !down_pressed:
		set_state(PlayerState.GRAPPLE_DETECT_L)
	elif up_pressed and !right_pressed and !left_pressed and !down_pressed:
		set_state(PlayerState.GRAPPLE_DETECT_U)
	elif down_pressed and !right_pressed and !left_pressed and !up_pressed:
		set_state(PlayerState.GRAPPLE_DETECT_D)
	elif right_pressed and up_pressed and !left_pressed and !down_pressed:
		set_state(PlayerState.GRAPPLE_DETECT_RU)
	elif right_pressed and down_pressed and !left_pressed and !up_pressed:
		set_state(PlayerState.GRAPPLE_DETECT_RD)
	elif left_pressed and up_pressed and !right_pressed and !down_pressed:
		set_state(PlayerState.GRAPPLE_DETECT_LU)
	elif left_pressed and down_pressed and !up_pressed and !right_pressed:
		set_state(PlayerState.GRAPPLE_DETECT_LD)

func grapple_detection_r(delta):
	$Grapple/DetectionR.enabled = true
	
	if $Grapple/DetectionR.is_colliding():
		velocity.x = 500
		velocity.y = 0
		set_state(PlayerState.GRAPPLE_ZIP)
	elif !$Grapple/DetectionR.is_colliding():
		set_state(PlayerState.GRAPPLE_MISS)

func grapple_detection_l(delta):
	$Grapple/DetectionL.enabled = true
	
	if $Grapple/DetectionL.is_colliding():
		velocity.x = -500
		velocity.y = 0
		set_state(PlayerState.GRAPPLE_ZIP)
	elif !$Grapple/DetectionL.is_colliding():
		set_state(PlayerState.GRAPPLE_MISS)

func grapple_detection_u(delta):
	$Grapple/DetectionU.enabled = true
	
	if $Grapple/DetectionU.is_colliding():
		velocity.x = 0
		velocity.y = -500
		set_state(PlayerState.GRAPPLE_ZIP)
	elif !$Grapple/DetectionU.is_colliding():
		set_state(PlayerState.GRAPPLE_MISS)

func grapple_detection_d(delta):
	$Grapple/DetectionD.enabled = true
	
	if $Grapple/DetectionD.is_colliding():
		velocity.x = 0
		velocity.y = 500
		set_state(PlayerState.GRAPPLE_ZIP)
	elif !$Grapple/DetectionD.is_colliding():
		set_state(PlayerState.GRAPPLE_MISS)

func grapple_detection_rd(delta):
	$Grapple/DetectionRD.enabled = true
	
	if $Grapple/DetectionRD.is_colliding():
		velocity.x = 500
		velocity.y = 500
		set_state(PlayerState.GRAPPLE_ZIP)
	elif !$Grapple/DetectionRD.is_colliding():
		set_state(PlayerState.GRAPPLE_MISS)

func grapple_detection_ru(delta):
	$Grapple/DetectionRU.enabled = true
	
	if $Grapple/DetectionRU.is_colliding():
		velocity.x = 500
		velocity.y = -500
		set_state(PlayerState.GRAPPLE_ZIP)
	elif !$Grapple/DetectionRU.is_colliding():
		set_state(PlayerState.GRAPPLE_MISS)

func grapple_detection_ld(delta):
	$Grapple/DetectionLD.enabled = true
	
	if $Grapple/DetectionLD.is_colliding():
		velocity.x = -500
		velocity.y = 500
		set_state(PlayerState.GRAPPLE_ZIP)
	elif !$Grapple/DetectionLD.is_colliding():
		$Grapple/DetectionLD.enabled = false

func grapple_detection_lu(delta):
	$Grapple/DetectionLU.enabled = true
	
	if $Grapple/DetectionLU.is_colliding():
		velocity.x = -500
		velocity.y = -500
		set_state(PlayerState.GRAPPLE_ZIP)
	elif !$Grapple/DetectionLU.is_colliding():
		$Grapple/DetectionLU.enabled = false
	

func grapple_zip_state(delta):
	velocity.x = velocity.x
	velocity.y = velocity.y
	
	if (timer_variable < 0.5):
		timer_variable += get_process_delta_time()
	elif (timer_variable >= 0.5):
		timer_variable = 0
		GRAVITY = 1000
		set_state(PlayerState.FALL)
	
	if touching_left_wall_all:
		GRAVITY = 1000
		set_state(PlayerState.WALL_CLING_L)
	if touching_right_wall_all:
		GRAVITY = 1000
		set_state(PlayerState.WALL_CLING_R)
	
	
	GRAVITY = 0

#	Attacking & Health



#	Slope Physics (maybe)
