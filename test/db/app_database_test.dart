import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';

void main() {
  test('AppDatabase opens and executes a query without error', () async {
    // NativeDatabase.memory() — an in-memory SQLite instance, not the
    // real file. Fast, parallel-test-safe, and leaves nothing behind.
    final db = AppDatabase(NativeDatabase.memory());

    final result = await db.customSelect('SELECT 1 AS value').getSingle();

    expect(result.read<int>('value'), equals(1));

    await db.close();
  });
}
