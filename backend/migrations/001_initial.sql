PRAGMA foreign_keys = ON;
CREATE TABLE IF NOT EXISTS families (
 id TEXT PRIMARY KEY, login TEXT UNIQUE NOT NULL, password_hash TEXT NOT NULL,
 pin_hash TEXT NOT NULL, locale TEXT NOT NULL DEFAULT 'ru-KZ',
 timezone TEXT NOT NULL DEFAULT 'Asia/Almaty', created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS auth_sessions (
 token_hash TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id),
 child_id TEXT, expires_at REAL NOT NULL
);
CREATE TABLE IF NOT EXISTS children (
 id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id),
 nickname TEXT NOT NULL, grade INTEGER NOT NULL CHECK(grade BETWEEN 1 AND 4),
 age_band TEXT NOT NULL, instruction_language TEXT NOT NULL, avatar TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS consent_events (
 id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id),
 purpose TEXT NOT NULL, version TEXT NOT NULL, granted INTEGER NOT NULL,
 created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS learning_sessions (
 id TEXT PRIMARY KEY, child_id TEXT NOT NULL REFERENCES children(id),
 lesson_id TEXT NOT NULL, state TEXT NOT NULL, revision INTEGER NOT NULL,
 task_revision INTEGER NOT NULL, step INTEGER NOT NULL, help_level INTEGER NOT NULL,
 created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS attempts (
 id TEXT PRIMARY KEY, session_id TEXT NOT NULL REFERENCES learning_sessions(id),
 client_event_id TEXT NOT NULL, payload_hash TEXT NOT NULL, response TEXT NOT NULL,
 evaluation TEXT NOT NULL, created_at TEXT NOT NULL,
 UNIQUE(session_id, client_event_id)
);
CREATE TABLE IF NOT EXISTS operations (
 scope TEXT NOT NULL, operation_key TEXT NOT NULL, payload_hash TEXT NOT NULL,
 response TEXT NOT NULL, PRIMARY KEY(scope, operation_key)
);
CREATE TABLE IF NOT EXISTS auth_failures (
 scope TEXT PRIMARY KEY, count INTEGER NOT NULL, blocked_until REAL NOT NULL
);
