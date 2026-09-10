# Discover

Discover is an offline, personalized view of the records already in the local
collection. Its recommendation service evaluates logged play history and keeps
ranking logic out of the widgets.

The screen contains:

- a taste profile with all-time genres, recent genres, favorite-artist
  signals, and the most-played release era
- **Rediscover your shelf** for records whose last valid play is at least 90
  days old
- **From your taste** for records matching recent/all-time genres and artists
- **From your favorite era** for additional picks from the leading decade
- **Give these a spin** for eligible records with zero to two logged plays

Recently played records are suppressed for 30 days, every record appears at
most once, and all tie breaking is deterministic. A card opens Album Details.
Its separate **Why this record?** action opens a bottom sheet with the complete
local evidence used for that suggestion and states that no external
recommendation server was involved.

External suggestions for records the user does not own remain separate work in
VinylApp-117.
# VinylApp-129: shelf discovery polish

The **Give these a spin** section supplies owned-album suggestions even with no
play history or genre/year metadata. Existing rediscover, genre, and era picks
take priority; this section never repeats their albums.

Eligible records have zero to two logged plays and no play inside the configured
recent-suppression window (30 days by default). Future-dated plays are suppressed;
records with logged plays but no parseable last-play date are excluded. Sort by
play count ascending, then title and album ID, with the existing section limit.
Zero plays means no plays **logged**, not proof the record was never listened to.

Cards label their explanation **Why this record?** and expose the local signals
that selected it. Rediscovery includes total logged plays and time since the last
play. Genre and era picks include the number of plays supporting that preference
plus the candidate's own play history. An unplayed pick includes its added date
when `createdAt` is valid. The wording always says “logged” because Groovefolio
cannot know about listening that was never entered.

The taste summary explicitly uses all-time history. Everything remains offline,
and card taps only navigate to Album Details. External discovery stays in
VinylApp-117.
