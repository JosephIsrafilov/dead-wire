extends SceneTree

## Every consequence has its own ending, and the night cannot outlast it.
##
## The cloud branch used to have no visible completion at all: the office only
## ever reported "the consequence is visible" for the window figure, so a
## moon_cloud night waited on the figure's visibility fallback — a timer that
## has nothing to do with a cloud — before the shift could close. A capture
## tool that slept a fixed 15 s then failed five exit checks because of it.
##
## Pinned here, on the production office and a real amendment: the cloud
## reports its own start and its own finish, the finish is bounded by authored
## timing, and the session actually completes from it.
##
##   godot --headless --audio-driver Dummy --path . --script tests/integration/consequence_completion_test.gd

var _assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Consequence Completion Test Suite ---")
	if not await _cloud_ends_the_session(): return
	if not await _cloud_lifts_gradually(): return
	print("--- All Consequence Completion Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

## The real path: a correct amendment resolves to the moon_cloud outcome, the
## office starts the cloud, and the session must reach COMPLETE from the
## cloud's own ending rather than from a fallback timer.
func _cloud_ends_the_session() -> bool:
	var office := await _office()
	if office == null: return false
	var session := office.session_controller
	var moon := office.get_node_or_null("MoonWeather") as MoonWeather
	if not _a(session != null and moon != null, "Office carries session and moon"): return false
	# The director would advance to the next slot the instant the session
	# completes, which is correct for a night but hides the completion this
	# test is about. The session is the authority here, so it is observed alone.
	office.shift_director.enabled = false

	if not _a(office.load_scenario_by_index(2), "The hook scenario loads into the office"): return false
	session._state = TelegraphSessionController.State.VERIFYING
	session.mark_transcript_verified()
	if not _a(session.submit_amendment("WATER"), "A correct amendment is accepted"): return false
	if not _a(session.get_resolved_outcome() == TelegraphScenarioData.OUTCOME_AMENDED_TRUE,
			"The correct amendment resolves to the authored outcome"): return false
	if not _a(session.get_state() == TelegraphSessionController.State.CONSEQUENCE,
			"The session enters its consequence"): return false

	# Cross the authored delay: this is where the office learns which
	# consequence to stage.
	session.advance_consequence(1.2)
	if not _a(moon.is_dimmed_now(), "The cloud outcome puts a cloud across the moon"): return false
	if not _a(moon.is_consequence_running(), "The cloud reports that its consequence is running"): return false

	# Nobody looks at the window. The cloud still has to end the consequence.
	var elapsed := 0.0
	var limit := 30.0
	while session.get_state() == TelegraphSessionController.State.CONSEQUENCE and elapsed < limit:
		var step := 1.0 / 30.0
		session.advance_consequence(step)
		moon.advance(step)
		elapsed += step
	if not _a(session.get_state() == TelegraphSessionController.State.COMPLETE,
			"The cloud consequence completes the session on its own (%.2f s of %.0f, state %d)"
				% [elapsed, limit, session.get_state()]): return false
	if not _a(elapsed < 20.0,
			"It completes inside the authored timing, not the 6 s visibility fallback (%.2f s)" % elapsed): return false
	office.queue_free()
	await process_frame
	return true

## The shadow lifts rather than snapping off.
func _cloud_lifts_gradually() -> bool:
	var scene: PackedScene = ResourceLoader.load("res://scenes/office/m1_office.tscn")
	var office: M1OfficeController = scene.instantiate() as M1OfficeController
	root.add_child(office)
	await process_frame
	var moon := office.get_node_or_null("MoonWeather") as MoonWeather
	if not _a(moon != null, "MoonWeather is in the production office"): return false
	var finishes: Array[int] = []
	moon.consequence_finished.connect(func() -> void: finishes.append(1))
	moon.force_cloud(1.0)
	# The shadow has to arrive before it can lift, so the sky is stepped the way
	# a frame loop steps it rather than in one leap.
	for _i in 45:
		moon.advance(1.0 / 60.0)
	if not _a(moon.dim > 0.05, "The cloud has actually dimmed the moonlight (%.3f)" % moon.dim): return false
	# Past the hold, still fading: the consequence is not finished yet.
	for _i in 25:
		moon.advance(1.0 / 60.0)
	if not _a(moon.is_consequence_running(), "A cloud that has just passed is still lifting"): return false
	if not _a(moon.dim > 0.05, "The moonlight has not snapped back in one frame (%.3f)" % moon.dim): return false
	# Through the fade: finished, once.
	for _i in 200:
		moon.advance(1.0 / 60.0)
	if not _a(not moon.is_consequence_running(), "The lifted cloud ends its consequence"): return false
	if not _a(finishes.size() == 1, "The consequence announces its end exactly once (got %d)" % finishes.size()): return false
	if not _a(is_zero_approx(moon.dim), "The moonlight is fully back (%.4f)" % moon.dim): return false
	for _i in 60:
		moon.advance(1.0 / 60.0)
	if not _a(finishes.size() == 1, "Advancing past the end announces nothing further"): return false
	office.queue_free()
	await process_frame
	return true

func _office() -> M1OfficeController:
	var scene: PackedScene = ResourceLoader.load("res://scenes/office/m1_office.tscn")
	if not _a(scene != null, "m1_office.tscn loads"): return null
	var office: M1OfficeController = scene.instantiate() as M1OfficeController
	if not _a(office != null, "Office instantiates"): return null
	root.add_child(office)
	await process_frame
	await process_frame
	return office

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
