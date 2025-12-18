# MusicManager.gd - Plays extracted Wolf3D music (WAV files)
extends Node

var music_player: AudioStreamPlayer
var current_track: String = ""
var music_cache: Dictionary = {}

# Track name to file mapping
const TITLE_MUSIC = "INTROCW3"  # Wolf3D title theme
const LEVEL_MUSIC = ["GETTHEM", "SEARCHN", "POW", "SUSPENSE", "WARMARCH", 
	"CORNER", "NAZI_NOR", "NAZI_OMI", "HEADACHE", "DUNGEON"]

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"
	add_child(music_player)

func play_title_music() -> void:
	play_track(TITLE_MUSIC)

func play_level_music(level_index: int) -> void:
	var track_idx = level_index % LEVEL_MUSIC.size()
	play_track(LEVEL_MUSIC[track_idx])

func play_track(track_name: String) -> void:
	if current_track == track_name and music_player.playing:
		return
	
	var stream = _load_music(track_name)
	if stream:
		current_track = track_name
		music_player.stream = stream
		music_player.play()
		print("MusicManager: Playing ", track_name)
	else:
		print("MusicManager: Track not found: ", track_name)

func stop() -> void:
	music_player.stop()
	current_track = ""

func _load_music(track_name: String) -> AudioStream:
	if music_cache.has(track_name):
		return music_cache[track_name]
	
	# Try loading from extracted music folder
	var music_path = "user://assets/%s/music/%s.wav" % [GameState.selected_game, track_name]
	
	var stream = _load_wav_file(music_path)
	if stream:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = stream.data.size()
		music_cache[track_name] = stream
		return stream
	
	return null

func _load_wav_file(path: String) -> AudioStreamWAV:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	
	# Read WAV header
	var riff = file.get_buffer(4).get_string_from_ascii()
	if riff != "RIFF":
		file.close()
		return null
	
	file.get_32()  # File size
	var wave = file.get_buffer(4).get_string_from_ascii()
	if wave != "WAVE":
		file.close()
		return null
	
	# Read fmt chunk
	file.get_buffer(4)  # "fmt "
	var fmt_size = file.get_32()
	file.get_16()  # Audio format
	var num_channels = file.get_16()
	var sample_rate = file.get_32()
	file.get_32()  # Byte rate
	file.get_16()  # Block align
	var bits_per_sample = file.get_16()
	
	# Skip extra fmt data if present
	if fmt_size > 16:
		file.get_buffer(fmt_size - 16)
	
	# Read data chunk
	file.get_buffer(4)  # "data"
	var data_size = file.get_32()
	var audio_data = file.get_buffer(data_size)
	file.close()
	
	var stream = AudioStreamWAV.new()
	if bits_per_sample == 8:
		stream.format = AudioStreamWAV.FORMAT_8_BITS
	else:
		stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = (num_channels == 2)
	stream.data = audio_data
	
	return stream

func reload_music() -> void:
	music_cache.clear()
	stop()
