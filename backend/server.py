"""Local synthetic-only API. No network AI integration."""
import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

LESSON = {"id": "addition-1", "curriculum": "demo-synthetic-v1", "grade": 1,
          "question": "3 + 2 = ?", "steps": [3, 2, 5]}

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
        with self.db.cursor() as cur:
            cur.execute("UPDATE demo_progress SET consent=%s, completed=%s WHERE id=1", (self.consent, self.completed))
        self.db.commit()
    def accept(self, value):
        super().accept(value)
        self.persist()
    def answer(self, value):
        result = super().answer(value)
        self.persist()
        return result

store = Store()

class Handler(BaseHTTPRequestHandler):
    def reply(self, code, data):
        body = json.dumps(data).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def do_GET(self):
        routes = {"/health": {"status": "demo"}, "/api/lesson": LESSON,
                  "/api/progress": store.progress(),
                  "/api/capabilities": {"ai": False, "voice": False, "ocr": False}}
        self.reply(200 if self.path in routes else 404, routes.get(self.path, {"error": "Not found"}))
    def do_POST(self):
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length > 1024:
                self.reply(413, {"error": "Request too large"})
                return
            data = json.loads(self.rfile.read(length))
            if not isinstance(data, dict):
                raise ValueError("Object required")
            if self.path == "/api/consent":
                store.accept(data.get("accepted"))
                self.reply(200, {"accepted": True})
            elif self.path == "/api/attempt":
                self.reply(200, store.answer(data.get("answer")))
            else:
                self.reply(404, {"error": "Not found"})
        except PermissionError as error:
            self.reply(403, {"error": str(error)})
        except (ValueError, TypeError):
            self.reply(400, {"error": "Invalid request"})

if __name__ == "__main__":
    if os.getenv("DATABASE_URL"):
        store = PostgresStore(os.environ["DATABASE_URL"])
    HTTPServer(("127.0.0.1", 8080), Handler).serve_forever()
