extends SceneTree
## Reproducible windowed production cameras. -- --phase=2/3/4/5/6 selects the evidence folder.

const TOWN := "res://scenes/town/black_creek_exterior.tscn"
const SALOON := "res://scenes/town/interiors/copper_mule_saloon.tscn"
const ROOM := "res://scenes/town/interiors/boarding_house_room.tscn"
var _out: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	var phase := "5"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="):
			phase = arg.trim_prefix("--phase=")
	_out = "res://.dream-loop/town_overhaul/phase" + phase
	DirAccess.make_dir_recursive_absolute(_out)
	var campaign := root.get_node("CampaignState") as CampaignStateStore
	campaign.reset_for_new_game()
	for dawn in [true, false]:
		campaign.phase = CampaignStateStore.PHASE_DAWN_WALK if dawn else CampaignStateStore.PHASE_DAY_TOWN
		var town := await _open(TOWN) as BlackCreekExteriorController
		town.fade_rect.hide()
		var cam := _camera(town)
		var mode := "dawn_" if dawn else "day_"
		await _shot(cam, Vector3(-16, 2.2, 23), Vector3(14, 2.5, 32), mode + "street")
		await _shot(cam, Vector3(6, 2.2, 24), Vector3(-2, 4.45, 33.7), mode + "saloon_front")
		if phase in ["3", "4", "5", "6"]:
			await _shot(cam, Vector3(4, 2.4, 29), Vector3(-15, 3.4, 34.8), mode + "south")
			await _shot(cam, Vector3(-3, 2.4, 23.7), Vector3(13, 2.9, 12.5), mode + "north")
			await _shot(cam, Vector3(1.75, 1.75, 4.4), Vector3(1.35, 2.12, -.3), mode + "depot")
			await _shot(cam, Vector3(21, 1.9, 31.5), Vector3(15, 2.3, 35.5), mode + "clinic")
		if phase in ["4", "5", "6"] and not dawn:
			await _shot(cam, Vector3(-41, 3, 24), Vector3(-48, 4.1, 15.5), "west_forge")
			await _shot(cam, Vector3(-44, 3, 32), Vector3(-53, 11.7, 63), "west_chapel")
			await _shot(cam, Vector3(34, 2.5, 23.5), Vector3(49, 1.4, 22.5), "east_bridge")
			await _shot(cam, Vector3(25, 1.92, -8.8), Vector3(21, 1.55, -14.0), "mj_gate")
			await _shot(cam, Vector3(18, 17, 47), Vector3(-10, 1.5, 4.3), "aerial_north")
			await _shot(cam, Vector3(13, 19, 3), Vector3(-11, 3.5, 52.4), "aerial_south")
		await _close(town)
	if phase in ["2", "5", "6"]:
		var saloon := await _open(SALOON)
		var cam := _camera(saloon)
		await _shot(cam, Vector3(0, 1.66, -5.3), Vector3(.1, 2.04, 5.2), "saloon_hall")
		await _shot(cam, Vector3(1.44, 1.71, -.22), Vector3(2.53, 1.88, 5.71), "saloon_backbar")
		await _shot(cam, Vector3(2.2, 1.91, 4.92), Vector3(.3, 3.40, -.6), "saloon_chandeliers")
		await _shot(cam, Vector3(-.7, 1.63, -1.66), Vector3(-4.5, 1.28, 1.6), "saloon_alcove")
		await _shot(cam, Vector3(-.9, 1.64, 2.96), Vector3(-2.78, 1.51, 6.31), "saloon_piano")
		await _close(saloon)
	if phase in ["5", "6"]:
		campaign.phase = CampaignStateStore.PHASE_DAWN_WALK
		var room := await _open(ROOM) as BoardingHouseRoomController
		room.fade_rect.hide()
		var cam := _camera(room)
		var anchor := room.room_builder.position
		var eye := anchor + Vector3(-0.14, 1.56, 1.25)
		var center := anchor + Vector3(1.55, 1.59, -0.41)
		await _shot(cam, eye, anchor + Vector3(0.5, 1.12, -.68), "dawn_room4")
		await _shot(cam, center + Vector3(-.61, .07, .08), center, "dawn_calendar")
		room.complete_sleep_immediate("")
		await _shot(cam, eye, anchor + Vector3(0.5, 1.12, -.68), "day_room4")
		await _shot(cam, center + Vector3(-.61, .07, .08), center, "day_calendar")
		await _close(room)
	quit()

func _open(path: String) -> Node3D:
	var scene := (load(path) as PackedScene).instantiate() as Node3D
	root.add_child(scene)
	for i in 7:
		await process_frame
	return scene

func _close(scene: Node3D) -> void:
	var host := scene.get_parent().get_parent()
	if host is SubViewportContainer:
		host.queue_free()
	else:
		scene.queue_free()
	for i in 4:
		await process_frame

func _camera(scene: Node3D) -> Camera3D:
	var player := scene.get_node("Player") as PlayerController
	player.set_process(false)
	player.set_physics_process(false)
	player.set_process_input(false)
	return player.get_node("Head/Camera3D") as Camera3D

func _shot(cam: Camera3D, eye: Vector3, target: Vector3, title: String) -> void:
	cam.global_position = eye
	cam.look_at(target, Vector3.UP)
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(_out.path_join(title + ".png"))
	print("SHOT ", title, " err=", error)
