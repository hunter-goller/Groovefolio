import 'package:flutter/material.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';

/// One choice in the Collection genre filter.
class GenreFilterOption {
  const GenreFilterOption(this.name, this.count);

  final String name;

  /// Records in the collection with this genre.
  final int count;
}

/// The genres worth offering as a filter: those used by at least one record
/// in [albumIds], most-used first, then by name. Names match ignoring case.
/// [selected] stays in the list even if no record uses it any more, so the
/// current filter can always be seen and cleared.
List<GenreFilterOption> rankGenreFilterOptions({
  required List<Genre> genres,
  required Map<String, List<Genre>> genresByAlbum,
  required Iterable<String> albumIds,
  String? selected,
}) {
  final counts = <String, int>{};
  for (final albumId in albumIds) {
    final seen = <String>{};
    for (final genre in genresByAlbum[albumId] ?? const <Genre>[]) {
      final key = genre.name.trim().toLowerCase();
      if (key.isNotEmpty && seen.add(key)) {
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
  }

  final selectedKey = selected?.trim().toLowerCase();
  final byKey = <String, GenreFilterOption>{};
  for (final genre in genres) {
    final key = genre.name.trim().toLowerCase();
    if (key.isEmpty || byKey.containsKey(key)) continue;
    final count = counts[key] ?? 0;
    if (count == 0 && key != selectedKey) continue;
    byKey[key] = GenreFilterOption(genre.name.trim(), count);
  }

  return byKey.values.toList()..sort((a, b) {
    final byCount = b.count.compareTo(a.count);
    if (byCount != 0) return byCount;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
}

/// Bottom sheet body for picking a genre filter. Pops with the chosen genre
/// name, or an empty string for "All genres".
class GenreFilterSheet extends StatefulWidget {
  const GenreFilterSheet({
    required this.options,
    required this.totalRecords,
    this.selected,
    super.key,
  });

  final List<GenreFilterOption> options;
  final int totalRecords;
  final String? selected;

  /// Shorter lists are easy to scan, so they get no search box.
  static const searchThreshold = 8;

  @override
  State<GenreFilterSheet> createState() => _GenreFilterSheetState();
}

class _GenreFilterSheetState extends State<GenreFilterSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _isSelected(String name) =>
      widget.selected?.toLowerCase() == name.toLowerCase();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.theme.textTheme;
    final query = _search.text.trim().toLowerCase();
    final showSearch = widget.options.length > GenreFilterSheet.searchThreshold;
    final matches = [
      for (final option in widget.options)
        if (query.isEmpty || option.name.toLowerCase().contains(query)) option,
    ];

    Widget chip({
      required Key key,
      required String label,
      required int count,
      required bool selected,
      required String result,
    }) => ChoiceChip(
      key: key,
      selected: selected,
      onSelected: (_) => Navigator.of(context).pop(result),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          SizedBox(width: tokens.space8),
          Text(
            '$count',
            style: text.labelSmall?.copyWith(
              color: selected ? null : tokens.textMuted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.space16,
            0,
            tokens.space16,
            tokens.space24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Filter by genre',
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (showSearch) ...[
                SizedBox(height: tokens.space12),
                TextField(
                  key: const Key('collection-genre-filter-search'),
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search genres',
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => setState(_search.clear),
                          ),
                  ),
                ),
              ],
              SizedBox(height: tokens.space12),
              Flexible(
                child: SingleChildScrollView(
                  key: const Key('collection-genre-filter-scroll'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (query.isEmpty && widget.options.isNotEmpty) ...[
                        Text(
                          'Most used first. Numbers are record counts.',
                          style: text.bodySmall?.copyWith(
                            color: tokens.textMuted,
                          ),
                        ),
                        SizedBox(height: tokens.space8),
                      ],
                      Wrap(
                        spacing: tokens.space8,
                        runSpacing: tokens.space8,
                        children: [
                          if (query.isEmpty)
                            chip(
                              key: const Key('collection-genre-all'),
                              label: 'All genres',
                              count: widget.totalRecords,
                              selected: widget.selected == null,
                              result: '',
                            ),
                          for (final option in matches)
                            chip(
                              key: ValueKey('collection-genre-${option.name}'),
                              label: option.name,
                              count: option.count,
                              selected: _isSelected(option.name),
                              result: option.name,
                            ),
                          if (matches.isEmpty)
                            Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: tokens.space8,
                              ),
                              child: Text(
                                widget.options.isEmpty
                                    ? 'None of your records have a genre yet. '
                                          'Add genres when you edit a record.'
                                    : 'No genres match “${_search.text.trim()}”.',
                                style: text.bodyMedium?.copyWith(
                                  color: tokens.textMuted,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
