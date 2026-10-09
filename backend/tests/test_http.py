import json
import threading
import unittest
from http.server import HTTPServer
from urllib.request import Request, urlopen
from urllib.error import HTTPError
from backend import server

class HttpFlowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.http = HTTPServer(('127.0.0.1', 0), server.Handler)
        cls.thread = threading.Thread(target=cls.http.serve_forever, daemon=True)
        cls.thread.start()
        cls.base = 'http://127.0.0.1:' + str(cls.http.server_port)
    @classmethod
    def tearDownClass(cls):
        cls.http.shutdown()
        cls.http.server_close()
        cls.thread.join()
    def setUp(self):
        server.store = server.Store()
        server.sessions.clear()
    def request(self, path, data=None, token=None, origin=None, method=None):
        headers = {'Content-Type': 'application/json'}
        if token:
            headers['Authorization'] = 'Bearer ' + token
        if origin:
            headers['Origin'] = origin
        req = Request(self.base + path, data=None if data is None else json.dumps(data).encode(), headers=headers, method=method)
        try:
            with urlopen(req, timeout=2) as r:
                return r.status, json.load(r) if r.status != 204 else {}, r.headers
        except HTTPError as r:
            return r.code, json.load(r), r.headers
    def consent(self):
        status, data, _ = self.request('/api/consent', {'accepted': True})
        self.assertEqual(status, 200)
        self.assertTrue(data['demo'])
        return data['session']
    def test_complete_flow_and_repeat(self):
        self.assertEqual(self.request('/api/profile')[0], 403)
        self.assertEqual(self.request('/api/consent', {'accepted': False})[0], 400)
        token = self.consent()
        self.assertTrue(self.request('/api/profile', token=token)[1]['synthetic'])
        self.assertEqual(self.request('/api/lesson', token=token)[1]['curriculum'], 'demo-synthetic-v1')
        self.assertFalse(self.request('/api/attempt', {'answer': 4}, token)[1]['correct'])
        self.assertTrue(self.request('/api/attempt', {'answer': 5}, token)[1]['correct'])
        self.request('/api/attempt', {'answer': 5}, token)
        self.assertEqual(self.request('/api/progress', token=token)[1]['completed'], 1)
        parent = self.request('/api/parent', token=token)[1]
        self.assertEqual(parent['progress']['completed'], 1)
        self.assertEqual(parent['storage'], 'server-memory-demo')
    def test_consent_is_per_session_and_invalid_input(self):
        token = self.consent()
        self.assertEqual(self.request('/api/attempt', {'answer': 5})[0], 403)
        self.assertEqual(self.request('/api/progress', token='wrong')[0], 403)
        for value in ('5', True, -1, 21):
            self.assertEqual(self.request('/api/attempt', {'answer': value}, token)[0], 400)
        self.assertEqual(self.request('/api/progress', token=token)[1]['completed'], 0)
    def test_cors_restricts_origin(self):
        self.assertEqual(self.request('/api/consent', {'accepted': True}, origin='https://untrusted.invalid')[0], 403)
        status, _, headers = self.request('/api/consent', origin='http://127.0.0.1:8090', method='OPTIONS')
        self.assertEqual(status, 204)
        self.assertEqual(headers['Access-Control-Allow-Origin'], 'http://127.0.0.1:8090')
    def test_storage_failure_never_acknowledges_success(self):
        token = self.consent()
        class BrokenStore(server.Store):
            def answer(self, value):
                raise RuntimeError('storage failed')
        server.store = BrokenStore()
        status, data, _ = self.request('/api/attempt', {'answer': 5}, token)
        self.assertEqual(status, 503)
        self.assertNotIn('completed', data)
