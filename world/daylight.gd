extends RefCounted

## A sun and sky rig the run advances on model time, never wall-clock time.
##
## Copied from Cube Trials' `world/daylight.gd` and adapted: a biome palette
## dictionary replaces that game's course scenery enum, and a new biome's
## palette blends in over `BLEND_SECONDS` (instantly under reduced motion).
## A palette may scale the sun and ambient light, which is how the Night
## Market is night whatever the clock says.

const CYCLE_SECONDS := 240.0
const START_PHASE := 0.34
const BLEND_SECONDS := 1.5
const COLOR_KEYS: Array[String] = ["top", "horizon", "ground", "ambient", "sun", "fill"]
## Sunny back garden: the palette before any biome sets one. The sky's lower
## half shows between backdrop props, so "ground" is a hazy distant lawn.
const BACKYARD := {
	"top": Color("6fa6c9"), "horizon": Color("f3e2bf"), "ground": Color("a9c38f"),
	"ambient": Color("c4d2c4"), "sun": Color("ffe9c4"), "fill": Color("bcd9e6"),
}

var environment: Environment
var sky_material: ProceduralSkyMaterial
var sun: DirectionalLight3D
var fill: DirectionalLight3D
var night_amount := 0.0
var phase := START_PHASE
var _last_seconds := -1.0
var _palette: Dictionary = BACKYARD
var _from: Dictionary = BACKYARD
var _to: Dictionary = BACKYARD
var _blend := 1.0


func _init(parent: Node3D, palette: Dictionary = BACKYARD) -> void:
	_palette = palette
	_from = palette
	_to = palette
	var world_environment := WorldEnvironment.new()
	world_environment.name = "Daylight"
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var sky := Sky.new()
	sky_material = ProceduralSkyMaterial.new()
	sky_material.sun_angle_max = 7.0
	sky.sky_material = sky_material
	environment.sky = sky
	world_environment.environment = environment
	parent.add_child(world_environment)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-42, -38, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 70.0
	sun.shadow_bias = 0.25
	sun.shadow_normal_bias = 1.2
	parent.add_child(sun)
	fill = DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.rotation_degrees = Vector3(-25, 145, 0)
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	parent.add_child(fill)
	set_elapsed(0.0)


## Moves toward `palette`, over `BLEND_SECONDS` unless `instant`.
func set_palette(palette: Dictionary, instant := false) -> void:
	if palette == _to:
		return
	_from = _palette
	_to = palette
	_blend = 1.0 if instant else 0.0
	_refresh()


## Advances a palette blend; a no-op once it has finished.
func advance(delta: float) -> void:
	if _blend >= 1.0:
		return
	_blend = minf(1.0, _blend + delta / BLEND_SECONDS)
	_refresh()


func _refresh() -> void:
	var mixed := {}
	for key in COLOR_KEYS:
		mixed[key] = (_from[key] as Color).lerp(_to[key], _blend)
	for key: String in ["sun_energy", "ambient_energy"]:
		mixed[key] = lerpf(float(_from.get(key, 1.0)), float(_to.get(key, 1.0)), _blend)
	_palette = mixed
	var seconds := _last_seconds
	_last_seconds = -1.0
	set_elapsed(maxf(seconds, 0.0))


## Zero is the biome's afternoon; the day/night toggle and reduced motion hold it.
func set_elapsed(seconds: float) -> void:
	if not is_finite(seconds) or seconds < 0.0:
		push_error("Daylight requires a finite, nonnegative time.")
		return
	if seconds == _last_seconds:
		return
	_last_seconds = seconds
	phase = fposmod(START_PHASE + seconds / CYCLE_SECONDS, 1.0)
	var height := sin(phase * TAU)
	var daylight := smoothstep(-0.22, 0.26, height)
	var warmth := 1.0 - smoothstep(0.10, 0.72, height)
	var darkness := 1.0 - daylight
	night_amount = 1.0 - smoothstep(-0.10, 0.32, height)
	sun.rotation_degrees.x = -42.0 * height / sin(START_PHASE * TAU)
	sun.light_color = (_palette["sun"] as Color).lerp(Color("ffac70"), warmth)
	sun.light_energy = 0.9 * smoothstep(-0.08, 0.50, height) * float(_palette.get("sun_energy", 1.0))
	sun.visible = sun.light_energy > 0.001
	fill.light_color = (_palette["fill"] as Color).lerp(Color("96b5e1"), darkness)
	fill.light_energy = lerpf(0.16, 0.34, darkness)
	environment.ambient_light_color = (_palette["ambient"] as Color).lerp(
		Color("a3b9d8"), darkness)
	environment.ambient_light_energy = lerpf(0.5, 0.36, darkness) \
		* float(_palette.get("ambient_energy", 1.0))
	sky_material.sky_top_color = (_palette["top"] as Color) \
		.lerp(Color("a4829b"), warmth * 0.7).lerp(Color("172b48"), darkness)
	var horizon := (_palette["horizon"] as Color).lerp(Color("efa575"), warmth) \
		.lerp(Color("526b87"), darkness)
	sky_material.sky_horizon_color = horizon
	sky_material.ground_horizon_color = horizon
	sky_material.ground_bottom_color = (_palette["ground"] as Color).lerp(
		Color("293448"), darkness)
