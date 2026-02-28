extends Node

var font1: Font
var font2: Font

signal fonts_loaded

func _ready() -> void:
	if not AssetExtractor.extraction_complete:
		await AssetExtractor.extraction_finished
	
	load_fonts()

func load_fonts() -> void:
	var fonts_path = GameState.get_fonts_path()
	
	font1 = _load_font_from_extracted(fonts_path + "FONT1")
	font2 = _load_font_from_extracted(fonts_path + "FONT2")
	
	if font1 and font2:
		print("[FontManager] Original fonts loaded successfully")
	else:
		push_warning("[FontManager] Failed to load original fonts, check extraction.")
	
	fonts_loaded.emit()

func _load_font_from_extracted(base_path: String) -> Font:
	var png_path = base_path + ".png"
	var json_path = base_path + ".json"
	
	if not FileAccess.file_exists(json_path) or not FileAccess.file_exists(png_path):
		return null
		
	var json_text = FileAccess.get_file_as_string(json_path)
	var json = JSON.parse_string(json_text)
	if not json: return null
	
	var image = Image.load_from_file(ProjectSettings.globalize_path(png_path))
	if not image: return null
	var texture = ImageTexture.create_from_image(image)
	
	var font = FontFile.new()
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.generate_mipmaps = false
	
	var height = json["height"]
	
	var h_int = int(height)
	var size_vec = Vector2i(h_int, 0)
	var cache_id = 0
	font.set_texture_image(cache_id, size_vec, 0, image)
	
	print("[FontManager] Loading font with height=%d from %s" % [h_int, base_path])
	
	var characters = json["characters"]
	var glyph_count = 0
	for char_code_str in characters:
		var char_code = int(char_code_str)
		var char_info = characters[char_code_str]
		
		var x = float(char_info["x"])
		var y = float(char_info["y"])
		var width = float(char_info["width"])
		
		font.set_glyph_advance(cache_id, h_int, char_code, Vector2(width, 0))
		font.set_glyph_offset(cache_id, size_vec, char_code, Vector2.ZERO)
		font.set_glyph_size(cache_id, size_vec, char_code, Vector2(width, h_int))
		font.set_glyph_uv_rect(cache_id, size_vec, char_code, Rect2(x, y, width, h_int))
		font.set_glyph_texture_idx(cache_id, size_vec, char_code, 0)
		glyph_count += 1
	
	print("[FontManager] Loaded %d glyphs" % glyph_count)
	return font
