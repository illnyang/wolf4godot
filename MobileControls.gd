extends CanvasLayer

@onready var joystick_base = $Joystick/Base
@onready var joystick_tip = $Joystick/Tip
@onready var shoot_button = $ShootButton
@onready var interact_button = $InteractButton

var joystick_active = false
var joystick_center = Vector2.ZERO
var joystick_max_distance = 50.0
var move_vector = Vector2.ZERO

func _ready():
	if OS.get_name() == "Windows" or OS.get_name() == "macOS" or OS.get_name() == "Linux":
		hide()
	
	joystick_center = joystick_base.global_position + joystick_base.size / 2
	joystick_tip.global_position = joystick_center - joystick_tip.size / 2

func _input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			if joystick_base.get_global_rect().has_point(event.position):
				joystick_active = true
		else:
			joystick_active = false
			move_vector = Vector2.ZERO
			joystick_tip.global_position = joystick_center - joystick_tip.size / 2
			Input.action_release("move_forward")
			Input.action_release("move_backward")
			Input.action_release("ui_left")
			Input.action_release("ui_right")

	if event is InputEventScreenDrag and joystick_active:
		var offset = event.position - joystick_center
		if offset.length() > joystick_max_distance:
			offset = offset.normalized() * joystick_max_distance
		
		joystick_tip.global_position = joystick_center + offset - joystick_tip.size / 2
		move_vector = offset / joystick_max_distance
		
		_update_movement_actions()

func _update_movement_actions():
	if move_vector.y < -0.3:
		Input.action_press("move_forward")
		Input.action_release("move_backward")
	elif move_vector.y > 0.3:
		Input.action_press("move_backward")
		Input.action_release("move_forward")
	else:
		Input.action_release("move_forward")
		Input.action_release("move_backward")
	
	if move_vector.x < -0.4:
		Input.action_press("turn_left")
		Input.action_release("turn_right")
	elif move_vector.x > 0.4:
		Input.action_press("turn_right")
		Input.action_release("turn_left")
	else:
		Input.action_release("turn_left")
		Input.action_release("turn_right")
