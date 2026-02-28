extends Area3D
class_name Pickup

enum PickupType {
	# Health items
	FOOD,           # +10 health
	HEALTH_KIT,     # +25 health
	
	# Ammo
	CLIP,           # +8 ammo
	AMMO_BOX,       # +25 ammo (Spear of Destiny)
	
	# Weapons
	MACHINEGUN,
	CHAINGUN,
	
	# Keys
	GOLD_KEY,
	SILVER_KEY,
	
	# Treasures
	CROSS,          # 100 points
	CHALICE,        # 500 points
	BIBLE,          # 1000 points
	CROWN,          # 5000 points
	
	# Special
	EXTRA_LIFE,     # +1 life, +25 ammo, full heal
}

@export var pickup_type: PickupType = PickupType.CLIP
@export var sprite: Sprite3D

var collected: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if collected:
		return
	
	if body is Player:
		if try_pickup(body):
			collected = true
			_play_sound()
			queue_free()

func try_pickup(player: Player) -> bool:
	match pickup_type:
		# ===== HEALTH =====
		PickupType.FOOD:
			return GameState.pickup_food()
		
		PickupType.HEALTH_KIT:
			return GameState.pickup_health_potion()
		
		# ===== AMMO =====
		PickupType.CLIP:
			return GameState.pickup_clip()
		
		PickupType.AMMO_BOX:
			if GameState.ammo >= 99:
				return false
			GameState.give_ammo(25)
			return true
		
		# ===== WEAPONS =====
		PickupType.MACHINEGUN:
			GameState.give_weapon(GameState.Weapon.MACHINEGUN)
			return true
		
		PickupType.CHAINGUN:
			GameState.give_weapon(GameState.Weapon.CHAINGUN)
			return true
		
		# ===== KEYS =====
		PickupType.GOLD_KEY:
			GameState.give_key(0)
			return true
		
		PickupType.SILVER_KEY:
			GameState.give_key(1)
			return true
		
		# ===== TREASURES =====
		PickupType.CROSS:
			GameState.pickup_treasure(100)
			return true
		
		PickupType.CHALICE:
			GameState.pickup_treasure(500)
			return true
		
		PickupType.BIBLE:
			GameState.pickup_treasure(1000)
			return true
		
		PickupType.CROWN:
			GameState.pickup_treasure(5000)
			return true
		
		# ===== SPECIAL =====
		PickupType.EXTRA_LIFE:
			GameState.heal(99)
			GameState.give_ammo(25)
			GameState.give_extra_life()
			GameState.pickup_treasure(0) 
			return true
	return false

func _play_sound() -> void:
	match pickup_type:
		PickupType.FOOD, PickupType.HEALTH_KIT:
			SoundManager.play_sfx("HEALTH1SND")
		PickupType.CLIP, PickupType.AMMO_BOX:
			SoundManager.play_sfx("GETAMMOSND")
		PickupType.MACHINEGUN:
			SoundManager.play_sfx("GETMACHINESND")
		PickupType.CHAINGUN:
			SoundManager.play_sfx("GETGATLINGSND")
		PickupType.GOLD_KEY, PickupType.SILVER_KEY:
			SoundManager.play_sfx("GETKEYSND")
		PickupType.CROSS:
			SoundManager.play_sfx("BONUS1SND")
		PickupType.CHALICE:
			SoundManager.play_sfx("BONUS2SND")
		PickupType.BIBLE:
			SoundManager.play_sfx("BONUS3SND")
		PickupType.CROWN:
			SoundManager.play_sfx("BONUS4SND")
		PickupType.EXTRA_LIFE:
			SoundManager.play_sfx("BONUS1UPSND")
		_:
			SoundManager.play_sfx("SLURPIESND")
