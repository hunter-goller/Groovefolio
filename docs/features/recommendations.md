# Recommendations

- Current status: Planned

## Goal

Produce explainable suggestions from collection metadata and play history rather
than a black-box list.

## Candidate signals

- Time since last play
- Total play count
- Recent artist, genre, or era preferences
- Similarity to recently played records
- Records owned but never played
- Repetition avoidance
- Seasonal or time-of-day patterns after enough history exists

## Output contract

A recommendation should include:

- Album ID
- Reason or explanation
- Signal category
- Confidence or priority when useful

Example explanation:

> You have not played this record in eight months, and it shares an artist with
> two albums you played this week.

## Architecture

Recommendation logic belongs in a service and should consume repository
interfaces. It must be testable with fixture data before a Discover UI is built.
External metadata may enrich recommendations later but should not be required
for basic rediscovery.
