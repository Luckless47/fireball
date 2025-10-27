extends Area3D

@onready var fireball_hit: AudioStreamPlayer3D = $FireballHit


var speed: float = 0.0
var direction := Vector3.ZERO
var has_hit := false
var lifetime := 5.0

var acceleration: float = 10.0  # How much speed increases per second
var max_speed: float = 20.0    # Optional speed cap

var damage: int = 25

func _ready() -> void:
	add_to_group("projectiles")
	body_entered.connect(_on_body_entered)
	collision_layer = 4  # Layer 3 (projectiles)
	collision_mask = 2   # Layer 2 (enemies)

func _physics_process(delta: float) -> void:
	
	if has_hit:
		return
	
	speed += acceleration * delta * (1.0 + speed * 0.05)
	speed = clamp(speed, 0.0, max_speed)
	
	global_position += direction * speed * delta
	lifetime -= delta
	
	if lifetime <= 0:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if has_hit:
		return
	
	has_hit = true
	set_deferred("monitorable", true)
	remove_from_group("projectiles")
	 
	damage_body(body)
		
	
	# Add hit effects here (particles, sound, damage, etc.)
	queue_free()

func damage_body(body):
	fireball_hit.reparent(get_tree().root)
	fireball_hit.global_position = global_position
	fireball_hit.play()
	fireball_hit.finished.connect(fireball_hit.queue_free)
	if "health" in body and body.health != 0:
		body.health -= damage
	
