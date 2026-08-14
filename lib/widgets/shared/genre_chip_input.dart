import 'package:flutter/material.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';
import 'package:vinyl_app/widgets/shared/genre_chip.dart';

/// Multi-value genre input composed of removable [GenreChip]s plus an add
/// action that opens a lightweight picker dialog.
///
/// This widget deliberately owns no persistence. Callers may provide
/// [suggestions] from any source and receive the updated selected genre names
/// through [onChanged].
class GenreChipInput extends StatelessWidget {
  const GenreChipInput({
    required this.genres,
    required this.onChanged,
    this.suggestions = const <String>[],
    super.key,
  });

  final List<String> genres;
  final ValueChanged<List<String>> onChanged;
  final List<String> suggestions;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Wrap(
      spacing: tokens.space8,
      runSpacing: tokens.space8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final genre in genres)
          GenreChip(
            genre: genre,
            removable: true,
            onRemove: () => _removeGenre(genre),
          ),
        ActionChip(
          key: const Key('genre-add-chip'),
          avatar: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Add genre'),
          onPressed: () => _openPicker(context),
          side: BorderSide(color: tokens.textMuted.withValues(alpha: 0.28)),
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          labelStyle: context.theme.textTheme.labelMedium?.copyWith(
            color: tokens.textMuted,
            fontWeight: FontWeight.w500,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  void _removeGenre(String genre) {
    onChanged(
      genres.where((candidate) => candidate != genre).toList(growable: false),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final genre = await showDialog<String>(
      context: context,
      builder: (context) =>
          _GenrePickerDialog(selectedGenres: genres, suggestions: suggestions),
    );

    if (genre == null) {
      return;
    }

    final normalized = genre.trim();
    if (normalized.isEmpty || _containsGenre(genres, normalized)) {
      return;
    }

    onChanged([...genres, normalized]);
  }

  static bool _containsGenre(Iterable<String> genres, String candidate) {
    final normalizedCandidate = candidate.trim().toLowerCase();
    return genres.any(
      (genre) => genre.trim().toLowerCase() == normalizedCandidate,
    );
  }
}

class _GenrePickerDialog extends StatefulWidget {
  const _GenrePickerDialog({
    required this.selectedGenres,
    required this.suggestions,
  });

  final List<String> selectedGenres;
  final List<String> suggestions;

  @override
  State<_GenrePickerDialog> createState() => _GenrePickerDialogState();
}

class _GenrePickerDialogState extends State<_GenrePickerDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final query = _controller.text.trim().toLowerCase();
    final availableSuggestions =
        widget.suggestions
            .map((genre) => genre.trim())
            .where((genre) => genre.isNotEmpty)
            .where((genre) => !_containsSelected(genre))
            .where(
              (genre) => query.isEmpty || genre.toLowerCase().contains(query),
            )
            .toSet()
            .toList(growable: false)
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final enteredGenre = _controller.text.trim();
    final canAddEntered =
        enteredGenre.isNotEmpty &&
        !_containsSelected(enteredGenre) &&
        !availableSuggestions.any(
          (genre) => genre.toLowerCase() == enteredGenre.toLowerCase(),
        );

    return AlertDialog(
      scrollable: true,
      title: const Text('Add genre'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('genre-picker-field'),
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: 'Search or enter a genre',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (canAddEntered) {
                  Navigator.of(context).pop(enteredGenre);
                }
              },
            ),
            if (availableSuggestions.isNotEmpty || canAddEntered) ...[
              SizedBox(height: tokens.space12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: tokens.space8,
                    runSpacing: tokens.space8,
                    children: [
                      if (canAddEntered)
                        ActionChip(
                          key: const Key('genre-create-chip'),
                          avatar: const Icon(Icons.add_rounded, size: 16),
                          label: Text(enteredGenre),
                          onPressed: () =>
                              Navigator.of(context).pop(enteredGenre),
                        ),
                      for (final genre in availableSuggestions)
                        ActionChip(
                          label: Text(genre),
                          onPressed: () => Navigator.of(context).pop(genre),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  bool _containsSelected(String candidate) {
    final normalizedCandidate = candidate.trim().toLowerCase();
    return widget.selectedGenres.any(
      (genre) => genre.trim().toLowerCase() == normalizedCandidate,
    );
  }
}
