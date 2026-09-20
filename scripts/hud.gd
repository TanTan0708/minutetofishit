class_name HUD
extends CanvasLayer

## Run UI: home screen, instructions modal, pause menu, score/countdown/money
## readouts, announcements, the results panel, and the run-start transition.
## Every panel here is a PanelContainer + VBoxContainer, sized from real
## font metrics rather than hand-picked pixel boxes - that's what keeps
## text from ever clipping regardless of font/size tweaks.

signal play_pressed
signal how_to_play_pressed
signal shop_pressed
signal instructions_dismissed(dont_show_again: bool)
signal pause_retry_pressed
signal pause_quit_pressed

const GOLD := Color(1.0, 0.85, 0.32, 1.0)
const DANGER := Color(1.0, 0.42, 0.3, 1.0)

@onready var top_bar: Control = $Root/TopBar
@onready var score_panel: Control = $Root/TopBar/ScorePanel
@onready var time_panel: Control = $Root/TopBar/TimePanel
@onready var money_panel: Control = $Root/TopBar/MoneyPanel
@onready var score_value: Label = $Root/TopBar/ScorePanel/VBox/ScoreValue
@onready var best_value: Label = $Root/TopBar/ScorePanel/VBox/BestValue
@onready var time_value: Label = $Root/TopBar/TimePanel/VBox/TimeValue
@onready var time_bar: ColorRect = $Root/TopBar/TimePanel/VBox/TimeBarWrap/TimeBar
@onready var money_value: Label = $Root/TopBar/MoneyPanel/VBox/MoneyValue
@onready var wallet_value: Label = $Root/TopBar/MoneyPanel/VBox/WalletValue
@onready var message: Label = $Root/Message
@onready var hint: Label = $Root/Hint

@onready var results: Control = $Root/Results
@onready var result_title: Label = $Root/Results/Panel/VBox/Title
@onready var result_score: Label = $Root/Results/Panel/VBox/ScoreLine
@onready var result_best: Label = $Root/Results/Panel/VBox/BestLine
@onready var result_money: Label = $Root/Results/Panel/VBox/MoneyLine
@onready var result_note: Label = $Root/Results/Panel/VBox/Note
@onready var result_retry: Label = $Root/Results/Panel/VBox/Retry

@onready var home: Control = $Root/Home
@onready var home_best_label: Label = $Root/Home/Panel/VBox/StatsRow/BestCard/BestVBox/BestLabel
@onready var home_wallet_label: Label = $Root/Home/Panel/VBox/StatsRow/WalletCard/WalletVBox/WalletLabel
@onready var play_button: Button = $Root/Home/Panel/VBox/PlayButton
@onready var shop_button: Button = $Root/Home/Panel/VBox/ActionsRow/ShopButton
@onready var how_to_button: Button = $Root/Home/Panel/VBox/ActionsRow/HowToButton
@onready var home_mute_button: Button = $Root/Home/MuteButton

## Power-ups aren't owned like skins - you pay for whatever's equipped
## fresh out of the wallet every time you hit Play, same idea as a
## Subway Surfers loadout pick.
var _powerup_buttons: Dictionary = {}
var _selected_powerups: Array[String] = []

@onready var instructions: Control = $Root/Instructions
@onready var dont_show_toggle: Button = $Root/Instructions/Panel/VBox/DontShowToggle
@onready var close_button: Button = $Root/Instructions/Panel/VBox/CloseButton

@onready var pause: Control = $Root/Pause
@onready var pause_sound_toggle: Button = $Root/Pause/Panel/VBox/SoundRow/SoundToggle
@onready var pause_music_toggle: Button = $Root/Pause/Panel/VBox/MusicRow/MusicToggle
@onready var pause_warning: Label = $Root/Pause/Panel/VBox/Warning
@onready var pause_quit_button: Button = $Root/Pause/Panel/VBox/QuitButton
@onready var pause_retry_button: Button = $Root/Pause/Panel/VBox/ActionsRow/RetryButton
@onready var pause_resume_button: Button = $Root/Pause/Panel/VBox/ActionsRow/ResumeButton

@onready var transition: ColorRect = $Root/Transition

var _message_tween: Tween


func _ready() -> void:
	_ignore_mouse($Root)
	for btn in [play_button, shop_button, how_to_button, dont_show_toggle, close_button,
			pause_sound_toggle, pause_music_toggle, pause_quit_button, pause_retry_button, pause_resume_button,
			home_mute_button]:
		_style_button(btn)
	play_button.pressed.connect(func(): play_pressed.emit())
	shop_button.pressed.connect(func(): shop_pressed.emit())
	how_to_button.pressed.connect(func(): how_to_play_pressed.emit())
	dont_show_toggle.toggled.connect(_update_toggle_text)
	close_button.pressed.connect(_close_instructions)
	pause_sound_toggle.toggled.connect(_on_sound_toggled)
	pause_music_toggle.toggled.connect(_on_music_toggled)
	pause_quit_button.pressed.connect(func():
		_close_pause()
		pause_quit_pressed.emit()
	)
	pause_retry_button.pressed.connect(func():
		_close_pause()
		pause_retry_pressed.emit()
	)
	pause_resume_button.pressed.connect(_close_pause)
	home_mute_button.toggled.connect(_on_home_mute_toggled)
	$Root/Home/Panel/VBox/StatsRow/BestCard.add_theme_stylebox_override(
		"panel", _stat_card_style(Color(1.0, 0.85, 0.32, 0.8)))
	$Root/Home/Panel/VBox/StatsRow/WalletCard.add_theme_stylebox_override(
		"panel", _stat_card_style(Color(0.55, 1.0, 0.75, 0.8)))
	_setup_powerups()

	results.visible = false
	home.visible = false
	instructions.visible = false
	pause.visible = false
	_refresh_home_mute_icon()


## Each power-up gets its own icon and accent color (instead of all four
## sharing one flat wood-brown look), so the loadout reads at a glance -
## same idea as color-coded upgrade cards in games like 2Fuse.
const POWERUP_ACCENTS := {
	"frozen_time": Color(0.55, 0.82, 1.0),
	"multiplier": Color(1.0, 0.85, 0.3),
	"gold_rush": Color(1.0, 0.68, 0.15),
	"rapid_fire": Color(1.0, 0.48, 0.32),
}
const POWERUP_ICONS := {
	"frozen_time": "res://assets/generated/icon_frozen.png",
	"multiplier": "res://assets/generated/icon_multiplier.png",
	"gold_rush": "res://assets/generated/icon_gold.png",
	"rapid_fire": "res://assets/generated/icon_bolt.png",
}


func _setup_powerups() -> void:
	var powerups_panel: PanelContainer = $Root/Home/Panel/VBox/PowerupsPanel
	powerups_panel.add_theme_stylebox_override("panel", _inset_panel_style())
	var grid := powerups_panel.get_node("PowerupsBox/PowerupGrid")
	var buttons := {
		"frozen_time": grid.get_node("FrozenTimeButton"),
		"multiplier": grid.get_node("MultiplierButton"),
		"gold_rush": grid.get_node("GoldRushButton"),
		"rapid_fire": grid.get_node("RapidFireButton"),
	}
	for id in buttons:
		var btn: Button = buttons[id]
		_powerup_buttons[id] = btn
		_style_powerup_button(btn, POWERUP_ACCENTS[id])
		btn.icon = Assets.load_texture(POWERUP_ICONS[id])
		btn.text = "%s\n$%d" % [SaveData.powerup_name(id), SaveData.powerup_price(id)]
		btn.toggled.connect(_on_powerup_toggled.bind(id))


func _on_powerup_toggled(pressed: bool, id: String) -> void:
	if pressed:
		if not _selected_powerups.has(id):
			_selected_powerups.append(id)
	else:
		_selected_powerups.erase(id)
	Audio.play("toggle_on" if pressed else "toggle_off")
	_refresh_powerup_cards()


func _powerup_total_cost() -> int:
	var total := 0
	for id in _selected_powerups:
		total += SaveData.powerup_price(id)
	return total


## Re-checks affordability (wallet may have changed since last shown) and
## keeps the Play button labeled with whatever equipping will cost.
func _refresh_powerup_cards() -> void:
	var total := _powerup_total_cost()
	for id in _powerup_buttons.keys():
		var btn: Button = _powerup_buttons[id]
		var selected: bool = _selected_powerups.has(id)
		if btn.button_pressed != selected:
			btn.set_pressed_no_signal(selected)
		if selected:
			btn.disabled = false
		else:
			var would_cost: int = total + SaveData.powerup_price(id)
			btn.disabled = SaveData.money < would_cost
	play_button.text = ("PLAY  -$%d" % total) if total > 0 else "PLAY"


## What the player has equipped for the next run, and what it costs -
## Game charges the wallet and applies the effects when Play fires.
func get_selected_powerups() -> Array[String]:
	return _selected_powerups.duplicate()


func get_powerup_cost() -> int:
	return _powerup_total_cost()


## Restarting forfeits whatever was equipped - the player has to go back
## to the home screen and pay again if they want power-ups on the new
## run, rather than restart just re-applying the same paid loadout.
func clear_selected_powerups() -> void:
	_selected_powerups.clear()
	_refresh_powerup_cards()


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


func _style_button(btn: Button) -> void:
	var normal := _button_style(Color(0.32, 0.20, 0.09, 0.95), Color(0.85, 0.7, 0.35, 1.0))
	var hover := _button_style(Color(0.42, 0.27, 0.12, 0.95), Color(1.0, 0.85, 0.4, 1.0))
	var pressed := _button_style(Color(0.22, 0.13, 0.05, 0.95), Color(0.85, 0.7, 0.35, 1.0))
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", normal)
	btn.add_theme_color_override("font_color", Color(1, 0.96, 0.85))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 0.92))
	btn.add_theme_color_override("font_pressed_color", Color(1, 0.9, 0.6))
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.resized.connect(func(): btn.pivot_offset = btn.size * 0.5)
	btn.mouse_entered.connect(func(): _punch_scale(btn, 1.06))
	btn.mouse_exited.connect(func(): _punch_scale(btn, 1.0))
	btn.button_down.connect(func():
		_punch_scale(btn, 0.94)
		Audio.play("click")
	)
	btn.button_up.connect(func(): _punch_scale(btn, 1.06 if btn.is_hovered() else 1.0))


## Toggle-mode cards for the power-up picker. Godot already swaps to the
## "pressed" stylebox for as long as button_pressed is true, so that state
## doubles as "equipped" for free - no manual style-swapping needed. Each
## card takes its own accent color (matching its icon) for the border, so
## the four read as distinct at a glance instead of one uniform style.
func _style_powerup_button(btn: Button, accent: Color) -> void:
	var dim_accent := Color(accent.r * 0.4, accent.g * 0.4, accent.b * 0.4)
	btn.add_theme_stylebox_override("normal",
		_button_style(Color(0.14, 0.15, 0.19, 0.95), Color(accent.r, accent.g, accent.b, 0.6)))
	btn.add_theme_stylebox_override("hover",
		_button_style(Color(0.19, 0.20, 0.25, 0.95), accent))
	btn.add_theme_stylebox_override("pressed",
		_button_style(Color(dim_accent.r, dim_accent.g, dim_accent.b, 0.95), accent))
	btn.add_theme_stylebox_override("focus",
		_button_style(Color(0.14, 0.15, 0.19, 0.95), Color(accent.r, accent.g, accent.b, 0.6)))
	btn.add_theme_stylebox_override("disabled",
		_button_style(Color(0.15, 0.17, 0.20, 0.85), Color(0.4, 0.45, 0.5, 1.0)))
	btn.add_theme_color_override("font_color", Color(1, 0.96, 0.9))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 0.96))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_disabled_color", Color(0.6, 0.65, 0.7, 0.8))
	btn.add_theme_constant_override("icon_max_width", 26)
	btn.add_theme_constant_override("h_separation", 8)
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.resized.connect(func(): btn.pivot_offset = btn.size * 0.5)
	btn.mouse_entered.connect(func(): _punch_scale(btn, 1.05))
	btn.mouse_exited.connect(func(): _punch_scale(btn, 1.0))


## A recessed sub-panel look for grouping content (the power-ups module)
## inside a bigger PanelContainer, without competing with the bold gold
## outer border.
func _inset_panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.28)
	sb.border_color = Color(0.55, 0.7, 0.85, 0.35)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	return sb


## Small badge-style card for the home screen's Best/Wallet stats - a
## colored border keyed to each stat (gold for best score, green for
## wallet) makes them read as highlighted callouts instead of plain text.
func _stat_card_style(accent: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.3)
	sb.border_color = accent
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	return sb


func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	return sb


func _punch_scale(node: Control, s: float) -> void:
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2(s, s), 0.08).set_trans(Tween.TRANS_SINE)


func _update_toggle_text(pressed: bool) -> void:
	dont_show_toggle.text = ("[x]" if pressed else "[ ]") + "  Don't show this automatically again"


func _on_sound_toggled(pressed: bool) -> void:
	if pressed:
		Audio.set_sound_enabled(true)
		Audio.play("toggle_on")
	else:
		Audio.play("toggle_off")
		Audio.set_sound_enabled(false)
	pause_sound_toggle.text = "ON" if pressed else "OFF"


func _on_music_toggled(pressed: bool) -> void:
	Audio.set_music_enabled(pressed)
	Audio.play("toggle_on" if pressed else "toggle_off")
	pause_music_toggle.text = "ON" if pressed else "OFF"


## One-tap mute for both sound and music from the home screen, separate from
## the pause menu's finer-grained per-channel toggles. `pressed` means the
## button is showing "muted".
func _on_home_mute_toggled(pressed: bool) -> void:
	if pressed:
		Audio.play("toggle_off")
		Audio.set_sound_enabled(false)
		Audio.set_music_enabled(false)
	else:
		Audio.set_sound_enabled(true)
		Audio.set_music_enabled(true)
		Audio.play("toggle_on")
	_refresh_home_mute_icon()


## Shows "muted" only once both channels are actually off, so the icon stays
## truthful even if the pause menu was used to mute just one of them.
func _refresh_home_mute_icon() -> void:
	var muted: bool = not (Audio.is_sound_enabled() or Audio.is_music_enabled())
	home_mute_button.set_pressed_no_signal(muted)
	home_mute_button.icon = Assets.load_texture(
		"res://assets/generated/icon_sound_off.png" if muted else "res://assets/generated/icon_sound_on.png")


# --------------------------------------------------------------- run HUD ---

## The score is how many fish you landed this run.
func set_score(value: int) -> void:
	score_value.text = str(value)


func set_best(value: int) -> void:
	best_value.text = "BEST  %d FISH" % value


## Money earned so far in this run.
func set_earned(value: int) -> void:
	money_value.text = "$%d" % value


## Banked money plus whatever the current run has earned.
func set_wallet(value: int) -> void:
	wallet_value.text = "WALLET  $%d" % value


## time_bar fills by anchor fraction (not pixel width), so it's correct
## no matter what width the panel actually resolves to.
func set_time(seconds_left: float, total: float) -> void:
	var left: float = maxf(seconds_left, 0.0)
	time_value.text = str(int(ceil(left)))
	time_bar.anchor_right = clampf(left / maxf(total, 0.001), 0.0, 1.0)
	var low: bool = left <= 10.0
	time_bar.color = DANGER if low else Color(0.45, 0.9, 1.0, 1.0)
	time_value.add_theme_color_override("font_color",
		DANGER if low else Color(0.95, 0.99, 1.0, 1.0))


## `p_font_size` defaults to 0, which keeps whatever size the Message label
## is set to in the scene (40, sized for short announcements like "GO!" or
## "BOOM!") - callers with longer sentences (the restart confirm prompt)
## pass a smaller size so the text wraps to a couple of readable lines
## instead of running off both edges of the screen.
func show_message(p_text: String, p_color: Color = Color.WHITE, p_duration: float = 1.2,
		p_font_size: int = 0) -> void:
	if _message_tween != null and _message_tween.is_valid():
		_message_tween.kill()
	message.text = p_text
	message.add_theme_color_override("font_color", p_color)
	if p_font_size > 0:
		message.add_theme_font_size_override("font_size", p_font_size)
	else:
		message.remove_theme_font_size_override("font_size")
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


## A little staggered pop for the score/time/money panels when a run
## actually starts, so the HUD feels like it "arrives" rather than just
## being static the whole time.
func animate_run_start() -> void:
	var panels: Array[Control] = [score_panel, time_panel, money_panel]
	for i in panels.size():
		var p: Control = panels[i]
		p.pivot_offset = p.size * 0.5
		p.scale = Vector2(0.3, 0.3)
		var tw := create_tween()
		tw.tween_interval(i * 0.08)
		tw.tween_property(p, "scale", Vector2(1.1, 1.1), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "scale", Vector2.ONE, 0.1)


## A short black flash - hides whatever visual "pop" would otherwise
## happen at the exact moment fish spawn in / the HUD resets, and gives
## starting (or restarting) a run a small, deliberate beat instead of an
## instant cut. `on_mid_flash` runs at the darkest point, so callers can
## swap what's on screen while it's hidden.
func play_transition(on_mid_flash: Callable) -> void:
	transition.color = Color(0, 0, 0, 0)
	transition.visible = true
	var tw := create_tween()
	tw.tween_property(transition, "color:a", 1.0, 0.14).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(on_mid_flash)
	tw.tween_property(transition, "color:a", 0.0, 0.26).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): transition.visible = false)


## `score` is the fish caught this run, `earned` the money it made and
## `wallet` the new banked total.
func show_results(score: int, best: int, earned: int, wallet: int, is_new_best: bool,
		title: String, title_color: Color, note: String) -> void:
	result_title.text = title
	result_title.add_theme_color_override("font_color", title_color)
	result_score.text = "CAUGHT   %d FISH" % score
	result_best.text = "BEST     %d FISH" % best
	result_money.text = "EARNED  $%d      WALLET  $%d" % [earned, wallet]
	if is_new_best:
		result_note.text = "NEW HIGH SCORE!"
		result_note.add_theme_color_override("font_color", GOLD)
	else:
		result_note.text = note
		result_note.add_theme_color_override("font_color", Color(0.8, 0.88, 0.98, 0.9))
	result_retry.text = "Press R to dive again   •   Esc for the menu"
	results.visible = true
	results.modulate.a = 0.0
	var panel: Control = $Root/Results/Panel
	panel.scale = Vector2(0.85, 0.85)
	panel.pivot_offset = panel.size * 0.5
	var t: Tween = create_tween()
	t.tween_property(results, "modulate:a", 1.0, 0.25)
	t.parallel().tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_results() -> void:
	results.visible = false
	results.modulate.a = 1.0


# ---------------------------------------------------------------- home ----

func show_home(best: int, wallet: int) -> void:
	home_best_label.text = "%d FISH" % best
	home_wallet_label.text = "$%d" % wallet
	_refresh_powerup_cards()
	_refresh_home_mute_icon()
	top_bar.visible = false
	home.visible = true
	home.modulate.a = 0.0
	var panel: Control = $Root/Home/Panel
	panel.scale = Vector2(0.92, 0.92)
	panel.pivot_offset = panel.size * 0.5
	var tw := create_tween()
	tw.tween_property(home, "modulate:a", 1.0, 0.3)
	tw.parallel().tween_property(panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_home() -> void:
	home.visible = false
	top_bar.visible = true


# ----------------------------------------------------------- instructions --

## Always pauses the tree while open - this node runs with
## process_mode = ALWAYS, so its own buttons/input keep working, while the
## paused world (fish, spear, timers) correctly freezes underneath.
func open_instructions(dont_show_pref: bool) -> void:
	dont_show_toggle.button_pressed = dont_show_pref
	_update_toggle_text(dont_show_pref)
	instructions.visible = true
	instructions.modulate.a = 0.0
	var panel: Control = $Root/Instructions/Panel
	panel.scale = Vector2(0.92, 0.92)
	panel.pivot_offset = panel.size * 0.5
	var tw := create_tween()
	tw.tween_property(instructions, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	get_tree().paused = true


func _close_instructions() -> void:
	instructions.visible = false
	get_tree().paused = false
	instructions_dismissed.emit(dont_show_toggle.button_pressed)


## Lets Game close the panel itself (e.g. the F1 hotkey) without
## re-emitting the dismissed signal a second time.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if instructions.visible:
		if event.keycode == KEY_F1 or event.keycode == KEY_ESCAPE:
			_close_instructions()
			get_viewport().set_input_as_handled()
		return
	if pause.visible:
		if event.keycode == KEY_ESCAPE:
			_close_pause()
			get_viewport().set_input_as_handled()
		return


# --------------------------------------------------------------- pause ----

## Esc mid-run opens this instead of the old quit confirmation - pauses the
## tree (same ALWAYS process_mode trick as Instructions) and shows whatever
## the current sound/music state actually is, since it may have been
## toggled on a previous pause. `warning_text` is Game's reminder that
## Quit/Retry forfeit this run's progress - shown right above those buttons.
func open_pause(warning_text: String = "") -> void:
	pause_sound_toggle.button_pressed = Audio.is_sound_enabled()
	pause_sound_toggle.text = "ON" if Audio.is_sound_enabled() else "OFF"
	pause_music_toggle.button_pressed = Audio.is_music_enabled()
	pause_music_toggle.text = "ON" if Audio.is_music_enabled() else "OFF"
	pause_warning.text = warning_text
	pause.visible = true
	pause.modulate.a = 0.0
	var panel: Control = $Root/Pause/Panel
	panel.scale = Vector2(0.92, 0.92)
	panel.pivot_offset = panel.size * 0.5
	var tw := create_tween()
	tw.tween_property(pause, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	get_tree().paused = true


func _close_pause() -> void:
	pause.visible = false
	get_tree().paused = false
