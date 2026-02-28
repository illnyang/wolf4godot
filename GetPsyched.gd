extends CanvasLayer

var pics_path: String:
	get: return GameState.get_pics_path()

var scale_factor: float = 2.0
var progress_bar: ColorRect
var progress: float = 0.0
var loading_complete: bool = false

signal loading_finished

func _ready() -> void:
	var window_size = get_viewport().get_visible_rect().size
	scale_factor = window_size.x / 320.0
	
	_create_ui()
	
	_simulate_loading()

func _create_ui() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.0, 0.3, 0.35, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	var psyched_texture = _load_pic("131_GETPSYCHEDPIC.png")
	if psyched_texture:
		var psyched_rect = TextureRect.new()
		psyched_rect.texture = psyched_texture
		psyched_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		psyched_rect.stretch_mode = TextureRect.STRETCH_SCALE
		var pic_width = psyched_texture.get_width() * scale_factor
		var pic_height = psyched_texture.get_height() * scale_factor
		var window_size = get_viewport().get_visible_rect().size
		psyched_rect.position = Vector2((window_size.x - pic_width) / 2, 80 * scale_factor)
		psyched_rect.size = Vector2(pic_width, pic_height)
		add_child(psyched_rect)
		
		var bar_bg = ColorRect.new()
		bar_bg.color = Color(0.3, 0.0, 0.0, 1.0)  # Dark red
		bar_bg.position = Vector2((window_size.x - pic_width) / 2, 80 * scale_factor + pic_height + 4)
		bar_bg.size = Vector2(pic_width, 8 * scale_factor)
		add_child(bar_bg)
		
		progress_bar = ColorRect.new()
		progress_bar.color = Color(1.0, 0.0, 0.0, 1.0)  # Bright red
		progress_bar.position = bar_bg.position
		progress_bar.size = Vector2(0, 8 * scale_factor)
		add_child(progress_bar)

func _load_pic(filename: String) -> Texture2D:
	var path = pics_path + filename
	var image = Image.load_from_file(path)
	if image:
		return ImageTexture.create_from_image(image)
	push_error("GetPsyched: Could not load " + path)
	return null

func _simulate_loading() -> void:
	var tween = create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, 1.5)
	tween.tween_callback(_on_loading_complete)

func _set_progress(value: float) -> void:
	progress = value
	if progress_bar:
		var max_width = 256 * scale_factor
		progress_bar.size.x = max_width * progress

func _on_loading_complete() -> void:
	loading_complete = true
	loading_finished.emit()
	await get_tree().create_timer(0.3).timeout
	queue_free()
