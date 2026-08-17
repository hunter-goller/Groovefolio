# ADR-0005: Use layered feature/project structure

**Status:** Accepted

## Decision
Separate database, repositories, providers, services, features, widgets, and integrations rather than placing persistence/business logic in screens.

## Rationale
The structure makes boundaries visible and supports testing as the app grows.

## Current note
The user-facing product name is Groovefolio. The internal Dart package may still appear as `vinyl_app`.
