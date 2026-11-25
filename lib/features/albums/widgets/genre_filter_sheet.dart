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
/// name, or an empty string for all records.
///
/// Laid out as: search, the most-used genres as quick picks, then every genre
/// A–Z as a list with its record count.
class GenreFilterSheet extends StatefulWidget {
  const GenreFilterSheet({
    required this.options,
    required this.totalRecords,
    this.selected,
    super.key,
  });

  /// Most-used first, as [rankGenreFilterOptions] returns them.
  final List<GenreFilterOption> options;
  final int totalRecords;
  final String? selected;

  /// Short lists are easy to scan, so they get no search box or quick picks.
  static const searchThreshold = 8;

  /// How many of the most-used genres are offered as quick picks.
  static const quickPicks = 6;

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

  void _choose(String result) => Navigator.of(context).pop(result);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.theme.textTheme;
    final colors = context.theme.colorScheme;
    final query = _search.text.trim().toLowerCase();
    final long = widget.options.length > GenreFilterSheet.searchThreshold;
    final alphabetical = [...widget.options]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final matches = [
      for (final option in alphabetical)
        if (query.isEmpty || option.name.toLowerCase().contains(query)) option,
    ];

    Widget sectionLabel(String label) => Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.space8,
        tokens.space16,
        0,
        tokens.space8,
      ),
      child: Text(
        label,
        style: text.labelSmall?.copyWith(
          color: tokens.textMuted,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );

    Widget row({
      required Key key,
      required String label,
      required int count,
      required bool selected,
      required String result,
    }) => InkWell(
      key: key,
      onTap: () => _choose(result),
      borderRadius: BorderRadius.circular(tokens.radiusMedium),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.space8,
            vertical: tokens.space8,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyLarge?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : null,
                    color: selected ? colors.primary : null,
                  ),
                ),
              ),
              SizedBox(width: tokens.space12),
              Text(
                '$count',
                style: text.bodyMedium?.copyWith(
                  color: tokens.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              SizedBox(
                width: 32,
                child: selected
                    ? Icon(Icons.check_rounded, size: 20, color: colors.primary)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.space16,
            0,
            tokens.space16,
            tokens.space16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filter by genre',
                        style: text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (widget.selected != null)
                      TextButton(
                        key: const Key('collection-genre-clear'),
                        onPressed: () => _choose(''),
                        child: const Text('Clear'),
                      ),
                  ],
                ),
              ),
              if (long) ...[
                SizedBox(height: tokens.space8),
                TextField(
                  key: const Key('collection-genre-filter-search'),
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search ${widget.options.length} genres',
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => setState(_search.clear),
                          ),
                  ),
                ),
              ],
              Flexible(
                child: SingleChildScrollView(
                  key: const Key('collection-genre-filter-scroll'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (query.isEmpty) ...[
                        SizedBox(height: tokens.space8),
                        row(
                          key: const Key('collection-genre-all'),
                          label: 'All records',
                          count: widget.totalRecords,
                          selected: widget.selected == null,
                          result: '',
                        ),
                        if (long) ...[
                          sectionLabel('MOST USED'),
                          Padding(
                            padding: EdgeInsets.only(left: tokens.space8),
                            child: Wrap(
                              spacing: tokens.space8,
                              runSpacing: tokens.space8,
                              children: [
                                for (final option in widget.options.take(
                                  GenreFilterSheet.quickPicks,
                                ))
                                  ChoiceChip(
                                    key: ValueKey(
                                      'collection-genre-top-${option.name}',
                                    ),
                                    label: Text(option.name),
                                    selected: _isSelected(option.name),
                                    onSelected: (_) => _choose(option.name),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        if (widget.options.isNotEmpty)
                          sectionLabel(long ? 'ALL GENRES A–Z' : 'GENRES'),
                      ] else
                        SizedBox(height: tokens.space8),
                      for (final option in matches)
                        row(
                          key: ValueKey('collection-genre-${option.name}'),
                          label: option.name,
                          count: option.count,
                          selected: _isSelected(option.name),
                          result: option.name,
                        ),
                      if (matches.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: tokens.space16,
                            horizontal: tokens.space8,
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
