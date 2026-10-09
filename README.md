# AI Tutor Kazakhstan

Consent-first demonstration for grades 1–4. Product name and pricing remain undecided.
Synthetic mathematics only; AI, OCR and voice are capability interfaces, unavailable in this demo.

Run Flutter: `cd app && flutter run -d chrome`.
Run API: `python3 -m backend.server` (localhost:8080).
Run tests: `python3 -m unittest discover -s backend/tests`; `cd app && flutter analyze && flutter test && flutter build web`.

The demo keeps consent in session memory and synthetic progress on-device. API supports a PostgreSQL repository
when DATABASE_URL is supplied and psycopg is installed. Do not use real child data.
No deployment, payments, external AI traffic or active CI is configured.

See docs/STATUS.md for verification and specification access limitations.
