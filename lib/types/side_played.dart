/// Which side of a record was played during a listening session.
/// Shared by Drift persistence and the current Log Play UI. Keeping this
/// enum outside the schema avoids a Drift import in presentation code.
enum SidePlayed { full, sideA, sideB }
