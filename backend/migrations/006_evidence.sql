CREATE TABLE IF NOT EXISTS learning_evidence (
 id TEXT PRIMARY KEY, session_id TEXT NOT NULL REFERENCES learning_sessions(id),
 step INTEGER NOT NULL, kind TEXT NOT NULL, occurred_at TEXT NOT NULL
);
