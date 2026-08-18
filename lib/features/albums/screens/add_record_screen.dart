import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/providers/album_providers.dart';
import 'package:vinyl_app/providers/genre_providers.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/repositories/discogs_release_link_repository.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/services/artwork_storage_service.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';
import 'package:vinyl_app/services/discogs/discogs_providers.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';
import 'package:vinyl_app/widgets/shared/artwork_picker.dart';
import 'package:vinyl_app/widgets/shared/discogs_banner.dart';
import 'package:vinyl_app/widgets/shared/genre_chip_input.dart';
import 'package:vinyl_app/widgets/ui/labeled_text_field.dart';
import 'package:vinyl_app/widgets/ui/primary_button.dart';

/// Manual record creation flow aligned with the approved compact mockup.
class AddRecordScreen extends ConsumerStatefulWidget {
  const AddRecordScreen({super.key});

  @override
  ConsumerState<AddRecordScreen> createState() => _AddRecordScreenState();
}

class _AddRecordScreenState extends ConsumerState<AddRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _artistController;
  late final TextEditingController _yearController;
  late final TextEditingController _labelController;
  List<String> _selectedGenres = const [];
  File? _selectedArtwork;
  File? _discogsTempArtwork;
  int? _selectedDiscogsReleaseId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _artistController = TextEditingController();
    _yearController = TextEditingController();
    _labelController = TextEditingController();
    _titleController.addListener(_refreshDiscogsPrefill);
    _artistController.addListener(_refreshDiscogsPrefill);
  }

  void _refreshDiscogsPrefill() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _titleController.removeListener(_refreshDiscogsPrefill);
    _artistController.removeListener(_refreshDiscogsPrefill);
    _titleController.dispose();
    _artistController.dispose();
    _yearController.dispose();
    _labelController.dispose();
    final tempArtwork = _discogsTempArtwork;
    if (tempArtwork != null && tempArtwork.existsSync()) {
      tempArtwork.deleteSync();
    }
    super.dispose();
  }

  Future<void> _pickArtwork() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
        maxWidth: 1600,
      );
      if (picked == null || !mounted) return;
      await _deleteDiscogsTempArtwork();
      setState(() => _selectedArtwork = File(picked.path));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn’t choose artwork: $error')),
      );
    }
  }

  Future<void> _openDiscogsSearch() async {
    FocusScope.of(context).unfocus();
    final credentials = await ref
        .read(discogsCredentialStoreProvider)
        .readCredentials();
    if (!mounted) return;
    if (credentials == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Connect Discogs in Settings to search releases.',
          ),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ),
      );
      return;
    }

    final details = await showModalBottomSheet<DiscogsReleaseDetails>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _DiscogsSearchSheet(
        initialArtist: _artistController.text,
        initialTitle: _titleController.text,
      ),
    );
    if (details == null || !mounted) return;
    await _applyDiscogsRelease(details);
  }

  Future<void> _applyDiscogsRelease(DiscogsReleaseDetails details) async {
    File? downloadedArtwork;
    if (details.artworkUrl != null) {
      try {
        final bytes = await ref
            .read(discogsCatalogServiceProvider)
            .downloadArtwork(details.artworkUrl!);
        final file = File(
          '${Directory.systemTemp.path}/groovefolio-discogs-${details.releaseId}.jpg',
        );
        await file.writeAsBytes(bytes, flush: true);
        downloadedArtwork = file;
      } on DiscogsFailure catch (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Metadata applied, but artwork could not be downloaded: ${failure.message}',
              ),
            ),
          );
        }
      }
    }

    await _deleteDiscogsTempArtwork();
    if (!mounted) return;
    setState(() {
      _titleController.text = details.title;
      _artistController.text = details.artist;
      _yearController.text = details.year?.toString() ?? '';
      _labelController.text = details.label ?? '';
      _selectedGenres = details.genreNames;
      _selectedDiscogsReleaseId = details.releaseId;
      if (downloadedArtwork != null) {
        _discogsTempArtwork = downloadedArtwork;
        _selectedArtwork = downloadedArtwork;
      }
    });
  }

  Future<void> _deleteDiscogsTempArtwork() async {
    final file = _discogsTempArtwork;
    _discogsTempArtwork = null;
    if (file != null && _selectedArtwork?.path == file.path) {
      _selectedArtwork = null;
    }
    if (file != null && await file.exists()) {
      await file.delete();
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    Album? createdAlbum;
    String? storedArtworkPath;
    try {
      final artist = await ref
          .read(artistRepositoryProvider)
          .findOrCreate(_artistController.text);
      final yearText = _yearController.text.trim();
      final labelText = _labelController.text.trim();
      createdAlbum = await ref
          .read(albumMutationsProvider.notifier)
          .create(
            title: _titleController.text,
            artistId: artist.id,
            releaseYear: yearText.isEmpty ? null : int.parse(yearText),
            label: labelText.isEmpty ? null : labelText,
          );

      final releaseId = _selectedDiscogsReleaseId;
      if (releaseId != null) {
        final links = ref.read(discogsReleaseLinkRepositoryProvider);
        final existingAlbumId = await links.findAlbumIdForRelease(releaseId);
        if (existingAlbumId != null && existingAlbumId != createdAlbum.id) {
          throw StateError(
            'That exact Discogs release is already linked to another record in your collection.',
          );
        }
        await links.link(albumId: createdAlbum.id, releaseId: releaseId);
      }

      if (_selectedArtwork != null) {
        storedArtworkPath = await ref
            .read(artworkStorageServiceProvider)
            .saveArtwork(_selectedArtwork!, createdAlbum.id);
        final albumWithArtwork = Album(
          id: createdAlbum.id,
          title: createdAlbum.title,
          artistId: createdAlbum.artistId,
          releaseYear: createdAlbum.releaseYear,
          label: createdAlbum.label,
          artworkPath: storedArtworkPath,
          purchaseDate: createdAlbum.purchaseDate,
          purchasePriceCents: createdAlbum.purchasePriceCents,
          createdAt: createdAlbum.createdAt,
        );
        final updated = await ref
            .read(albumMutationsProvider.notifier)
            .update(albumWithArtwork);
        if (!updated) {
          throw StateError('Artwork could not be linked to the record.');
        }
      }

      if (_selectedGenres.isNotEmpty) {
        final genreRepository = ref.read(genreRepositoryProvider);
        final genreIds = <String>[];
        for (final name in _selectedGenres) {
          genreIds.add((await genreRepository.findOrCreate(name)).id);
        }
        await genreRepository.setAlbumGenres(createdAlbum.id, genreIds);
        ref.invalidate(genresProvider);
        ref.invalidate(albumGenresProvider(createdAlbum.id));
      }

      await _deleteDiscogsTempArtwork();
      if (!mounted) return;
      context.go(AppRoutes.collection);
    } catch (error) {
      if (storedArtworkPath != null) {
        await ref
            .read(artworkStorageServiceProvider)
            .deleteArtwork(storedArtworkPath);
      }
      if (createdAlbum != null) {
        try {
          await ref
              .read(albumMutationsProvider.notifier)
              .delete(createdAlbum.id);
        } catch (_) {
          // Preserve the original failure; cleanup is best-effort.
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Couldn’t add record: $error')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final mutationState = ref.watch(albumMutationsProvider);
    final genresState = ref.watch(genresProvider);
    final isSaving = mutationState.isLoading || _isSubmitting;
    final genreSuggestions =
        genresState.value?.map((genre) => genre.name).toList(growable: false) ??
        const <String>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add a record'),
        actions: [
          TextButton(
            onPressed: isSaving ? null : _save,
            child: const Text('Save'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              tokens.space16,
              tokens.space8,
              tokens.space16,
              tokens.space32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ArtworkPicker(
                      key: const Key('add-record-artwork'),
                      image: _selectedArtwork,
                      size: 102,
                      height: 132,
                      enabled: !isSaving,
                      onTap: _pickArtwork,
                    ),
                    SizedBox(width: tokens.space12),
                    Expanded(
                      child: Column(
                        children: [
                          LabeledTextField(
                            key: const Key('add-record-title'),
                            label: 'TITLE *',
                            controller: _titleController,
                            hint: 'Blue Train',
                            enabled: !isSaving,
                            textInputAction: TextInputAction.next,
                            validator: _requiredValidator('Title'),
                          ),
                          SizedBox(height: tokens.space12),
                          LabeledTextField(
                            key: const Key('add-record-artist'),
                            label: 'ARTIST *',
                            controller: _artistController,
                            hint: 'John Coltrane',
                            enabled: !isSaving,
                            textInputAction: TextInputAction.next,
                            validator: _requiredValidator('Artist'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.space16),
                DiscogsBanner(
                  prefillQuery: [
                    _artistController.text.trim(),
                    _titleController.text.trim(),
                  ].where((value) => value.isNotEmpty).join(' — '),
                  onTap: isSaving ? () {} : _openDiscogsSearch,
                ),
                SizedBox(height: tokens.space16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: LabeledTextField(
                        key: const Key('add-record-year'),
                        label: 'YEAR',
                        controller: _yearController,
                        hint: '1957',
                        enabled: !isSaving,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        validator: _yearValidator,
                      ),
                    ),
                    SizedBox(width: tokens.space12),
                    Expanded(
                      child: LabeledTextField(
                        key: const Key('add-record-label'),
                        label: 'LABEL',
                        controller: _labelController,
                        hint: 'Blue Note',
                        enabled: !isSaving,
                        textInputAction: TextInputAction.done,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.space16),
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GENRE',
                        style: context.theme.textTheme.labelSmall?.copyWith(
                          color: tokens.textMuted,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                      SizedBox(height: tokens.space8),
                      IgnorePointer(
                        ignoring: isSaving,
                        child: Opacity(
                          opacity: isSaving ? 0.55 : 1,
                          child: GenreChipInput(
                            key: const Key('add-record-genres'),
                            genres: _selectedGenres,
                            suggestions: genreSuggestions,
                            onChanged: (genres) =>
                                setState(() => _selectedGenres = genres),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: tokens.space24),
                PrimaryButton(
                  label: 'Add to collection',
                  icon: Icons.add_rounded,
                  isLoading: isSaving,
                  onPressed: isSaving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  FormFieldValidator<String> _requiredValidator(String fieldName) {
    return (value) =>
        value == null || value.trim().isEmpty ? '$fieldName is required' : null;
  }

  String? _yearValidator(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return null;
    final year = int.tryParse(normalized);
    if (year == null) return 'Enter a valid year';
    final maxYear = DateTime.now().year + 1;
    if (year < 1900 || year > maxYear) {
      return 'Enter a year from 1900 to $maxYear';
    }
    return null;
  }
}

class _DiscogsSearchSheet extends ConsumerStatefulWidget {
  const _DiscogsSearchSheet({
    required this.initialArtist,
    required this.initialTitle,
  });

  final String initialArtist;
  final String initialTitle;

  @override
  ConsumerState<_DiscogsSearchSheet> createState() =>
      _DiscogsSearchSheetState();
}

class _DiscogsSearchSheetState extends ConsumerState<_DiscogsSearchSheet> {
  late final TextEditingController _artistController;
  late final TextEditingController _titleController;
  List<DiscogsReleaseSearchResult> _results = const [];
  DiscogsFailure? _failure;
  bool _searching = false;
  bool _hasSearched = false;
  int? _loadingReleaseId;

  @override
  void initState() {
    super.initState();
    _artistController = TextEditingController(text: widget.initialArtist);
    _titleController = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _artistController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final artist = _artistController.text.trim();
    final title = _titleController.text.trim();
    if (artist.isEmpty && title.isEmpty) {
      setState(() {
        _failure = const DiscogsApiFailure(
          'Enter an artist or title to search Discogs.',
        );
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _failure = null;
    });
    try {
      final results = await ref
          .read(discogsCatalogServiceProvider)
          .searchReleases(artist: artist, title: title);
      if (!mounted) return;
      setState(() {
        _results = results;
        _hasSearched = true;
      });
    } on DiscogsFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _failure = failure;
        _results = const [];
        _hasSearched = true;
      });
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _select(DiscogsReleaseSearchResult result) async {
    setState(() {
      _loadingReleaseId = result.releaseId;
      _failure = null;
    });
    try {
      final details = await ref
          .read(discogsCatalogServiceProvider)
          .release(result.releaseId);
      if (!mounted) return;
      Navigator.of(context).pop(details);
    } on DiscogsFailure catch (failure) {
      if (!mounted) return;
      setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _loadingReleaseId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.only(
        left: tokens.space16,
        right: tokens.space16,
        top: tokens.space16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + tokens.space16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Search Discogs', style: context.theme.textTheme.headlineSmall),
          SizedBox(height: tokens.space4),
          Text(
            'Choose the exact release or pressing. Nothing is saved until you add the record.',
            style: context.theme.textTheme.bodySmall?.copyWith(
              color: tokens.textMuted,
            ),
          ),
          SizedBox(height: tokens.space16),
          TextField(
            key: const Key('discogs-search-artist'),
            controller: _artistController,
            decoration: const InputDecoration(labelText: 'Artist'),
            textInputAction: TextInputAction.next,
          ),
          SizedBox(height: tokens.space12),
          TextField(
            key: const Key('discogs-search-title'),
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title'),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
          ),
          SizedBox(height: tokens.space12),
          FilledButton.icon(
            key: const Key('discogs-search-submit'),
            onPressed: _searching ? null : _search,
            icon: _searching
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search_rounded),
            label: const Text('Search releases'),
          ),
          if (_failure != null) ...[
            SizedBox(height: tokens.space12),
            _DiscogsFailurePanel(failure: _failure!, onRetry: _search),
          ],
          if (!_searching &&
              _failure == null &&
              _results.isEmpty &&
              !_hasSearched) ...[
            SizedBox(height: tokens.space16),
            Text(
              'Search Discogs to see up to 5 matching releases.',
              textAlign: TextAlign.center,
              style: context.theme.textTheme.bodyMedium?.copyWith(
                color: tokens.textMuted,
              ),
            ),
          ],
          if (!_searching &&
              _failure == null &&
              _results.isEmpty &&
              _hasSearched) ...[
            SizedBox(height: tokens.space16),
            Text(
              'No matching Discogs releases found.',
              textAlign: TextAlign.center,
              style: context.theme.textTheme.bodyMedium?.copyWith(
                color: tokens.textMuted,
              ),
            ),
          ],
          if (_results.isNotEmpty) ...[
            SizedBox(height: tokens.space12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.42,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _results.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final result = _results[index];
                  final loading = _loadingReleaseId == result.releaseId;
                  return ListTile(
                    key: Key('discogs-result-${result.releaseId}'),
                    contentPadding: EdgeInsets.zero,
                    leading: _DiscogsCover(url: result.coverImageUrl),
                    title: Text(result.title, maxLines: 2),
                    subtitle: Text(
                      [
                        result.artist,
                        if (result.subtitleParts.isNotEmpty)
                          result.subtitleParts,
                      ].join('\n'),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: loading
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: _loadingReleaseId == null
                        ? () => _select(result)
                        : null,
                  );
                },
              ),
            ),
          ],
          SizedBox(height: tokens.space8),
          Text(
            'Metadata provided by Discogs.',
            textAlign: TextAlign.center,
            style: context.theme.textTheme.labelSmall?.copyWith(
              color: tokens.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscogsCover extends ConsumerStatefulWidget {
  const _DiscogsCover({required this.url});
  final String? url;

  @override
  ConsumerState<_DiscogsCover> createState() => _DiscogsCoverState();
}

class _DiscogsCoverState extends ConsumerState<_DiscogsCover> {
  Future<Uint8List>? _future;

  @override
  void initState() {
    super.initState();
    final url = widget.url;
    if (url != null && url.isNotEmpty) {
      _future = ref.read(discogsCatalogServiceProvider).downloadArtwork(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return SizedBox.square(
      dimension: 52,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
        child: _future == null
            ? _placeholder(context)
            : FutureBuilder<Uint8List>(
                future: _future,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return _placeholder(context);
                  return Image.memory(
                    snapshot.data!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _placeholder(context),
                  );
                },
              ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final tokens = context.tokens;
    return ColoredBox(
      color: tokens.surfaceElevated,
      child: Icon(Icons.album_outlined, color: tokens.textMuted),
    );
  }
}

class _DiscogsFailurePanel extends StatelessWidget {
  const _DiscogsFailurePanel({required this.failure, required this.onRetry});

  final DiscogsFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surfaceElevated,
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.space12),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: tokens.textMuted),
            SizedBox(width: tokens.space8),
            Expanded(child: Text(failure.message)),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
        border: Border.all(color: tokens.textMuted.withValues(alpha: 0.16)),
      ),
      child: Padding(padding: EdgeInsets.all(tokens.space12), child: child),
    );
  }
}
