class_name HUD
extends CanvasLayer

## Run UI: score, countdown, catch counter, announcements and the results panel.

const GOLD := Color(1.0, 0.85, 0.32, 1.0)
const DANGER := Color(1.0, 0.42, 0.3, 1.0)

@onready var score_value: Label = $Root/ScoreValue
@onready var best_value: Label = $Root/BestValue
@onready var time_value: Label = $Root/TimeValue
@onready var time_bar: ColorRect = $Root/TimeBar
@onready var caught_value: Label = $Root/CaughtValue
@onready var message: Label = $Root/Message
@onready var hint: Label = $Root/Hint
@onready var results: Control = $Root/Results
@onready var result_title: Label = $Root/Results/Title
@onready var result_score: Label = $Root/Results/ScoreLine
@onready var result_best: Label = $Root/Results/BestLine
@onready var result_note: Label = $Root/Results/Note
@onready var result_retry: Label = $Root/Results/Retry

var _bar_full_width: float = 0.0
var _message_tween: Tween


func _ready() -> void:
	_ignore_mouse($Root)
	_bar_full_width = time_bar.size.x
	results.visible = false


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


func set_score(value: int) -> void:
	score_value.text = "$%d" % value


func set_best(value: int) -> void:
	best_value.text = "BEST  $%d" % value


func set_caught(count: int) -> void:
	caught_value.text = str(count)


func set_time(seconds_left: float, total: float) -> void:
	var left: float = maxf(seconds_left, 0.0)
	time_value.text = str(int(ceil(left)))
	time_bar.size.x = _bar_full_width * clampf(left / maxf(total, 0.001), 0.0, 1.0)
	var low: bool = left <= 10.0
	time_bar.color = DANGER if low else Color(0.45, 0.9, 1.0, 1.0)
	time_value.add_theme_color_override("font_color",
		DANGER if low else Color(0.95, 0.99, 1.0, 1.0))


func show_message(p_text: String, p_color: Color = Color.WHITE, p_duration: float = 1.2) -> void:
	if _message_tween != null and _message_tween.is_valid():
		_message_tween.kill()
	message.text = p_text
	message.add_theme_color_override("font_color", p_color)
	message.modulate.a = 1.0
	message.pivot_offset = message.size * 0.5
	message.scale = Vector2(0.55, 0.55)
	_message_tween = create_tween()
	_message_tween.tween_property(message, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if p_duration > 0.0:
		_message_tween.tween_interval(p_duration)
		_message_tween.tween_property(message, "modulate:a", 0.0, 0.35)


func clear_message() -> void:
	if _message_tween != null and _message_tween.is_valid():
		_message_tween.kill()
	message.text = ""
	message.modulate.a = 1.0
	message.scale = Vector2.ONE


func set_hint(p_text: String) -> void:
	hint.text = p_text


func show_results(score: int, best: int, is_new_best: bool, title: String,
		title_color: Color, note: String) -> void:
	result_title.text = title
	result_title.add_theme_color_override("font_color", title_color)
	result_score.text = "SCORE    $%d" % score
	result_best.text = "BEST     $%d" % best
	if is_new_best:
		result_note.text = "NEW HIGH SCORE!"
		result_note.add_theme_color_override("font_color", GOLD)
	else:
		result_note.text = note
		result_note.add_theme_color_override("font_color", Color(0.8, 0.88, 0.98, 0.9))
	result_retry.text = "Press R to dive again"
	results.visible = true
	results.modulate.a = 0.0
	var t: Tween = create_tween()
	t.tween_property(results, "modulate:a", 1.0, 0.25)


func hide_results() -> void:
	results.visible = false
	results.modulate.a = 1.0








