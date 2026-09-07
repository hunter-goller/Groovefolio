import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/providers/album_providers.dart';
import 'package:vinyl_app/services/nfc/nfc_play_logging_service.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';
import 'package:vinyl_app/widgets/shared/album_select_tile.dart';
import 'package:vinyl_app/widgets/ui/search_field.dart';

/// Debug-only entry point that exercises the NFC play pipeline without a tag.
///
/// The Settings screen only exposes this page when developer tools are
/// enabled. Choosing an album represents an already-resolved NFC tag and calls
/// [NfcPlayLoggingService.logResolvedAlbum] directly, just as the physical NFC
/// paths do after resolution.
class FakeNfcTapScreen extends ConsumerStatefulWidget {
  const FakeNfcTapScreen({super.key});

  @override
  ConsumerState<FakeNfcTapScreen> createState() => _FakeNfcTapScreenState();
}

class _FakeNfcTapScreenState extends ConsumerState<FakeNfcTapScreen> {
  late final TextEditingController _searchController;
  Timer? _searchDebounce;
  String _query = '';
  String? _loggingAlbumId;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _scheduleSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _query = value.trim());
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    setState(() => _query = '');
  }

  Future<void> _simulateTap(CollectionAlbum album) async {
    if (_loggingAlbumId != null) return;

    setState(() => _loggingAlbumId = album.id);
    try {
      final result = await ref
          .read(nfcPlayLoggingServiceProvider)
          .logResolvedAlbum(album.id);

      if (!result.suppressed) {
        ref.invalidate(albumsProvider);
        ref.invalidate(recentlyPlayedProvider);
        ref.invalidate(playCountProvider(album.id));
        ref.invalidate(albumDetailProvider(album.id));
        ref.invalidate(albumSearchProvider(_query));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              result.suppressed
                  ? '${album.title} is already logged.'
                  : 'Play logged: ${album.title}',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn’t simulate NFC tap: $error')),
      );
    } finally {
      if (mounted) setState(() => _loggingAlbumId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final albumsAsync = ref.watch(albumSearchProvider(_query));

    return Scaffold(
      appBar: AppBar(title: const Text('Test NFC tap')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            tokens.space16,
            tokens.space16,
            tokens.space16,
            tokens.space32,
          ),
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(tokens.space16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.developer_mode_rounded,
                      color: context.theme.colorScheme.primary,
                    ),
                    SizedBox(width: tokens.space12),
                    Expanded(
                      child: Text(
                        'Software-only test. Choosing a record simulates a '
                        'resolved NFC tag and immediately logs a full play.',
                        style: context.theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: tokens.space16),
            SearchField(
              key: const Key('fake-nfc-search'),
              controller: _searchController,
              hint: 'Search by record or artist…',
              onChanged: _scheduleSearch,
              onClear: _clearSearch,
            ),
            SizedBox(height: tokens.space16),
            if (_loggingAlbumId != null) const LinearProgressIndicator(),
            if (_loggingAlbumId != null) SizedBox(height: tokens.space12),
            albumsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => _LoadError(
                onRetry: () => ref.invalidate(albumSearchProvider(_query)),
              ),
              data: (albums) => _AlbumResults(
                albums: albums,
                query: _query,
                loggingAlbumId: _loggingAlbumId,
                onSelected: _simulateTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumResults extends StatelessWidget {
  const _AlbumResults({
    required this.albums,
    required this.query,
    required this.loggingAlbumId,
    required this.onSelected,
  });

  final List<CollectionAlbum> albums;
  final String query;
  final String? loggingAlbumId;
  final ValueChanged<CollectionAlbum> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (albums.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.space16),
        child: Text(
          query.isEmpty
              ? 'Your collection is empty. Add a record before testing NFC.'
              : 'No records match “$query”.',
          style: context.theme.textTheme.bodyMedium?.copyWith(
            color: tokens.textMuted,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          query.isEmpty ? 'Choose a record' : 'Search results',
          style: context.theme.textTheme.labelLarge?.copyWith(
            color: tokens.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: tokens.space8),
        for (var index = 0; index < albums.length; index++) ...[
          AlbumSelectTile(
            key: Key('fake-nfc-album-${albums[index].id}'),
            title: albums[index].title,
            artist: albums[index].artistName,
            releaseYear: albums[index].album.releaseYear,
            artworkPath: albums[index].album.artworkPath,
            playCount: albums[index].playCount,
            isSelected: loggingAlbumId == albums[index].id,
            onTap: () => onSelected(albums[index]),
          ),
          if (index != albums.length - 1) SizedBox(height: tokens.space8),
        ],
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Text('Couldn’t load your collection.')),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}
