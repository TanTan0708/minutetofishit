class_name Spear
extends Node2D

## The speargun spear. Flies through water (gravity + drag), bites into the
## first fish it touches, then gets reeled back to the sub along its rope.

signal impact(fish: Fish)
signal collected(fish: Fish)

enum Mode { FLYING, STUCK, REELING, DONE }

const TIP_LENGTH := 92.0
const STUCK_TIME := 0.14
const WALL_STUCK_TIME := 0.3
const ARRIVE_DISTANCE := 30.0

var mode: int = Mode.FLYING
var velocity: Vector2 = Vector2.ZERO
var gravity: float = 460.0
var drag: float = 0.85
var reel_speed: float = 1400.0
var home: Vector2 = Vector2.ZERO
var seabed_y: float = 596.0
var bounds: Rect2 = Rect2(6.0, 6.0, 1140.0, 590.0)
var captured: Fish = null
var held: bool = false

var _stuck_time: float = 0.0
var _finished: bool = false

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	_fit_sprite()


func launch(initial_velocity: Vector2, gravity_accel: float, drag_amount: float, reel: float) -> void:
	velocity = initial_velocity
	gravity = gravity_accel
	drag = drag_amount
	reel_speed = reel
	mode = Mode.FLYING
	rotation = velocity.angle()


## Stop permanently (used when a bomb ends the run).
func freeze() -> void:
	held = true
	mode = Mode.STUCK
	_stuck_time = 99999.0


## Where the rope ties on: behind the spear head.
func tail_position() -> Vector2:
	if velocity.length_squared() > 1.0:
		return global_position - velocity.normalized() * TIP_LENGTH
	return global_position - Vector2(TIP_LENGTH, 0.0)


## Put the spear head on the node origin so the node position is the tip.
func _fit_sprite() -> void:
	var tex: Texture2D = sprite.texture
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img == null:
		return
	var used: Rect2i = img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return
	var tex_size: Vector2 = Vector2(tex.get_size())
	var s: float = TIP_LENGTH / float(used.size.x)
	sprite.scale = Vector2(s, s)
	var tip_x: float = float(used.position.x + used.size.x)
	var center_y: float = float(used.position.y) + float(used.size.y) * 0.5
	sprite.position = Vector2(
		-(tip_x - tex_size.x * 0.5) * s,
		-(center_y - tex_size.y * 0.5) * s
	)


func _physics_process(delta: float) -> void:
	match mode:
		Mode.FLYING:
			_fly(delta)
		Mode.STUCK:
			if not held:
				_stuck_time -= delta
				if _stuck_time <= 0.0:
					mode = Mode.REELING
		Mode.REELING:
			_reel(delta)


func _fly(delta: float) -> void:
	velocity.y += gravity * delta
	velocity *= maxf(1.0 - drag * delta, 0.0)
	var previous: Vector2 = global_position
	var next: Vector2 = previous + velocity * delta

	var fish: Fish = _fish_on_segment(previous, next)
	if fish != null:
		captured = fish
		fish.captured = true
		global_position = fish.global_position - velocity.normalized() * (fish.hit_radius * 0.45)
		rotation = velocity.angle()
		_stick(STUCK_TIME)
		impact.emit(fish)
		return

	if next.y >= seabed_y:
		global_position = Vector2(next.x, seabed_y)
		_stick(WALL_STUCK_TIME)
		impact.emit(null)
		return
	if next.x <= bounds.position.x or next.x >= bounds.end.x or next.y <= bounds.position.y:
		global_position = Vector2(
			clampf(next.x, bounds.position.x, bounds.end.x),
			clampf(next.y, bounds.position.y, seabed_y)
		)
		_stick(WALL_STUCK_TIME)
		impact.emit(null)
		return

	global_position = next
	rotation = velocity.angle()


func _stick(stuck_for: float) -> void:
	mode = Mode.STUCK
	_stuck_time = stuck_for


func _reel(delta: float) -> void:
	var to_home: Vector2 = home - global_position
	var distance: float = to_home.length()
	if distance <= ARRIVE_DISTANCE or distance <= reel_speed * delta:
		global_position = home
		_finish()
		return
	velocity = to_home / distance * reel_speed
	global_position += velocity * delta
	rotation = velocity.angle()
	if captured != null and is_instance_valid(captured):
		captured.global_position = global_position
		captured.rotation = lerp_angle(captured.rotation, velocity.angle(), 0.25)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	mode = Mode.DONE
	var fish: Fish = captured if (captured != null and is_instance_valid(captured)) else null
	collected.emit(fish)
	queue_free()


func _fish_on_segment(previous: Vector2, next: Vector2) -> Fish:
	var best: Fish = null
	var best_progress: float = INF
	var segment: Vector2 = next - previous
	var segment_len_sq: float = segment.length_squared()
	for node in get_tree().get_nodes_in_group("fish"):
		var fish: Fish = node
		if fish.captured or fish.is_queued_for_deletion():
			continue
		var center: Vector2 = fish.global_position
		var radius: float = fish.hit_radius
		if absf(center.x - previous.x) > radius + 48.0:
			continue
		var t: float = 0.0
		if segment_len_sq > 0.0001:
			t = clampf((center - previous).dot(segment) / segment_len_sq, 0.0, 1.0)
		if previous.lerp(next, t).distance_squared_to(center) <= radius * radius:
			if t < best_progress:
				best_progress = t
				best = fish
	return best
