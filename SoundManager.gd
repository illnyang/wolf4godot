extends Node

var sound_cache: Dictionary = {}
var sounds_loaded: bool = false

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
	for i in range(MAX_PLAYERS):
		var player = AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		audio_players.append(player)

func _load_sounds() -> void:
	if sounds_loaded:
		return
	
	var sounds_path = GameState.get_sounds_path()
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
				var sound_name = file_name.replace(".wav", "")
				sound_cache[sound_name] = stream
		file_name = dir.get_next()
	dir.list_dir_end()
	
	sounds_loaded = true
	print("SoundManager: Loaded %d sounds" % sound_cache.size())

func _load_wav_file(path: String) -> AudioStreamWAV:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	
	var riff = file.get_buffer(4).get_string_from_ascii()
	if riff != "RIFF":
		file.close()
		return null
	
	file.get_32()
	var wave = file.get_buffer(4).get_string_from_ascii()
	if wave != "WAVE":
		file.close()
		return null
	
	var fmt = file.get_buffer(4).get_string_from_ascii()
	var fmt_size = file.get_32()
	var audio_format = file.get_16()
	var num_channels = file.get_16()
	var sample_rate = file.get_32()
	file.get_32()
	file.get_16()
	var bits_per_sample = file.get_16()
	
	var data_header = file.get_buffer(4).get_string_from_ascii()
	var data_size = file.get_32()
	var audio_data = file.get_buffer(data_size)
	file.close()
	
	print("Loading WAV: %s - rate=%d, bits=%d, channels=%d, size=%d" % [path.get_file(), sample_rate, bits_per_sample, num_channels, data_size])
	
	var signed_data = PackedByteArray()
	signed_data.resize(audio_data.size())
	for i in range(audio_data.size()):
		signed_data[i] = (audio_data[i] - 128) & 0xFF
	
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.stereo = (num_channels == 2)
	stream.data = signed_data
	
	return stream

func play_sfx(sound_name: String) -> void:
	if not sounds_loaded:
		_load_sounds()
	
	if not sound_cache.has(sound_name):
		if not sound_cache.has(sound_name.to_upper()):
			print("SoundManager: Sound '%s' not found! Available: %s" % [sound_name, sound_cache.keys()])
			return
		sound_name = sound_name.to_upper()
	
	for player in audio_players:
		if not player.playing:
			player.stream = sound_cache[sound_name]
			player.play()
			print("SoundManager: Playing '%s'" % sound_name)
			return
	
	audio_players[0].stream = sound_cache[sound_name]
	audio_players[0].play()
	print("SoundManager: Playing '%s' (busy)" % sound_name)

func play_sound(sound_id: int) -> void:
	var digi_name = "DIGI_%03d" % sound_id
	if sound_cache.has(digi_name):
		play_sfx(digi_name)
		return
	if not sounds_loaded:
		_load_sounds()

func play_pickup() -> void:
	play_sfx("SLURPIESND")

func play_key_pickup() -> void:
	play_sfx("SLURPIESND")

func play_ammo_pickup() -> void:
	play_sfx("SLURPIESND")
func play_health_pickup() -> void:
	play_sfx("SLURPIESND")

func play_door_open() -> void:
	play_sfx("OPENDOORSND")

func play_door_close() -> void:
	play_sfx("CLOSEDOORSND")

func play_pistol() -> void:
	play_sfx("ATKPISTOLSND")

func play_machinegun() -> void:
	play_sfx("ATKMACHINEGUNSND")

func play_chaingun() -> void:
	play_sfx("ATKGATLINGSND")

func play_knife() -> void:
	play_sfx("ATKPISTOLSND")

func play_hit_wall() -> void:
	play_sfx("HALTSND")

func play_no_way() -> void:
	play_sfx("HALTSND")

func play_player_death() -> void:
	play_sfx("DEATHSCREAM1SND")

func reload_sounds() -> void:
	sound_cache.clear()
	sounds_loaded = false
