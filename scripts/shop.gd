class_name Shop
extends Control

## Skin shop. Cards are built in code from SaveData's catalogue so the list can
## grow without touching the scene. Money comes from fishing; buying a skin
## equips it immediately so you see it on your sub on the very next dive.

const FONT_PRESS := preload("res://assets/fonts/PressStart2P.ttf")
const FONT_VT := preload("res://assets/fonts/VT323.ttf")
const PANEL_TEXTURE := "res://assets/generated/ui_panel.png"
const GAME_SCENE := "res://scenes/Main.tscn"

const GOLD := Color(1.0, 0.85, 0.32, 1.0)
const MINT := Color(0.75, 1.0, 0.85, 1.0)
const DIM := Color(0.8, 0.9, 1.0, 0.9)

@onready var grid: GridContainer = $Center/Grid
@onready var wallet_label: Label = $Header/Wallet
@onready var back_button: Button = $Footer/BackButton

var _cards: Dictionary = {}


func _ready() -> void:
	_style_button(back_button)
	back_button.pressed.connect(_go_back)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_go_back()
			get_viewport().set_input_as_handled()


func _go_back() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME_SCENE)


func _refresh() -> void:
	wallet_label.text = "WALLET  $%d" % SaveData.money
	for id in SaveData.SKIN_ORDER:
		if not _cards.has(id):
			var card: Dictionary = _build_card(id)
			_cards[id] = card
			grid.add_child(card["panel"])
		_update_card(id)


func _build_card(id: String) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 200)
	panel.add_theme_stylebox_override("panel", _card_style())

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(256, 68)
	preview.texture = SaveData.texture_for(id)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(preview)

	var name_label := Label.new()
	name_label.text = SaveData.skin_name(id)
	name_label.add_theme_font_override("font", FONT_PRESS)
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)

	var blurb := Label.new()
	blurb.text = str(SaveData.skin(id)["blurb"])
	blurb.add_theme_font_override("font", FONT_VT)
	blurb.add_theme_font_size_override("font_size", 17)
	blurb.add_theme_color_override("font_color", Color(0.85, 0.93, 1.0, 0.85))
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(0, 22)
	box.add_child(blurb)

	var state := Label.new()
	state.add_theme_font_override("font", FONT_VT)
	state.add_theme_font_size_override("font_size", 17)
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(state)

	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 38)
	button.add_theme_font_override("font", FONT_PRESS)
	button.add_theme_font_size_override("font_size", 11)
	button.pressed.connect(_on_card_pressed.bind(id))
	_style_button(button)
	box.add_child(button)

	return {"panel": panel, "button": button, "state": state}


func _update_card(id: String) -> void:
	var card: Dictionary = _cards[id]
	var button: Button = card["button"]
	var state: Label = card["state"]
	button.disabled = false
	if SaveData.is_equipped(id):
		button.text = "EQUIPPED"
		button.disabled = true
		state.text = "In the water"
		state.add_theme_color_override("font_color", MINT)
	elif SaveData.owns(id):
		button.text = "EQUIP"
		state.text = "Owned"
		state.add_theme_color_override("font_color", DIM)
	else:
		var price: int = SaveData.price(id)
		button.text = "BUY  $%d" % price
		button.disabled = not SaveData.can_afford(id)
		if SaveData.can_afford(id):
			state.text = "Ready to buy"
			state.add_theme_color_override("font_color", GOLD)
		else:
			state.text = "Need $%d more" % maxi(price - SaveData.money, 0)
			state.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5, 0.9))


func _on_card_pressed(id: String) -> void:
	if SaveData.owns(id):
		SaveData.equip(id)
	elif SaveData.buy(id):
		SaveData.equip(id)
	_refresh()
	_punch(_cards[id]["panel"])


func _punch(node: Control) -> void:
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(0.9, 0.9)
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _card_style() -> StyleBox:
	var tex: Texture2D = Assets.load_texture(PANEL_TEXTURE)
	if tex == null:
		return _flat_style(Color(0.05, 0.14, 0.22, 0.95), Color(0.4, 0.7, 0.85, 1.0))
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.set_texture_margin_all(16.0)
	sb.set_content_margin_all(12.0)
	return sb


func _flat_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(12)
	return sb


func _style_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal",
		_flat_style(Color(0.32, 0.20, 0.09, 0.95), Color(0.85, 0.7, 0.35, 1.0)))
	btn.add_theme_stylebox_override("hover",
		_flat_style(Color(0.42, 0.27, 0.12, 0.95), Color(1.0, 0.85, 0.4, 1.0)))
	btn.add_theme_stylebox_override("pressed",
		_flat_style(Color(0.22, 0.13, 0.05, 0.95), Color(0.85, 0.7, 0.35, 1.0)))
	btn.add_theme_stylebox_override("disabled",
		_flat_style(Color(0.18, 0.20, 0.24, 0.9), Color(0.45, 0.5, 0.55, 1.0)))
	btn.add_theme_color_override("font_color", Color(1, 0.96, 0.85))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 0.92))
	btn.add_theme_color_override("font_pressed_color", Color(1, 0.9, 0.6))
	btn.add_theme_color_override("font_disabled_color", Color(0.7, 0.75, 0.8, 0.8))
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
