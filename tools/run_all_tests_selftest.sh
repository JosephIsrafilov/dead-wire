#!/usr/bin/env bash
# Self-test for tools/run_all_tests.sh (ROADMAP 0.6).
#
#   bash tools/run_all_tests_selftest.sh
#
# Runs the real runner inside a throwaway sandbox against five fixture
# "suites" driven by a fake godot binary:
#   passing_test.gd        — prints PASS lines, exits 0        -> must be OK
#   indented_fail_test.gd  — prints "  FAIL:" (indented), exit 0 -> must be FAIL
#   script_error_test.gd   — prints "SCRIPT ERROR:", exit 0     -> must be FAIL
#   no_assertions_test.gd  — prints only status text, exit 0   -> must be FAIL
#   hanging_test.gd        — never returns                     -> must be FAIL + TIMEOUT
# No engine required; safe to run anytime. Exits 0 when the runner
# handles all five, 1 otherwise.

set -u

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

mkdir -p "$SANDBOX/tools" "$SANDBOX/tests"
cp "$SELF_DIR/run_all_tests.sh" "$SANDBOX/tools/"

cat > "$SANDBOX/fake_godot.sh" <<'EOF'
#!/usr/bin/env bash
script=""
prev=""
for arg in "$@"; do
	if [ "$prev" = "--script" ]; then script="$arg"; fi
	prev="$arg"
done
case "$script" in
*passing_test.gd)
	echo "WARNING: Failed to read the root certificate store"
	echo "  PASS: dummy assertion one"
	echo "  PASS: dummy assertion two"
	exit 0
	;;
*indented_fail_test.gd)
	echo "  PASS: before the failure"
	echo "  FAIL: deliberate indented failure"
	exit 0
	;;
*script_error_test.gd)
	echo "  PASS: before the script error"
	echo "SCRIPT ERROR: Invalid call. Nonexistent method." >&2
	exit 0
	;;
*no_assertions_test.gd)
	echo "Fixture has a PASS: label in its diagnostic text."
	exit 0
	;;
*hanging_test.gd)
	echo "  PASS: before the hang"
	exec sleep 120
	;;
esac
exit 0
EOF
chmod +x "$SANDBOX/fake_godot.sh"

touch "$SANDBOX/tests/passing_test.gd" \
	"$SANDBOX/tests/indented_fail_test.gd" \
	"$SANDBOX/tests/script_error_test.gd" \
	"$SANDBOX/tests/no_assertions_test.gd" \
	"$SANDBOX/tests/hanging_test.gd"

start_seconds=$SECONDS
output=$(cd "$SANDBOX" && GODOT_BIN="$SANDBOX/fake_godot.sh" SUITE_TIMEOUT=5 \
	bash tools/run_all_tests.sh 2>&1)
runner_exit=$?
elapsed=$((SECONDS - start_seconds))

echo "$output"
echo "-----"
echo "runner exit: $runner_exit, elapsed: ${elapsed}s"

failures=0
check() {
	if eval "$2"; then
		echo "  PASS: $1"
	else
		echo "  FAIL: $1"
		failures=$((failures + 1))
	fi
}

check "passing suite is OK with 2 assertions" \
	"echo \"\$output\" | grep -qE '^OK +tests/passing_test\.gd +2 assertions'"
check "indented FAIL suite is reported FAIL, not OK" \
	"echo \"\$output\" | grep -qE '^FAIL +tests/indented_fail_test\.gd' && ! echo \"\$output\" | grep -qE '^OK +tests/indented_fail_test\.gd'"
check "a script error still fails when Godot exits zero" \
	"echo \"\$output\" | grep -qE '^FAIL +tests/script_error_test\.gd' && grep -q 'SCRIPT ERROR:' \"\$SANDBOX/test_logs/tests_script_error_test.gd.log\""
check "a suite must report at least one assertion" \
	"echo \"\$output\" | grep -qE '^FAIL +tests/no_assertions_test\.gd'"
check "hanging suite is reported FAIL with TIMEOUT mark" \
	"echo \"\$output\" | grep -qE '^FAIL +tests/hanging_test\.gd +TIMEOUT'"
check "runner exits non-zero when any suite fails" "[ $runner_exit -ne 0 ]"
check "runner does not wait out the hang (elapsed ${elapsed}s < 60s)" "[ $elapsed -lt 60 ]"
check "summary counts 1 passed / 4 failed" \
	"echo \"\$output\" | grep -q 'suites passed: 1   failed: 4'"

# ROADMAP 0.10: failed suites must leave their full log behind in test_logs/.
check "failed suite log saved (indented fail)" \
	"[ -f \"\$SANDBOX/test_logs/tests_indented_fail_test.gd.log\" ] && grep -q 'FAIL: deliberate indented failure' \"\$SANDBOX/test_logs/tests_indented_fail_test.gd.log\""
check "failed suite log saved (timeout)" \
	"[ -f \"\$SANDBOX/test_logs/tests_hanging_test.gd.log\" ] && grep -q 'PASS: before the hang' \"\$SANDBOX/test_logs/tests_hanging_test.gd.log\""
check "passing suite leaves no log behind" \
	"[ ! -f \"\$SANDBOX/test_logs/tests_passing_test.gd.log\" ]"
check "FAIL line advertises the log path" \
	"echo \"\$output\" | grep -qE '^FAIL +tests/indented_fail_test\.gd +exit 0 \(log: test_logs/'"

if [ $failures -eq 0 ]; then
	echo "--- run_all_tests selftest PASSED ---"
	exit 0
fi
echo "--- run_all_tests selftest FAILED ($failures) ---"
exit 1
