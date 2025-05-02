class_name Player
extends Node3D

const SPEED := 7.0
const TURN_SPEED := 1.5

# Called every frame
func _process(delta):
	var movement := Vector3.ZERO

	# Moving forward and backward based on camera orientation
	if Input.is_action_pressed("move_forward"):
		movement -= $Camera3D.global_transform.basis.z * SPEED * delta
	if Input.is_action_pressed("move_backward"):
		movement += $Camera3D.global_transform.basis.z * SPEED * delta

	if Input.is_action_pressed("fly_up"):
		movement += $Camera3D.global_transform.basis.y * SPEED * delta
	if Input.is_action_pressed("fly_down"):
		movement -= $Camera3D.global_transform.basis.y * SPEED * delta

	# Update velocity
	position += movement

	# Rotating the player
	if Input.is_action_pressed("turn_right"):
		rotate_y(-TURN_SPEED * delta)
	elif Input.is_action_pressed("turn_left"):
		rotate_y(TURN_SPEED * delta)
