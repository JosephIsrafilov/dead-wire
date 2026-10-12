# Native crash event in final regression (2026-10-12, fix session)

Final full regression on the current tree: **85/86 suites PASS, 2747 assertions, 0 FAIL lines,
0 SCRIPT ERROR**. One suite, `tests/telegraph/rule44_content_test.gd`, exited with raw code
**3221225477 (0xC0000005)** after printing 12/12 PASS lines, including
"Scenario identity is preserved" — the same crash-after-green-assertions signature as the
historical `shift_director_test` probe (132 PASS, then 0xC0000005).

Handling per plan: the failed run is PRESERVED
(`beta_review_finish/final_regression_2/rule44_content_test.log` and the `summary.json` entry)
and NOT re-run until a new observation or tool exists. This is the first in-session live
observation of the native crash since the offline dump analysis; it matches the established
site (engine teardown, after green assertions) and keeps the crash **OPEN**.

It does NOT identify the freeing destructor and does not by itself prove or disprove the
#117991 applicability claim — but it is consistent with a teardown-path native fault in the
GDScript/ScriptServer path rather than a game-logic failure. The `error_bearing_suites`
count also rose from 16 to 20 in this run, which is another data point that the teardown
problem is variable run to run, not a stable property of any single suite.