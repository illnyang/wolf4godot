extends AudioStreamPlayer

var wav_files : Array[String] = []
var current_index := 0

func _ready():
	print("Włącza się SoundPlayer z: ", get_path())
	wav_files = [
		"res://sfx/digi_000.wav",
		"res://sfx/digi_001.wav",
		"res://sfx/digi_002.wav",
		"res://sfx/digi_003.wav",
		"res://sfx/digi_004.wav"
	]

	if wav_files.size() == 0:
		push_error("Brak .wav w res://sfx/")
		return

	# DŹWIĘK RUSZA TERAZ
	stream = load(wav_files[0])
	play()

#extends Node
#
#const SAMPLE_RATE = 7042
#const NUM_DIGI = 64  # Adjust if needed, usually ~46–64
#
#func _ready():
	#var vswap = FileAccess.open("res://data/VSWAP.WL6", FileAccess.READ)
	#if not vswap:
		#push_error("Missing VSWAP.WL6")
		#return
#
	## Read VSWAP header
	#var num_chunks = vswap.get_16()
	#var sprite_start = vswap.get_16()
	#var sound_start = vswap.get_16()
#
	## Read chunk offsets and lengths
	#var offsets = []
	#for i in range(num_chunks):
		#offsets.append(vswap.get_32())
	#var lengths = []
	#for i in range(num_chunks):
		#lengths.append(vswap.get_16())
#
	## Read sound map from last chunk
	#vswap.seek(offsets[num_chunks - 1])
	#var map_buf = vswap.get_buffer(lengths[num_chunks - 1])
	#var entries = []
	#for i in range(0, map_buf.size(), 4):
		#var rel_page = map_buf[i] | (map_buf[i+1] << 8)
		#var length = map_buf[i+2] | (map_buf[i+3] << 8)
		#entries.append({"page": rel_page, "length": length})
#
	#print("Found", entries.size(), "digi entries")
#
	#for i in range(min(entries.size(), NUM_DIGI)):
		#var entry = entries[i]
		#var rel_page = entry.page
		#var length = entry.length
		#if length < 100:
			#continue
		#var buf = PackedByteArray()
		#var remain = length
		#var p = sound_start + rel_page
		#while remain > 0 and p < num_chunks - 1:
			#vswap.seek(offsets[p])
			#var take = min(remain, lengths[p])
			#buf.append_array(vswap.get_buffer(take))
			#remain -= take
			#p += 1
#
		#if buf.size() == 0:
			#continue
#
		#var sample = AudioStreamWAV.new()
		#sample.format = AudioStreamWAV.FORMAT_8_BITS
		#sample.mix_rate = SAMPLE_RATE
		#sample.stereo = false
		#sample.loop_mode = AudioStreamWAV.LOOP_FORWARD
		#sample.data = buf
#
		#var player = AudioStreamPlayer.new()
		#player.stream = sample
		#player.volume_db = 6
		#add_child(player)
		#player.play()
#
		#print("✔ Playing digi_" + str(i).pad_zeros(3), " size:", buf.size())
		
		
