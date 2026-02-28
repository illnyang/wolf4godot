extends Control

const ORIG_WIDTH = 320
const ORIG_HEIGHT = 200

const COLOR_BACKGROUND = Color(138.0/255.0, 0.0, 0.0)
const COLOR_HIGHLIGHT = Color(1.0, 1.0, 0.0)
const COLOR_TEXT = Color(0.9, 0.9, 0.9)
const COLOR_GREEN = Color(0.0, 0.8, 0.0)

enum TitleState { SIGNON, PG13, TITLE, CREDITS, HIGHSCORES }
var current_state: TitleState = TitleState.SIGNON

const PG13_DURATION = 5.0
const TITLE_DURATION = 10.0
const CREDITS_DURATION = 7.0
const HIGHSCORES_DURATION = 7.0

var scale_factor: float = 1.0
var center_offset_x: float = 0.0
var center_offset_y: float = 0.0

var pics: Dictionary = {}

var background: TextureRect
var content_container: Control
var state_timer: float = 0.0
var fade_alpha: float = 1.0
var fading_out: bool = false
var fading_in: bool = false
var next_state_after_fade: TitleState = TitleState.TITLE

var signon_key_pressed: bool = false


func _ready() -> void:
	if not AssetExtractor.extraction_complete:
		await AssetExtractor.extraction_finished
	
	_calculate_scale()
	_load_pics()
	_create_ui()
	
	if GameState.skip_to_title_loop:
		GameState.skip_to_title_loop = false
		_show_title()
	else:
		_show_signon()


func _calculate_scale() -> void:
	var window_size = get_viewport().get_visible_rect().size
	var scale_x = window_size.x / ORIG_WIDTH
	var scale_y = window_size.y / ORIG_HEIGHT
	scale_factor = min(scale_x, scale_y)
	
	var scaled_width = ORIG_WIDTH * scale_factor
	var scaled_height = ORIG_HEIGHT * scale_factor
	center_offset_x = (window_size.x - scaled_width) / 2.0
	center_offset_y = (window_size.y - scaled_height) / 2.0


func _get_pics_path() -> String:
	return GameState.get_pics_path()


func _load_pics() -> void:
	var path = _get_pics_path()
	
	var pic_files = {
		"TITLEPIC": "084_TITLEPIC.png",
		"PG13PIC": "085_PG13PIC.png",
		"CREDITSPIC": "086_CREDITSPIC.png",
		"HIGHSCORESPIC": "087_HIGHSCORESPIC.png"
	}
	
	for pic_name in pic_files:
		var full_path = path + pic_files[pic_name]
		var texture = _load_texture(full_path)
		if texture:
			pics[pic_name] = texture
	
	var signon_path = GameState.get_asset_path() + "signon/SIGNON.png"
	var signon_texture = _load_texture(signon_path)
	if signon_texture:
		pics["SIGNON"] = signon_texture
		print("Loaded SIGNON from: %s" % signon_path)
	else:
		print("SIGNON not found at: %s" % signon_path)
	
	for pic_name in pic_files:
		var full_path = path + pic_files[pic_name]
		var texture = _load_texture(full_path)
		if texture:
			pics[pic_name] = texture


func _load_texture(path: String) -> Texture2D:
	var image = Image.load_from_file(ProjectSettings.globalize_path(path))
	if image:
		return ImageTexture.create_from_image(image)
	return null


func _create_ui() -> void:
	background = TextureRect.new()
	background.name = "Background"
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	
	content_container = Control.new()
	content_container.name = "ContentContainer"
	content_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(content_container)


func _clear_content() -> void:
	for child in content_container.get_children():
		child.queue_free()


# ============== SIGNON SCREEN ==============
func _show_signon() -> void:
	current_state = TitleState.SIGNON
	signon_key_pressed = false
	_clear_content()
	
	if pics.has("SIGNON"):
		var signon_rect = TextureRect.new()
		signon_rect.texture = pics["SIGNON"]
		signon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		signon_rect.position = Vector2(center_offset_x, center_offset_y)
		signon_rect.size = Vector2(ORIG_WIDTH * scale_factor, ORIG_HEIGHT * scale_factor)
		signon_rect.stretch_mode = TextureRect.STRETCH_SCALE
		content_container.add_child(signon_rect)
	else:
		var bg = ColorRect.new()
		bg.color = COLOR_BACKGROUND
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content_container.add_child(bg)
		
		var title_label = Label.new()
		title_label.text = "WOLFENSTEIN 3D"
		title_label.add_theme_font_size_override("font_size", int(24 * scale_factor))
		title_label.add_theme_color_override("font_color", COLOR_HIGHLIGHT)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.position = Vector2(0, center_offset_y + 60 * scale_factor)
		title_label.size = Vector2(get_viewport().get_visible_rect().size.x, 30 * scale_factor)
		content_container.add_child(title_label)
	
	var press_label = Label.new()
	press_label.name = "PressLabel"
	press_label.text = "Press a key"
	press_label.add_theme_font_size_override("font_size", int(14 * scale_factor))
	press_label.add_theme_color_override("font_color", COLOR_HIGHLIGHT)
	press_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	press_label.position = Vector2(0, center_offset_y + 175 * scale_factor)
	press_label.size = Vector2(get_viewport().get_visible_rect().size.x, 20 * scale_factor)
	content_container.add_child(press_label)


# ============== PG13 SCREEN ==============
func _show_pg13() -> void:
	current_state = TitleState.PG13
	state_timer = 0.0
	_clear_content()
	
	MusicManager.play_track("NAZI_NOR")
	
	background.texture = null
	
	var bg = ColorRect.new()
	bg.color = Color8(32, 170, 255)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_container.add_child(bg)
	
	if pics.has("PG13PIC"):
		var pg13_rect = TextureRect.new()
		pg13_rect.texture = pics["PG13PIC"]
		pg13_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pg13_rect.stretch_mode = TextureRect.STRETCH_SCALE
		
		var tex_width = pics["PG13PIC"].get_width()
		var tex_height = pics["PG13PIC"].get_height()
		
		var scaled_width = tex_width * scale_factor
		var scaled_height = tex_height * scale_factor
		
		var padding = 16 * scale_factor
		var pos_x = center_offset_x + (ORIG_WIDTH * scale_factor) - scaled_width - padding
		var pos_y = center_offset_y + (ORIG_HEIGHT * scale_factor) - scaled_height - padding
		
		pg13_rect.position = Vector2(pos_x, pos_y)
		pg13_rect.size = Vector2(scaled_width, scaled_height)
		content_container.add_child(pg13_rect)
	else:
		var pg_label = Label.new()
		pg_label.text = "THIS GAME IS RATED PG-13"
		pg_label.add_theme_font_size_override("font_size", int(16 * scale_factor))
		pg_label.add_theme_color_override("font_color", COLOR_TEXT)
		pg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pg_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content_container.add_child(pg_label)


# ============== TITLE SCREEN ==============
func _show_title() -> void:
	current_state = TitleState.TITLE
	state_timer = 0.0
	_clear_content()
		
	if pics.has("TITLEPIC"):
		background.texture = pics["TITLEPIC"]



# ============== CREDITS SCREEN ==============
func _show_credits() -> void:
	current_state = TitleState.CREDITS
	state_timer = 0.0
	_clear_content()
	
	if pics.has("CREDITSPIC"):
		background.texture = pics["CREDITSPIC"]


# ============== HIGH SCORES SCREEN ==============
func _show_highscores() -> void:
	current_state = TitleState.HIGHSCORES
	state_timer = 0.0
	_clear_content()
	
	if pics.has("HIGHSCORESPIC"):
		background.texture = pics["HIGHSCORESPIC"]
	else:
		background.texture = null
		var bg = ColorRect.new()
		bg.color = COLOR_BACKGROUND
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content_container.add_child(bg)
		
		var hs_label = Label.new()
		hs_label.text = "HIGH SCORES"
		hs_label.add_theme_font_size_override("font_size", int(20 * scale_factor))
		hs_label.add_theme_color_override("font_color", COLOR_HIGHLIGHT)
		hs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hs_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hs_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content_container.add_child(hs_label)


# ============== STATE TRANSITIONS ==============
func _start_fade_to(next_state: TitleState) -> void:
	fading_out = true
	fading_in = false
	fade_alpha = 1.0
	next_state_after_fade = next_state


func _process(delta: float) -> void:
	# Handle fading
	if fading_out:
		fade_alpha -= delta * 2.0
		if fade_alpha <= 0.0:
			fade_alpha = 0.0
			fading_out = false
			fading_in = true
			_transition_to_state(next_state_after_fade)
		background.modulate = Color(1, 1, 1, fade_alpha)
		content_container.modulate = Color(1, 1, 1, fade_alpha)
		return
	
	if fading_in:
		fade_alpha += delta * 2.0
		if fade_alpha >= 1.0:
			fade_alpha = 1.0
			fading_in = false
		background.modulate = Color(1, 1, 1, fade_alpha)
		content_container.modulate = Color(1, 1, 1, fade_alpha)
		return
	
	if current_state == TitleState.PG13:
		state_timer += delta
		if state_timer >= PG13_DURATION:
			_start_fade_to(TitleState.TITLE)
	elif current_state == TitleState.TITLE:
		state_timer += delta
		if state_timer >= TITLE_DURATION:
			_start_fade_to(TitleState.CREDITS)
	elif current_state == TitleState.CREDITS:
		state_timer += delta
		if state_timer >= CREDITS_DURATION:
			_start_fade_to(TitleState.HIGHSCORES)
	elif current_state == TitleState.HIGHSCORES:
		state_timer += delta
		if state_timer >= HIGHSCORES_DURATION:
			_start_fade_to(TitleState.TITLE)


func _transition_to_state(state: TitleState) -> void:
	match state:
		TitleState.SIGNON:
			_show_signon()
		TitleState.PG13:
			_show_pg13()
		TitleState.TITLE:
			_show_title()
		TitleState.CREDITS:
			_show_credits()
		TitleState.HIGHSCORES:
			_show_highscores()


func _input(event: InputEvent) -> void:
	if fading_out or fading_in:
		return
	
	var key_pressed = event.is_action_pressed("ui_accept") or \
					  event.is_action_pressed("ui_cancel") or \
					  (event is InputEventKey and event.pressed) or \
					  (event is InputEventScreenTouch and event.pressed) or \
					  (event is InputEventMouseButton and event.pressed)
	
	if not key_pressed:
		return
	
	match current_state:
		TitleState.SIGNON:
			if not signon_key_pressed:
				signon_key_pressed = true
				var press_label = content_container.get_node_or_null("PressLabel")
				if press_label:
					press_label.text = "Working..."
				await get_tree().create_timer(0.5).timeout
				_start_fade_to(TitleState.PG13)
		
		TitleState.PG13:
			MusicManager.play_track("WONDERIN")
			get_tree().change_scene_to_file("res://MainMenu.tscn")
		
		TitleState.TITLE, TitleState.CREDITS, TitleState.HIGHSCORES:
			MusicManager.play_track("WONDERIN")
			get_tree().change_scene_to_file("res://MainMenu.tscn")
