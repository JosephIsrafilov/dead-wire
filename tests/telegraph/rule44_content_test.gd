extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var scenario := load("res://data/scenarios/m1_scenario_2_attention.tres") as TelegraphScenarioData
	var ledger := DispatchLedger.new()
	var checks := {
		"Second request does not dictate HOLD": scenario.transmission_data.true_message == "FREIGHT 71 EAST",
		"All three signal layers agree for ordinary freight": scenario.transmission_data.true_message == scenario.transmission_data.written_transcript and scenario.transmission_data.true_message == scenario.transmission_data.elias_perception,
		"Standing rule distinguishes a request from clearance": ledger.get_ledger_text().contains("not permission") and ledger.get_ledger_text().contains("HOLD unverified"),
		"Scenario validates": scenario.get_validation_errors().is_empty(),
		"Existing authority still requires HOLD": scenario.expected_routing_action == "HOLD",
		"Rule 44 is a fictional company order": ledger.get_ledger_text().contains("fictional Black Creek company order"),
		"Freight 71 has no booked division clearance": ledger.get_ledger_text().contains("No division clearance is booked for Freight 71 tonight"),
		"Reveal cues cover exactly thirteen non-space glyphs": scenario.transcript_reveal_cues.size() == 13,
		"Scenario identity is preserved": scenario.scenario_id == "attention_hold_freight",
		"Transmission identity is preserved": scenario.transmission_data.transmission_id == &"trans_m1_02_hold_freight",
		"Existing route consequences are preserved": scenario.correct_world_fact == "freight_held_correctly" and scenario.incorrect_world_fact == "freight_cleared_in_error",
		"Existing lapse consequences are preserved": scenario.routing_lapsed_world_fact == "freight_no_order_sent" and scenario.routing_lapsed_knowledge_fact == "lapsed_attention_hold_freight",
	}
	var failed := false
	for description in checks:
		print(("  PASS: " if checks[description] else "  FAIL: ") + description)
		failed = failed or not checks[description]
	ledger.free()
	quit(1 if failed else 0)
