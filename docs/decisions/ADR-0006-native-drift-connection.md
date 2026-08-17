# ADR-0006: Use native Drift SQLite connection

**Status:** Accepted

## Decision
Use Drift NativeDatabase/LazyDatabase with the database stored in the application documents directory.

## Rationale
This supports local-first mobile persistence and background database opening while preserving a simple SQLite file model.

## Current note
The user-facing product name is Groovefolio. The internal Dart package may still appear as `vinyl_app`.
