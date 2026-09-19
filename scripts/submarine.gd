class_name Submarine
extends Node2D

## The player: a little submarine parked on the seabed. The muzzle marker is
## where spears leave from.

const TARGET_HEIGHT := 150.0
const SPARK_TEXTURE := preload("res://assets/generated/spark.png")

@export var body_texture: Texture2D:
	set(value):
		body_texture = value
		if is_node_ready() and sprite != null:
			sprite.texture = value
			_fit_sprite()

var _t: float = 0.0
var _sprite_base: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite
@onready var muzzle: Marker2D = $Muzzle


func _ready() -> void:
	if body_texture != null:
		sprite.texture = body_texture
	_fit_sprite()
	_sprite_base = sprite.position
	_make_bubbles()


func muzzle_position() -> Vector2:
	return muzzle.global_position


## Scale the art to TARGET_HEIGHT and put the keel on the node origin, so the
## node sits exactly on the seafloor.
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
	var s: float = TARGET_HEIGHT / float(used.size.y)
	sprite.scale = Vector2(s, s)
	var content_center_x: float = float(used.position.x) + float(used.size.x) * 0.5
	var content_bottom_y: float = float(used.position.y + used.size.y)
	sprite.position = Vector2(
		-(content_center_x - tex_size.x * 0.5) * s,
		-(content_bottom_y - tex_size.y * 0.5) * s
	)
	_sprite_base = sprite.position


func _process(delta: float) -> void:
	_t += delta
	sprite.position = _sprite_base + Vector2(0.0, sin(_t * 1.7) * 3.5)
	sprite.rotation = sin(_t * 1.1) * 0.02


func _make_bubbles() -> void:
	var bubbles: CPUParticles2D = CPUParticles2D.new()
	bubbles.texture = SPARK_TEXTURE
	bubbles.position = Vector2(46.0, -136.0)
	bubbles.z_index = 6
	bubbles.amount = 12
	bubbles.lifetime = 2.6
	bubbles.direction = Vector2(0.0, -1.0)
	bubbles.spread = 26.0
	bubbles.gravity = Vector2(0.0, -60.0)
	bubbles.initial_velocity_min = 20.0
	bubbles.initial_velocity_max = 46.0
	bubbles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	bubbles.emission_rect_extents = Vector2(26.0, 5.0)
	var size_curve: Curve = Curve.new()
	size_curve.add_point(Vector2(0.0, 0.018))
	size_curve.add_point(Vector2(1.0, 0.05))
	bubbles.scale_amount_curve = size_curve
	bubbles.color = Color(0.85, 0.96, 1.0, 0.5)
	add_child(bubbles)
	bubbles.emitting = true
