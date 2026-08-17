# ADR-0002: Use Riverpod for dependency injection and state

**Status:** Accepted

## Decision
Use Riverpod, including generated providers where appropriate, for repository/service injection and feature state.

## Rationale
Provider overrides make tests practical, while reactive providers keep screens separated from persistence construction.

## Current note
The user-facing product name is Groovefolio. The internal Dart package may still appear as `vinyl_app`.
