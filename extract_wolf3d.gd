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
	DirAccess.make_dir_recursive_absolute(current_output_path + "sounds")
	DirAccess.make_dir_recursive_absolute(current_output_path + "music")
	DirAccess.make_dir_recursive_absolute(current_output_path + "pics")
	DirAccess.make_dir_recursive_absolute(current_output_path + "fonts")
	
	extract_maps()
	extract_vswap()
	extract_audio()  # Extract IMF music from AUDIOT
	extract_adlib_sounds()  # Extract AdLib beep sounds from AUDIOT
	extract_vgagraph()  # Extract pics from VGAGRAPH
	
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
	
	# Extract digitized sounds using sound info page (last chunk)
	# The last chunk contains (startpage, length) pairs for each logical sound
	var sound_info_offset = chunk_offsets[num_chunks - 1]
	var sound_info_length = chunk_lengths[num_chunks - 1]
	
	if sound_info_length == 0:
		print("--> No sound info page found, extracting sounds individually...")
		# Fallback to old method
		var num_sounds_fallback = num_chunks - sound_start - 1
		for i in range(sound_start, num_chunks - 1):
			var offset = chunk_offsets[i]
			var length = chunk_lengths[i]
			if length == 0:
				continue
			vswap.seek(offset)
			var sound_data = vswap.get_buffer(length)
			save_sound_as_wav(sound_data, i - sound_start, "DIGI_%03d" % (i - sound_start))
	else:
		# Read sound info page to get (startpage, length) pairs
		vswap.seek(sound_info_offset)
		var sound_info_data = vswap.get_buffer(sound_info_length)
		
		# Each entry is 4 bytes: 2 bytes startpage + 2 bytes length
		var num_digi = sound_info_length / 4
		print("--> Sound info page found: %d digitized sounds" % num_digi)
		
		for snd_idx in range(num_digi):
			var info_offset = snd_idx * 4
			if info_offset + 3 >= sound_info_data.size():
				break
			
			var start_page = sound_info_data.decode_u16(info_offset)
			var sound_length = sound_info_data.decode_u16(info_offset + 2)
			
			# startpage is relative to sound_start
			var absolute_chunk = sound_start + start_page
			
			if absolute_chunk >= num_chunks - 1 or sound_length == 0:
				continue
			
			# Collect data from all pages that make up this sound
			var combined_data = PackedByteArray()
			var remaining_length = sound_length
			var current_chunk = absolute_chunk
			
			while remaining_length > 0 and current_chunk < num_chunks - 1:
				var chunk_offset = chunk_offsets[current_chunk]
				var chunk_length = chunk_lengths[current_chunk]
				
				if chunk_length == 0:
					current_chunk += 1
					continue
				
				vswap.seek(chunk_offset)
				var bytes_to_read = mini(chunk_length, remaining_length)
				var page_data = vswap.get_buffer(bytes_to_read)
				combined_data.append_array(page_data)
				
				remaining_length -= bytes_to_read
				current_chunk += 1
			
			# Get sound name
			var sound_name = "DIGI_%03d" % snd_idx
			if snd_idx < DIGI_SOUND_NAMES.size():
				sound_name = DIGI_SOUND_NAMES[snd_idx]
			
			save_sound_as_wav(combined_data, snd_idx, sound_name)
		
		print("--> Extracted %d digitized sounds" % num_digi)
	
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


#-----------------------------------------------------
# Sound Extraction - Convert raw PCM to WAV
#-----------------------------------------------------
func save_sound_as_wav(data: PackedByteArray, sound_id: int, sound_name: String = "") -> void:
	if data.size() == 0:
		return
	
	# Wolf3D digitized sounds: 8-bit unsigned PCM, mono, 7042 Hz (original rate)
	const SAMPLE_RATE = 7042
	const BITS_PER_SAMPLE = 8
	const NUM_CHANNELS = 1
	
	# Use provided name or fall back to numbered format
	var name_part = sound_name if sound_name != "" else "DIGI_%03d" % sound_id
	var filename = "%ssounds/%s.wav" % [current_output_path, name_part]
	var file = FileAccess.open(filename, FileAccess.WRITE)
	if file == null:
		push_error("Cannot create sound file: " + filename)
		return
	
	# WAV file header (44 bytes)
	var data_size = data.size()
	var file_size = 36 + data_size
	
	# RIFF header
	file.store_buffer("RIFF".to_ascii_buffer())
	file.store_32(file_size)
	file.store_buffer("WAVE".to_ascii_buffer())
	
	# fmt sub-chunk
	file.store_buffer("fmt ".to_ascii_buffer())
	file.store_32(16)  # Sub-chunk size
	file.store_16(1)   # Audio format (1 = PCM)
	file.store_16(NUM_CHANNELS)
	file.store_32(SAMPLE_RATE)
	file.store_32(SAMPLE_RATE * NUM_CHANNELS * BITS_PER_SAMPLE / 8)  # Byte rate
	file.store_16(NUM_CHANNELS * BITS_PER_SAMPLE / 8)  # Block align
	file.store_16(BITS_PER_SAMPLE)
	
	# data sub-chunk
	file.store_buffer("data".to_ascii_buffer())
	file.store_32(data_size)
	
	# Wolf3D uses unsigned 8-bit PCM, WAV expects unsigned 8-bit
	# So we can write the data directly
	file.store_buffer(data)
	
	file.close()


#-----------------------------------------------------
# Audio Extraction - Extract IMF music from AUDIOT
#-----------------------------------------------------
# Wolf3D audio structure:
# - AUDIOHED contains 32-bit offsets to chunks
# - AUDIOT contains the actual audio data
# - Chunks are: PC speaker sounds, AdLib sounds, then AdLib music
# - Music is in IMF format (OPL2 register writes + timing)

# Wolf3D music track names (AUDIOWL6.H)
const MUSIC_NAMES = [
	"CORNER", "DUNGEON", "WARMARCH", "GETTHEM", "HEADACHE",
	"HITLWLTZ", "INTROCW3", "NAZI_NOR", "NAZI_OMI", "POW",
	"SALUTE", "SEARCHN", "SUSPENSE", "VICTORS", "WONDERIN",
	"FUNKYOU", "ENDLEVEL", "GOINGAFT", "PREGNANT", "ULTIMATE",
	"NAZI_RAP", "ZEROHOUR", "TWELFTH", "ROSTER", "URAHERO", "VICMARCH", "PACMAN"
]

# Wolf3D digitized sound names (matching VSWAP order from your screenshot)
# These correspond to the sounds in the sound info page
const DIGI_SOUND_NAMES = [
	"HALTSND", "DOGBARKSND", "CLOSEDOORSND", "OPENDOORSND", "ATKMACHINEGUNSND",
	"ATKPISTOLSND", "ATKGATLINGSND", "SCHUTZADSND", "GUTENTAGSND", "MUTTISND",
	"BOSSFIRESND", "SSFIRESND", "DEATHSCREAM1SND", "DEATHSCREAM2SND", "TAKEDAMAGESND",
	"PUSHWALLSND", "DOGDEATHSND", "AHHHGSND", "DIESND", "EVASND",
	"LEBENSND", "NAZIFIRESND", "SLURPIESND", "TOT_HUNDSND", "MEINGOTTSND",
	"SCHABBSHASND", "HITLERHASND", "SPIONSND", "NEINSOVASSND", "DOGATTACKSND",
	"LEVELDONESND", "MECHSTEPSND", "YEAHSND", "SCHEISTSND", "DEATHSCREAM4SND",
	"DEATHSCREAM5SND", "DONNERSND", "EINESND", "ERLAUBENSND", "DEATHSCREAM6SND",
	"DEATHSCREAM7SND", "DEATHSCREAM8SND", "DEATHSCREAM9SND", "KEINSND", "MEINSND",
	"ROSESND"
]

# AdLib sound names (from AUDIOWL6.H) - these are synthesized beeps stored in AUDIOT
const ADLIB_SOUND_NAMES = [
	"HITWALLSND", "SELECTWPNSND", "SELECTITEMSND", "HEARTBEATSND", "MOVEGUN2SND",
	"MOVEGUN1SND", "NOWAYSND", "NAZIHITPLAYERSND", "SCHABBSTHROWSND", "PLAYERDEATHSND",
	"DOGDEATHSND_AL", "ATKGATLINGSND_AL", "GETKEYSND", "NOITEMSND", "WALK1SND",
	"WALK2SND", "TAKEDAMAGESND_AL", "GAMEOVERSND", "OPENDOORSND_AL", "CLOSEDOORSND_AL",
	"DONOTHINGSND", "HALTSND_AL", "DEATHSCREAM2SND_AL", "ATKKNIFESND", "ATKPISTOLSND_AL",
	"DEATHSCREAM3SND", "ATKMACHINEGUNSND_AL", "HITENEMYSND", "SHOOTDOORSND", "DEATHSCREAM1SND_AL",
	"GETMACHINESND", "GETAMMOSND", "SHOOTSND", "HEALTH1SND", "HEALTH2SND",
	"BONUS1SND", "BONUS2SND", "BONUS3SND", "GETGATLINGSND", "ESCPRESSEDSND",
	"LEVELDONESND_AL", "DOGBARKSND_AL", "ENDBONUS1SND", "ENDBONUS2SND", "BONUS1UPSND",
	"BONUS4SND", "PUSHWALLSND_AL", "NOBONUSSND", "PERCENT100SND", "BOSSACTIVESND",
	"MUTTISND_AL", "SCHUTZADSND_AL", "AHHHGSND_AL", "DIESND_AL", "EVASND_AL",
	"GUTENTAGSND_AL", "LEBENSND_AL", "SCHEISTSND_AL", "NAZIFIRESND_AL", "BOSSFIRESND_AL",
	"SSFIRESND_AL", "SLURPIESND_AL", "TOTHUNDSND_AL", "MEINGOTTSND_AL", "SCHABBSHASND_AL",
	"HITLERHASND_AL", "SPIONSND_AL", "NEINSOVASSND_AL", "DOGATTACKSND_AL", "FLAMETHROWERSND",
	"MECHSTEPSND_AL", "GOOBSSND", "YEAHSND_AL", "DEATHSCREAM4SND_AL", "DEATHSCREAM5SND_AL",
	"DEATHSCREAM6SND_AL", "DEATHSCREAM7SND_AL", "DEATHSCREAM8SND_AL", "DEATHSCREAM9SND_AL",
	"DONNERSND_AL", "EINESND_AL", "ERLAUBENSND_AL", "KEINSND_AL", "MEINSND_AL",
	"ROSESND_AL", "MISSILEFIRESND", "MISSILEHITSND"
]

#-----------------------------------------------------
# AdLib Sound Extraction - Convert OPL2 data to WAV
#-----------------------------------------------------
# AdLib sounds are OPL2 FM synthesis data. We use a simplified square wave
# approximation to convert them to playable WAV files.

func extract_adlib_sounds() -> void:
	print("Extracting AdLib sounds from AUDIOT...")
	
	var audiohed_path = current_data_path + "AUDIOHED" + current_extension
	var audiot_path = current_data_path + "AUDIOT" + current_extension
	
	var audiohed = FileAccess.open(audiohed_path, FileAccess.READ)
	if audiohed == null:
		print("--> No AUDIOHED found, skipping AdLib extraction")
		return
	
	var audiot = FileAccess.open(audiot_path, FileAccess.READ)
	if audiot == null:
		audiohed.close()
		print("--> No AUDIOT found, skipping AdLib extraction")
		return
	
	# Read all offsets from AUDIOHED (32-bit each)
	var offsets: Array[int] = []
	while audiohed.get_position() < audiohed.get_length():
		offsets.append(audiohed.get_32())
	audiohed.close()
	
	var num_chunks = offsets.size() - 1
	
	# In Wolf3D, AdLib sounds start at index LASTSOUND (NUMSOUNDS)
	# PC speaker sounds are 0 to LASTSOUND-1
	# AdLib sounds are LASTSOUND to 2*LASTSOUND-1
	# We estimate LASTSOUND as ~87 based on audiowl6.h
	var lastsound = 87
	var adlib_start = lastsound  # AdLib sounds start after PC speaker sounds
	
	print("--> Extracting AdLib sounds (indices %d to %d)" % [adlib_start, adlib_start + lastsound - 1])
	
	var sounds_dir = current_output_path + "sounds/"
	DirAccess.make_dir_recursive_absolute(sounds_dir)
	
	var extracted = 0
	for i in range(lastsound):
		var chunk_idx = adlib_start + i
		if chunk_idx >= num_chunks:
			break
		
		var offset = offsets[chunk_idx]
		var next_offset = offsets[chunk_idx + 1] if chunk_idx + 1 < offsets.size() else audiot.get_length()
		
		# Skip invalid offsets
		if offset == 0xFFFFFFFF or offset >= audiot.get_length():
			continue
		if next_offset == 0xFFFFFFFF:
			continue
		
		var chunk_size = next_offset - offset
		if chunk_size < 24:  # Minimum AdLib sound header is 24 bytes
			continue
		
		audiot.seek(offset)
		
		# Read AdLib sound header (6 byte SoundCommon + 16 byte Instrument + 1 byte block)
		var length = audiot.get_32()  # Data length
		var priority = audiot.get_16() # Priority
		
		# Read instrument data (16 bytes) - we'll use simplified synthesis
		var inst_data = audiot.get_buffer(16)
		
		# Read block (octave selector)
		var block = audiot.get_8()
		
		# Read sound data
		if length == 0 or length > chunk_size - 23:
			continue
		
		var data = audiot.get_buffer(length)
		
		# Convert AdLib data to WAV using simplified synthesis
		var pcm_data = _render_adlib_to_pcm(data, block, inst_data)
		
		if pcm_data.size() > 0:
			var sound_name = "ADLIB_%03d" % i
			if i < ADLIB_SOUND_NAMES.size():
				sound_name = ADLIB_SOUND_NAMES[i]
			
			_save_adlib_wav(pcm_data, sound_name)
			extracted += 1
	
	audiot.close()
	print("--> Extracted %d AdLib sounds" % extracted)

func _render_adlib_to_pcm(data: PackedByteArray, block: int, inst: PackedByteArray) -> PackedByteArray:
	# Simplified AdLib rendering using square wave synthesis
	# Real OPL2 uses FM synthesis, but square waves give recognizable beeps
	
	const SAMPLE_RATE = 22050  # Output sample rate
	const TICK_RATE = 140.0    # Wolf3D runs AdLib at 140 Hz
	const SAMPLES_PER_TICK = SAMPLE_RATE / TICK_RATE
	
	var result = PackedByteArray()
	
	# OPL2 frequency calculation:
	# The block value from Wolf3D header is raw octave (0-7)
	# Freq = F-Number * 49716 / (2^(20-Block))
	# Since we only have the low byte of F-Number, we treat it as is
	# Wolf3D uses block values typically 2-5 for sound effects
	var octave = block & 7
	if octave == 0:
		octave = 4  # Default to middle octave if not set
	
	var phase = 0.0
	
	for byte_idx in range(data.size()):
		var freq_low = data[byte_idx]
		
		if freq_low == 0:
			# Silence - output silence samples
			for s in range(int(SAMPLES_PER_TICK)):
				result.append(128)  # 8-bit silence (unsigned)
		else:
			# Calculate frequency from F-Number
			# F-Number is 10-bit (0-1023), we have low byte only
			# Adjust multiplier to tune pitch (try 2, 3, or 4)
			var f_number = freq_low * 0.5  # Tune this value for correct pitch
			
			# OPL2 formula: Freq = F-Number * 49716 / (2^(20-Block))
			var freq = (f_number * 49716.0) / pow(2, 20 - octave)
			
			# Clamp frequency to audible range
			freq = clamp(freq, 80.0, 8000.0)
			
			# Generate square wave samples for this tick
			var phase_inc = freq / SAMPLE_RATE
			
			for s in range(int(SAMPLES_PER_TICK)):
				# Square wave with reduced amplitude for less harsh sound
				var sample = 192 if sin(phase * TAU) > 0 else 64
				result.append(sample)
				phase += phase_inc
				if phase >= 1.0:
					phase -= 1.0
	
	return result

func _save_adlib_wav(data: PackedByteArray, sound_name: String) -> void:
	if data.size() == 0:
		return
	
	const SAMPLE_RATE = 22050
	var filename = "%ssounds/%s.wav" % [current_output_path, sound_name]
	
	var file = FileAccess.open(filename, FileAccess.WRITE)
	if file == null:
		return
	
	var data_size = data.size()
	var file_size = 36 + data_size
	
	# WAV header
	file.store_buffer("RIFF".to_ascii_buffer())
	file.store_32(file_size)
	file.store_buffer("WAVE".to_ascii_buffer())
	
	# fmt chunk
	file.store_buffer("fmt ".to_ascii_buffer())
	file.store_32(16)
	file.store_16(1)  # PCM
	file.store_16(1)  # Mono
	file.store_32(SAMPLE_RATE)
	file.store_32(SAMPLE_RATE)  # Byte rate
	file.store_16(1)  # Block align
	file.store_16(8)  # 8 bits
	
	# data chunk
	file.store_buffer("data".to_ascii_buffer())
	file.store_32(data_size)
	file.store_buffer(data)
	
	file.close()

func extract_audio() -> void:
	print("Extracting audio (IMF music)...")
	
	var audiohed_path = current_data_path + "AUDIOHED" + current_extension
	var audiot_path = current_data_path + "AUDIOT" + current_extension
	
	var audiohed = FileAccess.open(audiohed_path, FileAccess.READ)
	if audiohed == null:
		print("-> No AUDIOHED found, skipping music extraction")
		return
	
	var audiot = FileAccess.open(audiot_path, FileAccess.READ)
	if audiot == null:
		audiohed.close()
		print("-> No AUDIOT found, skipping music extraction")
		return
	
	# Read all offsets from AUDIOHED (32-bit each)
	var offsets: Array[int] = []
	while audiohed.get_position() < audiohed.get_length():
		offsets.append(audiohed.get_32())
	audiohed.close()
	
	# Find where music starts by looking for the pattern
	# Music chunks are larger and start after sound effects
	# In Wolf3D: startmusic = STARTMUSIC constant (varies by version)
	# We'll detect it by finding larger chunks near the end
	
	var num_chunks = offsets.size() - 1  # Last offset is end-of-file marker
	
	# Heuristic: music is in the last ~27 chunks for Wolf3D
	# Calculate chunk sizes and find music section
	var chunk_sizes: Array[int] = []
	for i in range(num_chunks):
		if offsets[i] != 0xFFFFFFFF and offsets[i + 1] != 0xFFFFFFFF:
			var size = offsets[i + 1] - offsets[i]
			chunk_sizes.append(size)
		else:
			chunk_sizes.append(0)
	
	# Find first large chunk (likely music) - music chunks are typically > 1000 bytes
	var music_start_idx = -1
	for i in range(num_chunks - 1, -1, -1):
		if chunk_sizes[i] > 1000:
			music_start_idx = i
	
	if music_start_idx < 0:
		print("-> Could not find music in AUDIOT")
		audiot.close()
		return
	
	# Count backwards to find first music chunk
	var music_count = 0
	for i in range(music_start_idx, num_chunks):
		if chunk_sizes[i] > 500:  # Music is usually > 500 bytes
			music_count += 1
	
	# Adjust music_start_idx to the actual start
	music_start_idx = num_chunks - music_count
	
	print("-> Found %d music tracks starting at chunk %d" % [music_count, music_start_idx])
	
	# Extract each music track
	var extracted = 0
	for i in range(music_count):
		var chunk_idx = music_start_idx + i
		if chunk_idx >= num_chunks:
			break
		
		var offset = offsets[chunk_idx]
		var next_offset = offsets[chunk_idx + 1]
		
		if offset == 0xFFFFFFFF or next_offset == 0xFFFFFFFF:
			continue
		
		var size = next_offset - offset
		if size <= 0:
			continue
		
		audiot.seek(offset)
		var data = audiot.get_buffer(size)
		
		# Get track name
		var track_name = "TRACK_%02d" % i
		if i < MUSIC_NAMES.size():
			track_name = MUSIC_NAMES[i]
		
		# Save as .imf file (can be played with AdPlug or converted)
		var filename = "%smusic/%s.imf" % [current_output_path, track_name]
		var file = FileAccess.open(filename, FileAccess.WRITE)
		if file:
			# IMF Type-0 format: just the raw data
			file.store_buffer(data)
			file.close()
			extracted += 1
	
	audiot.close()
	print("-> Extracted %d IMF music files to music/" % extracted)
	
	# Automatically convert IMF to WAV using bundled imf2wav.exe
	_convert_imf_to_wav()


func _convert_imf_to_wav() -> void:
	# Path to bundled imf2wav.exe
	var imf2wav_path = ProjectSettings.globalize_path("res://tools/imf2wav.exe")
	
	if not FileAccess.file_exists("res://tools/imf2wav.exe"):
		print("-> imf2wav.exe not found in tools/, skipping WAV conversion")
		print("   Copy imf2wav.exe to res://tools/ for automatic conversion")
		return
	
	var music_dir = current_output_path + "music/"
	var global_music_dir = ProjectSettings.globalize_path(music_dir)
	
	var dir = DirAccess.open(music_dir)
	if dir == null:
		return
	
	print("-> Converting IMF to WAV...")
	var converted = 0
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".imf"):
			var imf_path = global_music_dir + file_name
			var wav_name = file_name.replace(".imf", ".wav")
			var wav_path = global_music_dir + wav_name
			
			# Skip if WAV already exists
			if FileAccess.file_exists(music_dir + wav_name):
				file_name = dir.get_next()
				continue
			
			# Run imf2wav.exe
			var args = [imf_path, wav_path]
			var output = []
			var result = OS.execute(imf2wav_path, args, output, true)
			
			if result == 0:
				converted += 1
			else:
				print("   Failed to convert: ", file_name)
		
		file_name = dir.get_next()
	dir.list_dir_end()
	
	print("-> Converted %d IMF files to WAV" % converted)


#-----------------------------------------------------
# VGAGRAPH Extraction - Extract pics from VGAGRAPH
#-----------------------------------------------------
# Based on original Wolf3D source code (ID_CA.C, ID_VH.C)
# VGAGRAPH uses Huffman compression and VGA Mode X planar format

# Picture names from GFXV_WL6.H (Wolf3D full version)
# Pics start at chunk 3
const PIC_NAMES = [
	"H_BJPIC", "H_CASTLEPIC", "H_BLAZEPIC", "H_TOPWINDOWPIC", "H_LEFTWINDOWPIC",
	"H_RIGHTWINDOWPIC", "H_BOTTOMINFOPIC", "C_OPTIONSPIC", "C_CURSOR1PIC", "C_CURSOR2PIC",
	"C_NOTSELECTEDPIC", "C_SELECTEDPIC", "C_FXTITLEPIC", "C_DIGITITLEPIC", "C_MUSICTITLEPIC",
	"C_MOUSELBACKPIC", "C_BABYMODEPIC", "C_EASYPIC", "C_NORMALPIC", "C_HARDPIC",
	"C_LOADSAVEDISKPIC", "C_DISKLOADING1PIC", "C_DISKLOADING2PIC", "C_CONTROLPIC",
	"C_CUSTOMIZEPIC", "C_LOADGAMEPIC", "C_SAVEGAMEPIC", "C_EPISODE1PIC", "C_EPISODE2PIC",
	"C_EPISODE3PIC", "C_EPISODE4PIC", "C_EPISODE5PIC", "C_EPISODE6PIC", "C_CODEPIC",
	"C_TIMECODEPIC", "C_LEVELPIC", "C_NAMEPIC", "C_SCOREPIC", "C_JOY1PIC", "C_JOY2PIC",
	"L_GUYPIC", "L_COLONPIC", "L_NUM0PIC", "L_NUM1PIC", "L_NUM2PIC", "L_NUM3PIC",
	"L_NUM4PIC", "L_NUM5PIC", "L_NUM6PIC", "L_NUM7PIC", "L_NUM8PIC", "L_NUM9PIC",
	"L_PERCENTPIC", "L_APIC", "L_BPIC", "L_CPIC", "L_DPIC", "L_EPIC", "L_FPIC",
	"L_GPIC", "L_HPIC", "L_IPIC", "L_JPIC", "L_KPIC", "L_LPIC", "L_MPIC", "L_NPIC",
	"L_OPIC", "L_PPIC", "L_QPIC", "L_RPIC", "L_SPIC", "L_TPIC", "L_UPIC", "L_VPIC",
	"L_WPIC", "L_XPIC", "L_YPIC", "L_ZPIC", "L_EXPOINTPIC", "L_APOSTROPHEPIC",
	"L_GUY2PIC", "L_BJWINSPIC", "STATUSBARPIC", "TITLEPIC", "PG13PIC", "CREDITSPIC",
	"HIGHSCORESPIC", "KNIFEPIC", "GUNPIC", "MACHINEGUNPIC", "GATLINGGUNPIC",
	"NOKEYPIC", "GOLDKEYPIC", "SILVERKEYPIC", "N_BLANKPIC", "N_0PIC", "N_1PIC",
	"N_2PIC", "N_3PIC", "N_4PIC", "N_5PIC", "N_6PIC", "N_7PIC", "N_8PIC", "N_9PIC",
	"FACE1APIC", "FACE1BPIC", "FACE1CPIC", "FACE2APIC", "FACE2BPIC", "FACE2CPIC",
	"FACE3APIC", "FACE3BPIC", "FACE3CPIC", "FACE4APIC", "FACE4BPIC", "FACE4CPIC",
	"FACE5APIC", "FACE5BPIC", "FACE5CPIC", "FACE6APIC", "FACE6BPIC", "FACE6CPIC",
	"FACE7APIC", "FACE7BPIC", "FACE7CPIC", "FACE8APIC", "GOTGATLINGPIC", "MUTANTBJPIC",
	"PAUSEDPIC", "GETPSYCHEDPIC"
]

const STARTPICS = 3  # First pic chunk in VGAGRAPH

func extract_vgagraph() -> void:
	print("Extracting VGAGRAPH (pics)...")
	
	var vgadict_path = current_data_path + "VGADICT" + current_extension
	var vgahead_path = current_data_path + "VGAHEAD" + current_extension
	var vgagraph_path = current_data_path + "VGAGRAPH" + current_extension
	
	# Open VGADICT (Huffman dictionary)
	var vgadict = FileAccess.open(vgadict_path, FileAccess.READ)
	if vgadict == null:
		print("-> No VGADICT found, skipping VGAGRAPH extraction")
		return
	
	# Read Huffman table (255 nodes, each with 2 unsigned shorts = 4 bytes)
	var huffman_table: Array = []
	for i in range(255):
		var bit0 = vgadict.get_16()
		var bit1 = vgadict.get_16()
		huffman_table.append([bit0, bit1])
	vgadict.close()
	print("-> Loaded Huffman dictionary (255 nodes)")
	
	# Open VGAHEAD (chunk offsets - 3 bytes each for Wolf3D)
	var vgahead = FileAccess.open(vgahead_path, FileAccess.READ)
	if vgahead == null:
		print("-> No VGAHEAD found, skipping VGAGRAPH extraction")
		return
	
	# Read 3-byte offsets
	var offsets: Array[int] = []
	while vgahead.get_position() < vgahead.get_length():
		var b0 = vgahead.get_8()
		var b1 = vgahead.get_8()
		var b2 = vgahead.get_8()
		var offset = b0 | (b1 << 8) | (b2 << 16)
		# -1 (0xFFFFFF) means sparse/unused chunk
		if offset == 0xFFFFFF:
			offset = -1
		offsets.append(offset)
	vgahead.close()
	print("-> Found %d chunk offsets" % offsets.size())
	
	# Open VGAGRAPH
	var vgagraph = FileAccess.open(vgagraph_path, FileAccess.READ)
	if vgagraph == null:
		print("-> No VGAGRAPH found, skipping extraction")
		return
	
	# First, read the picture table from chunk 0 (STRUCTPIC)
	# Contains width/height for each pic
	var pic_table = _read_pic_table(vgagraph, offsets, huffman_table)
	if pic_table.is_empty():
		print("-> Failed to read picture table")
		vgagraph.close()
		return
	print("-> Loaded picture dimensions for %d pics" % pic_table.size())
	
	# Extract each pic (starting at STARTPICS)
	var extracted = 0
	var num_pics = mini(PIC_NAMES.size(), pic_table.size())
	
	# Extract fonts first (Chunks 1 and 2)
	_extract_fonts(vgagraph, offsets, huffman_table)
	
	for i in range(num_pics):
		var chunk_idx = STARTPICS + i
		if chunk_idx >= offsets.size() - 1:
			break
		
		var offset = offsets[chunk_idx]
		var next_offset = offsets[chunk_idx + 1]
		
		# Skip sparse chunks
		if offset < 0:
			continue
		
		# Find next valid offset for size calculation
		var j = chunk_idx + 1
		while j < offsets.size() and offsets[j] < 0:
			j += 1
		if j >= offsets.size():
			break
		next_offset = offsets[j]
		
		var compressed_size = next_offset - offset
		if compressed_size <= 4:
			continue
		
		# Read compressed data
		vgagraph.seek(offset)
		var expanded_len = vgagraph.get_32()  # First 4 bytes = expanded length
		var compressed_data = vgagraph.get_buffer(compressed_size - 4)
		
		# Huffman decompress
		var decompressed = _huffman_expand(compressed_data, expanded_len, huffman_table)
		if decompressed.size() == 0:
			continue
		
		# Get dimensions from pic table
		var pic_info = pic_table[i] if i < pic_table.size() else {"width": 0, "height": 0}
		var width = pic_info.width
		var height = pic_info.height
		
		if width <= 0 or height <= 0 or width > 320 or height > 200:
			continue
		
		# Unmunge from VGA planar format
		var linear_data = _unmunge_pic(decompressed, width, height)
		if linear_data.size() != width * height:
			continue
		
		# Save as PNG
		var pic_name = PIC_NAMES[i] if i < PIC_NAMES.size() else "PIC_%03d" % i
		_save_pic(linear_data, width, height, i, pic_name)
		extracted += 1
	
	vgagraph.close()
	print("-> Extracted %d pics to pics/" % extracted)


func _read_pic_table(vgagraph: FileAccess, offsets: Array[int], huffman_table: Array) -> Array:
	# Chunk 0 (STRUCTPIC) contains picture dimensions
	# Each entry: 2 bytes width + 2 bytes height
	var pic_table: Array = []
	
	if offsets.size() < 2 or offsets[0] < 0:
		return pic_table
	
	var offset = offsets[0]
	var next_offset = offsets[1]
	
	# Find next valid offset
	var j = 1
	while j < offsets.size() and offsets[j] < 0:
		j += 1
	if j >= offsets.size():
		return pic_table
	next_offset = offsets[j]
	
	var compressed_size = next_offset - offset
	if compressed_size <= 4:
		return pic_table
	
	vgagraph.seek(offset)
	var expanded_len = vgagraph.get_32()
	var compressed_data = vgagraph.get_buffer(compressed_size - 4)
	
	var decompressed = _huffman_expand(compressed_data, expanded_len, huffman_table)
	if decompressed.size() == 0:
		return pic_table
	
	# Parse width/height pairs
	var pos = 0
	while pos + 3 < decompressed.size():
		var width = decompressed.decode_u16(pos)
		var height = decompressed.decode_u16(pos + 2)
		pic_table.append({"width": width, "height": height})
		pos += 4
	
	return pic_table


func _huffman_expand(source: PackedByteArray, expanded_len: int, huffman_table: Array) -> PackedByteArray:
	# Huffman decompression based on CAL_HuffExpand from ID_CA.C
	var result = PackedByteArray()
	result.resize(expanded_len)
	
	if source.size() == 0 or expanded_len == 0:
		return PackedByteArray()
	
	var src_pos = 0
	var dest_pos = 0
	var node_idx = 254  # Head node is always 254
	
	while dest_pos < expanded_len and src_pos < source.size():
		var byte_val = source[src_pos]
		src_pos += 1
		
		for bit in range(8):
			if dest_pos >= expanded_len:
				break
			
			var bit_val = (byte_val >> bit) & 1
			var next_node = huffman_table[node_idx][bit_val]
			
			if next_node < 256:
				# It's a byte value
				result[dest_pos] = next_node
				dest_pos += 1
				node_idx = 254  # Back to head
			else:
				# It's a node pointer (subtract 256 to get node index)
				node_idx = next_node - 256
				if node_idx >= 255:
					node_idx = 254  # Safety: reset to head
	
	return result


func _unmunge_pic(data: PackedByteArray, width: int, height: int) -> PackedByteArray:
	# Reverse the VL_MungePic operation from ID_VH.C
	# VGA Mode X format: data is stored as 4 separate planes
	# Plane 0: pixels 0, 4, 8, 12... (every 4th pixel starting at 0)
	# Plane 1: pixels 1, 5, 9, 13... (every 4th pixel starting at 1)
	# etc.
	
	var result = PackedByteArray()
	result.resize(width * height)
	
	if data.size() < width * height:
		# Not enough data, return as-is (non-planar format)
		return data
	
	# Width must be divisible by 4 for planar format
	if width % 4 != 0:
		# Not planar format, return as-is
		return data
	
	var pwidth = width / 4  # Width of each plane
	var src_pos = 0
	
	for plane in range(4):
		for y in range(height):
			for x in range(pwidth):
				if src_pos < data.size():
					var dest_x = x * 4 + plane
					var dest_idx = y * width + dest_x
					if dest_idx < result.size():
						result[dest_idx] = data[src_pos]
				src_pos += 1
	
	return result


func _save_pic(data: PackedByteArray, width: int, height: int, pic_id: int, name: String) -> void:
	# Create image with Wolf3D palette
	var img = Image.create(width, height, false, Image.FORMAT_RGBA8)
	
	for y in range(height):
		for x in range(width):
			var idx = y * width + x
			if idx < data.size():
				var pal_idx = data[idx]
				if pal_idx < WOLF_PALETTE.size():
					var color = WOLF_PALETTE[pal_idx]
					img.set_pixel(x, y, Color8(color[0], color[1], color[2], 255))
				else:
					img.set_pixel(x, y, Color8(0, 0, 0, 255))
	
	var filename = "%spics/%03d_%s.png" % [current_output_path, pic_id, name]
	var err = img.save_png(filename)
	if err != OK:
		print("   Failed to save: ", filename)

func _extract_fonts(vgagraph: FileAccess, offsets: Array[int], huffman_table: Array) -> void:
	print("-> Extracting fonts (Chunks 1 and 2)...")
	
	for i in range(1, 3):  # Chunks 1 and 2 are fonts
		var offset = offsets[i]
		if offset < 0: continue
		
		# Find next valid offset for size
		var j = i + 1
		while j < offsets.size() and offsets[j] < 0: j += 1
		if j >= offsets.size(): break
		
		var compressed_size = offsets[j] - offset
		vgagraph.seek(offset)
		var expanded_len = vgagraph.get_32()
		var compressed_data = vgagraph.get_buffer(compressed_size - 4)
		
		var decompressed = _huffman_expand(compressed_data, expanded_len, huffman_table)
		if decompressed.size() < 770: continue # fontstruct is 770 bytes
		
		_save_font_atlas(decompressed, i)

func _save_font_atlas(data: PackedByteArray, font_id: int) -> void:
	# fontstruct: height (2), location[256] (512), width[256] (256)
	var height = data.decode_u16(0)
	var locations: Array[int] = []
	for i in range(256):
		locations.append(data.decode_u16(2 + i * 2))
	var widths: Array[int] = []
	for i in range(256):
		widths.append(data[514 + i])
	
	# Calculate total width for atlas (16x16 grid)
	var max_char_width = 0
	for w in widths: max_char_width = max(max_char_width, w)
	
	var atlas_width = max_char_width * 16
	var atlas_height = height * 16
	
	var img = Image.create(atlas_width, atlas_height, false, Image.FORMAT_RGBA8)
	var font_metrics = {
		"height": height,
		"characters": {}
	}
	
	for i in range(256):
		var char_width = widths[i]
		var char_loc = locations[i]
		
		if char_width == 0 or char_loc == 0 or char_loc >= data.size():
			continue
			
		var col = i % 16
		var row = i / 16
		var atlas_x = col * max_char_width
		var atlas_y = row * height
		
		# Copy character pixels
		for y in range(height):
			for x in range(char_width):
				var src_idx = char_loc + y * char_width + x
				if src_idx < data.size():
					var val = data[src_idx]
					if val != 0:
						# Original drawer uses fontcolor, we'll use white for the atlas
						img.set_pixel(atlas_x + x, atlas_y + y, Color.WHITE)
					else:
						img.set_pixel(atlas_x + x, atlas_y + y, Color(0,0,0,0))
		
		font_metrics["characters"][i] = {
			"x": atlas_x,
			"y": atlas_y,
			"width": char_width
		}
	
	var font_name = "FONT%d" % font_id
	var base_path = "%sfonts/%s" % [current_output_path, font_name]
	img.save_png(base_path + ".png")
	
	var json_file = FileAccess.open(base_path + ".json", FileAccess.WRITE)
	if json_file:
		json_file.store_string(JSON.stringify(font_metrics, "\t"))
		json_file.close()
	
	print("   Extracted %s (%dpx high) to fonts/" % [font_name, height])
