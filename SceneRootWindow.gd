# https://github.com/godotengine/godot/issues/79336#issuecomment-1631627181
extends Window

# Stretch to 5:6 ratio like in the original game
const target_ratio: float = 5.0 / 6.0

func _ready():
	# NOTE: `size_changed` doesn't get emitted when using CONTENT_SCALE_MODE_VIEWPORT!!!
	# var vp: Viewport = get_tree().root
	# vp.connect("size_changed", _on_vp_sized_changed)
	_on_vp_sized_changed()

# NOTE: prevents infinite recursion
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
		# Too tall - adjust width first to maintain ratiao while scaling up	
		new_width = max(width, ceil(height * t))
		new_height = ceil(new_width / t)
	else:
		# Too wide or correct ratio - adjust height first
		new_height = max(height, ceil(width / t))
		new_width = ceil(new_height * t)

	vp.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	vp.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	vp.content_scale_size = Vector2(new_width, new_height)

	guard = false
	
