import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/providers/album_providers.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/services/play_logging_service.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';
import 'package:vinyl_app/types/side_played.dart';
import 'package:vinyl_app/widgets/shared/album_select_tile.dart';
import 'package:vinyl_app/widgets/shared/side_selector.dart';
import 'package:vinyl_app/widgets/ui/primary_button.dart';
import 'package:vinyl_app/widgets/ui/search_field.dart';

/// Play logging flow with manual album selection.
///
/// NFC controls stay hidden while the hardware feature is marked Coming soon.
/// The held NFC tickets can later set [_selectedAlbum] and reuse this save path.
class LogPlayScreen extends ConsumerStatefulWidget {
  const LogPlayScreen({
    this.isBottomSheet = false,
    this.initialAlbum,
    super.key,
  });

  final bool isBottomSheet;
  final CollectionAlbum? initialAlbum;

  @override
  ConsumerState<LogPlayScreen> createState() => _LogPlayScreenState();
}

class _LogPlayScreenState extends ConsumerState<LogPlayScreen> {
  static const _recentRecordLimit = 6;

  late final TextEditingController _searchController;
  Timer? _searchDebounce;
  String _query = '';
  bool _browseAll = false;
  CollectionAlbum? _selectedAlbum;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  SidePlayed _side = SidePlayed.full;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _selectedTime = TimeOfDay.fromDateTime(now);
    _searchController = TextEditingController();
    _selectedAlbum = widget.initialAlbum;
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
      setState(() {
        _query = value.trim();
        _browseAll = false;
      });
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    setState(() {
      _query = '';
      _browseAll = false;
    });
  }

  void _selectAlbum(CollectionAlbum album) {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _selectedAlbum = album;
      _query = '';
      _browseAll = false;
    });
  }

  void _changeAlbum() {
    setState(() {
      _selectedAlbum = null;
      _query = '';
      _browseAll = false;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
    );

    if (selected != null && mounted) {
      setState(() => _selectedDate = selected);
    }
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (selected != null && mounted) {
      setState(() => _selectedTime = selected);
    }
  }

  Future<void> _save() async {
    final album = _selectedAlbum;
    if (album == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Choose a record first.')));
      return;
    }

    setState(() => _isSaving = true);

    final playedAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    try {
      await ref
          .read(playLoggingServiceProvider)
          .logPlay(album.id, playedAt, _side);

      ref.invalidate(albumsProvider);
      ref.invalidate(recentlyPlayedProvider);
      ref.invalidate(playCountProvider(album.id));
      ref.invalidate(albumDetailProvider(album.id));
      ref.invalidate(albumSearchProvider(_query));

      if (!mounted) return;
      if (widget.isBottomSheet) {
        Navigator.of(context).pop();
      } else {
        context.go(AppRoutes.collection);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Couldn’t log play: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final albumsAsync = ref.watch(albumSearchProvider(_query));

    final body = SafeArea(
      top: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          tokens.space16,
          widget.isBottomSheet ? tokens.space8 : tokens.space16,
          tokens.space16,
          tokens.space32,
        ),
        children: [
          if (widget.isBottomSheet) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Log a play',
                    style: context.theme.textTheme.headlineSmall?.copyWith(
                      color: tokens.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            SizedBox(height: tokens.space8),
          ],
          Text(
            'Choose a record',
            style: context.theme.textTheme.titleMedium?.copyWith(
              color: tokens.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: tokens.space8),
          if (_selectedAlbum != null)
            _SelectedAlbum(album: _selectedAlbum!, onChange: _changeAlbum)
          else ...[
            SearchField(
              key: const Key('log-play-search'),
              controller: _searchController,
              hint: 'Search by record or artist…',
              onChanged: _scheduleSearch,
              onClear: _clearSearch,
            ),
            SizedBox(height: tokens.space12),
            albumsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => _SearchError(
                onRetry: () => ref.invalidate(albumSearchProvider(_query)),
              ),
              data: (albums) => _AlbumResults(
                albums: albums,
                query: _query,
                browseAll: _browseAll,
                recentLimit: _recentRecordLimit,
                onBrowseAll: () => setState(() => _browseAll = true),
                onShowRecent: () => setState(() => _browseAll = false),
                onSelected: _selectAlbum,
              ),
            ),
          ],
          SizedBox(height: tokens.space24),
          Text(
            'When',
            style: context.theme.textTheme.titleMedium?.copyWith(
              color: tokens.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: tokens.space8),
          Row(
            children: [
              Expanded(
                child: _PickerButton(
                  icon: Icons.calendar_today_rounded,
                  label: _dateLabel(context),
                  onPressed: _pickDate,
                ),
              ),
              SizedBox(width: tokens.space8),
              Expanded(
                child: _PickerButton(
                  icon: Icons.schedule_rounded,
                  label: MaterialLocalizations.of(context)
                      .formatTimeOfDay(_selectedTime),
                  onPressed: _pickTime,
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.space24),
          Text(
            'Side played',
            style: context.theme.textTheme.titleMedium?.copyWith(
              color: tokens.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: tokens.space8),
          SideSelector(
            value: _side,
            onChanged: (value) => setState(() => _side = value),
          ),
          SizedBox(height: tokens.space32),
          PrimaryButton(
            label: 'Save play',
            icon: Icons.play_arrow_rounded,
            isLoading: _isSaving,
            onPressed: _isSaving || _selectedAlbum == null ? null : _save,
          ),
        ],
      ),
    );

    if (widget.isBottomSheet) {
      return Material(color: tokens.background, child: body);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Log a play')),
      body: body,
    );
  }

  String _dateLabel(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_selectedDate == today) {
      return 'Today';
    }
    return MaterialLocalizations.of(context).formatMediumDate(_selectedDate);
  }
}

class _AlbumResults extends StatelessWidget {
  const _AlbumResults({
    required this.albums,
    required this.query,
    required this.browseAll,
    required this.recentLimit,
    required this.onBrowseAll,
    required this.onShowRecent,
    required this.onSelected,
  });

  final List<CollectionAlbum> albums;
  final String query;
  final bool browseAll;
  final int recentLimit;
  final VoidCallback onBrowseAll;
  final VoidCallback onShowRecent;
  final ValueChanged<CollectionAlbum> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    if (albums.isEmpty) {
      if (query.isNotEmpty) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: tokens.space16),
          child: Text(
            'No records match “$query”. Try an album title or artist.',
            style: context.theme.textTheme.bodyMedium?.copyWith(
              color: tokens.textMuted,
            ),
          ),
        );
      }

      return Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your collection is empty. Add a record before logging a play.',
              style: context.theme.textTheme.bodyMedium?.copyWith(
                color: tokens.textMuted,
              ),
            ),
            SizedBox(height: tokens.space8),
            TextButton.icon(
              key: const Key('log-play-add-record'),
              onPressed: () => context.push(AppRoutes.addAlbum),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add a record'),
            ),
          ],
        ),
      );
    }

    final searching = query.isNotEmpty;
    final visibleAlbums = searching || browseAll
        ? albums
        : albums.take(recentLimit).toList();
    final heading = searching
        ? 'Search results'
        : browseAll
        ? 'All records'
        : 'Recent records';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                heading,
                style: context.theme.textTheme.labelLarge?.copyWith(
                  color: tokens.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (!searching && albums.length > recentLimit)
              TextButton(
                key: Key(browseAll ? 'show-recent' : 'browse-all-records'),
                onPressed: browseAll ? onShowRecent : onBrowseAll,
                child: Text(browseAll ? 'Show recent' : 'Browse all'),
              ),
          ],
        ),
        SizedBox(height: tokens.space4),
        for (var index = 0; index < visibleAlbums.length; index++) ...[
          AlbumSelectTile(
            title: visibleAlbums[index].title,
            artist: visibleAlbums[index].artistName,
            releaseYear: visibleAlbums[index].album.releaseYear,
            artworkPath: visibleAlbums[index].album.artworkPath,
            playCount: visibleAlbums[index].playCount,
            isSelected: false,
            onTap: () => onSelected(visibleAlbums[index]),
          ),
          if (index != visibleAlbums.length - 1)
            SizedBox(height: tokens.space8),
        ],
      ],
    );
  }
}

class _SelectedAlbum extends StatelessWidget {
  const _SelectedAlbum({required this.album, required this.onChange});

  final CollectionAlbum album;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AlbumSelectTile(
          title: album.title,
          artist: album.artistName,
          releaseYear: album.album.releaseYear,
          artworkPath: album.album.artworkPath,
          playCount: album.playCount,
          isSelected: true,
          onTap: onChange,
        ),
        SizedBox(height: tokens.space4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: const Key('change-log-play-album'),
            onPressed: onChange,
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('Change record'),
          ),
        ),
      ],
    );
  }
}

class _SearchError extends StatelessWidget {
  const _SearchError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.space12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Couldn’t load your collection.',
              style: context.theme.textTheme.bodyMedium?.copyWith(
                color: tokens.textMuted,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: tokens.text,
        padding: EdgeInsets.symmetric(
          horizontal: tokens.space12,
          vertical: tokens.space12,
        ),
        side: BorderSide(color: tokens.textMuted.withValues(alpha: 0.28)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMedium),
        ),
      ),
    );
  }
}
