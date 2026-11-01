class_name PlaytestTelemetry
extends Node

## A local playtest log (plan 10.6, ROADMAP 2.8): one JSON line per moment
## that matters when watching a stranger play, written to
## user://playtest/session_<unix>.jsonl. Nothing leaves the machine.
##
## Only a watch begun from the title writes (MainMenu.begin_watch and Stand
## Another Watch arm it), so tests and capture tools that build the office
## directly never leave files. The corrected word is never written: a filing
## records its outcome and the word's length, never the word.

const DEFAULT_DIRECTORY: String = "user://playtest"

static var _armed: bool = false
static var _directory: String = DEFAULT_DIRECTORY

static func arm() -> void:
	_armed = true

static func is_armed() -> bool:
	return _armed

## Tests point the log at a scratch folder.
static func set_directory(path: String) -> void:
	_directory = path

var _file: FileAccess = null
var _started_msec: int = 0
var _copy_finished_msec: int = -1
var _whisper: Node = null
var _whisper_shown: bool = false

func _ready() -> void:
	var armed := _armed
	_armed = false
	# Suites run with a scratch settings file; they never write into the
	# player's own playtest folder (a test points the log elsewhere).
	var under_suite := OS.has_environment(GameSettings.PATH_OVERRIDE_ENV) and _directory == DEFAULT_DIRECTORY
	if not armed or under_suite or not GameSettings.load_settings().playtest_telemetry_enabled:
		set_process(false)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_directory))
	var file_name := "session_%d_%d.jsonl" % [int(Time.get_unix_time_from_system()), Time.get_ticks_msec()]
	_file = FileAccess.open(_directory.path_join(file_name), FileAccess.WRITE)
	if _file == null:
		set_process(false)
		return
	_started_msec = Time.get_ticks_msec()
	record("session_start", {"build": ProjectSettings.get_setting("application/config/version", "")})
	_bind.call_deferred()

## Closed when the office is freed, not when it leaves the tree: the office
## is reparented into its presentation frame at start, which exits the tree.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _file != null:
		record("session_end")
		_file.close()
		_file = null

func is_writing() -> bool:
	return _file != null

## One event, timed from the start of the session.
func record(event: String, fields: Dictionary = {}) -> void:
	if _file == null:
		return
	var line := {"t": snappedf((Time.get_ticks_msec() - _started_msec) / 1000.0, 0.01), "event": event}
	line.merge(fields)
	_file.store_line(JSON.stringify(line))
	_file.flush()

func _bind() -> void:
	var office := get_parent() as M1OfficeController
	if office == null:
		return
	var director := office.shift_director
	if director != null:
		director.shift_opened.connect(func() -> void: record("night_start"))
		director.phase_changed.connect(func(phase: ShiftDirector.Phase, _previous: ShiftDirector.Phase) -> void:
			record("phase", {"phase": ShiftDirector.Phase.keys()[phase]}))
		director.call_started.connect(func(slot: int, number: int) -> void:
			record("call", {"slot": slot, "number": number}))
		director.call_answered.connect(func(slot: int, number: int) -> void:
			record("call_answered", {"slot": slot, "number": number}))
		director.traffic_missed.connect(func(slot: int, _scenario: TelegraphScenarioData) -> void:
			record("traffic_missed", {"slot": slot}))
		director.route_defaulted.connect(func(slot: int, _scenario: TelegraphScenarioData) -> void:
			record("route_defaulted", {"slot": slot}))
		director.shift_closed.connect(func() -> void: record("night_end"))
	var session := office.session_controller
	if session != null:
		session.session_state_changed.connect(func(state: int, _previous: int) -> void:
			record("session_state", {"state": TelegraphSessionController.State.keys()[state]}))
		session.copy_finished.connect(func(scenario_id: String) -> void:
			_copy_finished_msec = Time.get_ticks_msec()
			record("copy_finished", {"scenario": scenario_id}))
		session.routing_resolved.connect(func(action: String, outcome: int) -> void:
			record("route", {"action": action, "outcome": TelegraphSessionController.RoutingOutcome.keys()[outcome],
				"since_copy_s": _since_copy()}))
		# The word itself never reaches the log: only how long it was.
		session.commit_recorded.connect(func(scenario_id: String, action_id: StringName, word: String) -> void:
			record("filing", {"scenario": scenario_id, "action": String(action_id), "word_length": word.length(),
				"since_copy_s": _since_copy()}))
		var register := session.get_tape_register()
		if register != null:
			register.tape_inspected.connect(func(_text: String) -> void: record("tape_read"))
			register.register_wound.connect(func() -> void: record("register_wound"))
	if office.document_viewer != null:
		office.document_viewer.document_opened.connect(func(doc_id: String) -> void:
			record("document_opened", {"id": doc_id}))
	if office.window_observation != null:
		office.window_observation.visibility_started.connect(func() -> void: record("figure_visible"))
		office.window_observation.event_observed.connect(func() -> void: record("figure_observed"))
	var pause := office.get_node_or_null("PauseMenu")
	if pause != null and pause.has_signal("paused"):
		pause.connect("paused", func() -> void: record("paused"))
		pause.connect("resumed", func() -> void: record("resumed"))
	if office.office_door != null:
		office.office_door.player_left_office.connect(func() -> void: record("exit"))
	var ledger := office.get_node_or_null("DispatchLedger") as DispatchLedger
	if ledger != null:
		ledger.signed_on.connect(func(time_text: String) -> void: record("signed_on", {"station_time": time_text}))
		ledger.stamped.connect(func() -> void: record("watch_closed"))
	var found := office.find_children("*", "MurmurCaption", true, false)
	_whisper = found[0] if not found.is_empty() else null

## The whisper has no signals of its own; its visibility is watched here.
func _process(_delta: float) -> void:
	if _whisper == null or not is_instance_valid(_whisper):
		return
	var shown: bool = _whisper.call("is_visible_on_screen")
	if shown != _whisper_shown:
		_whisper_shown = shown
		record("whisper_shown" if shown else "whisper_gone")

func _since_copy() -> float:
	if _copy_finished_msec < 0:
		return -1.0
	return snappedf((Time.get_ticks_msec() - _copy_finished_msec) / 1000.0, 0.01)
