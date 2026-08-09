import 'package:drift/drift.dart';

/// Creates the complete schema for a brand-new v1 database.
///
/// Version 1 contains the artists, albums, and plays tables registered on
/// AppDatabase. Future schema upgrades should be added as separate migration
/// steps rather than changing this function after v1 has shipped.
Future<void> migrateToV1(Migrator migrator) async {
  await migrator.createAll();
}
