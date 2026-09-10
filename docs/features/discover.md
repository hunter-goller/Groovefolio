# Discover

The Discover route exists, but the current screen is a placeholder.

Planned direction:
- rediscover records that have not been played recently
- recommendations based on genres, artists, listening history, recency, and future track/Discogs metadata
- explain why each album is recommended
- surface collection insights rather than generic streaming recommendations

Production recommendation logic should be a service/provider layer, not hard-coded widget logic.
# VinylApp-129: shelf discovery polish

The **Give these a spin** section supplies owned-album suggestions even with no
play history or genre/year metadata. Existing rediscover, genre, and era picks
take priority; this section never repeats their albums.

Eligible records have zero to two logged plays and no play inside the configured
recent-suppression window (30 days by default). Future-dated plays are suppressed;
records with logged plays but no parseable last-play date are excluded. Sort by
play count ascending, then title and album ID, with the existing section limit.
Zero plays means no plays **logged**, not proof the record was never listened to.

Cards label their explanation **Why this record?**. The taste summary explicitly
uses all-time history. Everything remains offline, and card taps only navigate
to Album Details. External discovery stays in VinylApp-117.
