#!/usr/bin/env bash
# Runs every DEAD WIRE test suite headless and reports a single pass/fail summary.
#
#   bash tools/run_all_tests.sh
#
# Override the engine binary with GODOT_BIN when it lives somewhere else.
# Per-suite wall-clock budget: SUITE_TIMEOUT seconds (default 180); a hung
# suite is reported as `FAIL … TIMEOUT`, never a wedged runner.

set -u

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

find_godot() {
	local override="${GODOT_BIN:-}"
	if [ -n "$override" ] && command -v cygpath >/dev/null 2>&1; then
		override="$(cygpath -u "$override" 2>/dev/null || echo "$override")"
	elif [ -n "$override" ] && command -v wslpath >/dev/null 2>&1; then
		override="$(wslpath -u "$override" 2>/dev/null || echo "$override")"
	elif [[ "$override" =~ ^[A-Za-z]:[\\/] ]]; then
		# WSL images may not ship wslpath; still accept a conventional Windows path.
		local drive="${override:0:1}"
		local rest="${override:2}"
		drive="$(printf '%s' "$drive" | tr '[:upper:]' '[:lower:]')"
		override="/mnt/$drive/${rest//\\//}"
	fi
	if [ -n "$override" ] && [ -f "$override" ]; then
		echo "$override"
		return 0
	fi

	for candidate in godot4 godot \
		"$HOME/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" \
		"$HOME/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" \
		"/mnt/c/Users/YUSIF/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" \
		"/c/Users/YUSIF/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" \
		"C:/Users/YUSIF/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"; do
		if command -v "$candidate" >/dev/null 2>&1; then
			command -v "$candidate"
			return 0
		fi
		if [ -f "$candidate" ]; then
			echo "$candidate"
			return 0
		fi
	done
	return 1
}

if ! GODOT_BIN="$(find_godot)"; then
	echo "Godot binary not found." >&2
	echo "Set GODOT_BIN to the console executable path, e.g. GODOT_BIN=/path/to/Godot_console.exe." >&2
	exit 2
fi

GODOT_PROJECT_DIR="$PROJECT_DIR"
if [[ "$GODOT_BIN" =~ \.exe$ ]]; then
	if command -v cygpath >/dev/null 2>&1; then
		GODOT_PROJECT_DIR="$(cygpath -w "$PROJECT_DIR" 2>/dev/null || echo "$PROJECT_DIR")"
	elif command -v wslpath >/dev/null 2>&1; then
		GODOT_PROJECT_DIR="$(wslpath -w "$PROJECT_DIR" 2>/dev/null || echo "$PROJECT_DIR")"
	fi
fi

passed_suites=0
failed_suites=0
total_assertions=0
failed_names=""

# Per-suite wall-clock budget; a hung suite is a FAIL marked TIMEOUT, not a
# wedged runner. Overridable: SUITE_TIMEOUT=300 bash tools/run_all_tests.sh
SUITE_TIMEOUT="${SUITE_TIMEOUT:-180}"

# Full output of every FAILED suite is preserved here (gitignored) so flake
# evidence survives without manual capture; a suite passing again clears its log.
log_dir="$PROJECT_DIR/test_logs"
mkdir -p "$log_dir"

for suite in $(find "$PROJECT_DIR/tests" -name "*_test.gd" | sort); do
	relative="${suite#"$PROJECT_DIR"/}"
	log_name="$(echo "$relative" | tr '/' '_').log"
	# Match the Windows runner: tests validate the audio graph/telemetry, not a
	# host device, so use a deterministic headless backend.
	# Portable watchdog (macOS has no coreutils `timeout`, HANDOVER trap 19):
	# the suite runs in the background; if the budget expires the watchdog
	# marks the timeout file and kills it. Watchdog stdout goes to /dev/null so
	# an orphaned `sleep` can never hold the runner's output pipe open.
	out_file="$(mktemp)"
	timeout_marker="$(mktemp)"
	rm -f "$timeout_marker"
	"$GODOT_BIN" --headless --audio-driver Dummy --path "$GODOT_PROJECT_DIR" --script "res://$relative" >"$out_file" 2>&1 &
	suite_pid=$!
	(
		sleep "$SUITE_TIMEOUT"
		touch "$timeout_marker"
		kill -TERM "$suite_pid" 2>/dev/null
		sleep 10
		kill -KILL "$suite_pid" 2>/dev/null
	) >/dev/null 2>&1 &
	watchdog_pid=$!
	wait "$suite_pid"
	exit_code=$?
	kill "$watchdog_pid" 2>/dev/null
	wait "$watchdog_pid" 2>/dev/null
	timed_out=0
	if [ -f "$timeout_marker" ]; then
		timed_out=1
	fi
	rm -f "$timeout_marker"
	output="$(cat "$out_file")"
	rm -f "$out_file"
	assertions=$(echo "$output" | grep -c "PASS:")
	if [ $timed_out -eq 1 ]; then
		failed_suites=$((failed_suites + 1))
		failed_names="$failed_names $relative"
		printf '%s\n' "$output" > "$log_dir/$log_name"
		printf 'FAIL %-58s TIMEOUT after %ss (exit %d, log: test_logs/%s)\n' "$relative" "$SUITE_TIMEOUT" "$exit_code" "$log_name"
		echo "$output" | tail -8 | sed 's/^/       /'
	elif [ $exit_code -eq 0 ] && ! echo "$output" | grep -qE '^[[:space:]]*FAIL:'; then
		passed_suites=$((passed_suites + 1))
		total_assertions=$((total_assertions + assertions))
		rm -f "$log_dir/$log_name"
		printf 'OK   %-58s %4d assertions\n' "$relative" "$assertions"
	else
		failed_suites=$((failed_suites + 1))
		failed_names="$failed_names $relative"
		printf '%s\n' "$output" > "$log_dir/$log_name"
		printf 'FAIL %-58s exit %d (log: test_logs/%s)\n' "$relative" "$exit_code" "$log_name"
		echo "$output" | grep -i "fail\|error" | head -8 | sed 's/^/       /'
	fi
done

echo "-------------------------------------------------------------------------"
echo "suites passed: $passed_suites   failed: $failed_suites   assertions: $total_assertions"
if [ $failed_suites -ne 0 ]; then
	echo "failed suites:$failed_names"
	exit 1
fi
