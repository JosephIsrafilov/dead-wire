#!/usr/bin/env python3
"""Vision check tool: sends game screenshots to a GLM vision model via the
user's existing proxy and prints what the model sees.

Usage:
  python3 tools/vision_check.py <image.png> ["question"]
  python3 tools/vision_check.py --all <dir> ["question"]   # every png in dir
  python3 tools/vision_check.py --selftest                 # local mocks only

Model priority: bandelbanget glm-5.3-flash -> modelhub glm-5.3-flash
-> openrouter z-ai/glm-5.3-flashx. Keys come from opencode config/auth,
never printed.

Honesty rules (a run is only "green" when a model actually answered):
  - total failure of all providers  -> exit 1, no PASS wording
  - empty folder / missing file     -> exit 2
  - empty or truncated content      -> INCONCLUSIVE, one bounded retry only
  - reasoning_content is never used as the final vision verdict and is
    never printed or logged
  - every successful answer is appended to .dream-loop/vision_log.jsonl
    with provider/model, timestamp, SHA-256 of the image, question and the
    final answer (no keys, no base64, no reasoning)
"""

import base64
import glob
import hashlib
import json
import os
import sys
import time
import urllib.request

CFG_PATH = os.path.expanduser('~/.config/opencode/opencode.json')
AUTH_PATH = os.path.expanduser('~/.local/share/opencode/auth.json')
LOG_PATH = os.path.join('.dream-loop', 'vision_log.jsonl')

MAX_ATTEMPTS_PER_PROVIDER = 2  # one primary + one bounded retry
REQUEST_TIMEOUT_SECONDS = 90


def _targets():
    out = []
    try:
        cfg = json.load(open(CFG_PATH))
        for pid in ('bandelbanget', 'modelhub'):
            p = cfg.get('provider', {}).get(pid, {}).get('options', {})
            if p.get('baseURL') and p.get('apiKey'):
                out.append((pid, p['baseURL'], p['apiKey'], 'glm-5.3-flash'))
    except Exception:
        pass
    try:
        auth = json.load(open(AUTH_PATH))
        if 'openrouter' in auth:
            out.append(('openrouter', 'https://openrouter.ai/api/v1',
                        auth['openrouter']['key'], 'z-ai/glm-5.3-flashx'))
    except Exception:
        pass
    return out


class VisionAnswer:
    """A usable answer: non-empty content, not truncated."""

    def __init__(self, provider, model, content, finish_reason):
        self.provider = provider
        self.model = model
        self.content = content
        self.finish_reason = finish_reason


def _post_chat(base, key, model, body):
    req = urllib.request.Request(
        base.rstrip('/') + '/chat/completions',
        data=json.dumps(body).encode(),
        headers={'Authorization': 'Bearer ' + key,
                 'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT_SECONDS) as r:
        return json.load(r)


def _extract_answer(out):
    """Returns (content, finish_reason). reasoning_content is deliberately
    ignored as a verdict source: a model that only reasoned did not answer."""
    choices = out.get('choices') or []
    if not choices:
        return None, None
    message = choices[0].get('message') or {}
    content = (message.get('content') or '').strip()
    finish_reason = (choices[0].get('finish_reason') or '').strip()
    if not content:
        return None, finish_reason
    return content, finish_reason


def _ask_once(targets, b64, question, allow_retry):
    """Tries providers in order. Returns (answer, failure_note).

    - usable content  -> VisionAnswer
    - truncated (finish_reason == 'length') or empty -> retry once, else
      move on to the next provider; recorded as inconclusive, never success
    - network/API error -> retry once, then next provider
    """
    failure_note = 'all providers failed'
    for pid, base, key, model in targets:
        attempts = MAX_ATTEMPTS_PER_PROVIDER if allow_retry else 1
        for attempt in range(attempts):
            body = {
                'model': model,
                'messages': [{
                    'role': 'user',
                    'content': [
                        {'type': 'text', 'text': question},
                        {'type': 'image_url',
                         'image_url': {'url': 'data:image/png;base64,' + b64}},
                    ],
                }],
                'max_tokens': 2400,
            }
            try:
                out = _post_chat(base, key, model, body)
            except Exception as e:
                failure_note = '%s error: %s' % (pid, e)
                print('  (%s attempt %d failed: %s)' % (pid, attempt + 1, e),
                      file=sys.stderr)
                continue
            content, finish_reason = _extract_answer(out)
            if content is None:
                # Empty content is not an answer even if the model reasoned.
                failure_note = ('%s returned empty content (finish_reason=%s)'
                                % (pid, finish_reason or 'unknown'))
                print('  (%s attempt %d: empty content, not counted as '
                      'success)' % (pid, attempt + 1), file=sys.stderr)
                continue
            if finish_reason == 'length':
                failure_note = ('%s truncated the answer (finish_reason=length)'
                                % pid)
                print('  (%s attempt %d truncated, inconclusive)'
                      % (pid, attempt + 1), file=sys.stderr)
                continue
            return VisionAnswer(pid, model, content, finish_reason), None
    return None, failure_note


def ask_vision(path, question, allow_retry=True):
    """Returns VisionAnswer or None. Never fabricates success."""
    data = open(path, 'rb').read()
    b64 = base64.b64encode(data).decode()
    targets = _targets()
    if not targets:
        print('  (no providers configured)', file=sys.stderr)
        return None
    answer, _note = _ask_once(targets, b64, question, allow_retry)
    return answer


def _log_answer(path, question, answer):
    try:
        digest = hashlib.sha256(open(path, 'rb').read()).hexdigest()
    except Exception:
        digest = 'unavailable'
    entry = {
        'image': path,
        'sha256': digest,
        'provider': answer.provider,
        'model': answer.model,
        'finish_reason': answer.finish_reason,
        'question': question,
        'answer': answer.content,
        'time': time.strftime('%Y-%m-%dT%H:%M:%S'),
    }
    try:
        os.makedirs(os.path.dirname(LOG_PATH), exist_ok=True)
        with open(LOG_PATH, 'a', encoding='utf-8') as fh:
            fh.write(json.dumps(entry, ensure_ascii=False) + '\n')
    except Exception as e:
        print('  (could not write vision log: %s)' % e, file=sys.stderr)


DEFAULT_QUESTION = (
    "This is a first-person PSX-style horror game screenshot. Describe: "
    "1) what UI text is readable, 2) the main objects/props visible, "
    "3) anything that looks visually broken (disconnected meshes, holes in "
    "walls, misplaced objects). Be concrete and brief.")


def _run_selftest():
    """Local fixtures only, no live API: parser + exit-code honesty."""
    import unittest

    class ParserTests(unittest.TestCase):
        def test_reasoning_content_is_not_a_verdict(self):
            content, finish = _extract_answer({
                'choices': [{'message': {
                    'content': '',
                    'reasoning_content': 'I think it looks fine.',
                }, 'finish_reason': 'stop'}]})
            self.assertIsNone(content)
            self.assertEqual(finish, 'stop')

        def test_empty_choices_is_not_a_verdict(self):
            content, finish = _extract_answer({'choices': []})
            self.assertIsNone(content)
            self.assertIsNone(finish)

        def test_truncation_is_detected(self):
            content, finish = _extract_answer({
                'choices': [{'message': {'content': 'half an answ'},
                             'finish_reason': 'length'}]})
            self.assertEqual(content, 'half an answ')
            self.assertEqual(finish, 'length')

        def test_good_answer_passes(self):
            content, finish = _extract_answer({
                'choices': [{'message': {'content': ' A dark room. '},
                             'finish_reason': 'stop'}]})
            self.assertEqual(content, 'A dark room.')
            self.assertEqual(finish, 'stop')

        def test_targets_never_expose_keys(self):
            # Reading config errors are swallowed; targets simply stay empty.
            self.assertIsInstance(_targets(), list)

        def test_ask_once_all_failures_returns_none(self):
            real_post = sys.modules[__name__]._post_chat

            def boom(base, key, model, body):
                raise OSError('network down')

            sys.modules[__name__]._post_chat = boom
            try:
                answer, note = _ask_once(
                    [('fake', 'http://localhost:1', 'k', 'm')], 'x', 'q',
                    allow_retry=False)
            finally:
                sys.modules[__name__]._post_chat = real_post
            self.assertIsNone(answer)
            self.assertIn('error', note)

        def test_ask_once_truncated_is_inconclusive(self):
            real_post = sys.modules[__name__]._post_chat

            def truncated(base, key, model, body):
                return {'choices': [{'message': {'content': 'partial'},
                                     'finish_reason': 'length'}]}

            sys.modules[__name__]._post_chat = truncated
            try:
                answer, note = _ask_once(
                    [('fake', 'http://localhost:1', 'k', 'm')], 'x', 'q',
                    allow_retry=False)
            finally:
                sys.modules[__name__]._post_chat = real_post
            self.assertIsNone(answer)
            self.assertIn('truncated', note)

        def test_ask_once_reasoning_only_is_not_success(self):
            real_post = sys.modules[__name__]._post_chat

            def reasoning_only(base, key, model, body):
                return {'choices': [{'message': {
                    'content': '',
                    'reasoning_content': 'looks okay to me',
                }, 'finish_reason': 'stop'}]}

            sys.modules[__name__]._post_chat = reasoning_only
            try:
                answer, note = _ask_once(
                    [('fake', 'http://localhost:1', 'k', 'm')], 'x', 'q',
                    allow_retry=False)
            finally:
                sys.modules[__name__]._post_chat = real_post
            self.assertIsNone(answer)
            self.assertIn('empty content', note)

    suite = unittest.defaultTestLoader.loadTestsFromTestCase(ParserTests)
    result = unittest.TextTestRunner(verbosity=1).run(suite)
    return 0 if result.wasSuccessful() else 1


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        sys.exit(2)
    if args[0] == '--selftest':
        sys.exit(_run_selftest())

    if args[0] == '--all':
        if len(args) < 2:
            print('--all needs a directory')
            sys.exit(2)
        images = sorted(glob.glob(os.path.join(args[1], '*.png')))
        question = args[2] if len(args) > 2 else DEFAULT_QUESTION
        if not images:
            print('ERROR: no .png files in %s — an empty folder is not a '
                  'performed check.' % args[1], file=sys.stderr)
            sys.exit(2)
    else:
        images = [args[0]]
        question = args[1] if len(args) > 1 else DEFAULT_QUESTION
        if not os.path.isfile(images[0]):
            print('ERROR: no such file: %s' % images[0], file=sys.stderr)
            sys.exit(2)

    failures = 0
    for path in images:
        answer = ask_vision(path, question)
        if answer is None:
            failures += 1
            print('=== %s: NO USABLE ANSWER (inconclusive — not a pass)'
                  % os.path.basename(path))
            print()
            continue
        _log_answer(path, question, answer)
        print('=== %s  [%s/%s]' % (os.path.basename(path),
                                   answer.provider, answer.model))
        print(answer.content.strip())
        print()

    if failures:
        print('VISION CHECK: %d of %d image(s) produced no usable answer.'
              % (failures, len(images)), file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
