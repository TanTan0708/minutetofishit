extends Node

## Persistent player profile, registered as the `SaveData` autoload.
##
## The wallet and the best catch count survive between runs, and the wallet is
## what pays for submarine skins in the shop.

const SAVE_PATH := "user://minute_to_fish_save.cfg"

const SKIN_ORDER := ["classic", "coral", "toxic", "abyss", "gold"]

const SKINS := {
	"classic": {
		"name": "CLASSIC",
		"path": "res://assets/generated/submarine.png",
		"price": 0,
		"blurb": "The trusty starter sub. Smells faintly of sardines.",
		"muzzle": Vector2(104.0, -118.0),
	},
	"coral": {
		"name": "CORAL CRUISER",
		"path": "res://assets/generated/skin_coral.png",
		"price": 200,
		"blurb": "Reef-pink hull with hand-painted shells.",
	},
	"toxic": {
		"name": "TOXIC TIN",
		"path": "res://assets/generated/skin_toxic.png",
		"price": 500,
		"blurb": "Hazard stripes and a glow nobody approved.",
	},
	"abyss": {
		"name": "ABYSS RUNNER",
		"path": "res://assets/generated/skin_abyss.png",
		"price": 1000,
		"blurb": "Blacked-out hull, bioluminescent seams.",
	},
	"gold": {
		"name": "GOLDEN GILLS",
		"path": "res://assets/generated/skin_gold.png",
		"price": 2000,
		"blurb": "Solid gold. Impractical. Perfect.",
	},
}

## Power-ups: NOT owned like skins - each run you pay again for whatever
## you want equipped, same as a Subway Surfers-style loadout pick. Nothing
## here is persisted; only the wallet that pays for them is.
const POWERUP_ORDER := ["frozen_time", "multiplier", "gold_rush", "rapid_fire"]

const POWERUPS := {
	"frozen_time": {
		"name": "FROZEN TIME", "price": 120,
		"blurb": "Clock stays frozen for the first 10s of the run.",
	},
	"multiplier": {
		"name": "2X MULTIPLIER", "price": 180,
		"blurb": "Every dollar you earn this run is doubled.",
	},
	"gold_rush": {
		"name": "GOLD RUSH", "price": 260,
		"blurb": "Every fish that spawns this run is golden.",
	},
	"rapid_fire": {
		"name": "RAPID FIRE", "price": 140,
		"blurb": "Your spear reels back in a flash - fire much faster.",
	},
}

var money: int = 0
var best_score: int = 0
var runs_played: int = 0
var total_caught: int = 0
var owned_skins: Array[String] = ["classic"]
var equipped_skin: String = "classic"

var _texture_cache: Dictionary = {}


func _ready() -> void:
	load_profile()


func load_profile() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	money = int(config.get_value("wallet", "money", 0))
	best_score = int(config.get_value("wallet", "best", 0))
	runs_played = int(config.get_value("wallet", "runs", 0))
	total_caught = int(config.get_value("wallet", "caught", 0))
	owned_skins.clear()
	for id in config.get_value("skins", "owned", ["classic"]):
		var key: String = str(id)
		if SKINS.has(key) and not owned_skins.has(key):
			owned_skins.append(key)
	if not owned_skins.has("classic"):
		owned_skins.append("classic")
	var equipped: String = str(config.get_value("skins", "equipped", "classic"))
	equipped_skin = equipped if owned_skins.has(equipped) else "classic"


func save_profile() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("wallet", "money", money)
	config.set_value("wallet", "best", best_score)
	config.set_value("wallet", "runs", runs_played)
	config.set_value("wallet", "caught", total_caught)
	config.set_value("skins", "owned", owned_skins)
	config.set_value("skins", "equipped", equipped_skin)
	config.save(SAVE_PATH)


## Bank a finished run. Returns true when it beat the best catch count.
func record_run(money_earned: int, fish_caught: int) -> bool:
	money += maxi(money_earned, 0)
	runs_played += 1
	total_caught += maxi(fish_caught, 0)
	var is_best: bool = fish_caught > best_score
	if is_best:
		best_score = fish_caught
	save_profile()
	return is_best


func skin(id: String) -> Dictionary:
	if SKINS.has(id):
		return SKINS[id]
	return SKINS["classic"]


func skin_name(id: String) -> String:
	return str(skin(id)["name"])


func price(id: String) -> int:
	return int(skin(id)["price"])


## Where that skin's speargun sits, if the art has a visible barrel.
func muzzle_for(id: String) -> Vector2:
	return skin(id).get("muzzle", Vector2.ZERO)


func owns(id: String) -> bool:
	return owned_skins.has(id)


func is_equipped(id: String) -> bool:
	return equipped_skin == id


func can_afford(id: String) -> bool:
	return money >= price(id)


func buy(id: String) -> bool:
	if not SKINS.has(id) or owns(id) or not can_afford(id):
		return false
	money -= price(id)
	owned_skins.append(id)
	save_profile()
	return true


func equip(id: String) -> bool:
	if not owns(id):
		return false
	equipped_skin = id
	save_profile()
	return true


func powerup(id: String) -> Dictionary:
	return POWERUPS.get(id, {})


func powerup_name(id: String) -> String:
	return str(powerup(id).get("name", id))


func powerup_price(id: String) -> int:
	return int(powerup(id).get("price", 0))


## Spends straight from the wallet - used to pay for a run's equipped
## power-ups. Returns false (and spends nothing) if you can't afford it.
func spend(amount: int) -> bool:
	if amount <= 0:
		return true
	if money < amount:
		return false
	money -= amount
	save_profile()
	return true


func texture_for(id: String) -> Texture2D:
	if _texture_cache.has(id):
		return _texture_cache[id]
	var tex: Texture2D = Assets.load_texture(str(skin(id)["path"]))
	_texture_cache[id] = tex
	return tex


func equipped_texture() -> Texture2D:
	return texture_for(equipped_skin)


func reset_profile() -> void:
	money = 0
	best_score = 0
	runs_played = 0
	total_caught = 0
	owned_skins.clear()
	owned_skins.append("classic")
	equipped_skin = "classic"
	save_profile()
