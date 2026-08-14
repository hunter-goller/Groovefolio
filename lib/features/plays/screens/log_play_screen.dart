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
import 'package:vinyl_app/widgets/shared/nfc_prompt.dart';
import 'package:vinyl_app/widgets/shared/side_selector.dart';
import 'package:vinyl_app/widgets/ui/primary_button.dart';
import 'package:vinyl_app/widgets/ui/search_field.dart';

/// Play logging flow with manual album selection and the animated NFC prompt.
///
/// VinylApp-020 owns the scanning UI. Hardware tag detection remains deferred
/// to VinylApp-066, which can set [_selectedAlbum] and reuse the same save path.
class LogPlayScreen extends ConsumerStatefulWidget {
  const LogPlayScreen({this.isBottomSheet = false, super.key});

  final bool isBottomSheet;

  @override
  ConsumerState<LogPlayScreen> createState() => _LogPlayScreenState();
}

class _LogPlayScreenState extends ConsumerState<LogPlayScreen> {
  late final TextEditingController _searchController;
  Timer? _searchDebounce;
  String _query = '';
  CollectionAlbum? _selectedAlbum;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  SidePlayed _side = SidePlayed.full;
  bool _isSaving = false;
  bool _isNfcScanning = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _selectedTime = TimeOfDay.fromDateTime(now);
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

  void _startNfcScan() {
    FocusScope.of(context).unfocus();
    setState(() => _isNfcScanning = true);
  }

  void _cancelNfcScan() {
    setState(() => _isNfcScanning = false);
  }

  void _beginManualSearch() {
    if (_isNfcScanning) {
      setState(() => _isNfcScanning = false);
    }
  }

  void _selectAlbum(CollectionAlbum album) {
    setState(() {
      _selectedAlbum = album;
      _isNfcScanning = false;
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Couldn’t log play: $error')));
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
          NFCPrompt(
            isScanning: _isNfcScanning,
            onStart: _startNfcScan,
            onCancel: _cancelNfcScan,
          ),
          SizedBox(height: tokens.space16),
          Text(
            'Choose a record',
            style: context.theme.textTheme.titleMedium?.copyWith(
              color: tokens.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: tokens.space8),
          SearchField(
            key: const Key('log-play-search'),
            controller: _searchController,
            hint: 'Search your collection…',
            onTap: _beginManualSearch,
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
              selectedAlbumId: _selectedAlbum?.id,
              query: _query,
              onSelected: _selectAlbum,
            ),
          ),
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
                  label: MaterialLocalizations.of(
                    context,
                  ).formatTimeOfDay(_selectedTime),
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
    required this.selectedAlbumId,
    required this.query,
    required this.onSelected,
  });

  final List<CollectionAlbum> albums;
  final String? selectedAlbumId;
  final String query;
  final ValueChanged<CollectionAlbum> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    if (albums.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.space16),
        child: Text(
          query.isEmpty
              ? 'Your collection is empty. Add a record before logging a play.'
              : 'No records match “$query”.',
          style: context.theme.textTheme.bodyMedium?.copyWith(
            color: tokens.textMuted,
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var index = 0; index < albums.length; index++) ...[
          AlbumSelectTile(
            title: albums[index].title,
            artist: albums[index].artistName,
            releaseYear: albums[index].album.releaseYear,
            artworkPath: albums[index].album.artworkPath,
            playCount: albums[index].playCount,
            isSelected: albums[index].id == selectedAlbumId,
            onTap: () => onSelected(albums[index]),
          ),
          if (index != albums.length - 1) SizedBox(height: tokens.space8),
        ],
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
