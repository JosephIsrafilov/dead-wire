extends SceneTree

## Did the physics sounds actually bind in the production room?
##
## The foley binder is defensive — it returns quietly if a node is missing — so
## a room where the cup clink never plays looks exactly like a healthy one at
## boot. This instantiates the real office, waits for the deferred bind, and
## reports every physics source it found plus the props it is listening to.
##
##   godot --headless --audio-driver Dummy --path . --script tools/physics_audio_probe.gd

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var office: Node = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	for _i in 12:
		await process_frame

	var foley := office.get_node_or_null("OfficeFoley")
	if foley == null:
		print("NO FOLEY NODE")
		quit(1)
		return
	print("--- foley children ---")
	var found := 0
	for child in foley.get_children():
		var player := child as AudioStreamPlayer3D
		if player == null:
			continue
		if not (String(child.name).contains("Impact") or String(child.name).contains("Cloth")):
			continue
		found += 1
		print("  %-22s stream=%-28s %.1f dB  at %s" % [
			child.name, player.stream.resource_path.get_file(), player.volume_db,
			str(player.global_position.snapped(Vector3.ONE * 0.01))])
	print("--- %d physics audio source(s) bound ---" % found)

	var loose := office.get_node_or_null("LooseProps")
	if loose != null:
		print("--- loose props in the room ---")
		for child in loose.get_children():
			var prop := child as LooseProp
			if prop == null:
				continue
			print("  %-12s mass %.2f kg  contacting=%d  impacted listeners=%d" % [
				child.name, prop.mass, prop.max_contacts_reported,
				prop.impacted.get_connections().size()])
	var coat := office.get_node_or_null("HangingCoat") as HangingCoat
	if coat != null:
		print("--- coat: %d particles, %d rustle listeners ---" % [
			coat.get_particle_count(), coat.rustled.get_connections().size()])
	office.queue_free()
	await process_frame
	quit(0 if found > 0 else 1)
