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

	stream = load(wav_files[0])
	play()
