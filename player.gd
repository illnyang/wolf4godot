extends CharacterBody3D  # Now inherits from CharacterBody3D

const SPEED := 150.0
const TURN_SPEED := 2.5

# Called every frame
func _physics_process(delta):
	var movement := Vector3.ZERO

	# Moving forward and backward based on camera orientation
	if Input.is_action_pressed("move_forward"):
		movement -= $Camera3D.global_transform.basis.z * SPEED * delta
	if Input.is_action_pressed("move_backward"):
		movement += $Camera3D.global_transform.basis.z * SPEED * delta

	# Update velocity
	velocity = movement

	# Apply movement using move_and_slide (no arguments needed in Godot 4)
	move_and_slide()

	# Rotating the player
	if Input.is_action_pressed("turn_right"):
		rotate_y(-TURN_SPEED * delta)
	elif Input.is_action_pressed("turn_left"):
		rotate_y(TURN_SPEED * delta)
