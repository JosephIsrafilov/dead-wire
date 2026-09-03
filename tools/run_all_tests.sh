#!/usr/bin/env bash
# Runs every DEAD WIRE test suite headless and reports a single pass/fail summary.
#
#   bash tools/run_all_tests.sh
#
# Override the engine binary with GODOT_BIN when it lives somewhere else.

set -u

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-C:/Users/YUSIF/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe}"

if [ ! -f "$GODOT_BIN" ]; then
	echo "Godot binary not found: $GODOT_BIN" >&2
	echo "Set GODOT_BIN to the console executable path." >&2
	exit 2
fi

passed_suites=0
failed_suites=0
total_assertions=0
failed_names=""

for suite in $(find "$PROJECT_DIR/tests" -name "*_test.gd" | sort); do
	relative="${suite#"$PROJECT_DIR"/}"
	output=$("$GODOT_BIN" --headless --path "$PROJECT_DIR" --script "res://$relative" 2>&1)
	exit_code=$?
	assertions=$(echo "$output" | grep -c "PASS:")
	if [ $exit_code -eq 0 ] && ! echo "$output" | grep -q "FAIL"; then
		passed_suites=$((passed_suites + 1))
		total_assertions=$((total_assertions + assertions))
		printf 'OK   %-58s %4d assertions\n' "$relative" "$assertions"
	else
		failed_suites=$((failed_suites + 1))
		failed_names="$failed_names $relative"
		printf 'FAIL %-58s exit %d\n' "$relative" "$exit_code"
		echo "$output" | grep -i "fail\|error" | head -8 | sed 's/^/       /'
	fi
done

echo "-------------------------------------------------------------------------"
echo "suites passed: $passed_suites   failed: $failed_suites   assertions: $total_assertions"
if [ $failed_suites -ne 0 ]; then
	echo "failed suites:$failed_names"
	exit 1
fi
