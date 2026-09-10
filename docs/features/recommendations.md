# Recommendations

Groovefolio builds personalized suggestions for a physical record collection
while explaining *why* every recommendation appears. The current engine runs
entirely on the device. It does not call an AI model or an external
recommendation server.

Current signals:
- album genres across all logged history
- genres played in the last 90 days
- artist affinity across logged history, weighted toward recent artist plays
- the most-played release decade
- each candidate's own play count and last-play date
- how long an owned record has gone unplayed

Example explanations:
- “Recent Soul match · No plays logged.”
- “You often play John Coltrane · 1 play logged.”
- “4 plays logged · Last played Mar 2, 2026 (5 months ago).”

Recommendations remain deterministic so the UI can show the evidence behind
each pick rather than presenting a black-box score.

## Current local signals

- **Rediscover:** a record has a logged play, but its latest valid play is at
  least 90 days old. Older last-play dates rank first.
- **Taste:** eligible records share a top genre or artist with logged plays.
  Recent genre and artist activity receives more weight than older history.
  Matching the favorite era and having fewer plays add smaller rotation bonuses.
- **Era:** eligible records come from the decade with the most logged plays.
- **Underplayed:** remaining records have zero to two logged plays and have not
  been played inside the 30-day suppression window.

Rediscover, taste, and era picks take priority in that order. Underplayed fills
from the remaining shelf. Each record appears at most once, and title then ID
break deterministic ties.

## Taste ranking

The local score combines evidence instead of relying on one rule:

- all-time matching genre play: 10 points
- recent matching genre play: 20 additional points
- all-time matching artist play: 8 points
- recent matching artist play: 18 additional points
- favorite-decade play: 4 points when the record is from that decade
- rotation bonus: 3 points for each play below three

A recent play is included in both the all-time and recent totals. This means a
recent genre play contributes 30 points and a recent artist play contributes 26
points. A candidate's own plays are subtracted from genre, artist, and era
support, so a record cannot recommend itself from circular evidence. Records
played inside the 30-day suppression window stay out of taste, era, and
underplayed shelves. The constants are intentionally explicit so the ranking
remains testable and can be tuned from real usage later.

## Explanation evidence

Each card shows a short leading reason. **Why this record?** opens the complete
evidence available for that pick: up to three matched genres, recent and
all-time supporting counts, favorite-artist history, era affinity, and the
candidate's own rotation history. Rediscovery and underplayed picks show their
corresponding last-play or collection-added evidence.

“No plays logged” does not claim the owner has never listened outside
Groovefolio. Future-dated plays do not count as recent listening. Plays with an
invalid date can support all-time counts, but never bypass recency safeguards.

Future server-backed discovery can add artist similarity, track-level musical
attributes, related releases, and records not already owned. Those are not
invented by the current local engine.
