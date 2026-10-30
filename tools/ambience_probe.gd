extends SceneTree

## What is the room actually playing, and from where?
##
## The complaint was "рандомный набор непонятных звуков": several beds at once,
## none of them identifiable as an object. This probe prints every player, its
## stream length, volume, bus and world position, so the mix can be judged on
## numbers instead of guessed at. Read-only: it changes nothing.
##
##   godot --headless --audio-driver Dummy --path . --script tools/ambience_probe.gd

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var office: Node = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	for _i in 6:
		await process_frame
	var intro := office.get_node_or_null("IntroCard")
	if intro != null and intro.has_method("skip_immediately"):
		intro.skip_immediately()
	await process_frame

	var ambience := office.get_node_or_null("OfficeAmbience")
	if ambience == null:
		print("NO AMBIENCE NODE")
		quit(1)
		return

	var player: Node3D = office.get_node("Player") as Node3D
	print("--- players (bus, dB, stream length, world position, distance to player) ---")
	for child in ambience.get_children():
		var p := child as AudioStreamPlayer
		var p3 := child as AudioStreamPlayer3D
		if p == null and p3 == null:
			continue
		var stream: AudioStream = p.stream if p != null else p3.stream
		var length := stream.get_length() if stream != null else 0.0
		var where := "2D"
		var distance := -1.0
		if p3 != null:
			where = str(p3.global_position.snapped(Vector3.ONE * 0.01))
			distance = p3.global_position.distance_to(player.global_position)
		print("  %-16s bus=%-9s %6.1f dB  %5.2fs  %s  dist=%.2fm  playing=%s" % [
			child.name, String(p.bus if p != null else p3.bus),
			p.volume_db if p != null else p3.volume_db,
			length, where, distance, p.playing if p != null else p3.playing])

	var unease := office.get_node_or_null("UneaseDirector")
	if unease != null:
		var anchors: Array = unease.get_creak_anchors()
		print("--- creak anchors: %d ---" % anchors.size())
		for anchor in anchors:
			var marker := anchor as Marker3D
			print("  %-22s %s  dist=%.2fm" % [
				marker.name,
				str(marker.global_position.snapped(Vector3.ONE * 0.01)),
				marker.global_position.distance_to(player.global_position)])

	print("--- director pacing ---")
	var director := office.get_node_or_null("ShiftDirector")
	if director != null:
		print("  waits before call: %s" % str(director.wait_seconds_before_call))
		print("  foreign traffic at slot %d after %.1fs: '%s'" % [
			director.foreign_traffic_slot, director.foreign_traffic_after_seconds,
			director.foreign_traffic_text])

	office.queue_free()
	await process_frame
	quit(0)
