extends Node3D

const SPEED := 5.0
const TURN_SPEED := 2.5

func _physics_process(delta):
	var movement := Vector3.ZERO

	if Input.is_action_pressed("move_forward"):
		movement += $Camera3D.global_basis * Vector3.FORWARD * SPEED * delta;
	if Input.is_action_pressed("move_backward"):
		movement -= $Camera3D.global_basis * Vector3.FORWARD * SPEED * delta;

	translate(movement)

	if Input.is_action_pressed("turn_right"):
		rotate_y(-TURN_SPEED * delta)
	elif Input.is_action_pressed("turn_left"):
		rotate_y(TURN_SPEED * delta)
