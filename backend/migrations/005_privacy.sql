CREATE TABLE IF NOT EXISTS privacy_reauth (
 token_hash TEXT PRIMARY KEY, session_hash TEXT NOT NULL, purpose TEXT NOT NULL,
 expires_at REAL NOT NULL
);
CREATE TABLE IF NOT EXISTS privacy_jobs (
 id TEXT PRIMARY KEY, family_id TEXT NOT NULL, kind TEXT NOT NULL,
 child_id TEXT, state TEXT NOT NULL, created_at TEXT NOT NULL, completed_at TEXT,
 receipt_hash TEXT, artifact TEXT, expires_at REAL,
 UNIQUE(family_id,kind,child_id,id)
);
CREATE TABLE IF NOT EXISTS deletion_ledger (
 id TEXT PRIMARY KEY, family_id TEXT NOT NULL, child_id TEXT,
 occurred_at TEXT NOT NULL, applied_at TEXT
);
CREATE TABLE IF NOT EXISTS privacy_replays (
 session_hash TEXT NOT NULL, operation_key TEXT NOT NULL, request_hash TEXT NOT NULL,
 response TEXT NOT NULL, expires_at REAL NOT NULL,
 PRIMARY KEY(session_hash,operation_key)
);
