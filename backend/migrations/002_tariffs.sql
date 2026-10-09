CREATE TABLE IF NOT EXISTS administrator_roles (
 family_id TEXT PRIMARY KEY REFERENCES families(id), granted_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS tariff_configuration (
 id INTEGER PRIMARY KEY CHECK(id=1), name TEXT NOT NULL, price_per_child_kzt INTEGER NOT NULL CHECK(price_per_child_kzt>0),
 max_saved_profiles INTEGER NOT NULL CHECK(max_saved_profiles BETWEEN 1 AND 5),
 revision INTEGER NOT NULL, updated_at TEXT NOT NULL
);
INSERT OR IGNORE INTO tariff_configuration VALUES (1,'Индивидуальный доступ',10000,5,1,strftime('%Y-%m-%dT%H:%M:%SZ','now'));
CREATE TABLE IF NOT EXISTS tariff_audit (
 id TEXT PRIMARY KEY, actor_family_id TEXT NOT NULL REFERENCES families(id),
 old_configuration TEXT NOT NULL, new_configuration TEXT NOT NULL, occurred_at TEXT NOT NULL
);
