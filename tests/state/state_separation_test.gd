extends SceneTree

func _init() -> void:
	print("--- Starting State Separation Invariant Test ---")
	
	# Instantiate isolated test stores
	var world_store: WorldStateStore = WorldStateStore.new()
	var knowledge_store: KnowledgeStateStore = KnowledgeStateStore.new()
	
	# Invariant 1: Both stores start empty
	if not assert_condition(world_store.snapshot().is_empty(), "WorldState starts empty"): return
	if not assert_condition(knowledge_store.snapshot().is_empty(), "KnowledgeState starts empty"): return
	if not assert_condition(not world_store.has_fact(&"test_fact"), "WorldState has no initial facts"): return
	if not assert_condition(not knowledge_store.knows(&"test_fact"), "KnowledgeState has no initial knowledge"): return
	
	# Invariant 10: Distinct instances and storage dictionaries
	if not assert_condition(world_store != knowledge_store, "Stores are distinct objects"): return
	if not assert_condition(world_store.get_instance_id() != knowledge_store.get_instance_id(), "Stores have different instance IDs"): return
	
	# Invariant 2 & 7: WorldState.set_fact() stores objective value and handles idempotency
	var fact_signals: Array = []
	world_store.fact_changed.connect(func(id, prev, curr): fact_signals.append([id, prev, curr]))
	
	world_store.set_fact(&"door_unlocked", true)
	if not assert_condition(world_store.has_fact(&"door_unlocked"), "WorldState has fact 'door_unlocked'"): return
	if not assert_condition(world_store.get_fact(&"door_unlocked") == true, "WorldState value is true"): return
	if not assert_condition(fact_signals.size() == 1, "fact_changed signal emitted on new fact"): return
	if not assert_condition(fact_signals[0] == [&"door_unlocked", null, true], "fact_changed signal payload matches"): return
	
	# Idempotent set_fact (same value)
	world_store.set_fact(&"door_unlocked", true)
	if not assert_condition(fact_signals.size() == 1, "Repeated set_fact with same value does not emit repeat signal"): return
	
	# Invariant 3: KnowledgeState.knows() remains false after WorldState mutation
	if not assert_condition(not knowledge_store.knows(&"door_unlocked"), "KnowledgeState does not automatically learn from WorldState"): return
	if not assert_condition(knowledge_store.snapshot().is_empty(), "KnowledgeState snapshot remains empty"): return
	
	# Invariant 4 & 6: KnowledgeState.learn() makes knowledge true and is idempotent
	var learn_signals: Array = []
	knowledge_store.knowledge_learned.connect(func(id): learn_signals.append(id))
	
	knowledge_store.learn(&"door_unlocked")
	if not assert_condition(knowledge_store.knows(&"door_unlocked"), "KnowledgeState now knows 'door_unlocked'"): return
	if not assert_condition(learn_signals.size() == 1, "knowledge_learned signal emitted on new knowledge"): return
	if not assert_condition(learn_signals[0] == &"door_unlocked", "knowledge_learned signal payload matches"): return
	
	# Idempotent learn
	knowledge_store.learn(&"door_unlocked")
	if not assert_condition(learn_signals.size() == 1, "Repeated learn does not emit repeat signal"): return
	if not assert_condition(knowledge_store.knows(&"door_unlocked"), "KnowledgeState still knows fact after repeat learn"): return
	
	# Invariant 5: KnowledgeState.learn() does not modify WorldState
	if not assert_condition(world_store.get_fact(&"door_unlocked") == true, "WorldState value unaffected by KnowledgeState mutation"): return
	if not assert_condition(fact_signals.size() == 1, "WorldState received no extra signals from KnowledgeState mutation"): return
	
	# Invariant 8: Mutating snapshot does not mutate internal store state
	var world_snap: Dictionary[StringName, Variant] = world_store.snapshot()
	world_snap[&"door_unlocked"] = false
	world_snap[&"injected_fact"] = 999
	if not assert_condition(world_store.get_fact(&"door_unlocked") == true, "Internal WorldState protected from snapshot mutation"): return
	if not assert_condition(not world_store.has_fact(&"injected_fact"), "WorldState protected from injected snapshot keys"): return
	
	var know_snap: Dictionary[StringName, bool] = knowledge_store.snapshot()
	know_snap.clear()
	if not assert_condition(knowledge_store.knows(&"door_unlocked"), "Internal KnowledgeState protected from snapshot clear"): return
	
	# Invariant 9: Reset of one system does not clear the other
	var world_reset_count: Array = [0]
	var know_reset_count: Array = [0]
	world_store.state_reset.connect(func(): world_reset_count[0] += 1)
	knowledge_store.state_reset.connect(func(): know_reset_count[0] += 1)
	
	world_store.reset_for_new_game()
	if not assert_condition(world_store.snapshot().is_empty(), "WorldState cleared after reset"): return
	if not assert_condition(world_reset_count[0] == 1, "WorldState emitted state_reset"): return
	if not assert_condition(knowledge_store.knows(&"door_unlocked"), "KnowledgeState remains intact after WorldState reset"): return
	if not assert_condition(know_reset_count[0] == 0, "KnowledgeState received no reset signal"): return
	
	knowledge_store.reset_for_new_game()
	if not assert_condition(knowledge_store.snapshot().is_empty(), "KnowledgeState cleared after reset"): return
	if not assert_condition(know_reset_count[0] == 1, "KnowledgeState emitted state_reset"): return
	
	# Clean up allocated test stores
	world_store.free()
	knowledge_store.free()
	
	print("--- All State Separation Tests PASSED ---")
	quit(0)

func assert_condition(condition: bool, description: String) -> bool:
	if not condition:
		printerr("FAIL: Assertion failed: %s" % description)
		quit(1)
		return false
	else:
		print("  PASS: %s" % description)
		return true
