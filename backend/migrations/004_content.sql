CREATE TABLE IF NOT EXISTS content_roles (
 account_id TEXT NOT NULL REFERENCES families(id), role TEXT NOT NULL CHECK(role IN ('editor','method_reviewer','language_reviewer','publisher')),
 PRIMARY KEY(account_id,role)
);
CREATE TABLE IF NOT EXISTS curriculum_sources (id TEXT PRIMARY KEY, metadata TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS curriculum_objectives (id TEXT PRIMARY KEY, subject_id TEXT NOT NULL, code TEXT NOT NULL, grade INTEGER NOT NULL, metadata TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS lesson_versions (
 id TEXT PRIMARY KEY, logical_id TEXT NOT NULL, version INTEGER NOT NULL,
 author_id TEXT NOT NULL, objective_id TEXT NOT NULL REFERENCES curriculum_objectives(id),
 grade INTEGER NOT NULL, locale TEXT NOT NULL, status TEXT NOT NULL,
 payload TEXT NOT NULL, payload_hash TEXT NOT NULL, created_at TEXT NOT NULL,
 UNIQUE(logical_id,version)
);
CREATE TABLE IF NOT EXISTS content_reviews (
 id TEXT PRIMARY KEY, lesson_id TEXT NOT NULL REFERENCES lesson_versions(id),
 reviewer_id TEXT NOT NULL REFERENCES families(id), stage TEXT NOT NULL,
 decision TEXT NOT NULL, notes TEXT NOT NULL, created_at TEXT NOT NULL,
 UNIQUE(lesson_id,stage)
);
CREATE TABLE IF NOT EXISTS content_releases (
 id TEXT PRIMARY KEY, lesson_id TEXT NOT NULL REFERENCES lesson_versions(id),
 manifest TEXT NOT NULL, publisher_id TEXT NOT NULL REFERENCES families(id), created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS content_audit (
 id TEXT PRIMARY KEY, actor_id TEXT NOT NULL REFERENCES families(id),
 action TEXT NOT NULL, target_id TEXT NOT NULL, occurred_at TEXT NOT NULL
);
