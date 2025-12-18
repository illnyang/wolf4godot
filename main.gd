extends Control

func _ready():
	# EXTRACT ASSETS FIRST
	print("Checking assets...")
	if not AssetExtractor.extraction_complete:
		await AssetExtractor.extraction_finished
	print("Assets ready!")
	
	# Hide start screen, the MainMenu Control handles all menus
	if has_node("StartScreen"):
		$StartScreen.visible = false
	
	# Music
	if has_node("MusicPlayer"):
		$MusicPlayer.play()
