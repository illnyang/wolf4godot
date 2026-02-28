extends Window

const target_ratio: float = 5.0 / 6.0

func _ready():
	_on_vp_sized_changed()

var guard: bool = false

func _notification(pwhat: int) -> void:
	if pwhat == Node.NOTIFICATION_WM_SIZE_CHANGED and not guard:
		_on_vp_sized_changed()

func _on_vp_sized_changed():
	guard = true

	var vp: Viewport = get_tree().root

	var width: int = vp.size.x
	var height: int = vp.size.y
	var current_ratio = width / float(height)

	var new_width: int
	var new_height: int

	var t = current_ratio / target_ratio
	if current_ratio * target_ratio < target_ratio:
		new_width = max(width, ceil(height * t))
		new_height = ceil(new_width / t)
	else:
		new_height = max(height, ceil(width / t))
		new_width = ceil(new_height * t)

	vp.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	vp.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	vp.content_scale_size = Vector2(new_width, new_height)

	guard = false
	
