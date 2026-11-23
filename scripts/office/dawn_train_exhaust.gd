extends Node3D
## A small world-space plume: each cloud keeps its birth position as No. 17 rolls away.
## The train owns the clock, so a paused shift and a stepped capture agree.

const POOL_LIMIT := 80
const JET_DURATION := 2.35
const JET_STEP := 0.085
const SOOT := Color(0.23, 0.24, 0.255)
const VAPOR := Color(0.73, 0.75, 0.77)

class Puff:
	var sprite: Sprite3D
	var start: Vector3
	var drift: Vector3
	var born: float
	var life: float
	var size: float
	var strength: float
	var roll: float
	var jet: bool

static var _textures: Array[Texture2D] = []
var _active: Array[Puff] = []
var _spare: Array[Puff] = []
var _rng := RandomNumberGenerator.new()
var _smoke_at: float
var _jet_at := INF
var _jet_end := -INF

func reset(first_smoke_at: float) -> void:
	for puff in _active:
		puff.sprite.hide()
		_spare.append(puff)
	_active.clear()
	_rng.seed = 171890
	_smoke_at = first_smoke_at
	_jet_at = INF
	_jet_end = -INF

func release_steam(at: float) -> void:
	_jet_at = at
	_jet_end = at + JET_DURATION

func advance(now: float, stack: Vector3, cylinder: Vector3, speed: float, emitting: bool) -> void:
	if emitting and now >= _smoke_at:
		var load_factor := clampf(speed / 9.0, 0.0, 1.0)
		_spawn_smoke(now, stack, load_factor)
		_smoke_at = now + lerpf(0.90, 0.15, load_factor) * _rng.randf_range(0.89, 1.11)
	# Alternate outlets on each side, with a brief swell and a dwindling release.
	while _jet_at < _jet_end and _jet_at <= now:
		var remaining := _jet_end - _jet_at
		if emitting and now - _jet_at < 2.6:
			var side := 1.0 if roundi(remaining / JET_STEP) % 2 == 0 else -1.0
			_spawn_steam(_jet_at, cylinder, side, remaining)
		_jet_at += JET_STEP
	for i in range(_active.size() - 1, -1, -1):
		var puff := _active[i]
		if now >= puff.born + puff.life:
			puff.sprite.hide()
			_spare.append(puff)
			_active.remove_at(i)
		else:
			_pose(puff, now - puff.born)

func _spawn_smoke(now: float, origin: Vector3, load_factor: float) -> void:
	var puff := _take(false)
	puff.born = now
	puff.start = origin + Vector3(_rng.randf_range(-0.10, 0.10), 0.08, _rng.randf_range(-0.10, 0.10))
	puff.drift = Vector3(_rng.randf_range(-0.84, -0.48), _rng.randf_range(0.94, 1.44), _rng.randf_range(-0.43, 0.13))
	puff.life = lerpf(3.4, 4.7, load_factor) * _rng.randf_range(0.86, 1.12)
	puff.size = lerpf(0.86, 1.67, load_factor) * _rng.randf_range(0.82, 1.18)
	puff.strength = lerpf(0.48, 0.94, load_factor)

func _spawn_steam(now: float, origin: Vector3, side: float, remaining: float) -> void:
	var puff := _take(true)
	var envelope := smoothstep(0.0, 0.95, remaining) * smoothstep(2.42, 1.75, remaining)
	puff.born = now
	puff.start = origin + Vector3(_rng.randf_range(-0.12, 0.12), 0.0, side * 1.24)
	puff.drift = Vector3(_rng.randf_range(-1.4, -0.32), _rng.randf_range(-0.32, 0.1), side * _rng.randf_range(1.3, 2.3))
	puff.life = _rng.randf_range(1.6, 2.55)
	puff.size = lerpf(0.54, 0.92, envelope) * _rng.randf_range(0.82, 1.16)
	puff.strength = lerpf(0.22, 0.68, envelope)

func _take(jet: bool) -> Puff:
	var puff: Puff
	if not _spare.is_empty():
		puff = _spare.pop_back()
	elif _active.size() >= POOL_LIMIT:
		puff = _active.pop_front()
	else:
		puff = Puff.new()
		puff.sprite = Sprite3D.new()
		puff.sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		puff.sprite.pixel_size = 1.0 / 96.0
		puff.sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		puff.sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(puff.sprite)
	if _textures.is_empty():
		_bake_masks()
	puff.sprite.name = "%s%d" % ["CylinderSteam" if jet else "StackSmoke", puff.sprite.get_instance_id()]
	puff.sprite.texture = _textures[_rng.randi_range(0, _textures.size() - 1)]
	puff.roll = _rng.randf_range(-PI, PI)
	puff.jet = jet
	_active.append(puff)
	return puff

func _pose(puff: Puff, age: float) -> void:
	var fraction := age / puff.life
	var spread := (1.0 - exp(-age * 1.7)) if puff.jet else age
	var displacement := puff.drift * spread
	var growth := 1.0 + fraction * (2.35 if puff.jet else 2.65)
	if puff.jet:
		displacement += Vector3(-age * 0.42, age * age * 0.27, 0.0)
	else:
		displacement += Vector3(-age * age * 0.11, (1.0 - exp(-age * 2.1)) * 0.64, 0.0)
	var tint := VAPOR if puff.jet else SOOT
	tint.a = puff.strength * lerpf(0.45, 1.0, smoothstep(0.0, 0.18, age))
	tint.a *= pow(1.0 - fraction, 1.7 if puff.jet else 1.32)
	puff.sprite.position = puff.start + displacement
	puff.sprite.scale = Vector3.ONE * puff.size * growth
	# Sprite offset is centered; rotate the outline as the cloud rolls in the wind.
	puff.sprite.rotation.z = puff.roll + age * 0.44
	puff.sprite.modulate = tint
	puff.sprite.show()

static func _bake_masks() -> void:
	# A few low-resolution, irregular density masks, shared by both outlets.
	var noise := FastNoiseLite.new()
	noise.frequency = 0.046
	noise.fractal_octaves = 3
	for variant in 4:
		noise.seed = 171 + variant * 33
		var image := Image.create_empty(96, 96, false, Image.FORMAT_RGBA8)
		for y in 96:
			for x in 96:
				var p := (Vector2(x, y) + Vector2(0.5, 0.5)) / 48.0 - Vector2.ONE
				var detail := noise.get_noise_2d(x, y)
				var radius := p.length() + detail * 0.39
				var edge := 1.0 - smoothstep(0.39, 0.92, radius)
				var border := 1.0 - smoothstep(0.78, 0.98, p.length())
				var density := clampf(0.75 + detail * 0.67, 0.0, 1.0)
				image.set_pixel(x, y, Color(1, 1, 1, edge * border * density))
		image.generate_mipmaps()
		_textures.append(ImageTexture.create_from_image(image))
