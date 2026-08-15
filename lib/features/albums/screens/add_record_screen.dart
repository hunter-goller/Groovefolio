import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/providers/album_providers.dart';
import 'package:vinyl_app/providers/genre_providers.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';
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
  bool _isSubmitting = false;

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

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final artist = await ref
          .read(artistRepositoryProvider)
          .findOrCreate(_artistController.text);
      final yearText = _yearController.text.trim();
      final labelText = _labelController.text.trim();
      final album = await ref
          .read(albumMutationsProvider.notifier)
          .create(
            title: _titleController.text,
            artistId: artist.id,
            releaseYear: yearText.isEmpty ? null : int.parse(yearText),
            label: labelText.isEmpty ? null : labelText,
          );

      if (_selectedGenres.isNotEmpty) {
        final genreRepository = ref.read(genreRepositoryProvider);
        final genreIds = <String>[];
        for (final name in _selectedGenres) {
          genreIds.add((await genreRepository.findOrCreate(name)).id);
        }
        await genreRepository.setAlbumGenres(album.id, genreIds);
        ref.invalidate(genresProvider);
        ref.invalidate(albumGenresProvider(album.id));
      }

      if (!mounted) return;
      context.go(AppRoutes.collection);
    } catch (error) {
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
                    _ArtworkPlaceholder(enabled: !isSaving),
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
                _DeferredDiscogsBanner(),
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

class _ArtworkPlaceholder extends StatelessWidget {
  const _ArtworkPlaceholder({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return SizedBox(
      width: 102,
      height: 132,
      child: OutlinedButton(
        onPressed: enabled
            ? () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Artwork picker is coming soon.')),
              )
            : null,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.all(8),
          side: BorderSide(
            color: tokens.textMuted.withValues(alpha: 0.35),
            style: BorderStyle.solid,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radiusMedium),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, color: tokens.textMuted),
            const SizedBox(height: 8),
            Text(
              'Add art',
              style: context.theme.textTheme.labelMedium?.copyWith(
                color: tokens.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeferredDiscogsBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF123B2C),
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
        border: Border.all(
          color: const Color(0xFF2F8B63).withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              color: Color(0xFF4BD095),
              size: 19,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Search Discogs to autofill →',
                style: context.theme.textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF4BD095),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
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
