# ADR-0004: Use go_router

**Status:** Accepted

## Decision
Use go_router with centralized route constants and a Riverpod-exposed router.

## Rationale
Named route constants/helpers reduce hard-coded paths and support parameterized album detail/edit flows.

## Current note
The user-facing product name is Groovefolio. The internal Dart package may still appear as `vinyl_app`.
