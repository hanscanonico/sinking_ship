class_name SettingsMenu
extends CanvasLayer
## The settings screen, from the main menu or the pause menu, in three pages a row of
## tabs over them picks: Sound — master, music and effects volume; Controls — the
## first-person view's mouse sensitivity, invert Y, field of view, and the deck-roll
## and view-kick comfort sliders (D14, Q17, R15); Graphics — fullscreen, the graphics
## preset with a line on what it changes (GraphicsQuality), and the 3D view's render
## scale, both this machine's own until the player picks them. Each change applies as
## it is made; closing saves them under user://.

signal closed
## The first-person view or the graphics changed: whatever is on screen should take
## them up.
signal view_changed(settings: ViewSettings)

## The pages, in the tabs' order.
enum Page { SOUND, CONTROLS, GRAPHICS }

## Where closing saves the choices; a test points them elsewhere.
var audio_path := AudioSettings.PATH
var view_path := ViewSettings.PATH

var _audio: AudioSettings
var _view: ViewSettings
## What had the focus when the screen opened, to hand it back on closing.
var _opener: Control

@onready var _master: HSlider = %Master
@onready var _music: HSlider = %Music
@onready var _effects: HSlider = %Effects
@onready var _fullscreen: CheckButton = %Fullscreen
@onready var _sensitivity: HSlider = %Sensitivity
@onready var _invert_y: CheckButton = %InvertY
@onready var _fov: HSlider = %FieldOfView
@onready var _deck_roll: HSlider = %DeckRoll
@onready var _view_kick: HSlider = %ViewKick
@onready var _quality: OptionButton = %Quality
@onready var _render_scale: HSlider = %RenderScale
@onready var _pages: Array[Control] = [%Sound, %Controls, %Graphics]
@onready var _tabs: Array[Button] = [%SoundTab, %ControlsTab, %GraphicsTab]


func _ready() -> void:
	UiTheme.apply_to(self)
	hide()
	_master.value_changed.connect(_on_volume)
	_music.value_changed.connect(_on_volume)
	_effects.value_changed.connect(_on_volume)
	_fullscreen.toggled.connect(_on_window)
	for slider: HSlider in [_sensitivity, _fov, _deck_roll, _view_kick]:
		slider.value_changed.connect(_on_view)
	_invert_y.toggled.connect(_on_view)
	for preset: int in GraphicsQuality.Preset.values():
		_quality.add_item(GraphicsQuality.title(preset), preset)
	_quality.item_selected.connect(_on_quality)
	_render_scale.min_value = GraphicsQuality.SCALE_MIN * 100.0
	_render_scale.max_value = GraphicsQuality.SCALE_MAX * 100.0
	_render_scale.value_changed.connect(_on_render_scale)
	var tabs := ButtonGroup.new()
	for page in _tabs.size():
		_tabs[page].button_group = tabs
		_tabs[page].pressed.connect(show_page.bind(page))
	%Back.pressed.connect(close)


## Opens on [param page], the focus on its first choice.
func open(page := Page.SOUND) -> void:
	_audio = AudioSettings.local()
	_view = ViewSettings.local()
	_opener = get_viewport().gui_get_focus_owner()
	_master.set_value_no_signal(_audio.master * 100.0)
	_music.set_value_no_signal(_audio.music * 100.0)
	_effects.set_value_no_signal(_audio.effects * 100.0)
	_fullscreen.set_pressed_no_signal(_view.fullscreen)
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
	var first: Array[Control] = [_master, _sensitivity, _fullscreen]
	first[page].grab_focus()


## Shows [param page] under its tab, the other pages hidden.
func show_page(page: Page) -> void:
	for index in _pages.size():
		_pages[index].visible = index == page
		_tabs[index].set_pressed_no_signal(index == page)


func close() -> void:
	for saved: Error in [_audio.save(audio_path), _view.save(view_path)]:
		if saved != OK:
			push_warning("settings: not saved: %s" % error_string(saved))
	hide()
	if is_instance_valid(_opener) and _opener.is_visible_in_tree():
		_opener.grab_focus()
	closed.emit()


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


func _on_window(fullscreen: bool) -> void:
	_view.fullscreen = fullscreen
	_view.apply_window()


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
	_show_values()
	view_changed.emit(_view)


func _on_render_scale(value: float) -> void:
	_view.render_scale = value / 100.0
	_show_values()
	view_changed.emit(_view)


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
