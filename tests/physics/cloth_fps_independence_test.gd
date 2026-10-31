extends SceneTree

## The coat must move the same way at 30, 60 and 144 frames per second.
##
## The solver used to integrate once per rendered frame with `damping`, shape
## memory and constraint passes all applied per CALL rather than per second. The
## measured consequence: the same shove from the same start left the hem at
## 59.7 mm after half a second at 30 Hz and at 7.6 mm at 144 Hz. The garment
## was four times softer on a slow machine, and a long frame lost the time it
## overran instead of catching up.
##
## The fix is a fixed simulation step with bounded sub-steps: the solver always
## advances in units of SIM_STEP, and a frame contributes as many of those as it
## actually took. This suite pins the tolerance, so a future change that
## reintroduces per-frame damping fails here rather than on someone's laptop.
##
##   godot --headless --audio-driver Dummy --path . --script tests/physics/cloth_fps_independence_test.gd

var _assertions: int = 0

## How far apart two frame rates may leave the same particle after the same
## real time. In metres. The old behaviour differed by 52 mm, so 5 mm is a
## meaningful bar and still leaves room for the solver's own step quantisation.
const TOLERANCE_M: float = 0.005
## A long frame is simulated as several steps, never as one giant one.
const LONG_FRAME_SECONDS: float = 0.25

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Cloth FPS Independence Test Suite ---")
	if not _push_is_velocity(): return
	if not _shape_memory_is_a_spring(): return
	if not _same_shove_same_place(): return
	if not _long_frame_catches_up(): return
	if not _settles_in_similar_time(): return
	print("--- All Cloth FPS Independence Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

## Isolate integration: a 0.6 m/s draft travels 5 mm in one 120 Hz tick,
## not 60 cm, and the following tick retains that velocity without another push.
func _push_is_velocity() -> bool:
	var coat := _settled_coat()
	if coat == null: return false
	coat.gravity = 0.0
	coat.iterations = 0
	coat.shape_memory = 0.0
	coat.damping = 1.0
	coat._prev = coat._pos.duplicate()
	var hem := coat.rings - 1
	var before := coat.get_particle_position(hem, 0)
	coat.draft(before, Vector3.RIGHT, 0.6)
	if not _a(coat.get_particle_position(hem, 0) == before,
			"A draft changes velocity, not the current cloth position"): return false
	coat.step(HangingCoat.SIM_STEP)
	var first := coat.get_particle_position(hem, 0)
	var travel := 0.6 * HangingCoat.SIM_STEP
	if not _a(absf(first.x - before.x - travel) < 0.00001,
			"The first tick integrates the draft in metres per second (%.5f m)" % (first.x - before.x)): return false
	coat.step(HangingCoat.SIM_STEP)
	var second := coat.get_particle_position(hem, 0)
	if not _a(absf(second.x - first.x - travel) < 0.00001,
			"The next tick carries momentum without another shove"): return false
	coat.free()
	return true

## With gravity, constraints and drag removed, shape memory must oscillate
## about the authored drape, not ease monotonically toward a displaced home.
func _shape_memory_is_a_spring() -> bool:
	var coat := _settled_coat()
	if coat == null: return false
	coat.gravity = 0.0
	coat.iterations = 0
	coat.damping = 1.0
	coat._pos = coat._rest.duplicate()
	var index := (coat.rings - 1) * coat.segments
	coat._pos[index].x += 0.02
	coat._prev = coat._pos.duplicate()
	coat._home = coat._pos.duplicate()
	coat._frozen = false
	for tick in 60:
		coat.step(HangingCoat.SIM_STEP)
	var opposite := coat._pos[index].x - coat._rest[index].x
	if not _a(opposite < -0.015,
			"Shape memory swings past the authored drape after half a second (%.4f m)" % opposite): return false
	for tick in 60:
		coat.step(HangingCoat.SIM_STEP)
	var returned := coat._pos[index].x - coat._rest[index].x
	if not _a(absf(returned - 0.02) < 0.003,
			"An undamped shape-memory cycle lasts about one second (%.4f m)" % returned): return false
	coat.free()
	return true

## The measurement the review made: one shove, four frame rates, one particle.
func _same_shove_same_place() -> bool:
	var results := {}
	for fps in [30, 60, 144, 240]:
		var coat := _settled_coat()
		if coat == null: return false
		var hem := coat.rings - 1
		var origin := coat.get_particle_position(hem, 0) + Vector3(0.0, 0.35, -0.45)
		coat.disturb(origin, Vector3(0.0, 0.0, 1.4))
		var dt := 1.0 / float(fps)
		var elapsed := 0.0
		while elapsed < 0.5:
			coat.step(dt)
			elapsed += dt
		results[fps] = coat.get_particle_position(hem, 0)
		coat.free()
	var reference: Vector3 = results[60]
	for fps in [30, 144, 240]:
		var drift: float = (results[fps] as Vector3).distance_to(reference)
		if not _a(drift < TOLERANCE_M,
				"A %d Hz frame leaves the hem within %.1f mm of a 60 Hz one (%.2f mm)"
					% [fps, TOLERANCE_M * 1000.0, drift * 1000.0]): return false
	return true

## A quarter-second hitch must not be simulated as one quarter-second step: it
## has to catch up in bounded sub-steps, or the cloth teleports.
func _long_frame_catches_up() -> bool:
	var smooth := _settled_coat()
	var hitched := _settled_coat()
	if smooth == null or hitched == null: return false
	var hem := smooth.rings - 1
	var origin := smooth.get_particle_position(hem, 0) + Vector3(0.0, 0.35, -0.45)
	smooth.disturb(origin, Vector3(0.0, 0.0, 1.4))
	hitched.disturb(origin, Vector3(0.0, 0.0, 1.4))
	# 0.5 s of smooth 60 Hz frames, against 0.5 s delivered as two 0.25 s hitches.
	for _i in 30:
		smooth.step(1.0 / 60.0)
	for _i in 2:
		hitched.step(LONG_FRAME_SECONDS)
	var drift := smooth.get_particle_position(hem, 0).distance_to(hitched.get_particle_position(hem, 0))
	if not _a(drift < TOLERANCE_M * 2.0,
			"A 250 ms hitch lands within %.1f mm of smooth frames (%.2f mm)"
				% [TOLERANCE_M * 2000.0, drift * 1000.0]): return false
	smooth.free()
	hitched.free()
	return true

## The solver must actually sleep near its original pose, not merely pass
## through a turning point with a small instantaneous velocity.
func _settles_in_similar_time() -> bool:
	var times := {}
	for fps in [30, 144]:
		var coat := _settled_coat()
		if coat == null: return false
		var hem := coat.rings - 1
		coat.disturb(coat.get_particle_position(hem, 0) + Vector3(0.0, 0.35, -0.45),
			Vector3(0.0, 0.0, 1.4))
		var dt := 1.0 / float(fps)
		# Step first, then test. A settled coat reports itself settled at the
		# instant it is shoved — the impulse only moves it on the NEXT step —
		# so a loop that tests first exits immediately and measures nothing.
		#
		# Above 120 Hz a single frame is SHORTER than one simulation step, so
		# the first few calls legitimately produce no motion at all: the
		# accumulator is still filling. The loop therefore runs for a minimum
		# time before it is allowed to believe the coat has settled.
		var rest := coat._home.duplicate()
		var minimum := 0.1
		var elapsed := 0.0
		while elapsed < minimum or (elapsed < 12.0 and not coat._frozen):
			coat.step(dt)
			elapsed += dt
		times[fps] = elapsed
		var drift := 0.0
		for index in rest.size():
			drift = maxf(drift, rest[index].distance_to(coat._pos[index]))
		if not _a(drift < HangingCoat.FREEZE_SHAPE_TOLERANCE,
				"At %d Hz every particle returns to the original hanging pose (%.2f mm)" % [fps, drift * 1000]): return false
		coat.free()
	if not _a((times[30] as float) > 0.05 and (times[144] as float) > 0.05,
			"The coat is actually moving after the shove (30 Hz %.2f s, 144 Hz %.2f s)"
				% [times[30], times[144]]): return false
	if not _a((times[30] as float) < 12.0 and (times[144] as float) < 12.0,
			"The coat settles at both 30 Hz (%.2f s) and 144 Hz (%.2f s)" % [times[30], times[144]]): return false
	var ratio: float = maxf(times[30], times[144]) / maxf(minf(times[30], times[144]), 0.001)
	if not _a(ratio < 2.0,
			"Settling takes a comparable time at both rates (%.2f s vs %.2f s)" % [times[30], times[144]]): return false
	return true

## A coat that has already come to rest in the authored drape.
func _settled_coat() -> HangingCoat:
	var scene: PackedScene = load("res://scenes/office/hanging_coat.tscn")
	if not _a(scene != null, "The hanging-coat scene loads"): return null
	var coat := scene.instantiate() as HangingCoat
	if not _a(coat != null, "The coat instantiates"): return null
	root.add_child(coat)
	coat.set_process(false)
	for _i in 300:
		coat.step(1.0 / 60.0)
	return coat

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
