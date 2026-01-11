extends MeshInstance3D

enum State { CLOSED, OPENING, OPEN, CLOSING }
var current_state = State.CLOSED

var open_ratio: float = 0.0
var slide_speed: float = 4
var auto_close_timer: float = 0.0
const OPEN_DURATION: float = 3.5 
var start_pos: Vector3 = Vector3.ZERO

func _ready() -> void:
	add_to_group("doors")
	start_pos = position

func _process(delta: float) -> void:
	match current_state:
		State.OPENING:
			open_ratio = move_toward(open_ratio, 1.0, delta * slide_speed)
			_apply_slide()
			if open_ratio >= 1.0:
				current_state = State.OPEN
				auto_close_timer = OPEN_DURATION
		State.OPEN:
			auto_close_timer -= delta
			if auto_close_timer <= 0:
				current_state = State.CLOSING
				SoundManager.play_sfx("CLOSEDOORSND")
				
		State.CLOSING:
			open_ratio = move_toward(open_ratio, 0.0, delta * slide_speed)
			_apply_slide()
			if open_ratio <= 0.0:
				current_state = State.CLOSED

func _apply_slide() -> void:
	position = start_pos + (transform.basis.x * open_ratio * 0.95)

func interact() -> void:
	if current_state == State.CLOSED or current_state == State.CLOSING:
		current_state = State.OPENING
		SoundManager.play_sfx("OPENDOORSND")
	elif current_state == State.OPEN:
		current_state = State.CLOSING

func is_open() -> bool:
	return open_ratio > 0.8

