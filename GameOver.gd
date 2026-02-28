extends CanvasLayer

var scale_factor: float = 1.0

var high_score_texture: Texture2D

func _ready() -> void:
	var window_size = get_viewport().get_visible_rect().size
	scale_factor = window_size.x / 320.0
	
	_load_assets()
	_create_ui()
	
	SoundManager.play_sfx("DEATHSCREAM1SND")

func _load_assets() -> void:
	var path = GameState.get_pics_path() + "087_HIGHSCORESPIC.png"
	high_score_texture = _load_texture(path)

func _load_texture(path: String) -> Texture2D:
	if FileAccess.file_exists(path):
		var image = Image.load_from_file(ProjectSettings.globalize_path(path))
		if image:
			return ImageTexture.create_from_image(image)
	
	push_error("GameOver: Failed to load texture: " + path)
	return null

func _create_ui() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.0, 65.0/255.0, 65.0/255.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	if high_score_texture:
		var board = TextureRect.new()
		board.texture = high_score_texture
		board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		board.stretch_mode = TextureRect.STRETCH_SCALE
		
		var board_w = high_score_texture.get_width() * scale_factor
		var board_h = high_score_texture.get_height() * scale_factor
		var window_size = get_viewport().get_visible_rect().size
		
		board.position = Vector2((window_size.x - board_w) / 2, (window_size.y - board_h) / 2)
		board.size = Vector2(board_w, board_h)
		add_child(board)
		
		var score_label = Label.new()
		score_label.text = "YOUR SCORE: %d\nENTERING HIGH SCORES..." % GameState.score
		_apply_font(score_label, 1)
		score_label.add_theme_color_override("font_color", Color.YELLOW)
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_label.position = Vector2(0, (window_size.y + board_h) / 2 + 10 * scale_factor)
		score_label.size = Vector2(window_size.x, 30 * scale_factor)
		add_child(score_label)
	else:
		var fail_label = Label.new()
		fail_label.text = "GAME OVER\nFINAL SCORE: %d" % GameState.score
		_apply_font(fail_label, 2)
		fail_label.add_theme_color_override("font_color", Color.RED)
		fail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fail_label.set_anchors_preset(Control.PRESET_CENTER)
		add_child(fail_label)

func _apply_font(label: Label, font_id: int) -> void:
	var font = FontManager.font1 if font_id == 1 else FontManager.font2
	if font:
		label.add_theme_font_override("font", font)
		var native_size = 10 if font_id == 1 else 13
		label.add_theme_font_size_override("font_size", native_size)
		label.scale = Vector2(scale_factor, scale_factor)

func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton:
		if event.pressed:
			GameState.start_new_game()
			get_tree().change_scene_to_file("res://main.tscn")
			queue_free()
