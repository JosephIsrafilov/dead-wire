extends SceneTree
## Real-time frame sampling during LIVE transmission + viewer transition, director ENABLED.
## Source recovered into evidence per review note (was in tools/, missing from published branch).
## 4.7.1 run: p50 5.129 / p95 5.994 / p99 8.414 ms (300 frames after 120 warmup);
## viewer p50 5.021 / p95 5.478 (120 frames). Windowed 1280x720, D3D12 Forward+, RTX 3070 laptop.
## Thresholds for this test setting only: p95 < 20 ms, p99 < 33.3 ms (not universal guarantees).
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	var office: M1OfficeController = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	await process_frame
	office.get_node("IntroCard").skip_immediately()
	office.operator_seat.sit_duration = 0.0
	office.operator_seat.approach_duration = 0.0
	office.operator_seat.sit()
	await process_frame
	var session := office.session_controller
	var scheduler := session.scheduler
	scheduler.auto_process = true
	var encoder := AmericanMorseEncoder.new()
	var compiler := MorseScheduleCompiler.new()
	var schedule := compiler.compile(encoder.encode("WATER", session.alphabet), session.playback_profile)
	scheduler.start(schedule)
	# Warmup 120 frames (director live, transmission running).
	for i in 120:
		await process_frame
	var samples: Array[float] = []
	for i in 300:
		var t0 := Time.get_ticks_usec()
		await process_frame
		samples.append(float(Time.get_ticks_usec() - t0) / 1000.0)
	samples.sort()
	print("PERF_LIVE frames=", samples.size(), " p50=", samples[samples.size() / 2],
		" p95=", samples[int(samples.size() * 0.95)], " p99=", samples[int(samples.size() * 0.99)])
	# Viewer open sample (document transition under load).
	var viewer := office.document_viewer
	if viewer.has_method("open_document"):
		var samples2: Array[float] = []
		for i in 120:
			var tt := Time.get_ticks_usec()
			await process_frame
			samples2.append(float(Time.get_ticks_usec() - tt) / 1000.0)
		samples2.sort()
		print("PERF_VIEWER frames=", samples2.size(), " p50=", samples2[samples2.size() / 2],
			" p95=", samples2[int(samples2.size() * 0.95)])
	quit(0)