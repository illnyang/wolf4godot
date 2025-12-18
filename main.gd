extends Control

func _ready():
	print("Checking assets...")
	if not AssetExtractor.extraction_complete:
		await AssetExtractor.extraction_finished
	print("Assets ready!")

	if has_node("StartScreen"):
		$StartScreen.visible = false

	if has_node("MusicPlayer"):
		$MusicPlayer.play()
