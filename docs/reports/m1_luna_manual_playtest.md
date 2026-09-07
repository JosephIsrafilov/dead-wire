# M1 Luna Manual Playtest Script

This is a blind acceptance script. The facilitator must not mention WATER,
WATCHER, the commit desk, or the expected branch.

## Setup

1. Start the production main scene in Forward+ at 1280x720.
2. Use a fresh game state.
3. Do not enable the debug inspector.
4. Record screen resolution, graphics backend, and whether head bob is enabled.

## Run

1. Let the player discover the operator seat and open the line.
2. Observe whether the player returns to the key when the call arrives.
3. During each message, record whether the player notices the physical writing
   and whether they look at the transcript after the sound stops.
4. On the third message, do not provide a hint. Record the first action after
   transcript completion.
5. If the player reaches the two-copy desk, record whether both options are
   understood as physical records and whether only one is filed.
6. After filing, record whether the player notices the stamp and connects the
   later window beat to the preceding choice.
7. Repeat with a second player using the other copy if time permits.

## Record

For each player, capture:

- noticed signal/transcript mismatch: yes/no;
- understood next action without prompting: yes/no;
- inspected transcript before attempting a commit: yes/no;
- understood both copy labels: yes/no;
- selected exactly one copy: yes/no;
- noticed stamp/void result: yes/no;
- connected consequence to commit: yes/no;
- missed a critical call due to unclear presentation: yes/no;
- motion discomfort or head-bob complaint: yes/no;
- voluntary continuation interest after the shift: yes/no.

Acceptance targets are at least 70% mismatch discovery, 80% next-action
comprehension, 70% authorship attribution, 70% consequence attribution, and
fewer than 10% unfair critical-call misses. These are human gates and cannot be
replaced by the automated regression suite.
