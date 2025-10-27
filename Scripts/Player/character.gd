extends CharacterBody3D

## Camera and Character Mesh
@onready var character_mesh: MeshInstance3D = $Skeleton3D/CharacterMesh
@onready var pivot = $Pivot
@onready var spring_arm: SpringArm3D = $Pivot/SpringArm3D

## Skeleton
@onready var skeleton: Skeleton3D = $Skeleton3D
@onready var spell_attachment: BoneAttachment3D = $Skeleton3D/CharacterMesh/SpellAttachment
@onready var back_attachment: ModifierBoneTarget3D = $Skeleton3D/BackAttachment

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
# Camera rotation to Character Rotation
var direction


## Animations
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var locomotion_machine = anim_tree.get("parameters/LocoMachine/playback")
@onready var combat_machine = anim_tree.get("parameters/CombatMachine/playback")

## Locomotion and velocity
const SPEED: float = 200.0
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
var character_class = "swordsman"


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Animation Tree
	anim_tree.set("parameters/CombatBlend/blend_amount", 0.0)
	anim_tree.root_motion_track = NodePath("Skeleton3D:mixamorig_Hips")
	
	
func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# Handle aiming
	handle_zoom(delta)

	# Handle equip
	handle_equip(delta)
	
	if Input.is_action_just_pressed("attack") and equipped and zoomed:
		cast_fireball()

	# Camera oriented movement
	orient_cam_to_movement_direction(delta)
	
	handle_animation()
	
	camera_rotation(delta)
	
	root_motion(delta)


## Mouse x,y axis movement stored in a rotation variable
func _unhandled_input(event) -> void:
	if event is InputEventMouseMotion:
		rotation_x -= event.relative.x * 0.003
		rotation_y -= event.relative.y * 0.003
		rotation_y = clamp(rotation_y, deg_to_rad(-70), deg_to_rad(70))
		

func handle_zoom(delta):
	if Input.is_action_just_pressed("zoom_toggle"):
		zoomed = true
	if Input.is_action_just_released("zoom_toggle"):
		zoomed = false
	
	var target_length = zoom_distance if zoomed else normal_distance
	spring_arm.spring_length = lerp(spring_arm.spring_length, target_length, delta * 3.0)
	var offset = shoulder_offset if zoomed else normal_offset
	spring_arm.position.x = lerp(spring_arm.position.x, offset, delta * 3.0)

func handle_equip(delta):
	if Input.is_action_just_pressed("equip"):
		if character_class == "mage":
			equip_fireball(delta)
		if character_class == "swordsman":
			equip_sword()

func root_motion(delta: float) -> void:
	var root_pos = anim_tree.get_root_motion_position()
	var local_displacement = Vector3(root_pos.x, root_pos.y, root_pos.z) * SPEED
	var mesh_basis = Basis(Vector3.UP, skeleton.rotation.y)
	var world_displacement = mesh_basis * local_displacement
	
	# Scale animation speed to velocity
	#animation_tree.set("parameters/playback_speed", current_speed)
	
	# Apply to character velocity
	velocity.x = world_displacement.x / delta
	velocity.z = world_displacement.z / delta
	
	move_and_slide()
	
## Rotate camera based on mouse movements
func camera_rotation(delta: float) -> void:
	# Camera Rotation
	current_rotation_y = lerp_angle(current_rotation_y, rotation_y, delta * smooth_speed)
	current_rotation_x = lerp_angle(current_rotation_x, rotation_x, delta * smooth_speed)
	
	# Set rotation of pivot (yaw) and spring arm (pitch)
	pivot.rotation.y = current_rotation_x
	spring_arm.rotation.x = current_rotation_y

func orient_cam_to_movement_direction(delta):
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var cam_basis = spring_arm.global_transform.basis
	var forward = cam_basis.z
	var right = cam_basis.x
	direction = (right * input_dir.x + forward * input_dir.y).normalized()
	
	if direction and walking:
		var target_yaw = atan2(direction.x, direction.z)
		skeleton.rotation.y = lerp_angle(skeleton.rotation.y, target_yaw, delta * smooth_speed)

func handle_animation():
	if direction and !walking:
		locomotion_machine.travel("start_walk")
		walking = true
		
	elif !direction and walking:
		locomotion_machine.travel("stop_walk")
		walking = false

func equip_fireball(_delta: float) -> void:
	if busy: return
	else: busy = true
	
	if !equipped:
		combat_machine.travel("summon_ball")
		
		spell_attachment.add_child(fireball_hand)
		fireball_hand.position.y = 0.068
		fireball_hand.position.z = 0.076
		
		await fade_combat_blend_in()
		
		anim_tree.set("parameters/TimeScale/scale", 0.5)
		
		equipped = true
		
	else:
		anim_tree.set("parameters/TimeScale/scale", 1.0)
		combat_machine.travel("unsummon_ball")
		await wait_for_state_enter("unsummon_ball")
		await get_tree().create_timer(0.7).timeout
		
		spell_attachment.remove_child(fireball_hand)
		
		await fade_combat_blend_out()
		
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
	
	combat_machine.travel("cast_ball")
	anim_tree.set("parameters/TimeScale/scale", 1.5)
	await wait_for_state_enter("cast_ball")
	await get_tree().create_timer(0.39).timeout
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
	
	await wait_for_state_exit("cast_ball")
	anim_tree.set("parameters/TimeScale/scale", 0.5)
	
	busy = false


## Animation Tree helper functions

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
	
	
