# Statistics

- Route: `/stats`
- Current status: Placeholder screen

## Purpose

Turn raw play history into useful, understandable collection insights.

## Planned metrics

- Total plays
- Unique albums played
- Most-played albums and artists
- Plays by month or year
- Genre distribution when genre metadata exists
- Recently active and long-unplayed records
- Full album versus side preference

## Data dependencies

Statistics require the Plays table and repository aggregation queries. Complex
interpretation may live in a StatisticsService, while efficient counts and
grouping should remain close to the database.

## Presentation requirements

- Define the selected time range clearly.
- Show zero and empty states without misleading charts.
- Use accessible labels in addition to visual encoding.
- Avoid implying statistical certainty from very small listening histories.
