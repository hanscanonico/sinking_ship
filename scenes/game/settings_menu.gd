class_name SettingsMenu
extends CanvasLayer
## The settings screen, from the main menu or the pause menu, in four pages a row of
## tabs over them picks: Sound — master, music and effects volume; Controls — the
## first-person view's mouse sensitivity, invert Y, field of view, and the deck-roll
## and view-kick comfort sliders (D14, Q17, R15); Keys — the key or mouse button of
## each action of play and of spectating (KeyBindings), picked by pressing it;
## Graphics — the window mode, VSync, a frame-rate cap, the graphics preset with a
## line on what it changes (GraphicsQuality), and the 3D view's render scale, both
## this machine's own until the player picks them. Each change applies as it is
## made; closing saves them under user://.

signal closed
## The first-person view or the graphics changed: whatever is on screen should take
## them up.
signal view_changed(settings: ViewSettings)

## The pages, in the tabs' order.
enum Page { SOUND, CONTROLS, KEYS, GRAPHICS }

## Where closing saves the choices; a test points them elsewhere.
var audio_path := AudioSettings.PATH
var view_path := ViewSettings.PATH
var keys_path := KeyBindings.PATH

var _audio: AudioSettings
var _view: ViewSettings
var _keys: KeyBindings
## The action whose row waits for the next key or mouse button, or none.
var _rebinding: StringName = &""
## Each action's row button, by action.
var _key_buttons := {}
## What had the focus when the screen opened, to hand it back on closing.
var _opener: Control
## In a browser, which draws at its own pace and fills the screen one way: VSync and
## the exclusive mode, which would do nothing there, are not offered.
var on_web := OS.has_feature("web")

@onready var _master: HSlider = %Master
@onready var _music: HSlider = %Music
@onready var _effects: HSlider = %Effects
@onready var _window_mode: OptionButton = %WindowMode
@onready var _vsync: CheckButton = %VSync
@onready var _max_fps: OptionButton = %MaxFps
@onready var _sensitivity: HSlider = %Sensitivity
@onready var _invert_y: CheckButton = %InvertY
@onready var _fov: HSlider = %FieldOfView
@onready var _deck_roll: HSlider = %DeckRoll
@onready var _view_kick: HSlider = %ViewKick
@onready var _quality: OptionButton = %Quality
@onready var _render_scale: HSlider = %RenderScale
@onready var _pages: Array[Control] = [%Sound, %Controls, %Keys, %Graphics]
@onready var _tabs: Array[Button] = [%SoundTab, %ControlsTab, %KeysTab, %GraphicsTab]


func _ready() -> void:
	UiTheme.apply_to(self)
	hide()
	_master.value_changed.connect(_on_volume)
	_music.value_changed.connect(_on_volume)
	_effects.value_changed.connect(_on_volume)
	_window_mode.add_item("Windowed", ViewSettings.WindowMode.WINDOWED)
	_window_mode.add_item("Borderless fullscreen", ViewSettings.WindowMode.BORDERLESS)
	if not on_web:
		_window_mode.add_item("Exclusive fullscreen", ViewSettings.WindowMode.EXCLUSIVE)
	for vsync_row: Control in [%VSyncLabel, _vsync, %VSyncSpacer]:
		vsync_row.visible = not on_web
	_window_mode.item_selected.connect(_on_window)
	_vsync.toggled.connect(_on_window)
	for fps: int in ViewSettings.MAX_FPS_CHOICES:
		_max_fps.add_item("Unlimited" if fps == 0 else "%d" % fps, fps)
	_max_fps.item_selected.connect(_on_window)
	for slider: HSlider in [_sensitivity, _fov, _deck_roll, _view_kick]:
		slider.value_changed.connect(_on_view)
	_invert_y.toggled.connect(_on_view)
	for preset: int in GraphicsQuality.Preset.values():
		_quality.add_item(GraphicsQuality.title(preset), preset)
	_quality.item_selected.connect(_on_quality)
	_render_scale.min_value = GraphicsQuality.SCALE_MIN * 100.0
	_render_scale.max_value = GraphicsQuality.SCALE_MAX * 100.0
	_render_scale.value_changed.connect(_on_render_scale)
	for action: StringName in KeyBindings.ACTIONS:
		var title := Label.new()
		title.text = KeyBindings.TITLES[action]
		%KeyRows.add_child(title)
		var key := Button.new()
		key.name = "Key_%s" % action
		key.custom_minimum_size = Vector2(120, 0)
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key.pressed.connect(_listen.bind(action))
		%KeyRows.add_child(key)
		_key_buttons[action] = key
	%ResetKeys.pressed.connect(_on_reset_keys)
	var tabs := ButtonGroup.new()
	for page in _tabs.size():
		_tabs[page].button_group = tabs
		_tabs[page].pressed.connect(show_page.bind(page))
	%Back.pressed.connect(close)


## Opens on [param page], the focus on its first choice.
func open(page := Page.SOUND) -> void:
	_audio = AudioSettings.local()
	_view = ViewSettings.local()
	_keys = KeyBindings.local()
	_rebinding = &""
	_opener = get_viewport().gui_get_focus_owner()
	_master.set_value_no_signal(_audio.master * 100.0)
	_music.set_value_no_signal(_audio.music * 100.0)
	_effects.set_value_no_signal(_audio.effects * 100.0)
	# Exclusive, where it is not offered, fills the screen as borderless does.
	var mode := _window_mode.get_item_index(_view.window_mode)
	if mode < 0:
		mode = _window_mode.get_item_index(ViewSettings.WindowMode.BORDERLESS)
	_window_mode.select(mode)
	_vsync.set_pressed_no_signal(_view.vsync)
	# A cap saved off the list shows as none until the player picks one.
	_max_fps.select(maxi(_max_fps.get_item_index(_view.max_fps), 0))
	_sensitivity.set_value_no_signal(_view.mouse_deg_per_pixel)
	_invert_y.set_pressed_no_signal(_view.invert_y)
	_fov.set_value_no_signal(_view.fov_deg)
	_deck_roll.set_value_no_signal(_view.deck_roll * 100.0)
	_view_kick.set_value_no_signal(_view.view_kick * 100.0)
	_quality.select(_quality.get_item_index(_view.graphics().preset))
	_render_scale.set_value_no_signal(_view.render_scale_3d() * 100.0)
	_show_values()
	show_page(page)
	show()
	var first: Array[Control] = [
		_master, _sensitivity, _key_buttons[KeyBindings.ACTIONS[0]], _window_mode
	]
	first[page].grab_focus()


## Shows [param page] under its tab, the other pages hidden.
func show_page(page: Page) -> void:
	_rebinding = &""
	_show_keys()
	for index in _pages.size():
		_pages[index].visible = index == page
		_tabs[index].set_pressed_no_signal(index == page)


func close() -> void:
	_rebinding = &""
	for saved: Error in [_audio.save(audio_path), _view.save(view_path), _keys.save(keys_path)]:
		if saved != OK:
			push_warning("settings: not saved: %s" % error_string(saved))
	hide()
	if is_instance_valid(_opener) and _opener.is_visible_in_tree():
		_opener.grab_focus()
	closed.emit()


## While a row waits, the next key or mouse button binds its action — Esc, or the
## pad's back, leaving it as it was — and nothing else hears it.
func _input(event: InputEvent) -> void:
	if not visible or _rebinding.is_empty() or not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	if key != null and (key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE):
		_stop_listening()
	elif event is InputEventKey or event is InputEventMouseButton:
		if _keys.bind(_rebinding, event):
			_keys.apply()
			_stop_listening()
	elif event.is_action_pressed("ui_cancel"):
		_stop_listening()
	else:
		return
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		close()
		get_viewport().set_input_as_handled()


func _on_volume(_value: float) -> void:
	_audio.master = _master.value / 100.0
	_audio.music = _music.value / 100.0
	_audio.effects = _effects.value / 100.0
	_audio.apply()
	_show_values()


func _on_window(_value: Variant) -> void:
	_view.window_mode = _window_mode.get_selected_id() as ViewSettings.WindowMode
	_view.vsync = _vsync.button_pressed
	_view.max_fps = _max_fps.get_selected_id()
	_view.apply_window(true)


func _on_view(_value: Variant) -> void:
	_view.mouse_deg_per_pixel = _sensitivity.value
	_view.invert_y = _invert_y.button_pressed
	_view.fov_deg = _fov.value
	_view.deck_roll = _deck_roll.value / 100.0
	_view.view_kick = _view_kick.value / 100.0
	_show_values()
	view_changed.emit(_view)


## The player's choice of preset, and of render scale: each theirs from then on,
## over this machine's own.
func _on_quality(index: int) -> void:
	_view.quality = _quality.get_item_id(index)
	_view.run_quality = ViewSettings.AUTOMATIC
	# A scale left to the preset follows it.
	_render_scale.set_value_no_signal(_view.render_scale_3d() * 100.0)
	_show_values()
	view_changed.emit(_view)


func _on_render_scale(value: float) -> void:
	_view.render_scale = value / 100.0
	_view.run_render_scale = ViewSettings.AUTOMATIC
	_show_values()
	view_changed.emit(_view)


## [param action]'s row waits for the key or mouse button to bind to it.
func _listen(action: StringName) -> void:
	_rebinding = action
	_show_keys()


func _stop_listening() -> void:
	var action := _rebinding
	_rebinding = &""
	_show_keys()
	if _key_buttons.has(action):
		(_key_buttons[action] as Control).grab_focus()


func _on_reset_keys() -> void:
	_rebinding = &""
	_keys.reset()
	_keys.apply()
	_show_keys()


## Each row's key, named as the hints name it, or the call to press one.
func _show_keys() -> void:
	if _keys == null:
		return
	for action: StringName in _key_buttons:
		var shown := _keys.shown(action)
		var events: Array[InputEvent] = []
		if shown != null:
			events.append(shown)
		var word := InputPrompts.word_for(events, false)
		(_key_buttons[action] as Button).text = (
			"Press a key…" if action == _rebinding else (word if not word.is_empty() else "—")
		)


func _show_values() -> void:
	%MasterValue.text = "%d %%" % roundi(_master.value)
	%MusicValue.text = "%d %%" % roundi(_music.value)
	%EffectsValue.text = "%d %%" % roundi(_effects.value)
	%SensitivityValue.text = "%.2f" % _sensitivity.value
	%FieldOfViewValue.text = "%d°" % roundi(_fov.value)
	%DeckRollValue.text = "level" if _deck_roll.value <= 0.0 else "%d %%" % roundi(_deck_roll.value)
	%ViewKickValue.text = "off" if _view_kick.value <= 0.0 else "%d %%" % roundi(_view_kick.value)
	%RenderScaleValue.text = "%d %%" % roundi(_render_scale.value)
	%QualityHint.text = GraphicsQuality.summary(_quality.get_selected_id())
