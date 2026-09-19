class_name Fish
extends Node2D

## A single swimming fish. Game.gd decides what it is worth; the fish only
## swims, wiggles, and knows how big it is for spear hits.

const BOMB := "bomb"
const GOLDEN := "golden"

var kind: String = "small"
var value: int = 10
var swim_speed: float = 80.0
var direction: float = -1.0
var hit_radius: float = 28.0
var base_y: float = 200.0
var captured: bool = false

var _t: float = 0.0
var _phase: float = 0.0
var _wiggle_amp: float = 7.0
var _sprite_height: float = 52.0

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	add_to_group("fish")
	_phase = randf() * TAU


func configure(p_kind: String, p_texture: Texture2D, p_size: float, p_value: int,
		p_speed: float, p_dir: float) -> void:
	kind = p_kind
	value = p_value
	swim_speed = p_speed
	direction = p_dir
	_sprite_height = p_size
	if sprite != null:
		sprite.texture = p_texture
		sprite.flip_h = p_dir < 0.0
		_fit_sprite()


## Scale the artwork to the requested height and centre it on the node origin.
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
	var s: float = _sprite_height / float(used.size.y)
	sprite.scale = Vector2(s, s)
	var cx: float = float(used.position.x) + float(used.size.x) * 0.5
	var cy: float = float(used.position.y) + float(used.size.y) * 0.5
	sprite.position = -Vector2(cx - tex_size.x * 0.5, cy - tex_size.y * 0.5) * s
	# generous round hitbox derived from the actually drawn size, so both long
	# slim fish (barracuda) and round ones (puffer) feel fair to spear
	var drawn: Vector2 = Vector2(used.size) * s
	hit_radius = maxf(drawn.y * 0.45, drawn.x * 0.28)


func _process(delta: float) -> void:
	_t += delta
	if captured:
		# thrashing on the end of the spear
		sprite.rotation = sin(_t * 22.0) * 0.3
		return
	position.x += direction * swim_speed * delta
	position.y = base_y + sin(_t * 3.1 + _phase) * _wiggle_amp
	sprite.rotation = sin(_t * 3.1 + _phase) * 0.09
	if kind == BOMB:
		# warning pulse so the player knows to leave it alone
		var pulse: float = 0.5 + 0.5 * sin(_t * 7.0)
		sprite.modulate = Color(1.0, 1.0 - pulse * 0.5, 1.0 - pulse * 0.5)
	elif kind == GOLDEN:
		var glow: float = 0.5 + 0.5 * sin(_t * 4.0)
		sprite.modulate = Color(1.0, 1.0, 0.85 + glow * 0.15)
