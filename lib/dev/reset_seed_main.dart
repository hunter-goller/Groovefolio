import 'package:flutter/material.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/dev/dev_seed_artwork_source.dart';
import 'package:vinyl_app/dev/seed_collection.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _ResetSeedApp());
}

class _ResetSeedApp extends StatefulWidget {
  const _ResetSeedApp();

  @override
  State<_ResetSeedApp> createState() => _ResetSeedAppState();
}

class _ResetSeedAppState extends State<_ResetSeedApp> {
  DevSeedProgress? _progress;
  DevSeedResult? _result;
  Object? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_runResetAndSeed);
  }

  Future<void> _runResetAndSeed() async {
    final db = AppDatabase();
    final artworkSource = MusicBrainzDevSeedArtworkSource();

    try {
      final result = await resetAndSeedCollectionForDev(
        db,
        artworkSource: artworkSource,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _progress = progress);
        },
      );
      if (!mounted) return;
      setState(() => _result = result);
    } catch (error, stackTrace) {
      debugPrint('Development reset/seed failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      await artworkSource.close();
      await db.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(padding: const EdgeInsets.all(32), child: _body()),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    final error = _error;
    if (error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 72),
          const SizedBox(height: 24),
          const Text(
            'Reset / seed failed',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SelectableText(error.toString(), textAlign: TextAlign.center),
        ],
      );
    }

    final result = _result;
    if (result != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, size: 72),
          const SizedBox(height: 24),
          const Text(
            'Fresh Groovefolio dev data ready',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            '${result.removedAlbums} old albums removed\n'
            '${result.createdAlbums} albums created\n'
            '${result.createdPlays} plays created\n'
            '${result.downloadedArtwork} covers downloaded\n'
            '${result.missingArtwork} covers unavailable',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const Text(
            'Stop this run, then launch the normal app with "flutter run". '
            'The fresh database and downloaded artwork will remain on-device.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    final progress = _progress;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 24),
        Text(
          progress?.stage ?? 'Starting dev reset…',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (progress != null && progress.totalAlbums > 0) ...[
          LinearProgressIndicator(value: progress.fraction),
          const SizedBox(height: 12),
          Text('${progress.completedAlbums} / ${progress.totalAlbums} albums'),
          if (progress.currentAlbum != null) ...[
            const SizedBox(height: 8),
            Text(progress.currentAlbum!, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 8),
          Text(
            '${progress.downloadedArtwork} covers downloaded • '
            '${progress.missingArtwork} unavailable',
          ),
        ],
        const SizedBox(height: 20),
        const Text(
          'Cover lookup uses MusicBrainz and Cover Art Archive. '
          'The reset intentionally rate-limits metadata requests, so the first '
          'run takes about a minute or more.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
