# Recommendations

Long-term Groovefolio goal: Spotify-like personalization for a physical record collection while explaining *why* each recommendation appears.

Potential signals:
- album genres
- artist similarity
- play frequency
- recent listening
- long-unplayed records
- track metadata after the Tracks/Discogs work
- collection gaps / related releases

Example explanations:
- “You have been playing a lot of soul lately.”
- “Similar genre profile to records you recently played.”
- “You own this but have not played it in six months.”

Recommendations remain deterministic so the UI can show the evidence behind
each pick rather than presenting a black-box score.

## Current local signals

- **Rediscover:** a record has a logged play, but its latest valid play is at
  least 90 days old. Older last-play dates rank first.
- **Genre:** eligible records share genres with the user's most-played genres.
  Matching genre play counts determine the score.
- **Era:** eligible records come from the decade with the most logged plays.
- **Underplayed:** remaining records have zero to two logged plays and have not
  been played inside the 30-day suppression window.

Rediscover, genre, and era picks take priority in that order. Underplayed fills
from the remaining shelf. Each record appears at most once, and title then ID
break deterministic ties.

## Explanation evidence

The visible reason reports the data used by its rule: play count, exact and
relative last-play date, genre name and supporting play count, favorite-decade
play count, or the date an unplayed record was added. “No plays logged” does
not claim the owner has never listened to the record outside Groovefolio.

Current genre and era preferences use all-time play history. References to
recent listening remain future work until a separate recent-history signal is
actually implemented.
