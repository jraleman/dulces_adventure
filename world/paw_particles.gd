extends MultiMeshInstance3D

## Footstep dust, landing puffs, burger crumbs and feather poofs (DESIGN §7.1).
##
## One fixed pool of billboarded soft puffs in a single draw call: bursts reuse
## the oldest slots, nothing is allocated per frame, and nothing casts a
## shadow. All of it is decoration, so reduced motion emits none.

const Art = preload("res://games/dulces_adventure/dulce_art.gd")

const POOL := 64
const GRAVITY := 2.2
const DRAG := 2.5

var reduced_motion := false
var _positions := PackedVector3Array()
var _velocities := PackedVector3Array()
var _ages := PackedFloat32Array()
var _lifetimes := PackedFloat32Array()
var _sizes := PackedFloat32Array()
var _colors := PackedColorArray()
var _cursor := 0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	name = "PawParticles"
	_rng.seed = 7
	var puff := QuadMesh.new()
	puff.size = Vector2.ONE
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = puff
	multimesh.instance_count = POOL
	var finish := StandardMaterial3D.new()
	finish.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	finish.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	finish.vertex_color_use_as_albedo = true
	finish.albedo_texture = Art.soft_particle_texture()
	finish.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	finish.billboard_keep_scale = true
	material_override = finish
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_positions.resize(POOL)
	_velocities.resize(POOL)
	_ages.resize(POOL)
	_lifetimes.resize(POOL)
	_sizes.resize(POOL)
	_colors.resize(POOL)
	_lifetimes.fill(1.0)
	_ages.fill(1.0)
	clear()


## `count` puffs at `at`, thrown out up to `speed` metres per second, rising
## by `rise`. Does nothing under reduced motion.
func burst(at: Vector3, count: int, color: Color, size: float, speed: float,
		rise := 0.6, lifetime := 0.5) -> void:
	if reduced_motion:
		return
	for _i in count:
		var slot := _cursor
		_cursor = (_cursor + 1) % POOL
		var angle := _rng.randf_range(0.0, TAU)
		_positions[slot] = at
		_velocities[slot] = Vector3(cos(angle) * speed, rise * _rng.randf_range(0.5, 1.0),
			sin(angle) * speed * 0.5)
		_ages[slot] = 0.0
		_lifetimes[slot] = lifetime * _rng.randf_range(0.7, 1.0)
		_sizes[slot] = size * _rng.randf_range(0.7, 1.15)
		_colors[slot] = color


## Steps every live puff; spent ones shrink to nothing.
func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	for slot in POOL:
		if _ages[slot] >= _lifetimes[slot]:
			continue
		_ages[slot] += delta
		var velocity := _velocities[slot]
		velocity.y -= GRAVITY * delta
		velocity *= maxf(0.0, 1.0 - DRAG * delta)
		_velocities[slot] = velocity
		_positions[slot] += velocity * delta
		_write(slot)


## Hides every puff, as a new run or reduced motion does.
func clear() -> void:
	for slot in POOL:
		_ages[slot] = _lifetimes[slot]
		_write(slot)


func live_count() -> int:
	var live := 0
	for slot in POOL:
		live += int(_ages[slot] < _lifetimes[slot])
	return live


func _write(slot: int) -> void:
	var left := 1.0 - clampf(_ages[slot] / _lifetimes[slot], 0.0, 1.0)
	var size := _sizes[slot] * (0.6 + 0.4 * left) if left > 0.0 else 0.0
	multimesh.set_instance_transform(slot,
		Transform3D(Basis.from_scale(Vector3.ONE * maxf(size, 0.0001)), _positions[slot]))
	var color := _colors[slot]
	color.a *= left
	multimesh.set_instance_color(slot, color)
