class_name Game
extends Node2D

## Minute to Fish It: drag to aim the speargun, spear fish, reel them in for
## money. A run lasts one minute. The score is how many fish you land in a run;
## the money you earn is banked into SaveData so it piles up and can be spent
## on submarine skins in the shop.

const RUN_SECONDS := 60.0
const COUNTDOWN_SECONDS := 3.0
const BOOM_SEQUENCE := 1.6
const RESTART_CONFIRM_WINDOW := 3.0

const GRAVITY := 460.0
const WATER_DRAG := 0.85
const MIN_SPEED := 340.0
const MAX_SPEED := 1250.0
const MAX_DRAG := 320.0
const MIN_DRAG_TO_FIRE := 26.0
const AIM_MIN := -172.0
const AIM_MAX := -8.0

const SEABED_Y := 596.0
const CEILING_Y := 8.0
const WALL_LEFT := 8.0
const WALL_RIGHT := 1144.0
const FISH_MIN_Y := 104.0
const FISH_MAX_Y := 430.0
const MAX_FISH := 9
const SPAWN_MIN := 0.35
const SPAWN_MAX := 0.8
const START_FISH := 5
const REEL_BASE_SPEED := 1500.0
const RAPID_FIRE_REEL_SPEED := 3200.0
const FROZEN_TIME_DURATION := 7.0
const GOLD_RUSH_DURATION := 7.0

## The wallet, best score and skins live in SaveData's own file; this is just
## the local UI preference for the instructions popup.
const PREFS_PATH := "user://minute_to_fish_prefs.cfg"
const SHOP_SCENE := "res://scenes/Shop.tscn"

enum State { HOME, READY, FISHING, BOOM, OVER }

const FISH_TYPES := {
	"small": {
		"path": "res://assets/generated/fish_small.png",
		"size": 52.0, "value": 10, "speed_min": 66.0, "speed_max": 104.0, "weight": 30.0,
	},
	"medium": {
		"path": "res://assets/generated/fish_medium.png",
		"size": 74.0, "value": 25, "speed_min": 50.0, "speed_max": 78.0, "weight": 26.0,
	},
	"large": {
		"path": "res://assets/generated/fish_large.png",
		"size": 112.0, "value": 55, "speed_min": 30.0, "speed_max": 48.0, "weight": 16.0,
	},
	"fast": {
		"path": "res://assets/generated/fish_dart.png",
		"size": 70.0, "value": 90, "speed_min": 185.0, "speed_max": 245.0, "weight": 12.0,
	},
	"golden": {
		"path": "res://assets/generated/fish_golden.png",
		"size": 78.0, "value": 160, "speed_min": 78.0, "speed_max": 118.0, "weight": 6.0,
	},
	"bomb": {
		"path": "res://assets/generated/fish_bomb.png",
		"size": 76.0, "value": 0, "speed_min": 34.0, "speed_max": 52.0, "weight": 8.0,
	},
}

const FISH_SCENE := preload("res://scenes/Fish.tscn")
const SPEAR_SCENE := preload("res://scenes/Spear.tscn")
const FLOAT_SCENE := preload("res://scenes/FloatingText.tscn")
const SPARK_TEXTURE := preload("res://assets/generated/spark.png")

@onready var world: Node2D = $World
@onready var sub: Submarine = $World/Sub
@onready var fish_root: Node2D = $World/Fish
@onready var spear_root: Node2D = $World/Spear
@onready var rope: Line2D = $World/Rope
@onready var preview: AimPreview = $World/AimPreview
@onready var camera: Camera2D = $Camera2D
@onready var hud: HUD = $HUD

var state: State = State.HOME
## `caught` is the run's score (fish landed); `earned` is the money it made.
var caught: int = 0
var earned: int = 0
var time_left: float = RUN_SECONDS
var aim_angle: float = -72.0
var aim_power: float = 0.62
var hide_instructions_pref: bool = false

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _dragging: bool = false
var _drag_origin: Vector2 = Vector2.ZERO
var _intro_timer: float = COUNTDOWN_SECONDS
var _countdown_step: int = -1
var _boom_timer: float = BOOM_SEQUENCE
var _spawn_timer: float = 0.4
var _shake: float = 0.0
var _spear: Spear = null
var _awaiting_first_play: bool = false
var _restart_armed: bool = false
var _restart_arm_timer: float = 0.0
## Power-ups paid for and active on the current run - re-charged from
## whatever's toggled on in the HUD every time a run actually begins, so
## a restart re-buys the same loadout rather than reusing it for free.
var _equipped_powerups: Array[String] = []
var _frozen_time_left: float = 0.0
var _gold_rush_left: float = 0.0
## Fish art lives here, loaded through Assets so a freshly generated png still
## works even before the editor has imported it.
var _fish_textures: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	for key in FISH_TYPES:
		_fish_textures[key] = Assets.load_texture(str(FISH_TYPES[key]["path"]))
	hide_instructions_pref = _load_hide_instructions_pref()
	sub.set_skin(SaveData.equipped_texture(), SaveData.muzzle_for(SaveData.equipped_skin))
	hud.set_score(0)
	hud.set_best(SaveData.best_score)
	hud.set_earned(0)
	hud.set_wallet(SaveData.money)
	hud.set_time(RUN_SECONDS, RUN_SECONDS)
	hud.hide_results()
	hud.set_hint("")
	rope.visible = false

	hud.play_pressed.connect(_on_play_pressed)
	hud.how_to_play_pressed.connect(_on_how_to_play_pressed)
	hud.instructions_dismissed.connect(_on_instructions_dismissed)
	hud.shop_pressed.connect(_on_shop_pressed)

	state = State.HOME
	hud.show_home(SaveData.best_score, SaveData.money)


func _on_play_pressed() -> void:
	hud.hide_home()
	if hide_instructions_pref:
		hud.play_transition(_begin_run)
	else:
		_awaiting_first_play = true
		hud.open_instructions(hide_instructions_pref)


func _on_how_to_play_pressed() -> void:
	_awaiting_first_play = false
	hud.open_instructions(hide_instructions_pref)


func _on_shop_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(SHOP_SCENE)


func _on_instructions_dismissed(dont_show_again: bool) -> void:
	if dont_show_again != hide_instructions_pref:
		hide_instructions_pref = dont_show_again
		_save_hide_instructions_pref()
	if _awaiting_first_play:
		_awaiting_first_play = false
		hud.play_transition(_begin_run)


## Starts an actual 60s run: spawns the opening fish, kicks off the 3-2-1-GO
## countdown (aiming/firing early skips straight to FISHING, same as before).
func _begin_run() -> void:
	state = State.READY
	_intro_timer = COUNTDOWN_SECONDS
	_countdown_step = -1
	caught = 0
	earned = 0
	time_left = RUN_SECONDS
	_apply_powerups()
	hud.set_score(0)
	hud.set_earned(0)
	for i in START_FISH:
		_spawn_fish(_rng.randf_range(90.0, 1060.0))
	hud.animate_run_start()


## Charges the wallet for whatever's equipped in the HUD's power-up picker
## and turns their effects on for this run. Anything that can't be
## afforded (e.g. the wallet dropped between selecting it and pressing
## Play) is silently dropped rather than blocking the run. The hint bar
## (not the countdown's Message label, which the 3-2-1-GO sequence needs
## for itself) shows what's active for the whole run.
func _apply_powerups() -> void:
	_equipped_powerups.clear()
	for id in hud.get_selected_powerups():
		if SaveData.spend(SaveData.powerup_price(id)):
			_equipped_powerups.append(id)
	_frozen_time_left = FROZEN_TIME_DURATION if _equipped_powerups.has("frozen_time") else 0.0
	_gold_rush_left = GOLD_RUSH_DURATION if _equipped_powerups.has("gold_rush") else 0.0
	hud.set_wallet(SaveData.money)
	if _equipped_powerups.is_empty():
		hud.set_hint("Drag anywhere to aim, release to fire   •   arrows to aim, Up/Down for power, Space to fire")
		return
	var names: PackedStringArray = []
	for id in _equipped_powerups:
		names.append(SaveData.powerup_name(id))
	hud.set_hint("EQUIPPED: " + ", ".join(names))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_handle_restart_key()
			return
		if event.keycode == KEY_F1:
			_awaiting_first_play = false
			hud.open_instructions(hide_instructions_pref)
			return
		if event.keycode == KEY_ESCAPE:
			_return_to_home()
			return
	if not can_aim():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var press_world: Vector2 = _screen_to_world(event.position)
		if event.pressed:
			_dragging = true
			_drag_origin = press_world
		elif _dragging:
			_dragging = false
			if press_world.distance_to(_drag_origin) >= MIN_DRAG_TO_FIRE:
				fire()
	elif event is InputEventMouseMotion and _dragging:
		_aim_from_drag(_screen_to_world(event.position))


## First R press arms a confirmation (and shows a prompt); a second press
## within the window actually restarts - straight back into a fresh run,
## without dropping to the home screen. Does nothing on the home screen
## itself (there's no run yet to restart there).
func _handle_restart_key() -> void:
	if state == State.HOME:
		return
	if _restart_armed:
		_restart_armed = false
		_restart_run()
		return
	_restart_armed = true
	_restart_arm_timer = RESTART_CONFIRM_WINDOW
	hud.show_message("Press R again to restart", Color(1.0, 0.65, 0.3), RESTART_CONFIRM_WINDOW)


## Clears the current run's fish/spear/score/timer, without touching the
## home screen or instructions - used by both restart (R) and going back
## to the menu (Esc), which then decide what to show next.
func _reset_run_state() -> void:
	for child in fish_root.get_children():
		child.queue_free()
	if _spear != null and is_instance_valid(_spear):
		_spear.queue_free()
	_spear = null
	rope.visible = false
	_dragging = false
	preview.enabled = false
	_restart_armed = false
	_equipped_powerups.clear()
	_frozen_time_left = 0.0
	_gold_rush_left = 0.0
	caught = 0
	earned = 0
	time_left = RUN_SECONDS
	hud.set_score(0)
	hud.set_earned(0)
	hud.set_wallet(SaveData.money)
	hud.set_time(RUN_SECONDS, RUN_SECONDS)
	hud.hide_results()
	hud.clear_message()


func _restart_run() -> void:
	hud.play_transition(func():
		_reset_run_state()
		_begin_run()
	)


## Esc: back to the title screen from anywhere in a run. Anything already
## caught is banked first, so leaving to visit the shop never costs you money.
func _return_to_home() -> void:
	if state != State.HOME and (caught > 0 or earned > 0):
		SaveData.record_run(earned, caught)
	_reset_run_state()
	state = State.HOME
	hud.set_hint("")
	hud.show_home(SaveData.best_score, SaveData.money)


## Screen (viewport) point to world point, following the camera.
func _screen_to_world(screen_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_position


func _process(delta: float) -> void:
	_update_shake(delta)
	_update_restart_arm(delta)

	match state:
		State.READY:
			_intro_timer -= delta
			var step: int = int(ceil(_intro_timer))
			if step != _countdown_step and step >= 1:
				_countdown_step = step
				hud.show_message(str(step), Color(0.66, 0.94, 1.0), 0.75)
			if _intro_timer <= 0.0:
				state = State.FISHING
				hud.show_message("GO!", Color(0.7, 0.98, 0.8), 0.6)
		State.FISHING:
			if _frozen_time_left > 0.0:
				_frozen_time_left -= delta
			else:
				time_left -= delta
			if _gold_rush_left > 0.0:
				_gold_rush_left -= delta
			hud.set_time(time_left, RUN_SECONDS)
			if time_left <= 0.0:
				time_left = 0.0
				hud.set_time(0.0, RUN_SECONDS)
				_end_run("TIME UP", Color(0.72, 0.9, 1.0), "Out of air!")
		State.BOOM:
			_boom_timer -= delta
			if _boom_timer <= 0.0:
				_end_run("BOOM!", Color(1.0, 0.45, 0.28), "A bomb fish blew up your sub")

	if can_aim():
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = _rng.randf_range(SPAWN_MIN, SPAWN_MAX)
			if fish_root.get_child_count() < MAX_FISH:
				_spawn_fish(-1.0)
		_keyboard_aim(delta)
	_cull_fish()
	_refresh_preview()
	_update_rope()


func _update_restart_arm(delta: float) -> void:
	if not _restart_armed:
		return
	_restart_arm_timer -= delta
	if _restart_arm_timer <= 0.0:
		_restart_armed = false


func can_aim() -> bool:
	return state == State.READY or state == State.FISHING


func can_fire() -> bool:
	if not can_aim():
		return false
	return _spear == null or not is_instance_valid(_spear)


func _keyboard_aim(delta: float) -> void:
	var turn: float = Input.get_axis("ui_left", "ui_right")
	var lift: float = Input.get_axis("ui_down", "ui_up")
	if not is_zero_approx(turn):
		aim_angle = clampf(aim_angle + turn * 52.0 * delta, AIM_MIN, AIM_MAX)
	if not is_zero_approx(lift):
		aim_power = clampf(aim_power + lift * 0.55 * delta, 0.12, 1.0)
	if Input.is_action_just_pressed("ui_accept"):
		fire()


func _aim_from_drag(mouse: Vector2) -> void:
	var drag: Vector2 = mouse - _drag_origin
	if drag.length() < 10.0:
		return
	var angle: float = rad_to_deg(drag.angle())
	if angle > 0.0:
		# dragging downwards: mirror it upwards, keeping the same side
		angle = -179.0 if drag.x < 0.0 else -1.0
	aim_angle = clampf(angle, AIM_MIN, AIM_MAX)
	aim_power = clampf(drag.length() / MAX_DRAG, 0.12, 1.0)


func aim_velocity() -> Vector2:
	return Vector2.RIGHT.rotated(deg_to_rad(aim_angle)) * lerpf(MIN_SPEED, MAX_SPEED, aim_power)


func fire() -> void:
	if not can_fire():
		return
	if state == State.READY:
		state = State.FISHING
		hud.clear_message()
	_dragging = false
	preview.enabled = false
	var muzzle: Vector2 = sub.muzzle_position()
	_spear = SPEAR_SCENE.instantiate()
	spear_root.add_child(_spear)
	_spear.global_position = muzzle
	_spear.home = muzzle
	_spear.seabed_y = SEABED_Y
	_spear.bounds = Rect2(WALL_LEFT, CEILING_Y, WALL_RIGHT - WALL_LEFT, SEABED_Y - CEILING_Y)
	var reel_speed: float = RAPID_FIRE_REEL_SPEED if _equipped_powerups.has("rapid_fire") else REEL_BASE_SPEED
	_spear.launch(aim_velocity(), GRAVITY, WATER_DRAG, reel_speed)
	_spear.impact.connect(_on_spear_impact)
	_spear.collected.connect(_on_spear_collected)
	add_shake(4.0)
	_burst(muzzle, Color(0.75, 0.95, 1.0, 0.5), 8, 150.0, 0.03, 0.1)


func _on_spear_impact(fish: Fish) -> void:
	if fish == null:
		add_shake(2.0)
		return
	if fish.kind == Fish.BOMB:
		_explode(fish)
		return
	add_shake(6.0)
	_burst(_spear.global_position, Color(0.85, 0.98, 1.0, 0.7), 10, 180.0, 0.04, 0.12)


func _explode(fish: Fish) -> void:
	state = State.BOOM
	_boom_timer = BOOM_SEQUENCE
	fish.captured = true
	if _spear != null and is_instance_valid(_spear):
		_spear.freeze()
	var blast: Vector2 = _spear.global_position
	add_shake(34.0)
	_burst(blast, Color(1.0, 0.6, 0.2, 0.95), 70, 620.0, 0.1, 0.34)
	_burst(blast, Color(1.0, 0.95, 0.65, 0.9), 40, 320.0, 0.12, 0.5)
	_burst(blast, Color(0.4, 0.42, 0.45, 0.8), 30, 220.0, 0.25, 0.7)
	hud.show_message("BOOM!", Color(1.0, 0.45, 0.25), 1.4)
	hud.set_hint("Your sub went up in bubbles...")


func _on_spear_collected(fish: Fish) -> void:
	_spear = null
	if fish == null or not is_instance_valid(fish):
		return
	var gained: int = fish.value
	if _equipped_powerups.has("multiplier"):
		gained *= 2
	var kind: String = fish.kind
	earned += gained
	caught += 1
	hud.set_score(caught)
	hud.set_earned(earned)
	hud.set_wallet(SaveData.money + earned)
	_popup(fish.global_position + Vector2(0.0, -40.0), "+$%d" % gained, Color(1.0, 0.88, 0.4), 42)
	_burst(fish.global_position, Color(1.0, 0.88, 0.4, 0.9), 16, 240.0, 0.05, 0.14)
	if kind == "golden":
		hud.show_message("GOLDEN FISH!  +$%d" % gained, Color(1.0, 0.86, 0.3), 1.0)
	elif kind == "fast":
		hud.show_message("SPEEDY CATCH!  +$%d" % gained, Color(0.75, 0.92, 1.0), 0.8)
	elif gained >= 55:
		hud.show_message("BIG CATCH!  +$%d" % gained, Color(0.8, 1.0, 0.86), 0.8)
	fish.queue_free()
	add_shake(5.0)


func _spawn_fish(at_x: float = -1.0) -> void:
	var kind: String = _pick_kind()
	var data: Dictionary = FISH_TYPES[kind]
	var from_left: bool = _rng.randf() < 0.5
	var direction: float = 1.0 if from_left else -1.0
	var x: float = at_x
	if x < 0.0:
		x = -80.0 if from_left else 1232.0
	var y: float = _pick_y()
	var fish: Fish = FISH_SCENE.instantiate()
	fish_root.add_child(fish)
	fish.global_position = Vector2(x, y)
	fish.base_y = y
	fish.configure(kind, _fish_textures[kind], float(data["size"]), int(data["value"]),
		_rng.randf_range(float(data["speed_min"]), float(data["speed_max"])),
		direction)


func _pick_kind() -> String:
	if _gold_rush_left > 0.0:
		return "golden"
	var total: float = 0.0
	for key in FISH_TYPES:
		total += float(FISH_TYPES[key]["weight"])
	var roll: float = _rng.randf() * total
	for key in FISH_TYPES:
		roll -= float(FISH_TYPES[key]["weight"])
		if roll <= 0.0:
			return key
	return "small"


func _pick_y() -> float:
	var chosen: float = _rng.randf_range(FISH_MIN_Y, FISH_MAX_Y)
	var best_gap: float = -1.0
	for attempt in 6:
		var candidate: float = _rng.randf_range(FISH_MIN_Y, FISH_MAX_Y)
		var closest: float = INF
		for child in fish_root.get_children():
			closest = minf(closest, absf(child.position.y - candidate))
		if closest > best_gap:
			best_gap = closest
			chosen = candidate
	return chosen


func _cull_fish() -> void:
	for child in fish_root.get_children():
		var fish: Fish = child
		if fish.captured:
			continue
		if fish.position.x < -180.0 or fish.position.x > 1332.0:
			fish.queue_free()


func _refresh_preview() -> void:
	if not can_aim():
		preview.enabled = false
		return
	preview.enabled = true
	preview.origin = sub.muzzle_position()
	preview.velocity = aim_velocity()
	preview.gravity = GRAVITY
	preview.drag = WATER_DRAG
	preview.power = aim_power
	preview.seabed_y = SEABED_Y
	preview.ceiling_y = CEILING_Y
	preview.wall_left = WALL_LEFT
	preview.wall_right = WALL_RIGHT
	var list: Array = []
	for child in fish_root.get_children():
		var fish: Fish = child
		if fish.captured or fish.is_queued_for_deletion():
			continue
		list.append({
			"position": fish.global_position,
			"radius": fish.hit_radius,
			"danger": fish.kind == Fish.BOMB,
			"gold": fish.kind == Fish.GOLDEN,
		})
	preview.targets = list


func _update_rope() -> void:
	if _spear == null or not is_instance_valid(_spear):
		rope.visible = false
		return
	var from: Vector2 = sub.muzzle_position()
	var to: Vector2 = _spear.tail_position()
	rope.visible = true
	var segments: int = 10
	var points: PackedVector2Array = PackedVector2Array()
	var distance: float = from.distance_to(to)
	var sag: float = clampf(distance * 0.05, 1.0, 22.0)
	for i in segments + 1:
		var t: float = float(i) / float(segments)
		var point: Vector2 = from.lerp(to, t)
		point.y += sin(t * PI) * sag
		points.append(point)
	rope.points = points


func _end_run(title: String, title_color: Color, note: String) -> void:
	if state == State.OVER:
		return
	state = State.OVER
	_dragging = false
	preview.enabled = false
	rope.visible = false
	if _spear != null and is_instance_valid(_spear):
		_spear.freeze()
	# bank the run: money piles up in the wallet, best score is fish caught
	var new_best: bool = SaveData.record_run(earned, caught)
	hud.set_best(SaveData.best_score)
	hud.set_wallet(SaveData.money)
	hud.clear_message()
	hud.set_hint("R to dive again   •   Esc for the menu")
	hud.show_results(caught, SaveData.best_score, earned, SaveData.money, new_best,
		title, title_color, note)
	add_shake(10.0)
	_burst(sub.muzzle_position(), Color(0.7, 0.95, 1.0, 0.8), 14, 220.0, 0.04, 0.12)


func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _update_shake(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 46.0)
		camera.offset = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * _shake
	elif camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO


func _popup(at: Vector2, message: String, color: Color, font_size: int) -> void:
	var node: FloatingText = FLOAT_SCENE.instantiate()
	world.add_child(node)
	node.pop_off(at, message, color, font_size)


func _burst(at: Vector2, color: Color, amount: int, speed: float,
		min_scale: float = 0.03, max_scale: float = 0.12) -> void:
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.texture = SPARK_TEXTURE
	particles.position = at
	particles.z_index = 35
	particles.amount = amount
	particles.lifetime = 0.7
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector2.RIGHT
	particles.spread = 180.0
	particles.gravity = Vector2(0.0, -140.0)
	particles.initial_velocity_min = speed * 0.3
	particles.initial_velocity_max = speed
	# the size curve wins over scale_amount_min/max, so drive sizes here
	var size_curve: Curve = Curve.new()
	size_curve.add_point(Vector2(0.0, max_scale))
	size_curve.add_point(Vector2(0.6, min_scale * 2.0))
	size_curve.add_point(Vector2(1.0, 0.0))
	particles.scale_amount_curve = size_curve
	particles.color = color
	world.add_child(particles)
	particles.emitting = true
	var t: Tween = particles.create_tween()
	t.tween_interval(1.6)
	t.tween_callback(particles.queue_free)


func _load_hide_instructions_pref() -> bool:
	var config: ConfigFile = ConfigFile.new()
	if config.load(PREFS_PATH) == OK:
		return bool(config.get_value("prefs", "hide_instructions", false))
	return false


func _save_hide_instructions_pref() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(PREFS_PATH)
	config.set_value("prefs", "hide_instructions", hide_instructions_pref)
	config.save(PREFS_PATH)
