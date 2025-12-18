# SoundManager.gd
# Wolf3D Sound Manager - Autoload singleton for playing game sounds
extends Node

# Sound cache - loaded on first access
var sound_cache: Dictionary = {}
var sounds_loaded: bool = false

# Audio players pool for overlapping sounds
var audio_players: Array[AudioStreamPlayer] = []
const MAX_PLAYERS = 8

# Wolf3D Sound IDs (from AUDIOWL6.H)
enum SoundID {
	HITWALLSND = 0,
	SELECTWPNSND = 1,
	SELECTITEMSND = 2,
	HEARTBEATSND = 3,
	MOVEGUN2SND = 4,
	MOVEGUN1SND = 5,
	NOWAYSND = 6,
	NAZIHITPLAYERSND = 7,
	SCHABORGSND = 8,
	PLAYERDEATHSND = 9,
	DOGDEATHSND = 10,
	ABORGSND = 11,
	QUIETSND = 12,
	GOABORDSND = 13,
	NAZIFIRESND = 14,
	BABORDSND = 15,
	MISSILESND = 16,
	MISSILEFIRESND = 17,
	ABORTSND = 18,
	GRABORDSND = 19,
	DEABORDSND = 20,
	LEVELDONESND = 21,
	DOGBARKSND = 22,
	ENDBONUS1SND = 23,
	ENDBONUS2SND = 24,
	BONUS1SND = 25,
	BONUS2SND = 26,
	BONUS3SND = 27,
	BONUS4SND = 28,
	SHOOTDOORSND = 29,
	PERCENT100SND = 30,
	BABORDSND2 = 31,
	PUSHWALLSND = 32,
	NOITEMSND = 33,
	DONOTHINGSND = 34,
	GAMEOVERSND = 35,
	OPENDOORSND = 36,
	CLOSEDOORSND = 37,
	DONOTHINGSND2 = 38,
	HALTSND = 39,
	DEABORDSND2 = 40,
	ATABORDSND = 41,
	TOABORDSND = 42,
	YOURABORDSND = 43,
	YOURABORDSND2 = 44,
	YOURABORDSND3 = 45,
	YOURABORDSND4 = 46,
	YOURABORDSND5 = 47,
	YOURABORDSND6 = 48,
	YOURABORDSND7 = 49,
	YOURABORDSND8 = 50,
	YOURABORDSND9 = 51,
	YOURABORDSND10 = 52,
	YOURABORDSND11 = 53,
	YOURABORDSND12 = 54,
	YOURABORDSND13 = 55,
	YOURABORDSND14 = 56,
	YOURABORDSND15 = 57,
	ATKKNIFESND = 58,
	ATKPISTOLSND = 59,
	ATKMACHINEGUNSND = 60,
	ATKGATLINGGUNSND = 61,
	SCABORDSND = 62,
	NABORDSND = 63,
	MECHASND = 64,
	GETKEYSND = 65,
	BONUS1UPSND = 66,
	GETAMMOSND = 67,
	SHOOTSND = 68,
	HEALTH1SND = 69,
	HEALTH2SND = 70
}

func _ready() -> void:
	# Create audio player pool
	for i in range(MAX_PLAYERS):
		var player = AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		audio_players.append(player)

func _load_sounds() -> void:
	if sounds_loaded:
		return
	
	# Load sounds from user://assets/{game}/sounds/
	var sounds_path = "user://assets/%s/sounds/" % GameState.selected_game
	var dir = DirAccess.open(sounds_path)
	
	if dir == null:
		print("SoundManager: No sounds directory found at: ", sounds_path)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".wav"):
			var full_path = sounds_path + file_name
			var stream = _load_wav_file(full_path)
			if stream:
				# Extract sound ID from filename (DIGI_XXX.wav)
				var id_str = file_name.replace("DIGI_", "").replace(".wav", "")
				var sound_id = id_str.to_int()
				sound_cache[sound_id] = stream
		file_name = dir.get_next()
	dir.list_dir_end()
	
	sounds_loaded = true
	print("SoundManager: Loaded %d sounds" % sound_cache.size())

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
	
	# Find fmt chunk
	var fmt = file.get_buffer(4).get_string_from_ascii()
	var fmt_size = file.get_32()
	var audio_format = file.get_16()
	var num_channels = file.get_16()
	var sample_rate = file.get_32()
	file.get_32()  # Byte rate
	file.get_16()  # Block align
	var bits_per_sample = file.get_16()
	
	# Skip to data chunk
	var data_header = file.get_buffer(4).get_string_from_ascii()
	var data_size = file.get_32()
	var audio_data = file.get_buffer(data_size)
	file.close()
	
	# Create AudioStreamWAV
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.stereo = (num_channels == 2)
	stream.data = audio_data
	
	return stream

func play_sound(sound_id: int) -> void:
	# Lazy load sounds on first play
	if not sounds_loaded:
		_load_sounds()
	
	if not sound_cache.has(sound_id):
		return
	
	# Find available player
	for player in audio_players:
		if not player.playing:
			player.stream = sound_cache[sound_id]
			player.play()
			return
	
	# All players busy - use first one (oldest sound)
	audio_players[0].stream = sound_cache[sound_id]
	audio_players[0].play()

# Convenience functions for common sounds
func play_pickup() -> void:
	play_sound(SoundID.BONUS1SND)

func play_key_pickup() -> void:
	play_sound(SoundID.GETKEYSND)

func play_ammo_pickup() -> void:
	play_sound(SoundID.GETAMMOSND)

func play_health_pickup() -> void:
	play_sound(SoundID.HEALTH1SND)

func play_door_open() -> void:
	play_sound(SoundID.OPENDOORSND)

func play_door_close() -> void:
	play_sound(SoundID.CLOSEDOORSND)

func play_pistol() -> void:
	play_sound(SoundID.ATKPISTOLSND)

func play_machinegun() -> void:
	play_sound(SoundID.ATKMACHINEGUNSND)

func play_chaingun() -> void:
	play_sound(SoundID.ATKGATLINGGUNSND)

func play_knife() -> void:
	play_sound(SoundID.ATKKNIFESND)

func play_hit_wall() -> void:
	play_sound(SoundID.HITWALLSND)

func play_no_way() -> void:
	play_sound(SoundID.NOWAYSND)

func play_player_death() -> void:
	play_sound(SoundID.PLAYERDEATHSND)

func reload_sounds() -> void:
	# Call when changing games to reload sounds
	sound_cache.clear()
	sounds_loaded = false
