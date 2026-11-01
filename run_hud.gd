extends PanelContainer

## Hearts, burgers and the Full state, over the sky at the top of the run.
##
## Distance and score live in the shell's own HUD cards. Nothing here relies
## on colour: an empty heart is an outline, Full adds a word to its icon, and
## every counter also has a sentence for assistive technology.
## Reads the model it is handed; touches no autoload.

const Art = preload("res://games/dolces_adventure/dolce_art.gd")
const State = preload("res://games/dolces_adventure/run_state.gd")
const HEART = preload("res://games/dolces_adventure/assets/icons/heart.svg")
const HEART_EMPTY = preload("res://games/dolces_adventure/assets/icons/heart_empty.svg")
const BURGER = preload("res://games/dolces_adventure/assets/icons/burger.svg")
const FULL = preload("res://games/dolces_adventure/assets/icons/full.svg")

const ICON_SIZE := 30.0

var hearts: Array[TextureRect] = []
var burger_label: Label
var full_badge: HBoxContainer
var _row: HBoxContainer
var _burger_icon: TextureRect
var _full_icon: TextureRect
var _full_label: Label
var _readability := 1.0
var _shown := {}


func _ready() -> void:
	name = "RunHud"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Art.INK, 0.72)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)
	_row = HBoxContainer.new()
	_row.name = "Counters"
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	for index in State.MAX_HEARTS:
		var heart := _icon(HEART, Art.KETCHUP)
		heart.name = "Heart%d" % (index + 1)
		_row.add_child(heart)
		hearts.append(heart)
	_row.add_child(_spacer())
	_burger_icon = _icon(BURGER, Art.MUSTARD)
	_row.add_child(_burger_icon)
	burger_label = _label("0")
	burger_label.name = "Burgers"
	_row.add_child(burger_label)
	full_badge = HBoxContainer.new()
	full_badge.name = "Full"
	full_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(full_badge)
	full_badge.add_child(_spacer())
	_full_icon = _icon(FULL, Art.MUSTARD)
	full_badge.add_child(_full_icon)
	_full_label = _label("FULL")
	full_badge.add_child(_full_label)
	full_badge.hide()
	fit(_readability)


## Copies the model's counters, touching nodes only when a value changed.
func present(state: State) -> void:
	var shown := {"hearts": state.hearts, "burgers": state.burgers, "full": state.full}
	if shown == _shown:
		return
	_shown = shown
	for index in hearts.size():
		hearts[index].texture = HEART if index < state.hearts else HEART_EMPTY
	burger_label.text = str(state.burgers)
	full_badge.visible = state.full
	accessibility_description = "%d of %d hearts. %d burgers.%s" % [
		state.hearts, State.MAX_HEARTS, state.burgers,
		" Full: the next hit costs Full, not a heart." if state.full else "",
	]
	tooltip_text = accessibility_description


func fit(readability: float) -> void:
	_readability = readability
	if _row == null:
		return
	_row.add_theme_constant_override("separation", roundi(6 * readability))
	for icon: TextureRect in hearts + [_burger_icon, _full_icon]:
		icon.custom_minimum_size = Vector2.ONE * ICON_SIZE * readability
	for label: Label in [burger_label, _full_label]:
		label.add_theme_font_size_override("font_size", roundi(24 * readability))
	reset_size()


func _icon(texture: Texture2D, tint: Color) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.modulate = tint
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Art.CREAM)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _spacer() -> Control:
	var gap := Control.new()
	gap.custom_minimum_size.x = 10
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap
