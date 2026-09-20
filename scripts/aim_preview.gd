class_name AimPreview
extends Node2D

##KUUUUUUUUURTT
## Dotted prediction of where the spear will go. Integrates with exactly the
## same water physics as the spear, and locks onto the first fish the path
## crosses so you always know what you are about to hit.

const STEPS := 190
const STEP_DT := 1.0 / 60.0
const DRAW_EVERY := 3

var enabled: bool = false
var origin: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var gravity: float = 460.0
var drag: float = 0.85
var power: float = 0.6
var color: Color = Color(0.72, 0.95, 1.0)
var seabed_y: float = 596.0
var ceiling_y: float = 6.0
var wall_left: float = 6.0
var wall_right: float = 1146.0
## [{position: Vector2, radius: float, danger: bool, gold: bool}]
var targets: Array = []


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not enabled or velocity.length_squared() < 1.0:
		return
	var origin_local: Vector2 = origin - global_position
	var dir: Vector2 = velocity.normalized()
	var reach: float = lerpf(52.0, 122.0, clampf(power, 0.0, 1.0))
	var tip: Vector2 = origin_local + dir * reach
	draw_line(origin_local, tip, Color(color.r, color.g, color.b, 0.9), 3.0)
	draw_circle(tip, 5.0, Color(color.r, color.g, color.b, 0.95))

	var pos: Vector2 = origin
	var vel: Vector2 = velocity
	var step: int = 0
	var end_point: Vector2 = Vector2.ZERO
	var has_end: bool = false
	var hit_target: Dictionary = {}
	while step < STEPS:
		var previous: Vector2 = pos
		vel.y += gravity * STEP_DT
		vel *= maxf(1.0 - drag * STEP_DT, 0.0)
		pos += vel * STEP_DT
		if step % DRAW_EVERY == 0:
			var t: float = float(step) / float(STEPS)
			draw_circle(pos - global_position, lerpf(4.6, 1.7, t),
				Color(color.r, color.g, color.b, lerpf(0.95, 0.22, t)))
		hit_target = _first_target(previous, pos)
		if not hit_target.is_empty():
			end_point = hit_target["position"]
			has_end = true
			break
		if pos.y >= seabed_y:
			var span: float = maxf(pos.y - previous.y, 0.0001)
			end_point = previous.lerp(pos, clampf((seabed_y - previous.y) / span, 0.0, 1.0))
			has_end = true
			break
		if pos.x <= wall_left or pos.x >= wall_right or pos.y <= ceiling_y:
			end_point = pos
			has_end = true
			break
		step += 1

	if not has_end:
		return
	var marker: Vector2 = end_point - global_position
	if hit_target.is_empty():
		draw_arc(marker, 13.0, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.7), 3.0)
		draw_circle(marker, 3.5, Color(1.0, 1.0, 1.0, 0.8))
		return
	var ring: Color = Color(0.62, 1.0, 0.72, 0.95)
	if hit_target.get("danger", false):
		ring = Color(1.0, 0.32, 0.26, 0.95)
	elif hit_target.get("gold", false):
		ring = Color(1.0, 0.86, 0.3, 0.95)
	var ring_radius: float = maxf(float(hit_target["radius"]) + 8.0, 16.0)
	draw_arc(marker, ring_radius, 0.0, TAU, 40, ring, 3.0)
	draw_arc(marker, ring_radius * 0.55, 0.0, TAU, 24, Color(ring.r, ring.g, ring.b, 0.45), 1.5)


func _first_target(previous: Vector2, next: Vector2) -> Dictionary:
	if targets.is_empty():
		return {}
	var best: Dictionary = {}
	var best_progress: float = INF
	var segment: Vector2 = next - previous
	var segment_len_sq: float = segment.length_squared()
	for target in targets:
		var center: Vector2 = target["position"]
		var radius: float = float(target["radius"])
		if absf(center.x - previous.x) > radius + 48.0:
			continue
		var t: float = 0.0
		if segment_len_sq > 0.0001:
			t = clampf((center - previous).dot(segment) / segment_len_sq, 0.0, 1.0)
		if previous.lerp(next, t).distance_squared_to(center) <= radius * radius:
			if t < best_progress:
				best_progress = t
				best = target
	return best
