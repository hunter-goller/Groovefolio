/// Which side of a record was played during a listening session.
/// Used by the Plays table (Drift) and by UI later (e.g. the
/// SideSelector widget on Log Play) — kept here rather than inside
/// plays.dart so UI code doesn't need to import Drift schema just
/// for this enum.
enum SidePlayed { full, sideA, sideB }
