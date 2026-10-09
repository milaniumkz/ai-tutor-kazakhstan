CREATE TABLE IF NOT EXISTS trial_policy (
 id INTEGER PRIMARY KEY CHECK(id=1), duration_days INTEGER NOT NULL CHECK(duration_days BETWEEN 1 AND 30)
);
INSERT OR IGNORE INTO trial_policy VALUES (1,3);
CREATE TABLE IF NOT EXISTS family_trials (
 family_id TEXT PRIMARY KEY REFERENCES families(id), started_at REAL NOT NULL,
 expires_at REAL NOT NULL, duration_days INTEGER NOT NULL, tariff_revision INTEGER NOT NULL
);
