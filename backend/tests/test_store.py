import unittest
from backend.server import Store

class ProgressTests(unittest.TestCase):
    def test_consent_required(self):
        with self.assertRaises(PermissionError):
            Store().answer(5)
    def test_explicit_consent(self):
        for value in (False, None, 1, "true"):
            with self.assertRaises(ValueError):
                Store().accept(value)
    def test_wrong_retry_and_idempotency(self):
        s = Store()
        s.accept(True)
        self.assertFalse(s.answer(4)["correct"])
        self.assertTrue(s.answer(5)["correct"])
        s.answer(5)
        s.answer(4)
        self.assertEqual(s.progress()["completed"], 1)
    def test_invalid_answer(self):
        s = Store()
        s.accept(True)
        for value in (True, "5", -1, 21):
            with self.assertRaises(ValueError):
                s.answer(value)
