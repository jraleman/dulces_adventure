extends Control

## The share card's portrait: Dolce in her victory sit, in the outfit she ran
## in, on a little lawn under the Backyard sky (DESIGN §9.4).
##
## `ShareManager` hands this the round's payload through `configure()`; the
## distance or clear time, burgers and score are already on the card around
## it, so the art only has to be her. Still on purpose, so a capture never
## depends on an animation's phase.

const Studio = preload("res://games/dolces_adventure/world/studio.gd")
const DolceModel = preload("res://games/dolces_adventure/world/dolce_model.gd")
const FoodModels = preload("res://games/dolces_adventure/world/food_models.gd")
const MeshBuilder = preload("res://games/dolces_adventure/world/mesh_builder.gd")
const Art = preload("res://games/dolces_adventure/dolce_art.gd")
const State = preload("res://games/dolces_adventure/run_state.gd")
const Grid = preload("res://games/dolces_adventure/tile_grid.gd")
const Options = preload("res://games/dolces_adventure/dolces_adventure_options.gd")

## A front three-quarter, a little above her, so the plinth's top reads.
const LENS := Vector3(1.0, 0.4, 1.4)
const FIELD_OF_VIEW := 34.0

var model: DolceModel
var _set: Dictionary = {}
var _outfit: Array[String] = [Options.COLLAR_RED, "", ""]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set = Studio.build(self, false, Viewport.MSAA_4X)
	(_set["viewport"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var stage: Node3D = _set["stage"]
	var lawn := MeshBuilder.new()
	lawn.cylinder(Vector3(0, -0.04, 0), 0.4, 0.08, Art.LETTUCE, Vector3.ZERO, 40)
	lawn.torus(Vector3(0, 0.0, 0), 0.38, 0.42, Art.MUSTARD)
	var plinth := MeshInstance3D.new()
	plinth.name = "Lawn"
	plinth.mesh = lawn.finish()
	plinth.material_override = Art.material()
	stage.add_child(plinth)
	var treat := MeshInstance3D.new()
	treat.name = "BigBurger"
	treat.mesh = FoodModels.mesh_for(State.BIG_BURGER)
	treat.material_override = Art.material()
	# Half size and a step behind her nose: a prize beside her, not a wall
	# in front of her.
	treat.scale = Vector3.ONE * 0.5
	treat.position = Vector3(0.24, 0.105, -0.2)
	stage.add_child(treat)
	model = DolceModel.new()
	model.set_victory(true)
	stage.add_child(model)
	_pose()
	resized.connect(_frame)
	_frame()


## Reads `outfit` (`[collar, hat, neck]` item ids) from the payload, so the
## card shows the dog that just ran, dressed as she ran.
func configure(data: Dictionary) -> void:
	var outfit: Array = data.get("outfit", [])
	if outfit.size() == 3:
		_outfit.assign(outfit)
	if is_node_ready():
		_pose()
		_frame()


func _pose() -> void:
	var rows: Array[String] = ["", "", "", "", "#".repeat(8), "#".repeat(8)]
	var state := State.new(Grid.new(rows), Vector2(4.5 * Grid.TILE, 4.0 * Grid.TILE))
	model.set_outfit(_outfit[0], _outfit[1], _outfit[2])
	model.present(state, 0.0, true)
	model.position = Vector3(-0.05, 0.0, 0.0)


func _frame() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var box := Studio.bounds(_set["stage"], _set["stage"])
	# The studio's container stretches its viewport to this card's size.
	Studio.frame(_set["camera"], box, LENS, FIELD_OF_VIEW, size.x / size.y, 1.05)
