# Scope and limitations

Library source: AI_Tutor_Complete_Package.zip, libfile_bab29b6cdc508191a3b8493137dd9a9d.
Two supported materialization attempts failed with "download failed"; no local readable ZIP was produced.
The specification and 37 images have therefore not been inspected. UI is provisional.
Internal financial documents must remain local and excluded from public Git history.

Implemented slice: explicit parent consent, synthetic child profile, subjects, mathematics
explanation, answer and hint, on-device synthetic progress, parent summary, RU/KK/EN navigation.
Translations need native educator review. Curriculum identifier is demo-synthetic-v1, not an official programme.
Production requires provider/ZDR assessment, Kazakhstan legal review, verified parent authorization,
authentication, retention/deletion controls, curriculum review and licensed learning content.

## Verification

Passed: backend 4 unit tests; real localhost HTTP smoke (7 assertions); Flutter analyze;
Flutter widget scenario (consent initially unchecked, retry, completion, Back, storage write);
Flutter web build. Browser scenario passed explicit consent, invalid text error, repeated
submission, in-app Back, and progress 1/1. A 390x844 reload screenshot shows the consent
layout without clipping. A resize without reload initially retained the old Flutter canvas
size; this browser resize behavior remains to investigate.

Not run: PostgreSQL integration (pg_isready reports no server, Docker daemon unavailable),
iOS/Android builds, native Back, external integrations. Flutter UI currently uses local
storage, not the HTTP API; API-to-client connection, authentication and robust durable
server progress are next steps. Parent zone is a demo summary and is not authenticated.
No official curriculum claims, no copyrighted textbooks, no real child data.

Public safety: source ZIP, finances, helpers, generated local configuration and signing
team identifiers excluded. No workflows/runners enabled. Initial public history contains
only the new project. Pattern scan found no common API/GitHub token strings in staged code.
