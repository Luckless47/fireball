extends CharacterBody3D
@export var dodge_speed := 2.0
@export var dodge_check_radius := 5.0
@export var dodge_reaction_time := 0.2
var dodge_direction := Vector3.ZERO
var dodge_timer := 0.0


var speed := 0.5

@onready var player: CharacterBody3D = $"../Player"

var health: int = 100
var _previous_health: int = 100

func _ready() -> void:
	# Randomize timer to stagger enemy updates
	dodge_timer = randf() * dodge_reaction_time

func _physics_process(delta: float) -> void:
	var to_player = (player.global_position - global_position).length()
	if to_player <= 15.0:
		var direction = (player.global_position - global_position)
		velocity = direction * speed
	health_check()
	dodge(delta)
	move_and_slide()



# helper functions

func health_check() -> void:
	if health != _previous_health:
		print("enemy hit for ", _previous_health - health)
		_previous_health = health
		if health <= 0:
			print("enemy died")
			queue_free()

func dodge(delta: float) -> void:
	dodge_timer -= delta
	
	# Reassess threats periodically
	if dodge_timer <= 0:
		
		dodge_timer = dodge_reaction_time
		
		if randf() < .25:
			dodge_direction = _calculate_dodge()
		else:
			dodge_direction = Vector3.ZERO
	
	# Apply dodge movement
	if dodge_direction != Vector3.ZERO:
		velocity.x = dodge_direction.x * dodge_speed
		velocity.z = dodge_direction.z * dodge_speed
	else:
		# Decelerate when not dodging
		velocity.x = move_toward(velocity.x, 0, dodge_speed * 5 * delta)
		velocity.z = move_toward(velocity.z, 0, dodge_speed * 5 * delta)
	
	velocity += get_gravity() * delta
	
func _calculate_dodge() -> Vector3:
	var closest_distance := INF
	var best_dodge := Vector3.ZERO
	
	var projectiles = get_tree().get_nodes_in_group("projectiles")
	
	for fireball in projectiles:
		if fireball == null or not is_instance_valid(fireball):
			continue
		
		if fireball.is_queued_for_deletion():
			continue
		
		# Skip if already hit
		if "has_hit" in fireball and fireball.has_hit:
			continue
		
		var to_fireball = fireball.global_position - global_position
		var distance = to_fireball.length()
		
		# Only care about nearby threats
		if distance >= dodge_check_radius:
			continue
		
		# Check if fireball is heading toward us
		var fireball_direction = fireball.direction.normalized()
		var to_us = -to_fireball.normalized()
		var heading_toward_us = fireball_direction.dot(to_us)
		
		# If fireball is moving toward us (dot > 0.5 means within ~60 degrees)
		if heading_toward_us > 0.5 and distance < closest_distance:
			closest_distance = distance
			# Dodge perpendicular to the fireball's path
			best_dodge = fireball_direction.cross(Vector3.UP).normalized()
			
			# Optional: pick left or right based on current position

			var right_side = fireball_direction.cross(Vector3.UP).normalized()
			var our_offset = (global_position - fireball.global_position).normalized()
			if our_offset.dot(right_side) < 0:
				best_dodge = -best_dodge
	
	return best_dodge
