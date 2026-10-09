# Localhost HTTP demo slice

This follow-up retains the existing Python backend while architecture awaits the approved
specification. No reference source documents have been changed. This is a synthetic demo,
not real parent authentication, official curriculum, or production child data storage.

The opt-in TUTOR_API_URL build accepts http://localhost or http://127.0.0.1 only. Without
this define, the app remains explicitly labelled as a local demo. The HTTP path sends explicit
consent, receives an ephemeral demo session, fetches synthetic profile/lesson/progress,
submits an attempt, refreshes progress, and fetches a parent overview. The API rejects
protected requests without a session issued after explicit consent. All demo sessions share
one synthetic profile; session tokens are not real account authentication.

API mode shows its actual demo storage type. The default server stores progress in memory
until restart. Local mode saves on-device. No automatic cross-mode fallback occurs.
Timeouts, bad responses, and persistence errors show saving as unconfirmed. Buttons are
locked while a request runs; completion updates only after a successful validated response.
Repeated correct attempts remain 1/1. A PostgreSQL persistence error rolls back the in-memory
change and returns 503, rather than acknowledging completion.

Allowed browser origins are limited to localhost:8090 and 127.0.0.1:8090 unless configured
explicitly. JSON payloads are limited to 1024 bytes. No request bodies or session tokens are
logged. The server binds loopback. No external AI, OCR, voice, payment or production services.

## Verification

Backend: 8 unit/HTTP tests pass, including full consent-to-parent path, consent isolation,
invalid attempts, restricted CORS, idempotency, and a simulated storage failure.
Flutter: analyze clean; 7 repository/widget tests pass including a server failure with no false
success, return to 0/1, and 1200→390→1200 metric changes preserving lesson state and input.
An explicit metrics observer invalidates layout on viewport changes without resetting state.
Live localhost Flutter HTTP repository test and API-mode web build results are recorded below.

Browser API flow and final resize verification remain pending during a requested pause in Mac
UI interaction for a printer task. Earlier desktop resize evidence is not proof of the final
API-mode resize fix. PostgreSQL integration remains blocked: no running local service and no
authorization to start the stopped Docker/Colima. Neither was started. No runners were used.

Live Flutter HTTP repository test passed against localhost:8081: consent, synthetic profile,
versioned lesson, wrong and correct attempts, repeated completion, progress and parent endpoint.
API-mode Flutter web build passed. Reference packet is still not present on this Mac or in
repository docs at the last check; original source specifications/mockups are not uploaded.
