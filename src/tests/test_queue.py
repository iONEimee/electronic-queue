import unittest
from features.queue_manager import QueueManager

class TestQueue(unittest.TestCase):
    def test_add_and_call(self):
        qm = QueueManager()
        ticket = {"number": "A-1", "status": "waiting"}
        qm.add_ticket(ticket)
        self.assertEqual(qm.get_queue_length(), 1)
        called = qm.call_next()
        self.assertEqual(called['number'], "A-1")
        self.assertEqual(called['status'], "called")

if __name__ == '__main__':
    unittest.main()