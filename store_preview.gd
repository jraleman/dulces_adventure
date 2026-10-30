extends Control

## The picture on a store card: Dulce herself, wearing the item that card sells.
##
## The store asks for this by path (`GameManifest.store_preview_scene_path`) and
## hands it the item, so the framework never learns what a chihuahua mix looks
## like. She is the same rig the run uses, dressed through the same
## `set_outfit()` call, so the shelf cannot promise a look the run then fails
## to deliver. Still on purpose: a shelf is for comparing at a glance, and a
## card that moved would leave reduced motion something to switch off.

const Studio = preload("res://games/dulces_adventure/world/studio.gd")
const DulceModel = preload("res://games/dulces_adventure/world/dulce_model.gd")
const State = preload("res://games/dulces_adventure/run_state.gd")
const Grid = preload("res://games/dulces_adventure/tile_grid.gd")
const Options = preload("res://games/dulces_adventure/dulces_adventure_options.gd")

## Front three-quarter: she faces +X, so the lens stands off her nose and near
## flank, where a collar, a hat brim and a bandana all read.
const LENS := Vector3(1.0, 0.35, 1.25)
const FIELD_OF_VIEW := 30.0

var _set: Dictionary = {}
var _dulce: DulceModel
var _item: Dictionary = {}
var _inert := false
var _draw_queued := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inert = DisplayServer.get_name() == "headless"
	if _inert:
		return
	_set = Studio.build(self)
	(_set["viewport"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
	_dulce = DulceModel.new()
	(_set["stage"] as Node3D).add_child(_dulce)
	_dulce.present(_standing(), 0.0, true)
	_dulce.position = Vector3.ZERO
	resized.connect(_reframe)
	visibility_changed.connect(_request_draw)
	_show()


## Its kind decides which slot it fills; the rest of her outfit is plain, so
## the card shows only what it sells. Ownership and price never matter here.
func configure(item: Dictionary) -> void:
	_item = item.duplicate(true)
	if not _inert and _dulce != null:
		_show()


## Part of the store card's preview contract. Nothing here moves, so this only
## asks for a redraw when a parked card comes back.
func set_preview_running(_running: bool) -> void:
	_request_draw()


func _show() -> void:
	var id := str(_item.get("id", Options.COLLAR_RED))
	var kind := str(_item.get("kind", Options.COLLAR_KIND))
	_dress(
		id if kind == Options.COLLAR_KIND else Options.COLLAR_RED,
		id if kind == Options.HAT_KIND else "",
		id if kind == Options.BANDANA_KIND else "",
	)


func _dress(collar: String, hat: String, neck: String) -> void:
	_dulce.set_outfit(collar, hat, neck)
	_reframe()


func _reframe() -> void:
	if _dulce == null or size.x < 1.0 or size.y < 1.0:
		return
	var box := Studio.bounds(_set["stage"], _dulce)
	Studio.frame(_set["camera"], box, _lens(), FIELD_OF_VIEW, size.x / size.y, _margin())
	_request_draw()


func _lens() -> Vector3:
	return LENS


func _margin() -> float:
	return 1.08


## Standing still on flat ground: the pose a card shows.
static func _standing() -> State:
	var rows: Array[String] = ["", "", "", "", "#".repeat(8), "#".repeat(8)]
	return State.new(Grid.new(rows), Vector2(4.5 * Grid.TILE, 4.0 * Grid.TILE))


func _request_draw() -> void:
	if _set.is_empty() or _draw_queued or not is_visible_in_tree():
		return
	_draw_queued = true
	# Routed scenes attach and resize their viewports during their first frame.
	RenderingServer.frame_post_draw.connect(_draw_once, CONNECT_ONE_SHOT)


func _draw_once() -> void:
	_draw_queued = false
	if not _set.is_empty() and is_visible_in_tree():
		(_set["viewport"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
