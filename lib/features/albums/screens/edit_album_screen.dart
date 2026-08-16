import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/providers/album_providers.dart';
import 'package:vinyl_app/providers/genre_providers.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';
import 'package:vinyl_app/widgets/shared/genre_chip_input.dart';
import 'package:vinyl_app/widgets/ui/empty_state.dart';
import 'package:vinyl_app/widgets/ui/labeled_text_field.dart';
import 'package:vinyl_app/widgets/ui/primary_button.dart';

class EditAlbumScreen extends ConsumerStatefulWidget {
  const EditAlbumScreen({required this.albumId, super.key});

  final String albumId;

  @override
  ConsumerState<EditAlbumScreen> createState() => _EditAlbumScreenState();
}

class _EditAlbumScreenState extends ConsumerState<EditAlbumScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _artistController;
  late final TextEditingController _yearController;
  late final TextEditingController _labelController;

  Album? _loadedAlbum;
  List<String> _selectedGenres = const [];
  bool _initialized = false;
  bool _isSubmitting = false;
  bool _rewriteNfc = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _artistController = TextEditingController();
    _yearController = TextEditingController();
    _labelController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _yearController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  void _initialize(AlbumDetailData detail, List<Genre> genres) {
    if (_initialized) return;
    _loadedAlbum = detail.album;
    _titleController.text = detail.album.title;
    _artistController.text = detail.artist.name;
    _yearController.text = detail.album.releaseYear?.toString() ?? '';
    _labelController.text = detail.album.label ?? '';
    _selectedGenres = genres.map((genre) => genre.name).toList(growable: false);
    _initialized = true;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final existing = _loadedAlbum;
    if (existing == null) return;

    setState(() => _isSubmitting = true);
    try {
      final artist = await ref
          .read(artistRepositoryProvider)
          .findOrCreate(_artistController.text);

      final yearText = _yearController.text.trim();
      final labelText = _labelController.text.trim();

      final updatedAlbum = Album(
        id: existing.id,
        title: _titleController.text.trim(),
        artistId: artist.id,
        releaseYear: yearText.isEmpty ? null : int.parse(yearText),
        label: labelText.isEmpty ? null : labelText,
        artworkPath: existing.artworkPath,
        purchaseDate: existing.purchaseDate,
        purchasePriceCents: existing.purchasePriceCents,
        createdAt: existing.createdAt,
      );

      final updated = await ref
          .read(albumMutationsProvider.notifier)
          .update(updatedAlbum);
      if (!updated) {
        throw StateError('Record could not be updated.');
      }

      final genreRepository = ref.read(genreRepositoryProvider);
      final genreIds = <String>[];
      for (final name in _selectedGenres) {
        genreIds.add((await genreRepository.findOrCreate(name)).id);
      }
      await genreRepository.setAlbumGenres(existing.id, genreIds);

      ref.invalidate(genresProvider);
      ref.invalidate(albumGenresProvider(existing.id));
      ref.invalidate(albumDetailProvider(existing.id));
      ref.invalidate(albumProvider(existing.id));
      ref.invalidate(albumsProvider);

      if (!mounted) return;
      context.go(AppRoutes.albumDetailPath(existing.id));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Couldn’t save changes: $error')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(albumDetailProvider(widget.albumId));
    final genresAsync = ref.watch(albumGenresProvider(widget.albumId));
    final allGenresAsync = ref.watch(genresProvider);
    final nfcAsync = ref.watch(_albumNfcProvider(widget.albumId));
    final mutationState = ref.watch(albumMutationsProvider);
    final isSaving = mutationState.isLoading || _isSubmitting;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit record'),
        actions: [
          TextButton(
            onPressed: isSaving || !_initialized ? null : _save,
            child: const Text('Save'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: detailAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _LoadError(
            onRetry: () => ref.invalidate(albumDetailProvider(widget.albumId)),
          ),
          data: (detail) {
            if (detail == null) {
              return EmptyState(
                icon: Icons.album_outlined,
                title: 'Record not found',
                subtitle:
                    'This record may have been removed from your collection.',
                ctaLabel: 'Back to collection',
                onCtaTap: () => context.go(AppRoutes.collection),
              );
            }

            final assignedGenres = genresAsync.value ?? const <Genre>[];
            _initialize(detail, assignedGenres);
            final suggestions =
                allGenresAsync.value
                    ?.map((genre) => genre.name)
                    .toList(growable: false) ??
                const <String>[];

            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  context.tokens.space16,
                  context.tokens.space8,
                  context.tokens.space16,
                  context.tokens.space32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ArtworkPreview(path: detail.album.artworkPath),
                        SizedBox(width: context.tokens.space12),
                        Expanded(
                          child: Column(
                            children: [
                              LabeledTextField(
                                key: const Key('edit-record-title'),
                                label: 'TITLE *',
                                controller: _titleController,
                                enabled: !isSaving,
                                textInputAction: TextInputAction.next,
                                validator: _requiredValidator('Title'),
                              ),
                              SizedBox(height: context.tokens.space12),
                              LabeledTextField(
                                key: const Key('edit-record-artist'),
                                label: 'ARTIST *',
                                controller: _artistController,
                                enabled: !isSaving,
                                textInputAction: TextInputAction.next,
                                validator: _requiredValidator('Artist'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.tokens.space16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: LabeledTextField(
                            key: const Key('edit-record-year'),
                            label: 'YEAR',
                            controller: _yearController,
                            enabled: !isSaving,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            validator: _yearValidator,
                          ),
                        ),
                        SizedBox(width: context.tokens.space12),
                        Expanded(
                          child: LabeledTextField(
                            key: const Key('edit-record-label'),
                            label: 'LABEL',
                            controller: _labelController,
                            enabled: !isSaving,
                            textInputAction: TextInputAction.done,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.tokens.space16),
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GENRE',
                            style: context.theme.textTheme.labelSmall?.copyWith(
                              color: context.tokens.textMuted,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                          SizedBox(height: context.tokens.space8),
                          IgnorePointer(
                            ignoring: isSaving,
                            child: Opacity(
                              opacity: isSaving ? 0.55 : 1,
                              child: GenreChipInput(
                                key: const Key('edit-record-genres'),
                                genres: _selectedGenres,
                                suggestions: suggestions,
                                onChanged: (genres) =>
                                    setState(() => _selectedGenres = genres),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (nfcAsync.value != null) ...[
                      SizedBox(height: context.tokens.space16),
                      _SectionCard(
                        child: SwitchListTile.adaptive(
                          key: const Key('edit-record-rewrite-nfc'),
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Rewrite NFC tag'),
                          subtitle: const Text(
                            'NFC writing will use this option once tag writing '
                            'is enabled.',
                          ),
                          value: _rewriteNfc,
                          onChanged: isSaving
                              ? null
                              : (value) => setState(() => _rewriteNfc = value),
                        ),
                      ),
                    ],
                    SizedBox(height: context.tokens.space24),
                    PrimaryButton(
                      key: const Key('edit-record-save'),
                      label: 'Save changes',
                      icon: Icons.save_outlined,
                      isLoading: isSaving,
                      onPressed: isSaving ? null : _save,
                    ),
                  ],
                ),
              ),
            );
          },
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

final _albumNfcProvider = FutureProvider.autoDispose.family<NfcTag?, String>((
  ref,
  albumId,
) {
  return ref.watch(nfcTagRepositoryProvider).findByAlbum(albumId);
});

class _ArtworkPreview extends StatelessWidget {
  const _ArtworkPreview({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final normalized = path?.trim();
    final hasArtwork = normalized != null && normalized.isNotEmpty;

    return Container(
      width: 102,
      height: 132,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
        border: Border.all(color: tokens.textMuted.withValues(alpha: 0.2)),
      ),
      child: hasArtwork
          ? Image.file(
              File(normalized),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const _ArtworkFallback(),
            )
          : const _ArtworkFallback(),
    );
  }
}

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback();

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.album_rounded, size: 42, color: context.tokens.textMuted);
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      color: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
        side: BorderSide(color: tokens.textMuted.withValues(alpha: 0.16)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: EdgeInsets.all(tokens.space12), child: child),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Try again'),
      ),
    );
  }
}
