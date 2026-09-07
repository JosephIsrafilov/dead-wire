#!/usr/bin/env bash
# Runs every DEAD WIRE test suite headless and reports a single pass/fail summary.
#
#   bash tools/run_all_tests.sh
#
# Override the engine binary with GODOT_BIN when it lives somewhere else.

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

for suite in $(find "$PROJECT_DIR/tests" -name "*_test.gd" | sort); do
	relative="${suite#"$PROJECT_DIR"/}"
	# Match the Windows runner: tests validate the audio graph/telemetry, not a
	# host device, so use a deterministic headless backend.
	output=$("$GODOT_BIN" --headless --audio-driver Dummy --path "$GODOT_PROJECT_DIR" --script "res://$relative" 2>&1)
	exit_code=$?
	assertions=$(echo "$output" | grep -c "PASS:")
	if [ $exit_code -eq 0 ] && ! echo "$output" | grep -q '^FAIL:'; then
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
