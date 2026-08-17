/// Schema version numbers for the Groovefolio database.
///
/// Keep these constants stable once a version has shipped. Add a new constant
/// for every physical schema change and point [current] at the newest version.
abstract final class SchemaVersions {
  static const int v1 = 1;
  static const int v2 = 2;
  static const int v3 = 3;

  static const int current = v3;
}
