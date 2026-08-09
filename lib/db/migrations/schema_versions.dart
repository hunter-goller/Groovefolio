/// Schema version numbers for the Vinyl App database.
///
/// Keep these constants stable once a version has shipped. When a future
/// schema version is introduced, add a new constant and point [current] at it.
///
/// Drift's generated step-by-step migration helper should be generated to a
/// separate file (for example `app_database.steps.dart`) so this version list
/// remains small and readable.
abstract final class SchemaVersions {
  static const int v1 = 1;

  static const int current = v1;
}
