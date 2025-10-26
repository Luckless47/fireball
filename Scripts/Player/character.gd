extends CharacterBody3D

# Camera and Character Mesh
@onready var character_mesh: MeshInstance3D = $Skeleton3D/CharacterMesh
@onready var pivot = $Pivot
@onready var spring_arm: SpringArm3D = $Pivot/SpringArm3D
@onready var skeleton: Skeleton3D = $Skeleton3D

# Animations
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var locomotion_machine = anim_tree.get("parameters/LocoMachine/playback")
@onready var combat_machine = anim_tree.get("parameters/CombatMachine/playback")
var anim_finished: bool = false


# Velocity based speed
const SPEED: float = 200.0
const JUMP_VELOCITY: float = 4.5
var walking: bool = false

# Spell logic
const SPELL_DISTANCE: float = 3.0
const FIREHEADER_SHADER = preload("uid://bf3cbuknktrmk")
const FIREBALL = preload("uid://bxljagwslm262")
var summoned: bool = false
var busy
const FIREBALL_HAND = preload("uid://cmt7lyxs0n1fy")
var zoomed: bool = false
var zoom_distance: float = 0.1
var shoulder_offset := 0.5
@onready var normal_distance: float = spring_arm.spring_length
@onready var normal_offset = 0.0
@onready var fireball_hand = FIREBALL_HAND.instantiate()
@onready var spell_attachment: BoneAttachment3D = $Skeleton3D/CharacterMesh/SpellAttachment
@onready var back_attachment: ModifierBoneTarget3D = $Skeleton3D/BackAttachment

var character_class = "mage"


@export var dodge_speed := 2.0
@export var dodge_check_radius := 5.0
@export var dodge_reaction_time := 0.2
var dodge_direction := Vector3.ZERO
var dodge_timer := 0.0
var speed := 0.5

# Camera
var rotation_x := 0.0
var rotation_y := 0.0
var current_rotation_x := 0.0
var current_rotation_y := 0.0
var smooth_speed := 10.0

var head_idx = -1
var head_rot_x := 0.0
var head_rot_y := 0.0
@export var head_pitch_limit := 45.0 # degrees up/down
@export var head_smooth_speed := 5.0 # higher = snappier
var head_rot_target := Basis() # optional for smooth lerp

# Create a target marker for aiming
var aim_target: Marker3D

const LOOK_DISTANCE: float = 10.0
const ROTATION_SPEED: float = 8.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	anim_tree.set("parameters/CombatBlend/blend_amount", 0.0)
	head_idx = skeleton.find_bone("mixamorig_Head")
func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	if Input.is_action_just_pressed("zoom_toggle"):
		zoomed = true
	if Input.is_action_just_released("zoom_toggle"):
		zoomed = false
	
	var target_length = zoom_distance if zoomed else normal_distance
	spring_arm.spring_length = lerp(spring_arm.spring_length, target_length, delta * 3.0)
	var offset = shoulder_offset if zoomed else normal_offset
	spring_arm.position.x = lerp(spring_arm.position.x, offset, delta * 3.0)
	
	# Handle spell - BACK TO ORIGINAL CODE
	if Input.is_action_just_pressed("summon_fireball"):
		if character_class == "mage":
			summon_fireball(delta)
		if character_class == "swordsman":
			equip_sword()
		
	if Input.is_action_just_pressed("shoot_fireball") and summoned and zoomed:
		spawn_fireball()

	# Get the input direction and handle the movement/deceleration.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# Camera oriented movement
	var cam_basis = spring_arm.global_transform.basis
	var forward = cam_basis.z
	var right = cam_basis.x
	var direction = (right * input_dir.x + forward * input_dir.y).normalized()
	
	if direction and !walking:
		locomotion_machine.travel("start_walk")
		walking = true
		
	elif !direction and walking:
		locomotion_machine.travel("stop_walk")
		walking = false
		
	elif direction and walking and input_dir:
		var target_yaw = atan2(direction.x, direction.z)
		skeleton.rotation.y = lerp_angle(skeleton.rotation.y, target_yaw, delta * smooth_speed)
	
	
	camera_rotation(delta)
	root_motion(delta)

func _unhandled_input(event) -> void:
	if event is InputEventMouseMotion:
		rotation_x -= event.relative.x * 0.003
		rotation_y -= event.relative.y * 0.003
		rotation_y = clamp(rotation_y, deg_to_rad(-70), deg_to_rad(70))
		
		
	
func root_motion(delta: float) -> void:
	var root_pos = anim_tree.get_root_motion_position()
	#var root_rot = anim_tree.get_root_motion_rotation()
	# Apply to root motion
	
	var local_displacement = Vector3(root_pos.x, root_pos.y, root_pos.z) * SPEED
	var mesh_basis = Basis(Vector3.UP, skeleton.rotation.y)
	var world_displacement = mesh_basis * local_displacement
	
	# Scale animation speed to velocity
	#animation_tree.set("parameters/playback_speed", current_speed)
	
	# Apply to character velocity
	velocity.x = world_displacement.x / delta
	velocity.z = world_displacement.z / delta
	move_and_slide()
	
	
func camera_rotation(delta: float) -> void:
	# Camera Rotation
	current_rotation_y = lerp_angle(current_rotation_y, rotation_y, delta * smooth_speed)
	current_rotation_x = lerp_angle(current_rotation_x, rotation_x, delta * smooth_speed)
	
	# Set rotation of pivot (yaw) and spring arm (pitch)
	pivot.rotation.y = current_rotation_x
	spring_arm.rotation.x = current_rotation_y
	
	# Get global position of head bone
	# Get current global head pose
	#var head_pose = skeleton.get_bone_global_pose(head_idx)
#
	## Define target position to look at (camera or player)
	#var target_pos = global_position + Vector3.UP * 1.6
#
	## Construct a look-at basis
	#var look_basis = Basis.looking_at(target_pos - head_pose.origin, Vector3.UP)
#
	## Convert to Euler to clamp pitch
	#var euler = look_basis.get_euler()
	#euler.x = clamp(euler.x, deg_to_rad(-head_pitch_limit), deg_to_rad(head_pitch_limit))
	#look_basis = Basis.from_euler(euler)
#
	## Smoothly interpolate from previous rotation
	#head_rot_target = head_rot_target.slerp(look_basis, delta * head_smooth_speed)
#
	## Apply as global pose override
	#head_pose.basis = head_rot_target
	#skeleton.set_bone_global_pose_override(head_idx, head_pose, 1.0, true)


func summon_fireball(_delta: float) -> void:
	if busy:
		return
		
	busy = true
	
	if !summoned:
		print("summoning")
		
		combat_machine.travel("summon_ball")
		spell_attachment.add_child(fireball_hand)
		fireball_hand.position.y = 0.068
		fireball_hand.position.z = 0.076
		await fade_combat_blend_in()
		anim_tree.set("parameters/TimeScale/scale", 0.5)
		summoned = true
	else:
		anim_tree.set("parameters/TimeScale/scale", 1.0)
		combat_machine.travel("unsummon_ball")
		await wait_for_state_enter("unsummon_ball")
		await get_tree().create_timer(0.7).timeout
		spell_attachment.remove_child(fireball_hand)
		await fade_combat_blend_out()
		summoned = false
		
	busy = false


func spawn_fireball() -> void:
	
	if busy:
		return
	busy = true
	combat_machine.travel("cast_ball")
	anim_tree.set("parameters/TimeScale/scale", 1.5)
	await wait_for_state_enter("cast_ball")
	await get_tree().create_timer(0.39).timeout
	var fireball_dir = -spring_arm.global_transform.basis.z.normalized()
	var fireball_pitch = spring_arm.rotation.x

	# Spawn the fireball
	var fireball = FIREBALL.instantiate()
	get_tree().current_scene.add_child(fireball)
	
	# Get hand bone
	
	# Set position in front of player and set direction according to player camera
	fireball.global_position = spell_attachment.global_position + fireball_dir * 0.5
	#fireball.global_position.y += 1
	#fireball.global_position.x += 0.5
	fireball.direction = fireball_dir

	# Rotate parent (yaw)
	fireball.rotation.y = atan2(fireball_dir.x, fireball_dir.z)

	# Rotate VFX child so its local Z points along the fireball direction
	var vfx = fireball.get_node("VFX_Fireball") # Node3D
	
	vfx.rotate_y(deg_to_rad(-90))
	vfx.rotate_x(-fireball_pitch)
	
	await wait_for_state_exit("cast_ball")
	anim_tree.set("parameters/TimeScale/scale", 0.5)
	
	busy = false


func equip_sword():
	if !summoned:
		var sword = back_attachment.get_children()[0]
		back_attachment.remove_child(sword)
		spell_attachment.add_child(sword)
		summoned = true
	else:
		var sword = spell_attachment.get_children()[0]
		spell_attachment.remove_child(sword)
		back_attachment.add_child(sword)
		summoned = false
		



func wait_for_state_enter(state_name: String) -> void:
	while !(combat_machine.get_current_node() == state_name):
		await get_tree().process_frame
		
func wait_for_state_exit(state_name: String) -> void:
	while combat_machine.get_current_node() == state_name:
		await get_tree().process_frame
		
func fade_combat_blend_out():
	var blend = anim_tree.get("parameters/CombatBlend/blend_amount")
	while blend > 0.01:
		blend -= 1.5 * get_process_delta_time()
		blend = max(blend, 0.0)
		anim_tree.set("parameters/CombatBlend/blend_amount", blend)
		await get_tree().process_frame
	anim_tree.set("parameters/CombatBlend/blend_amount", 0.0)
		

func fade_combat_blend_in():
	var blend = anim_tree.get("parameters/CombatBlend/blend_amount")
	while blend < 0.99:
		blend = lerp(blend, 1.0, get_process_delta_time() * 3.0)
		anim_tree.set("parameters/CombatBlend/blend_amount", blend)
		await get_tree().process_frame
	anim_tree.set("parameters/CombatBlend/blend_amount", 1.0)
	
	
