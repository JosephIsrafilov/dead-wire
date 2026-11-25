extends SceneTree

var _failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var campaign := root.get_node_or_null("CampaignState") as CampaignStateStore
	if campaign == null:
		campaign = CampaignStateStore.new()
		campaign.name = "CampaignState"
		root.add_child(campaign)
	campaign.reset_for_new_game()
	campaign.phase = CampaignStateStore.PHASE_DAY_TOWN
	campaign.pending_spawn_point = &"boarding_house_porch"

	var town := load("res://scenes/town/black_creek_exterior.tscn").instantiate() as BlackCreekExteriorController
	town.enable_psx_rendering = false
	root.add_child(town)
	current_scene = town
	await process_frame

	town.builder.interactable_triggered.emit(&"saloon_door")
	await process_frame
	await process_frame
	var saloon := current_scene
	_check(saloon != null and saloon.name == "CopperMuleSaloon", "Daytime saloon door transitions cleanly to CopperMuleSaloon")
	if saloon == null or saloon.name != "CopperMuleSaloon":
		quit(1)
		return

	var multimeshes := saloon.find_children("*", "MultiMeshInstance3D", true, false)
	var meshes := saloon.find_children("*", "MeshInstance3D", true, false)
	_check(multimeshes.size() >= 14, "Saloon batches repeated geometry into MultiMeshInstance3D (got %d)" % multimeshes.size())
	_check(meshes.size() < 320, "Saloon MeshInstance3D node count stays bounded (%d)" % meshes.size())

	var no_pcss := true
	var pbr_textures_ok := true
	for child in saloon.get_children():
		if child is SpotLight3D and (child as SpotLight3D).light_size > 0.001:
			no_pcss = false
		if child is MeshInstance3D and child.material_override is StandardMaterial3D:
			var mat := child.material_override as StandardMaterial3D
			if mat.normal_enabled and (mat.albedo_texture == null or mat.normal_texture == null or mat.roughness_texture == null):
				pbr_textures_ok = false
	_check(no_pcss, "Saloon window spotlights avoid costly PCSS shadow blurring")
	_check(pbr_textures_ok, "Saloon PBR materials preload valid albedo/normal/roughness textures")

	var player := saloon.get_node_or_null("Player") as PlayerController
	_check(player != null and not player.is_movement_locked, "Saloon unlocks player movement on arrival")

	var exit_area := saloon.get_node_or_null("SaloonExit") as Interactable
	_check(exit_area != null, "Saloon exit interactable is mounted")
	if exit_area != null:
		exit_area.interact()
		await process_frame
		await process_frame
		_check(current_scene is BlackCreekExteriorController, "Saloon exit returns cleanly to Black Creek")
		var returned := current_scene as BlackCreekExteriorController
		_check(returned.player.global_position.distance_to(Vector3(-2.0, 0.30, 32.20)) < 0.25,
			"Returning places the player on saloon_porch")

	var pres := SubViewportContainer.new()
	pres.set_script(load("res://scripts/presentation/office_presentation.gd"))
	pres.material = ShaderMaterial.new()
	var svp := SubViewport.new()
	pres.attach_source(svp)
	root.add_child(pres)
	pres.configure(Vector2i.ZERO, ReadabilityPolicy.profile(720, 1))
	_check(svp.size.x >= 1 and svp.size.y >= 1 and is_finite(pres.scale.x) and pres.scale.x > 0.0,
		"OfficePresentation.configure clamps zero window size safely")
	pres.queue_free()
	if is_instance_valid(current_scene):
		current_scene.queue_free()
	await process_frame
	quit(int(_failures > 0))

func _check(ok: bool, desc: String) -> void:
	_failures += int(not ok)
	print("  %s: %s" % ["PASS" if ok else "FAIL", desc])
