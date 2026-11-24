/// The key two artist or genre names are compared by.
///
/// Trims, collapses runs of whitespace and lower-cases with Dart's full
/// Unicode rules, so "BJÖRK" and "Björk" match. SQLite's `lower()` only
/// handles A–Z, so name matching must not happen in SQL. Accents are kept:
/// "Bjork" and "Björk" stay different names.
String nameMatchKey(String name) =>
    name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
