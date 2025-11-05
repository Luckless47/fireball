extends CharacterBody3D
#
#@export var dodge_speed := 2.0
#@export var dodge_check_radius := 5.0
#@export var dodge_reaction_time := 0.2
#var dodge_direction := Vector3.ZERO
#var dodge_timer := 0.0
#
#var speed := 0.5
#var direction: Vector3 = Vector3.ZERO
#var walking: bool = false
#var smooth_speed := 10.0
#
#@onready var player: CharacterBody3D = $"../Player"
#@onready var animation_tree: AnimationTree = $AnimationTree
#@onready var lower_machine = animation_tree.get("parameters/LowerMachine/playback")
#@onready var upper_machine = animation_tree.get("parameters/UpperMachine/playback")
#@onready var skeleton: Skeleton3D = $Skeleton3D
#@onready var spell_attachment: BoneAttachment3D = $Skeleton3D/SpellAttachment
#
#const FIREBALL = preload("uid://bxljagwslm262")
#const FIREBALL_HAND = preload("uid://cmt7lyxs0n1fy")
#@onready var fireball_hand = FIREBALL_HAND.instantiate()
#
#
#var health: int = 100
#var _previous_health: int = 100
#var chasing: bool = false
#var equipped: bool = false
#var character_class = "mage"
#var busy: bool = false
#
#func _ready() -> void:
	## Randomize timer to stagger enemy updates
	##dodge_timer = randf() * dodge_reaction_time
	#
	#animation_tree.root_motion_track = NodePath("Skeleton3D:mixamorig8_Hips")
#
#func _physics_process(delta: float) -> void:
	## Remove hp and queue_free() if hp is 0
	#health_check()
	#
	## Gravity
	#if not is_on_floor():
		#velocity += get_gravity() * delta
	#
	## Follow player if within distance
	#chase_player()
	#
	#handle_equip()
	#
	##attack_player(delta)
	#
	## Plays walking/running animations
	#animate_movement()
	#
	## Rotates character based on direction of player
	#directional_rotation(delta)
	#
	## Takes root motion of animations and applies it to velocity
	#apply_root_motion(delta)
	#
	## WIP
	##dodge(delta)
	#
	## Default godot function for node type character movement
	#move_and_slide()
#
#
### Helper Functions
#
#func health_check() -> void:
	#if health != _previous_health:
		#print("enemy hit for ", _previous_health - health)
		#_previous_health = health
		#if health <= 0:
			#print("enemy died")
			#queue_free()
#
#func chase_player() -> void:
	#var to_player = (player.global_position - global_position).length()
	#
	#if to_player <= 15.0 and to_player >= 5.0:
		#direction = (player.global_position - global_position).normalized()
		#chasing = true
		#
	#else: 
		#direction = Vector3.ZERO
		#chasing = false
#
#func handle_equip():
	#if chasing and !equipped:
		#equip_fireball()
	#elif !chasing and equipped:
		#unequip_fireball()
		#
#
##func attack_player():
	##if chasing and equipped:
		##
#
#func equip_fireball():
	#if busy: return
	#else: busy = true
	#
	#if !equipped:
		#upper_machine.travel("summon_ball")
		#
		#spell_attachment.add_child(fireball_hand)
		#fireball_hand.position.y = 0.068
		#fireball_hand.position.z = 0.076
		#
		#await fade_combat_blend_in()
		#
		#animation_tree.set("parameters/TimeScale/scale", 0.5)
		#
		#equipped = true
		#
	#busy = false
#
#func unequip_fireball():
	#if busy: return
	#else: busy = true
	#
	#if equipped:
		#animation_tree.set("parameters/TimeScale/scale", 1.0)
		#upper_machine.travel("unsummon_ball")
		#await wait_for_state_enter("unsummon_ball")
		#await get_tree().create_timer(0.7).timeout
		#
		#spell_attachment.remove_child(fireball_hand)
		#
		#await fade_combat_blend_out()
		#equipped = false
		#
	#busy = false
#
#func animate_movement() -> void:
	#if direction != Vector3.ZERO and !walking:
		#lower_machine.travel("start_walk")
		#walking = true
		#
	#elif direction == Vector3.ZERO and walking:
		#lower_machine.travel("stop_walk")
		#walking = false
#
#func directional_rotation(delta: float) -> void:
	#if direction != Vector3.ZERO:
		#var target_yaw = atan2(direction.x, direction.z)
		#rotation.y = lerp_angle(rotation.y, target_yaw, delta * smooth_speed)
#
#func apply_root_motion(delta: float) -> void:
	#if walking:
		#var root_motion = animation_tree.get_root_motion_position()
		#velocity = (Basis(Vector3.UP, rotation.y) * root_motion) / delta * 3.0
	#else:
		#velocity = Vector3.ZERO
#
#func dodge(delta: float) -> void:
	#dodge_timer -= delta
	#
	## Reassess threats periodically
	#if dodge_timer <= 0:
		#
		#dodge_timer = dodge_reaction_time
		#
		#if randf() < .25:
			#dodge_direction = _calculate_dodge()
		#else:
			#dodge_direction = Vector3.ZERO
	#
	## Apply dodge movement
	#if dodge_direction != Vector3.ZERO:
		#velocity.x = dodge_direction.x * dodge_speed
		#velocity.z = dodge_direction.z * dodge_speed
	#else:
		## Decelerate when not dodging
		#velocity.x = move_toward(velocity.x, 0, dodge_speed * 5 * delta)
		#velocity.z = move_toward(velocity.z, 0, dodge_speed * 5 * delta)
	#
	#velocity += get_gravity() * delta
	#
#func _calculate_dodge() -> Vector3:
	#var closest_distance := INF
	#var best_dodge := Vector3.ZERO
	#
	#var projectiles = get_tree().get_nodes_in_group("projectiles")
	#
	#for fireball in projectiles:
		#if fireball == null or not is_instance_valid(fireball):
			#continue
		#
		#if fireball.is_queued_for_deletion():
			#continue
		#
		## Skip if already hit
		#if "has_hit" in fireball and fireball.has_hit:
			#continue
		#
		#var to_fireball = fireball.global_position - global_position
		#var distance = to_fireball.length()
		#
		## Only care about nearby threats
		#if distance >= dodge_check_radius:
			#continue
		#
		## Check if fireball is heading toward us
		#var fireball_direction = fireball.direction.normalized()
		#var to_us = -to_fireball.normalized()
		#var heading_toward_us = fireball_direction.dot(to_us)
		#
		## If fireball is moving toward us (dot > 0.5 means within ~60 degrees)
		#if heading_toward_us > 0.5 and distance < closest_distance:
			#closest_distance = distance
			## Dodge perpendicular to the fireball's path
			#best_dodge = fireball_direction.cross(Vector3.UP).normalized()
			#
			## Optional: pick left or right based on current position
#
			#var right_side = fireball_direction.cross(Vector3.UP).normalized()
			#var our_offset = (global_position - fireball.global_position).normalized()
			#if our_offset.dot(right_side) < 0:
				#best_dodge = -best_dodge
	#
	#return best_dodge
#
#
#func wait_for_state_enter(state_name: String) -> void:
	#while !(upper_machine.get_current_node() == state_name):
		#await get_tree().process_frame
		#
#func wait_for_state_exit(state_name: String) -> void:
	#while upper_machine.get_current_node() == state_name:
		#await get_tree().process_frame
		#
#func fade_combat_blend_out():
	#var blend = animation_tree.get("parameters/UpperBlend/blend_amount")
	#while blend > 0.01:
		#blend -= 1.5 * get_process_delta_time()
		#blend = max(blend, 0.0)
		#animation_tree.set("parameters/UpperBlend/blend_amount", blend)
		#await get_tree().process_frame
	#animation_tree.set("parameters/UpperBlend/blend_amount", 0.0)
		#
#
#func fade_combat_blend_in():
	#var blend = animation_tree.get("parameters/UpperBlend/blend_amount")
	#while blend < 0.99:
		#blend = lerp(blend, 1.0, get_process_delta_time() * 3.0)
		#animation_tree.set("parameters/UpperBlend/blend_amount", blend)
		#await get_tree().process_frame
	#animation_tree.set("parameters/UpperBlend/blend_amount", 1.0)
