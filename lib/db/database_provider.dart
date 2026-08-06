import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vinyl_app/db/app_database.dart';

part 'database_provider.g.dart';

/// Singleton database connection for the whole app lifetime.
///
/// keepAlive: true is the key difference from routerProvider — a plain
/// @riverpod provider auto-disposes when nothing is watching it, which
/// would close and silently reopen the SQLite connection. A database
/// should never do that, so this opts out of auto-dispose explicitly.
@Riverpod(keepAlive: true)
AppDatabase database(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}
