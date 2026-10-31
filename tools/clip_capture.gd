extends SceneTree

## The fixed 30-second clip (plan 2.0): one route through the room at the same
## pace every time, with sound - entry, the desk seated, the window, the board,
## the door. Stills cannot show flicker, dust, cloth, the flame or the room's
## sound; this can. Keep the route; only append to it.
##
##   godot --path . --write-movie .dream-loop/clips/clip.avi --fixed-fps 30 --script tools/clip_capture.gd
##
## Windowed. Movie Maker records picture and audio at a fixed frame rate.

const SECONDS := 30.0

## [time, eye position, look-at point], interpolated smoothly between keys.
const ROUTE := [
	[0.0, Vector3(-1.6, 1.62, 1.9), Vector3(-1.6, 1.4, 0.0)],
	[5.0, Vector3(-0.6, 1.62, 0.4), Vector3(-2.4, 1.0, -0.5)],
	[10.0, Vector3(-1.55, 1.19, -0.6), Vector3(-2.3, 0.78, -0.7)],
	[15.0, Vector3(-1.55, 1.19, -0.6), Vector3(-1.5, 1.45, -2.4)],
	[20.0, Vector3(0.2, 1.62, -0.6), Vector3(2.9, 1.4, -0.9)],
	[25.0, Vector3(0.2, 1.62, 0.2), Vector3(-1.6, 1.1, 2.4)],
	[30.0, Vector3(-0.6, 1.62, 0.9), Vector3(-1.6, 1.0, 2.4)],
]

var _time := 0.0
var _cam: Camera3D = null

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var office: Node = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	for _i in 4:
		await process_frame
	office.get_node("IntroCard").skip_immediately()
	(office.get_node("LampLife") as LampLife).set_wick_immediate(1.0)
	office.get_node("ShiftDirector").set("enabled", false)
	var player := office.get_node("Player") as Node3D
	player.set_process(false)
	player.set_physics_process(false)
	_cam = player.get_node("Head/Camera3D") as Camera3D
	# The door opens once at 22 s so the clip carries a draft through the room.
	var door := office.get_node_or_null("SouthDoor/DoorController")
	while _time < SECONDS:
		var dt := 1.0 / 30.0
		_time += dt
		_place(_time)
		if door != null and _time >= 22.0 and _time - dt < 22.0 and door.has_method("open"):
			# The door is locked for the whole watch: without this the clip never
			# actually opened it, and never showed the draft it was meant to.
			door.call("unlock")
			door.call("open")
		await process_frame
	quit(0)

func _place(t: float) -> void:
	for i in ROUTE.size() - 1:
		var a: Array = ROUTE[i]
		var b: Array = ROUTE[i + 1]
		if t <= b[0]:
			var k := smoothstep(0.0, 1.0, (t - a[0]) / (b[0] - a[0]))
			_cam.global_position = (a[1] as Vector3).lerp(b[1], k)
			_cam.look_at((a[2] as Vector3).lerp(b[2], k), Vector3.UP)
			return
