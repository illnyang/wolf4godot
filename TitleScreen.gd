# TitleScreen.gd
# Displays the title screen with "PRESS A KEY" prompt
extends Control

# Original Wolf3D coordinates (320x200 VGA)
const ORIG_WIDTH = 320
const ORIG_HEIGHT = 200

# Colors from Wolf3D palette
const COLOR_HIGHLIGHT = Color(1.0, 1.0, 0.0)  # Yellow

# Scale factor for 320x200 -> current resolution
var scale_factor: float = 1.0

# Loaded textures
var pics: Dictionary = {}

# UI nodes
var background: TextureRect


func _ready() -> void:
	# Wait for extraction
	if not AssetExtractor.extraction_complete:
		await AssetExtractor.extraction_finished
	
	_calculate_scale()
	_load_pics()
	_show_title()
	
	# Play title music
	MusicManager.play_title_music()


func _calculate_scale() -> void:
	var window_size = get_viewport().get_visible_rect().size
	# Scale to fit 320x200 into window, maintaining aspect ratio
	var scale_x = window_size.x / ORIG_WIDTH
	var scale_y = window_size.y / ORIG_HEIGHT
	scale_factor = min(scale_x, scale_y)


func _get_pics_path() -> String:
	return GameState.get_pics_path()


func _load_pics() -> void:
	var path = _get_pics_path()
	
	# Load title pic
	var pic_files = {
		"TITLEPIC": "084_TITLEPIC.png"
	}
	
	for pic_name in pic_files:
		var full_path = path + pic_files[pic_name]
		var texture = _load_texture(full_path)
		if texture:
			pics[pic_name] = texture


func _load_texture(path: String) -> Texture2D:
	# For user:// paths, load image directly
	var image = Image.load_from_file(ProjectSettings.globalize_path(path))
	if image:
		return ImageTexture.create_from_image(image)
	
	push_error("TitleScreen: Failed to load texture: " + path)
	return null


func _show_title() -> void:
	# Create background
	background = TextureRect.new()
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	
	# Show title pic
	if pics.has("TITLEPIC"):
		background.texture = pics["TITLEPIC"]
		background.visible = true
	
	# Add "Press any key" text
	var press_label = Label.new()
	press_label.name = "PressLabel"
	press_label.text = "PRESS A KEY"
	press_label.add_theme_font_size_override("font_size", int(16 * scale_factor))
	press_label.add_theme_color_override("font_color", COLOR_HIGHLIGHT)
	press_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	press_label.position = Vector2(0, 180 * scale_factor)
	press_label.size = Vector2(get_viewport().get_visible_rect().size.x, 20 * scale_factor)
	add_child(press_label)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or (event is InputEventScreenTouch and event.pressed):
		# Transition to main menu
		get_tree().change_scene_to_file("res://MainMenu.tscn")