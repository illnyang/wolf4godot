extends Node

# Wolf3D Asset Extractor - Runs at game start

const NEARTAG = 0xA7
const FARTAG = 0xA8
const RLEW_TAG = 0xABCD
const MAP_SIZE = 64
const TEXTURE_SIZE = 64

# Helper function for signed 16-bit reads
static func decode_s16(data: PackedByteArray, offset: int) -> int:
	var unsigned = data.decode_u16(offset)
	if unsigned >= 32768:
		return unsigned - 65536
	return unsigned


# Game configurations
enum GameType { WOLF3D, SOD, BLAKE_STONE }

var game_configs = {
	GameType.WOLF3D: {
		"name": "wolf3d",
		"data_path": "res://data/wolf3d/",
		"extension": ".WL6",
		"output": "user://assets/wolf3d/"
	},
	GameType.SOD: {
		"name": "sod",
		"data_path": "res://data/sod/",
		"extension": ".SOD",
		"output": "user://assets/sod/"
	},
	GameType.BLAKE_STONE: {
		"name": "blake_stone",
		"data_path": "res://data/blake_stone/",
		"extension": ".BS6",
		"output": "user://assets/blake_stone/"
	}
}

# Current extraction paths (set during extraction)
var current_data_path: String = ""
var current_extension: String = ""
var current_output_path: String = ""

# Legacy variable aliases (for backward compatibility with Blake Stone code)
var output_path: String:
	get: return current_output_path
var texture_output_path: String:
	get: return current_output_path

# Available games after detection
var available_games: Array[GameType] = []

var extraction_complete = false

signal extraction_finished()

# Wolf3D VGA Palette (6-bit RGB converted to 8-bit)
var WOLF_PALETTE = [
	[0,0,0],[0,0,170],[0,170,0],[0,170,170],[170,0,0],[170,0,170],[170,85,0],[170,170,170],
	[85,85,85],[85,85,255],[85,255,85],[85,255,255],[255,85,85],[255,85,255],[255,255,85],[255,255,255],
	[239,239,239],[223,223,223],[211,211,211],[195,195,195],[182,182,182],[170,170,170],[154,154,154],[142,142,142],
	[126,126,126],[113,113,113],[101,101,101],[85,85,85],[73,73,73],[56,56,56],[44,44,44],[32,32,32],
	[255,0,0],[239,0,0],[227,0,0],[215,0,0],[203,0,0],[190,190,190],[178,0,0],[166,0,0],
	[154,0,0],[138,0,0],[126,0,0],[113,113,113],[101,0,0],[89,0,0],[77,0,0],[65,0,0],
	[255,219,219],[255,186,186],[255,158,158],[255,126,126],[255,93,93],[255,65,65],[255,32,32],[255,0,0],
	[255,170,93],[255,154,65],[255,138,32],[255,121,0],[231,109,0],[207,97,0],[182,85,0],[158,77,0],
	[255,255,219],[255,255,186],[255,255,158],[255,255,126],[255,251,93],[255,247,65],[255,247,32],[255,247,0],
	[231,219,0],[207,198,0],[182,174,0],[158,158,0],[134,134,0],[113,109,0],[89,85,0],[65,65,0],
	[211,255,93],[198,255,65],[182,255,32],[162,255,0],[146,231,0],[130,207,0],[117,182,0],[97,158,0],
	[219,255,219],[190,255,186],[158,255,158],[130,255,126],[97,255,93],[65,255,65],[32,255,32],[0,255,0],
	[0,255,0],[0,239,0],[0,227,0],[0,215,0],[4,203,0],[4,190,0],[4,178,0],[4,166,0],
	[4,154,0],[4,138,0],[4,126,0],[4,113,0],[4,101,0],[4,89,0],[4,77,0],[4,65,0],
	[219,255,255],[186,255,255],[158,255,255],[126,255,251],[93,255,255],[65,255,255],[32,255,255],[0,255,255],
	[0,231,231],[0,207,207],[0,182,182],[0,158,158],[0,134,134],[0,113,113],[0,89,89],[0,65,65],
	[93,190,255],[65,178,255],[32,170,255],[0,158,255],[0,142,231],[0,126,207],[0,109,182],[0,93,158],
	[219,219,255],[186,190,255],[158,158,255],[126,130,255],[93,97,255],[65,65,255],[32,36,255],[0,4,255],
	[0,0,255],[0,0,239],[0,0,227],[0,0,215],[0,0,203],[0,0,190],[0,0,178],[0,0,166],
	[0,0,154],[0,0,138],[0,0,126],[0,0,113],[0,0,101],[0,0,89],[0,0,77],[0,0,65],
	[40,40,40],[255,227,52],[255,215,36],[255,207,24],[255,195,8],[255,182,0],[182,32,255],[170,0,255],
	[154,0,231],[130,0,207],[117,0,182],[97,0,158],[81,0,134],[69,0,113],[52,0,89],[40,0,65],
	[255,219,255],[255,186,255],[255,158,255],[255,126,255],[255,93,255],[255,65,255],[255,32,255],[255,0,255],
	[227,0,231],[203,0,207],[182,0,182],[158,0,158],[134,0,134],[109,0,113],[89,0,89],[65,0,65],
	[255,235,223],[255,227,211],[255,219,198],[255,215,190],[255,207,178],[255,198,166],[255,190,158],[255,186,146],
	[255,178,130],[255,166,113],[255,158,97],[243,150,93],[235,142,89],[223,138,85],[211,130,81],[203,125,77],
	[190,121,73],[182,113,69],[170,105,65],[162,101,60],[158,97,56],[146,93,52],[138,89,48],[130,81,44],
	[117,77,40],[109,73,36],[93,65,32],[85,60,28],[73,56,24],[65,48,24],[56,44,20],[40,32,12],
	[97,0,101],[0,101,101],[0,97,97],[0,0,28],[0,0,44],[48,36,16],[73,0,73],[81,0,81],
	[0,0,52],[28,28,28],[77,77,77],[93,93,93],[65,65,65],[48,48,48],[52,52,52],[219,247,247],
	[186,235,235],[158,223,223],[117,203,203],[73,195,195],[32,182,182],[32,178,178],[0,166,166],[0,154,154],
	[0,142,142],[0,134,134],[0,126,126],[0,121,121],[0,117,117],[0,113,113],[0,109,109],[154,0,138]
]


func _ready():
	print("=== AssetExtractor Starting ===")
	
	# Detect available games
	_detect_available_games()
	
	# Extract all available games
	for game_type in available_games:
		var config = game_configs[game_type]
		if not _already_extracted_game(config.output):
			print("Extracting %s assets..." % config.name)
			_extract_game(game_type)
		else:
			print("%s assets already extracted, skipping..." % config.name)
	
	print("=== Extraction Complete ===")
	extraction_complete = true
	extraction_finished.emit()

func _detect_available_games() -> void:
	available_games.clear()
	for game_type in game_configs:
		var config = game_configs[game_type]
		var vswap_path = config.data_path + "VSWAP" + config.extension
		if FileAccess.file_exists(vswap_path):
			print("Found %s data files" % config.name.to_upper())
			available_games.append(game_type)
	
	if available_games.is_empty():
		push_warning("No game data found! Please add Wolf3D or SOD files.")

func _already_extracted_game(output: String) -> bool:
	var map_dir = DirAccess.open(output + "maps/json/")
	if map_dir == null:
		return false
	var wall_dir = DirAccess.open(output + "walls/")
	if wall_dir == null:
		return false
	return true

func _extract_game(game_type: GameType) -> void:
	var config = game_configs[game_type]
	current_data_path = config.data_path
	current_extension = config.extension
	current_output_path = config.output
	
	DirAccess.make_dir_recursive_absolute(current_output_path + "maps/json")
	DirAccess.make_dir_recursive_absolute(current_output_path + "maps/thumbs")
	DirAccess.make_dir_recursive_absolute(current_output_path + "walls")
	DirAccess.make_dir_recursive_absolute(current_output_path + "sprites")
	
	extract_maps()
	extract_vswap()
	
#func already_extracted() -> bool:
	#var map_dir = DirAccess.open(output_path + "maps/json/")
	#if map_dir == null:
		#return false
	#
	#var wall_dir = DirAccess.open(output_path + "walls/")
	#if wall_dir == null:
		#return false
	#
	#map_dir.list_dir_begin()
	#var has_maps = false
	#var file_name = map_dir.get_next()
	#while file_name != "":
		#if file_name.ends_with(".json"):
			#has_maps = true
			#break
		#file_name = map_dir.get_next()
	#map_dir.list_dir_end()
	#
	#wall_dir.list_dir_begin()
	#var has_walls = false
	#file_name = wall_dir.get_next()
	#while file_name != "":
		#if file_name.ends_with(".png"):
			#has_walls = true
			#break
		#file_name = wall_dir.get_next()
	#wall_dir.list_dir_end()
	#
	#return has_maps and has_walls
	
func already_extracted() -> bool:
	
	var map_dir = DirAccess.open(output_path + "maps/json/")
	if map_dir == null:
		return false
	
	# CHECK USER:// FOR WALLS NOW!
	var wall_dir = DirAccess.open(texture_output_path + "walls/")
	if wall_dir == null:
		return false
	
	map_dir.list_dir_begin()
	var has_maps = false
	var file_name = map_dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			has_maps = true
			break
		file_name = map_dir.get_next()
	map_dir.list_dir_end()
	
	wall_dir.list_dir_begin()
	var has_walls = false
	file_name = wall_dir.get_next()
	while file_name != "":
		if file_name.ends_with(".png"):
			has_walls = true
			break
		file_name = wall_dir.get_next()
	wall_dir.list_dir_end()
	
	return has_maps and has_walls


func extract_all_assets():
	DirAccess.make_dir_recursive_absolute(output_path + "maps/json")
	DirAccess.make_dir_recursive_absolute(output_path + "maps/thumbs")
	DirAccess.make_dir_recursive_absolute(texture_output_path + "walls")
	DirAccess.make_dir_recursive_absolute(texture_output_path + "sprites")
	
	extract_maps()
	extract_vswap()


#-----------------------------------------------------
# Carmack Decompression
#-----------------------------------------------------
func carmack_expand(src: PackedByteArray) -> PackedInt32Array:
	if src.size() < 2:
		push_error("Carmack: Source too small")
		return PackedInt32Array()
	
	var expanded_len = src.decode_u16(0)
	var result: PackedInt32Array = []
	result.resize(expanded_len / 2)
	
	var src_pos = 2
	var dest_pos = 0
	
	while dest_pos < expanded_len / 2 and src_pos < src.size():
		if src_pos + 1 >= src.size():
			break
			
		var word = src.decode_u16(src_pos)
		src_pos += 2
		
		var high_byte = (word >> 8) & 0xFF
		
		if high_byte == NEARTAG:
			var count = word & 0xFF
			if count == 0:
				if src_pos >= src.size():
					break
				word = word | src[src_pos]
				src_pos += 1
				result[dest_pos] = word
				dest_pos += 1
			else:
				if src_pos >= src.size():
					break
				var offset = src[src_pos]
				src_pos += 1
				for i in range(count):
					if dest_pos - offset < 0 or dest_pos >= result.size():
						break
					result[dest_pos] = result[dest_pos - offset]
					dest_pos += 1
					
		elif high_byte == FARTAG:
			var count = word & 0xFF
			if count == 0:
				if src_pos >= src.size():
					break
				word = word | src[src_pos]
				src_pos += 1
				result[dest_pos] = word
				dest_pos += 1
			else:
				if src_pos + 1 >= src.size():
					break
				var offset = src.decode_u16(src_pos)
				src_pos += 2
				for i in range(count):
					if offset + i >= result.size() or dest_pos >= result.size():
						break
					result[dest_pos] = result[offset + i]
					dest_pos += 1
		else:
			result[dest_pos] = word
			dest_pos += 1
	
	return result


#-----------------------------------------------------
# RLEW Decompression
#-----------------------------------------------------
func rlew_expand(src: PackedInt32Array, rlew_tag: int) -> PackedInt32Array:
	var result: PackedInt32Array = []
	var i = 0
	
	while i < src.size():
		var value = src[i]
		i += 1
		
		if value != rlew_tag:
			result.append(value)
		else:
			if i + 1 >= src.size():
				break
			var count = src[i]
			i += 1
			var repeat_value = src[i]
			i += 1
			
			for j in range(count):
				result.append(repeat_value)
	
	return result


#-----------------------------------------------------
# Full MAP Expansion
#-----------------------------------------------------
func map_expand(raw_bytes: PackedByteArray) -> PackedInt32Array:
	var carmacked = carmack_expand(raw_bytes)
	if carmacked.size() <= 1:
		return PackedInt32Array()
	
	var without_prefix: PackedInt32Array = []
	for i in range(1, carmacked.size()):
		without_prefix.append(carmacked[i])
	return rlew_expand(without_prefix, RLEW_TAG)


#-----------------------------------------------------
# Map Extraction
#-----------------------------------------------------
func extract_maps():
	print("Extracting maps...")
	
	var maphead_path = current_data_path + "MAPHEAD" + current_extension
	var gamemaps_path = current_data_path + "GAMEMAPS" + current_extension
	
	var maphead = FileAccess.open(maphead_path, FileAccess.READ)
	if maphead == null:
		push_error("Cannot open " + maphead_path)
		return
	
	var sig = maphead.get_16()
	if sig != 0xABCD:
		push_error("Invalid MAPHEAD signature")
		maphead.close()
		return
	
	var map_offsets: Array[int] = []
	while maphead.get_position() < maphead.get_length():
		var offset = maphead.get_32()
		if offset == 0:
			break
		map_offsets.append(offset)
	
	maphead.close()
	print("-> Found %d levels" % map_offsets.size())
	
	var gamemaps = FileAccess.open(gamemaps_path, FileAccess.READ)
	if gamemaps == null:
		push_error("Cannot open " + gamemaps_path)
		return
	
	for level in range(map_offsets.size()):
		print("  Level %d..." % level)
		
		gamemaps.seek(map_offsets[level])
		
		var l1_offset = gamemaps.get_32()
		var l2_offset = gamemaps.get_32()
		var l3_offset = gamemaps.get_32()
		
		var l1_len = gamemaps.get_16()
		var l2_len = gamemaps.get_16()
		var l3_len = gamemaps.get_16()
		
		var width = gamemaps.get_16()
		var height = gamemaps.get_16()
		
		var name_bytes = gamemaps.get_buffer(16)
		var map_name = name_bytes.get_string_from_ascii().strip_edges()
		var null_pos = map_name.find(char(0))
		if null_pos >= 0:
			map_name = map_name.substr(0, null_pos)
		
		var sig_bytes = gamemaps.get_buffer(4)
		
		gamemaps.seek(l1_offset)
		var l1_raw = gamemaps.get_buffer(l1_len)
		var layer1 = map_expand(l1_raw)
		
		gamemaps.seek(l2_offset)
		var l2_raw = gamemaps.get_buffer(l2_len)
		var layer2 = map_expand(l2_raw)
		
		if layer1.size() != MAP_SIZE * MAP_SIZE:
			push_error("Invalid layer1 size for level %d" % level)
			continue
		
		var map_data = {
			"Name": map_name,
			"CeilingColor": [128, 128, 128],
			"FloorColor": [112, 112, 112],
			"Tiles": Array(layer1),
			"Things": Array(layer2) if layer2.size() > 0 else []
		}
		
		var json_string = JSON.stringify(map_data, "\t")
		var json_file = FileAccess.open(
			"%smaps/json/%02d_%s.json" % [current_output_path, level, map_name],
			FileAccess.WRITE
		)
		if json_file:
			json_file.store_string(json_string)
			json_file.close()
		
		generate_thumbnail(layer1, layer2, level, map_name)
	
	gamemaps.close()


#-----------------------------------------------------
# VSWAP Extraction (Textures & Sprites)
#-----------------------------------------------------
func extract_vswap():
	print("Extracting VSWAP assets...")
	
	var vswap_path = current_data_path + "VSWAP" + current_extension
	var vswap = FileAccess.open(vswap_path, FileAccess.READ)
	if vswap == null:
		push_error("Cannot open " + vswap_path)
		return
	
	# Read header
	var num_chunks = vswap.get_16()
	var sprite_start = vswap.get_16()
	var sound_start = vswap.get_16()
	
	print("-> Chunks: %d, Sprites start: %d, Sounds start: %d" % [num_chunks, sprite_start, sound_start])
	
	# Read chunk offsets (4 bytes each)
	var chunk_offsets: Array[int] = []
	for i in range(num_chunks):
		chunk_offsets.append(vswap.get_32())
	
	# Read chunk lengths (2 bytes each)
	var chunk_lengths: Array[int] = []
	for i in range(num_chunks):
		chunk_lengths.append(vswap.get_16())
	
	# Calculate number of digits needed for wall naming
	var max_wall_idx = (sprite_start - 1) / 2
	var num_digits = len(str(max_wall_idx))
	
	# Extract wall textures (chunks 0 to sprite_start - 1)
	print("-> Extracting %d wall textures..." % sprite_start)
	for i in range(sprite_start):
		var offset = chunk_offsets[i]
		var length = chunk_lengths[i]
		
		if length == 0:
			continue
		
		vswap.seek(offset)
		var texture_data = vswap.get_buffer(length)
		
		# Textures are 64x64, stored column-first (transposed)
		if texture_data.size() == TEXTURE_SIZE * TEXTURE_SIZE:
			save_wall_texture(texture_data, i, num_digits)
	
	# Extract sprites (chunks sprite_start to sound_start - 1)
	print("-> Extracting %d sprites..." % (sound_start - sprite_start))
	for i in range(sprite_start, sound_start):
		var offset = chunk_offsets[i]
		var length = chunk_lengths[i]
		
		if length == 0:
			continue
		
		vswap.seek(offset)
		var sprite_data = vswap.get_buffer(length)
		save_sprite(sprite_data, i - sprite_start)
	
	vswap.close()
	print("-> VSWAP extraction complete")
	
	# ENHANCED DEBUG CODE
	print("========== EXTRACTION DEBUG ==========")
	print("Texture output path: ", texture_output_path + "walls/")
	var wall_dir = DirAccess.open(texture_output_path + "walls/")
	if wall_dir:
		print("Wall directory opened successfully!")
		wall_dir.list_dir_begin()
		var count = 0
		var file_name = wall_dir.get_next()
		while file_name != "":
			if file_name.ends_with(".png"):
				count += 1
			file_name = wall_dir.get_next()
		wall_dir.list_dir_end()
		print("Total wall PNG files found: ", count)
	else:
		print("FAILED TO OPEN WALL DIRECTORY!")
	
	# ADD SPRITE DEBUG
	print("\nSprite output path: ", texture_output_path + "sprites/")
	var sprite_dir = DirAccess.open(texture_output_path + "sprites/")
	if sprite_dir:
		print("Sprite directory opened successfully!")
		sprite_dir.list_dir_begin()
		var count = 0
		var file_name = sprite_dir.get_next()
		while file_name != "":
			if file_name.ends_with(".png"):
				count += 1
				if count <= 5:  # Print first 5 files
					print("  Found: ", file_name)
			file_name = sprite_dir.get_next()
		sprite_dir.list_dir_end()
		print("Total sprite PNG files found: ", count)
	else:
		print("FAILED TO OPEN SPRITE DIRECTORY!")
	print("======================================")
#-----------------------------------------------------
# Save wall texture with palette
#-----------------------------------------------------
func save_wall_texture(data: PackedByteArray, texture_id: int, num_digits: int):
	var img = Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	
	# Transpose: data is stored column-first, we need row-first
	for x in range(TEXTURE_SIZE):
		for y in range(TEXTURE_SIZE):
			var src_idx = x * TEXTURE_SIZE + y
			if src_idx < data.size():
				var pal_idx = data[src_idx]
				var color = WOLF_PALETTE[pal_idx]
				img.set_pixel(x, y, Color8(color[0], color[1], color[2], 255))
	
	# Generate mipmaps for texture loading
	img.generate_mipmaps()
	
	# Match Python naming: every 2 chunks = 1 wall (unshaded/shaded pair)
	var wall_idx = texture_id / 2  # Integer division
	var is_shaded = texture_id % 2 == 1
	
	# Format: 00.png, 00_shaded.png, 01.png, 01_shaded.png, etc.
	var format_str = "%0" + str(num_digits) + "d"
	var filename = "%swalls/" % current_output_path + format_str % wall_idx
	filename += "_shaded.png" if is_shaded else ".png"
	
	img.save_png(filename)
#-----------------------------------------------------
# Save sprite with proper column decoding
#-----------------------------------------------------
func save_sprite(data: PackedByteArray, sprite_id: int):
	print("    save_sprite called for sprite %d with %d bytes" % [sprite_id, data.size()])
	
	if data.size() < 4:
		print("    FAILED: data too small")
		return
	
	# Read sprite header
	var left_column = data.decode_u16(0)
	var right_column = data.decode_u16(2)
	
	print("    Left: %d, Right: %d" % [left_column, right_column])
	
	if left_column >= TEXTURE_SIZE or right_column >= TEXTURE_SIZE or left_column > right_column:
		print("    FAILED: invalid column bounds")
		return
	
	var num_columns = right_column - left_column + 1
	
	# Read column data pointers
	var column_data_ptrs: Array[int] = []
	for i in range(num_columns):
		var offset_pos = 4 + i * 2
		if offset_pos + 1 < data.size():
			column_data_ptrs.append(data.decode_u16(offset_pos))
		else:
			print("    FAILED: not enough data for column pointers")
			return
	
	# Initialize all pixels as transparent
	var tmp: PackedByteArray = PackedByteArray()
	tmp.resize(TEXTURE_SIZE * TEXTURE_SIZE)
	tmp.fill(255)
	
	# Process each column
	for col_idx in range(num_columns):
		var x = left_column + col_idx
		if x >= TEXTURE_SIZE:
			continue
		
		var cmd_offset = column_data_ptrs[col_idx]
		if cmd_offset >= data.size():
			continue
		
		var pos = cmd_offset
		while pos + 5 < data.size():
			var cmd0 = decode_s16(data, pos)
			if cmd0 == 0:
				break
			
			var cmd1 = decode_s16(data, pos + 2)
			var cmd2 = decode_s16(data, pos + 4)
			pos += 6
			
			var pixel_start = cmd2 / 2 + cmd1
			var row_start = cmd2 / 2
			var row_end = cmd0 / 2
			
			for y in range(row_start, row_end):
				if y >= TEXTURE_SIZE or pixel_start >= data.size():
					break
				
				tmp[y * TEXTURE_SIZE + x] = data[pixel_start]
				pixel_start += 1
	
	# Convert to RGBA image
	var img = Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	
	for y in range(TEXTURE_SIZE):
		for x in range(TEXTURE_SIZE):
			var pal_idx = tmp[y * TEXTURE_SIZE + x]
			
			if pal_idx == 255:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				if pal_idx < WOLF_PALETTE.size():
					var color = WOLF_PALETTE[pal_idx]
					img.set_pixel(x, y, Color8(color[0], color[1], color[2], 255))
	
	img.generate_mipmaps()
	
	var filename
	if sprite_id == 0:
		filename = "%ssprites/SPR_STAT_MINUS2.png" % current_output_path
	elif sprite_id == 1:
		filename = "%ssprites/SPR_STAT_MINUS1.png" % current_output_path
	else:
		filename = "%ssprites/SPR_STAT_%d.png" % [current_output_path, sprite_id - 2]
	print("    Saving to: ", filename)
	var err = img.save_png(filename)
	if err != OK:
		print("    FAILED to save PNG! Error: ", err)
	else:
		print("    SUCCESS!")

#-----------------------------------------------------
# Thumbnail Generation
#-----------------------------------------------------
func generate_thumbnail(layer1: PackedInt32Array, layer2: PackedInt32Array, level: int, map_name: String):
	var img = Image.create(MAP_SIZE, MAP_SIZE, false, Image.FORMAT_RGB8)
	
	for y in range(MAP_SIZE):
		for x in range(MAP_SIZE):
			var idx = y * MAP_SIZE + x
			var tile = layer1[idx] if idx < layer1.size() else 0
			var thing = layer2[idx] if idx < layer2.size() else 0
			
			var color = tile_to_color(tile)
			
			if thing >= 19 and thing <= 22:
				color = Color(0, 1, 0)
			
			img.set_pixel(x, y, color)
	
	img.save_png("%smaps/thumbs/%02d_%s.png" % [current_output_path, level, map_name])


func tile_to_color(tile: int) -> Color:
	if tile == 0:
		return Color.WHITE
	elif tile >= 1 and tile <= 63:
		return Color(0.25, 0.25, 0.25)
	elif tile >= 90 and tile <= 101:
		return Color(0, 0.5, 1)
	elif tile >= 106 and tile <= 111:
		return Color(1, 0, 0)
	else:
		return Color(0.5, 0.5, 0.5)
