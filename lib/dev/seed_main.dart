import 'package:flutter/material.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/dev/seed_collection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase();

  try {
    final result = await seedCollectionForDev(db);
    await db.close();

    runApp(_SeedResultApp(result: result));
  } catch (error, stackTrace) {
    await db.close();
    debugPrint('Development seed failed: $error');
    debugPrintStack(stackTrace: stackTrace);

    runApp(_SeedFailureApp(error: error));
  }
}

class _SeedResultApp extends StatelessWidget {
  const _SeedResultApp({required this.result});

  final DevSeedResult result;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline, size: 72),
                  const SizedBox(height: 24),
                  const Text(
                    'Groovefolio dev data seeded',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${result.createdAlbums} albums created\n'
                    '${result.reusedAlbums} albums reused\n'
                    '${result.createdPlays} plays created',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Stop this run, then launch the normal app with '
                    '"flutter run". The seeded data will remain in the '
                    'same on-device database.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SeedFailureApp extends StatelessWidget {
  const _SeedFailureApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 72),
                  const SizedBox(height: 24),
                  const Text(
                    'Seeding failed',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SelectableText(error.toString(), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
