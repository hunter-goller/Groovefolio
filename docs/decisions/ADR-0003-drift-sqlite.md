# ADR-0003: Use Drift over SQLite

**Status:** Accepted

## Decision
Use Drift as the typed Dart persistence layer over a local SQLite database.

## Rationale
Groovefolio is local-first and relational: artists, albums, plays, NFC tags, genres, and future tracks need durable offline relationships and migrations.

## Current note
The user-facing product name is Groovefolio. The internal Dart package may still appear as `vinyl_app`.
