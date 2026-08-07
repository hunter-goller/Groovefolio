# Discover

- Route: `/discover`
- Current status: Placeholder screen

## Purpose

Help collectors choose something meaningful from records they already own.

## Planned sections

- Records not played recently
- Similar albums to recent listening
- Genre or era suggestions
- Underplayed records
- Personal listening-pattern prompts

## Principles

- Explain why an album is suggested.
- Prioritize the user's existing collection.
- Work with local data before requiring external integrations.
- Avoid repeating the same few suggestions indefinitely.
- Let the user open Album Detail or log a play directly.

## Dependencies

- AlbumRepository
- PlayRepository
- RecommendationService
- Optional future metadata adapters
