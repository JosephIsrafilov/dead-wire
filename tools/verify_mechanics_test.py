import unittest
from verify_mechanics import classify

class ClassificationTests(unittest.TestCase):
    def test_indented_failure_even_zero_exit(self):
        r = classify('  PASS: before\n  FAIL: hidden', 0)
        self.assertFalse(r['passed'])
        self.assertEqual(r['assertions'], 1)
    def test_error_and_warning_separate_from_assertions(self):
        r = classify('PASS: contract\nERROR: detached\nWARNING: leaked', 0)
        self.assertTrue(r['passed'])
        self.assertEqual(len(r['runtime_errors']), 1)
        self.assertEqual(len(r['warnings']), 1)
    def test_nonzero_without_fail_line(self):
        self.assertFalse(classify('PASS: before crash', 139)['passed'])
    def test_script_error_cannot_hide_behind_zero_exit(self):
        self.assertFalse(classify('SCRIPT ERROR: stopped coroutine', 0)['passed'])

if __name__ == '__main__':
    unittest.main()
