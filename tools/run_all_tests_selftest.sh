#!/usr/bin/env bash
# Self-test for tools/run_all_tests.sh (ROADMAP 0.6).
#
#   bash tools/run_all_tests_selftest.sh
#
# Runs the real runner inside a throwaway sandbox against three fixture
# "suites" driven by a fake godot binary:
#   passing_test.gd        — prints PASS lines, exits 0        -> must be OK
#   indented_fail_test.gd  — prints "  FAIL:" (indented), exit 0 -> must be FAIL
#   hanging_test.gd        — never returns                     -> must be FAIL + TIMEOUT
# No engine required; safe to run anytime. Exits 0 when the runner
# handles all three, 1 otherwise.

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
	echo "  PASS: dummy assertion one"
	echo "  PASS: dummy assertion two"
	exit 0
	;;
*indented_fail_test.gd)
	echo "  PASS: before the failure"
	echo "  FAIL: deliberate indented failure"
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
check "hanging suite is reported FAIL with TIMEOUT mark" \
	"echo \"\$output\" | grep -qE '^FAIL +tests/hanging_test\.gd +TIMEOUT'"
check "runner exits non-zero when any suite fails" "[ $runner_exit -ne 0 ]"
check "runner does not wait out the hang (elapsed ${elapsed}s < 60s)" "[ $elapsed -lt 60 ]"
check "summary counts 1 passed / 2 failed" \
	"echo \"\$output\" | grep -q 'suites passed: 1   failed: 2'"

if [ $failures -eq 0 ]; then
	echo "--- run_all_tests selftest PASSED ---"
	exit 0
fi
echo "--- run_all_tests selftest FAILED ($failures) ---"
exit 1
