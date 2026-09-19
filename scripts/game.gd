class_name Game
extends Node2D

## Minute to Fish It: drag to aim the speargun, spear fish, reel them in for
## money. A run lasts one minute; the best score is kept between runs.

const RUN_SECONDS := 60.0
const INTRO_SECONDS := 1.8
const BOOM_SEQUENCE := 1.6

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
const SAVE_PATH := "user://minute_to_fish_best.cfg"

enum State { READY, FISHING, BOOM, OVER }

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

var state: State = State.READY
var score: int = 0
var best: int = 0
var caught: int = 0
var time_left: float = RUN_SECONDS
var aim_angle: float = -72.0
var aim_power: float = 0.62

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _dragging: bool = false
var _drag_origin: Vector2 = Vector2.ZERO
var _intro_timer: float = INTRO_SECONDS
var _boom_timer: float = BOOM_SEQUENCE
var _spawn_timer: float = 0.4
var _shake: float = 0.0
var _spear: Spear = null
## Fish art lives here, loaded through _load_texture() so a freshly generated
## png still works before the editor has imported it.
var _fish_textures: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	for key in FISH_TYPES:
		_fish_textures[key] = _load_texture(str(FISH_TYPES[key]["path"]))
	best = _load_best()
	hud.set_best(best)
	hud.set_score(0)
	hud.set_caught(0)
	hud.set_time(RUN_SECONDS, RUN_SECONDS)
	hud.hide_results()
	hud.set_hint("Drag anywhere to aim, release to fire   •   arrows to aim, Up/Down for power, Space to fire")
	hud.show_message("GET READY", Color(0.66, 0.94, 1.0), 1.2)
	rope.visible = false
	for i in START_FISH:
		_spawn_fish(_rng.randf_range(90.0, 1060.0))



func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			get_tree().reload_current_scene()
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


## Screen (viewport) point to world point, following the camera.
func _screen_to_world(screen_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_position


func _process(delta: float) -> void:
	_update_shake(delta)

	match state:
		State.READY:
			_intro_timer -= delta
			if _intro_timer <= 0.0:
				state = State.FISHING
				hud.show_message("GO!", Color(0.7, 0.98, 0.8), 0.6)
		State.FISHING:
			time_left -= delta
			hud.set_time(time_left, RUN_SECONDS)
			if time_left <= 0.0:
				time_left = 0.0
				hud.set_time(0.0, RUN_SECONDS)
				_end_run("TIME UP", Color(0.72, 0.9, 1.0), "Out of air!")
		State.BOOM:
			_boom_timer -= delta
			if _boom_timer <= 0.0:
				_end_run("BOOM!", Color(1.0, 0.45, 0.28), "A bomb fish blew up your sub")

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = _rng.randf_range(SPAWN_MIN, SPAWN_MAX)
		if fish_root.get_child_count() < MAX_FISH:
			_spawn_fish(-1.0)
	_cull_fish()

	if can_aim():
		_keyboard_aim(delta)
	_refresh_preview()
	_update_rope()


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
	_spear.launch(aim_velocity(), GRAVITY, WATER_DRAG, REEL_BASE_SPEED)
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
	var kind: String = fish.kind
	score += gained
	caught += 1
	hud.set_score(score)
	hud.set_caught(caught)
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
	var new_best: bool = score > best
	if new_best:
		best = score
		_save_best()
	hud.set_best(best)
	hud.clear_message()
	hud.set_hint("Press R for another run")
	hud.show_results(score, best, new_best, title, title_color, note)
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


## Importer-independent texture loading: falls back to reading the png straight
## from disk, which is what happens for an asset the editor has not imported yet.
func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			return res
	var image: Image = Image.load_from_file(path)
	if image != null:
		return ImageTexture.create_from_image(image)
	push_warning("Missing texture: %s" % path)
	return null


func _load_best() -> int:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		return int(config.get_value("score", "best", 0))
	return 0


func _save_best() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("score", "best", best)
	config.save(SAVE_PATH)
