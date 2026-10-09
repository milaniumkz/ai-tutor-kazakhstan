# AI Tutor Kazakhstan

Consent-first demonstration for grades 1–4. Product name and pricing remain undecided.
Synthetic mathematics only; AI, OCR and voice are capability interfaces, unavailable in this demo.

Run local demo: `cd app && flutter run -d chrome`.
Run API demo: `PORT=8081 python3 -m backend.server`, then build with
`cd app && flutter build web --dart-define=TUTOR_API_URL=http://127.0.0.1:8081`.
Serve with `python3 -m http.server 8090 --bind 127.0.0.1 --directory app/build/web` from the repo root.
Open http://127.0.0.1:8090. Other web origins must be explicitly listed in `DEMO_WEB_ORIGINS`.
Run tests: `python3 -m unittest discover -s backend/tests`; `cd app && flutter analyze && flutter test && flutter build web`.

Local demo stores synthetic progress on-device. API demo uses localhost-only HTTP, per-session
explicit consent, and shared synthetic profile progress in server memory until restart. It never
silently falls back to on-device saving after server errors. API supports an unverified PostgreSQL
adapter when DATABASE_URL is supplied and psycopg is installed. Do not use real child data.
No deployment, payments, external AI traffic or active CI is configured.

See docs/STATUS.md for verification and specification access limitations.

Real HTTP client test (start API first): `cd app && flutter test test/live_api_test.dart --dart-define=TEST_TUTOR_API_URL=http://127.0.0.1:8081`.
See [HTTP slice validation](docs/HTTP_SLICE.md) for the latest stage.
