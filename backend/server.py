"""Local synthetic-only API. No external AI or real child accounts."""
import json
import os
import secrets
from http.server import BaseHTTPRequestHandler, HTTPServer

PROFILE = {"id": "synthetic-aliya", "names": {"ru": "Алия", "kk": "Әлия", "en": "Aliya"}, "grade": 1, "synthetic": True}
LESSON = {"id": "addition-1", "curriculum": "demo-synthetic-v1", "grade": 1,
          "question": "3 + 2 = ?", "visual": "🍎 🍎 🍎  +  🍎 🍎",
          "explanations": {
              "ru": "1. Было 3 яблока.\n2. Добавили ещё 2.\n3. Посчитай все яблоки.",
              "kk": "1. 3 алма болды.\n2. Тағы 2 алма қостық.\n3. Барлық алманы сана.",
              "en": "1. Start with 3 apples.\n2. Add 2 more.\n3. Count all the apples."},
          "hints": {"ru": "Начни с 3, затем скажи 4 и 5.", "kk": "3-тен баста, содан кейін 4 және 5 де.", "en": "Start at 3, then say 4 and 5."}}

class Store:
    def __init__(self):
        self.consent = False
        self.completed = False
    def accept(self, value):
        if value is not True:
            raise ValueError("Explicit parent consent required")
        self.consent = True
    def answer(self, value):
        if not self.consent:
            raise PermissionError("Parent consent required")
        if type(value) is not int or not 0 <= value <= 20:
            raise ValueError("Answer must be an integer from 0 to 20")
        correct = value == 5
        if correct:
            self.completed = True
        return {"correct": correct, "completed": self.completed}
    def progress(self):
        return {"completed": int(self.completed), "total": 1}

class PostgresStore(Store):
    def __init__(self, url):
        import psycopg
        self.db = psycopg.connect(url)
        with self.db.cursor() as cur:
            cur.execute("CREATE TABLE IF NOT EXISTS demo_progress (id INTEGER PRIMARY KEY, consent BOOLEAN NOT NULL, completed BOOLEAN NOT NULL)")
            cur.execute("INSERT INTO demo_progress VALUES (1, false, false) ON CONFLICT DO NOTHING")
        self.db.commit()
        with self.db.cursor() as cur:
            cur.execute("SELECT consent, completed FROM demo_progress WHERE id=1")
            self.consent, self.completed = cur.fetchone()
    def persist(self):
        try:
            with self.db.cursor() as cur:
                cur.execute("UPDATE demo_progress SET consent=%s, completed=%s WHERE id=1", (self.consent, self.completed))
            self.db.commit()
        except Exception:
            self.db.rollback()
            raise
    def accept(self, value):
        old = self.consent
        super().accept(value)
        try:
            self.persist()
        except Exception:
            self.consent = old
            raise
    def answer(self, value):
        old = self.completed
        result = super().answer(value)
        try:
            self.persist()
        except Exception:
            self.completed = old
            raise
        return result

store = Store()
sessions = set()
allowed_origins = set(os.getenv("DEMO_WEB_ORIGINS", "http://127.0.0.1:8090,http://localhost:8090").split(","))

def storage_kind():
    return "postgres-demo" if isinstance(store, PostgresStore) else "server-memory-demo"

class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # Do not log request bodies, tokens, or child data.
        pass
    def origin_allowed(self):
        origin = self.headers.get("Origin")
        return origin is None or origin in allowed_origins
    def authorized(self):
        return self.headers.get("Authorization", "").removeprefix("Bearer ") in sessions
    def reply(self, code, data):
        body = json.dumps(data, ensure_ascii=False).encode()
        self.send_response(code)
        origin = self.headers.get("Origin")
        if origin in allowed_origins:
            self.send_header("Access-Control-Allow-Origin", origin)
            self.send_header("Vary", "Origin")
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def do_OPTIONS(self):
        if not self.origin_allowed():
            self.reply(403, {"error": "Origin not allowed"})
            return
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", self.headers.get("Origin", "http://127.0.0.1:8090"))
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.send_header("Vary", "Origin")
        self.end_headers()
    def do_GET(self):
        if not self.origin_allowed():
            self.reply(403, {"error": "Origin not allowed"})
            return
        if self.path == "/health":
            self.reply(200, {"status": "demo", "storage": storage_kind()})
            return
        if not self.authorized():
            self.reply(403, {"error": "Explicit demo consent required"})
            return
        try:
            routes = {"/api/profile": PROFILE, "/api/lesson": LESSON,
                      "/api/progress": {**store.progress(), "storage": storage_kind()},
                      "/api/parent": {"profile": PROFILE, "progress": store.progress(), "curriculum": LESSON["curriculum"], "storage": storage_kind()},
                      "/api/capabilities": {"ai": False, "voice": False, "ocr": False}}
            self.reply(200 if self.path in routes else 404, routes.get(self.path, {"error": "Not found"}))
        except Exception:
            self.reply(503, {"error": "Demo storage unavailable"})
    def do_POST(self):
        if not self.origin_allowed():
            self.reply(403, {"error": "Origin not allowed"})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length < 1 or length > 1024:
                self.reply(413 if length > 1024 else 400, {"error": "Invalid request size"})
                return
            data = json.loads(self.rfile.read(length))
            if not isinstance(data, dict):
                raise ValueError("Object required")
            if self.path == "/api/consent":
                if len(sessions) >= 100:
                    self.reply(503, {"error": "Demo session capacity reached"})
                    return
                store.accept(data.get("accepted"))
                token = secrets.token_urlsafe(24)
                sessions.add(token)
                self.reply(200, {"accepted": True, "session": token, "demo": True, "storage": storage_kind()})
            elif self.path == "/api/attempt":
                if not self.authorized():
                    raise PermissionError("Explicit demo consent required")
                self.reply(200, {**store.answer(data.get("answer")), "storage": storage_kind()})
            else:
                self.reply(404, {"error": "Not found"})
        except PermissionError as error:
            self.reply(403, {"error": str(error)})
        except (ValueError, TypeError):
            self.reply(400, {"error": "Invalid request"})
        except Exception:
            self.reply(503, {"error": "Demo storage unavailable"})

if __name__ == "__main__":
    if os.getenv("DATABASE_URL"):
        store = PostgresStore(os.environ["DATABASE_URL"])
    HTTPServer(("127.0.0.1", int(os.getenv("PORT", "8080"))), Handler).serve_forever()
