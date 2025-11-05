extends CharacterBody3D

## Camera and Character Mesh
@onready var character_mesh: MeshInstance3D = $Skeleton3D/CharacterMesh
@onready var pivot = $Pivot
@onready var spring_arm: SpringArm3D = $Pivot/SpringArm3D

## Skeleton
@onready var skeleton: Skeleton3D = $Skeleton3D
@onready var spell_attachment: BoneAttachment3D = $Skeleton3D/SpellAttachment
@onready var back_attachment: BoneAttachment3D = $Skeleton3D/BackAttachment


## Camera zoom
var zoomed: bool = false
var zoom_distance: float = 0.1
var shoulder_offset := 0.5
var normal_offset = 0.0
@onready var normal_distance: float = spring_arm.spring_length

## Camera rotation
var rotation_x := 0.0
var rotation_y := 0.0
var current_rotation_x := 0.0
var current_rotation_y := 0.0
var smooth_speed := 10.0


## Animations
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var lower_statemachine: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/LowerStateMachine/playback")

## Locomotion and velocity
const SPEED: float = 5.0
const JUMP_VELOCITY: float = 4.5
var walking: bool = false

## Spell logic
const SPELL_DISTANCE: float = 3.0
const FIREHEADER_SHADER = preload("uid://bf3cbuknktrmk")
const FIREBALL = preload("uid://bxljagwslm262")
const FIREBALL_HAND = preload("uid://cmt7lyxs0n1fy")
@onready var fireball_hand = FIREBALL_HAND.instantiate()

## Cooldown for weapon use and state changes
var equipped: bool = false
var busy

## Classes
var character_class = "magic"


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	
	handle_input(delta)
	
	handle_movement_and_animation(delta)
	
	camera_rotation(delta)
	
	move_and_slide()

	

## Mouse x,y axis movement stored in a rotation variable
func _unhandled_input(event) -> void:
	if event is InputEventMouseMotion:
		rotation_x -= event.relative.x * 0.003
		rotation_y -= event.relative.y * 0.003
		rotation_y = clamp(rotation_y, deg_to_rad(-70), deg_to_rad(70))
		

func handle_input(delta) -> void:
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	if Input.is_action_just_pressed("attack") and equipped and zoomed:
		cast_fireball()
	
	if Input.is_action_just_pressed("equip"):
		
		if character_class == "magic":
			equip_fireball(delta)
			
		elif character_class == "swordsman":
			equip_sword()
			
	if Input.is_action_just_pressed("zoom_toggle"):
		zoomed = true
		
	if Input.is_action_just_released("zoom_toggle"):
		zoomed = false
	
	handle_zoom(delta)
	

func handle_zoom(delta):
	var target_length = zoom_distance if zoomed else normal_distance
	spring_arm.spring_length = lerp(spring_arm.spring_length, target_length, delta * 3.0)
	var offset = shoulder_offset if zoomed else normal_offset
	spring_arm.position.x = lerp(spring_arm.position.x, offset, delta * 3.0)

	
## Rotate camera based on mouse movements
func camera_rotation(delta: float) -> void:
	# Camera Rotation
	current_rotation_y = lerp_angle(current_rotation_y, rotation_y, delta * smooth_speed)
	current_rotation_x = lerp_angle(current_rotation_x, rotation_x, delta * smooth_speed)
	
	# Set rotation of pivot (yaw) and spring arm (pitch)
	pivot.rotation.y = current_rotation_x
	spring_arm.rotation.x = current_rotation_y

func handle_movement_and_animation(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_backward", "move_forward")
	var movement: String
	
	# Determine movement prefix
	if !equipped:
		movement = "movement"
	else:
		movement = character_class
	
	if busy:
		return
	
	# --- Animation state handling ---
	if input_dir == Vector2.ZERO:
		lower_statemachine.travel("%s_Idle" % [movement])
	else:
		# Determine direction from input
		if abs(input_dir.x) > abs(input_dir.y):
			if input_dir.x > 0:
				lower_statemachine.travel("%s_Right_Turn" % [movement])
			else:
				lower_statemachine.travel("%s_Left_Turn" % [movement])
		else:
			if input_dir.y > 0:
				lower_statemachine.travel("%s_Walk_Forward" % [movement])
			else:
				lower_statemachine.travel("%s_Walk_Backwards" % [movement])
	
	
	# --- Movement direction and rotation ---
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction != Vector3.ZERO:
		# Fix atan2 argument order (z for forward)
		var target_yaw = atan2(direction.x, direction.z)
		skeleton.rotation.y = lerp_angle(skeleton.rotation.y, target_yaw, delta * 10.0)
		
		# Smooth velocity acceleration
		var target_velocity = direction * 3.0
		velocity = velocity.lerp(target_velocity, 6.0 * delta)
	else:
		# Smooth deceleration
		velocity = velocity.lerp(Vector3.ZERO, 4.0 * delta)

	

func equip_fireball(_delta: float) -> void:
	if busy: return
	else: busy = true
	
	if !equipped:
			# Travel to magic_idle in state machine
		
		# Place fireball to characters hand
		spell_attachment.add_child(fireball_hand)
		fireball_hand.position.y = 0.068
		fireball_hand.position.z = 0.076
		
		#await fade_combat_blend_in()
		
		#anim_tree.set("parameters/TimeScale/scale", 0.5)
		
		equipped = true
		
	else:
		#animation_tree.set("parameters/TimeScale/scale", 1.0)
		
		#await wait_for_state_enter("unsummon_ball")
		#await get_tree().create_timer(0.7).timeout
		
		spell_attachment.remove_child(fireball_hand)
		
		#await fade_combat_blend_out()
		
		equipped = false
		
	busy = false


func equip_sword():
	if !equipped:
		var sword = back_attachment.get_children()[0]
		back_attachment.remove_child(sword)
		spell_attachment.add_child(sword)
		equipped = true
	else:
		var sword = spell_attachment.get_children()[0]
		spell_attachment.remove_child(sword)
		back_attachment.add_child(sword)
		equipped = false

func cast_fireball() -> void:
	if busy: return
	else: busy = true
	
	lower_statemachine.travel("magic_2H")
	#animation_tree.set("parameters/TimeScale/scale", 1.5)
	#await wait_for_state_enter("cast_ball")
	#await get_tree().create_timer(0.39).timeout
	var fireball_dir = -spring_arm.global_transform.basis.z.normalized()
	var fireball_pitch = spring_arm.rotation.x

	# Spawn the fireball
	var fireball = FIREBALL.instantiate()
	get_tree().current_scene.add_child(fireball)
	
	# Attach spell to hand and place at offset
	fireball.global_position = spell_attachment.global_position + fireball_dir * 0.5
	fireball.direction = fireball_dir

	# Rotate parent (yaw)
	fireball.rotation.y = atan2(fireball_dir.x, fireball_dir.z)

	# Rotate VFX node3D child so its local Z points along the fireball direction
	var vfx = fireball.get_node("VFX_Fireball")
	vfx.rotate_y(deg_to_rad(-90))
	vfx.rotate_x(-fireball_pitch)
	
	#await wait_for_state_exit("cast_ball")
	#animation_tree.set("parameters/TimeScale/scale", 0.5)
	
	busy = false


	
	
