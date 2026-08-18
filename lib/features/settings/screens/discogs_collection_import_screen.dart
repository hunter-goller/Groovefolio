import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/providers/album_providers.dart';
import 'package:vinyl_app/providers/genre_providers.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/services/discogs/discogs_collection_import_service.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';
import 'package:vinyl_app/services/discogs/discogs_providers.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';

class DiscogsCollectionImportScreen extends ConsumerStatefulWidget {
  const DiscogsCollectionImportScreen({super.key});

  @override
  ConsumerState<DiscogsCollectionImportScreen> createState() =>
      _DiscogsCollectionImportScreenState();
}

class _DiscogsCollectionImportScreenState
    extends ConsumerState<DiscogsCollectionImportScreen> {
  DiscogsCollectionPreview? _preview;
  DiscogsCollectionImportResult? _result;
  DiscogsImportProgress? _progress;
  Object? _error;
  bool _loading = true;
  bool _importing = false;
  Set<int> _selectedReleaseIds = <int>{};

  @override
  void initState() {
    super.initState();
    unawaited(Future<void>.microtask(_loadPreview));
  }

  Future<void> _loadPreview() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _result = null;
      });
    }

    try {
      final account = await ref.read(discogsAccountProvider.future);
      if (account == null) {
        throw const DiscogsAuthenticationFailure(
          'Connect a Discogs account in Settings before importing.',
        );
      }

      final preview = await ref
          .read(discogsCollectionImportServiceProvider)
          .prepare(account.username);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _selectedReleaseIds = {
          for (final candidate in preview.candidates)
            if (candidate.selectedByDefault) candidate.item.releaseId,
        };
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _startImport() async {
    final preview = _preview;
    if (preview == null || _selectedReleaseIds.isEmpty || _importing) return;

    final selected = preview.candidates
        .where(
          (candidate) =>
              _selectedReleaseIds.contains(candidate.item.releaseId) &&
              candidate.canImport,
        )
        .toList(growable: false);
    if (selected.isEmpty) return;

    setState(() {
      _importing = true;
      _error = null;
      _progress = DiscogsImportProgress(completed: 0, total: selected.length);
    });

    try {
      final result = await ref
          .read(discogsCollectionImportServiceProvider)
          .importCandidates(
            selected,
            onProgress: (progress) {
              if (!mounted) return;
              setState(() => _progress = progress);
            },
          );

      ref.invalidate(albumsProvider);
      ref.invalidate(genresProvider);
      ref.invalidate(albumGenresProvider);

      if (!mounted) return;
      setState(() {
        _result = result;
        _importing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _importing = false;
      });
    }
  }

  void _toggleCandidate(DiscogsCollectionCandidate candidate, bool selected) {
    if (!candidate.canImport || _importing) return;
    setState(() {
      if (selected) {
        _selectedReleaseIds.add(candidate.item.releaseId);
      } else {
        _selectedReleaseIds.remove(candidate.item.releaseId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import from Discogs')),
      body: SafeArea(
        top: false,
        child: switch ((_loading, _importing, _result, _error, _preview)) {
          (true, _, _, _, _) => const _LoadingImportState(),
          (false, true, _, _, _) => _ImportProgressState(progress: _progress),
          (false, false, final result?, _, _) => _ImportResultState(
            result: result,
            onViewCollection: () => context.go(AppRoutes.collection),
            onImportMore: _loadPreview,
          ),
          (false, false, _, final error?, _) => _ImportErrorState(
            message: _errorMessage(error),
            onRetry: _loadPreview,
          ),
          (false, false, _, _, final preview?) => _PreviewState(
            preview: preview,
            selectedReleaseIds: _selectedReleaseIds,
            onToggle: _toggleCandidate,
            onImport: _startImport,
            onRefresh: _loadPreview,
          ),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }

  String _errorMessage(Object error) {
    if (error is DiscogsFailure) return error.message;
    return 'Could not prepare the Discogs collection import.';
  }
}

class _LoadingImportState extends StatelessWidget {
  const _LoadingImportState();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.space24),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Reading your Discogs collection…',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewState extends StatelessWidget {
  const _PreviewState({
    required this.preview,
    required this.selectedReleaseIds,
    required this.onToggle,
    required this.onImport,
    required this.onRefresh,
  });

  final DiscogsCollectionPreview preview;
  final Set<int> selectedReleaseIds;
  final void Function(DiscogsCollectionCandidate candidate, bool selected)
  onToggle;
  final Future<void> Function() onImport;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final selectedCount = preview.candidates
        .where(
          (candidate) =>
              candidate.canImport &&
              selectedReleaseIds.contains(candidate.item.releaseId),
        )
        .length;

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  tokens.space16,
                  tokens.space12,
                  tokens.space16,
                  0,
                ),
                sliver: SliverList.list(
                  children: [
                    Text(
                      'Review before importing',
                      style: context.theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: tokens.space8),
                    Text(
                      'New vinyl releases are selected automatically. '
                      'Possible local matches stay unchecked until you explicitly choose them.',
                      style: context.theme.textTheme.bodyMedium?.copyWith(
                        color: tokens.textMuted,
                      ),
                    ),
                    SizedBox(height: tokens.space16),
                    _ImportSummary(preview: preview),
                    SizedBox(height: tokens.space12),
                    const _InfoPanel(
                      icon: Icons.info_outline_rounded,
                      message:
                          'Collection data and release metadata provided by Discogs.',
                    ),
                    if (preview.nonVinylIgnored > 0) ...[
                      SizedBox(height: tokens.space12),
                      _InfoPanel(
                        icon: Icons.filter_alt_outlined,
                        message:
                            '${preview.nonVinylIgnored} non-vinyl Discogs '
                            '${preview.nonVinylIgnored == 1 ? 'item was' : 'items were'} ignored.',
                      ),
                    ],
                    SizedBox(height: tokens.space16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Releases',
                            style: context.theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: onRefresh,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Refresh'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (preview.candidates.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(tokens.space24),
                      child: const Text(
                        'No vinyl releases were found in this Discogs collection.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: preview.candidates.length,
                  itemBuilder: (context, index) {
                    final candidate = preview.candidates[index];
                    return _CandidateTile(
                      candidate: candidate,
                      selected: selectedReleaseIds.contains(
                        candidate.item.releaseId,
                      ),
                      onChanged: candidate.canImport
                          ? (selected) => onToggle(candidate, selected ?? false)
                          : null,
                    );
                  },
                ),
              SliverToBoxAdapter(child: SizedBox(height: tokens.space16)),
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.surface,
            border: Border(
              top: BorderSide(color: tokens.textMuted.withValues(alpha: 0.18)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.all(tokens.space16),
              child: FilledButton.icon(
                key: const Key('discogs-import-selected-button'),
                onPressed: selectedCount == 0 ? null : onImport,
                icon: const Icon(Icons.download_rounded),
                label: Text(
                  selectedCount == 1
                      ? 'Import 1 record'
                      : 'Import $selectedCount records',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ImportSummary extends StatelessWidget {
  const _ImportSummary({required this.preview});

  final DiscogsCollectionPreview preview;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Wrap(
      spacing: tokens.space8,
      runSpacing: tokens.space8,
      children: [
        _SummaryPill(label: 'Vinyl found', value: preview.vinylFound),
        _SummaryPill(label: 'New', value: preview.newCount),
        _SummaryPill(label: 'Already here', value: preview.exactDuplicateCount),
        _SummaryPill(label: 'Review', value: preview.needsReviewCount),
      ],
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: tokens.surfaceElevated,
        borderRadius: BorderRadius.circular(tokens.radiusXLarge),
      ),
      child: Text(
        '$label $value',
        style: context.theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({
    required this.candidate,
    required this.selected,
    required this.onChanged,
  });

  final DiscogsCollectionCandidate candidate;
  final bool selected;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final item = candidate.item;
    final subtitle = <String>[
      item.artist,
      if (item.year != null) item.year.toString(),
      if (item.label != null && item.label!.isNotEmpty) item.label!,
      if (item.formats.isNotEmpty) item.formats.join(', '),
    ].join(' • ');

    return Column(
      children: [
        CheckboxListTile(
          key: Key(
            'discogs-import-release-${item.releaseId}-${item.instanceId}',
          ),
          value:
              candidate.status ==
                  DiscogsCollectionCandidateStatus.exactDuplicate
              ? false
              : selected,
          onChanged: onChanged,
          controlAffinity: ListTileControlAffinity.leading,
          secondary: _StatusIcon(status: candidate.status),
          title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(
                _statusText(candidate),
                style: context.theme.textTheme.bodySmall?.copyWith(
                  color:
                      candidate.status ==
                          DiscogsCollectionCandidateStatus.needsReview
                      ? context.theme.colorScheme.primary
                      : tokens.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          indent: 56,
          color: tokens.textMuted.withValues(alpha: 0.14),
        ),
      ],
    );
  }

  String _statusText(DiscogsCollectionCandidate candidate) {
    return switch (candidate.status) {
      DiscogsCollectionCandidateStatus.newRecord => 'New record',
      DiscogsCollectionCandidateStatus.exactDuplicate =>
        'Exact Discogs release already represented',
      DiscogsCollectionCandidateStatus.needsReview =>
        'Possible local match: ${candidate.localMatchTitle ?? 'review before importing'}',
    };
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final DiscogsCollectionCandidateStatus status;

  @override
  Widget build(BuildContext context) {
    return Icon(
      switch (status) {
        DiscogsCollectionCandidateStatus.newRecord =>
          Icons.add_circle_outline_rounded,
        DiscogsCollectionCandidateStatus.exactDuplicate =>
          Icons.check_circle_outline_rounded,
        DiscogsCollectionCandidateStatus.needsReview =>
          Icons.warning_amber_rounded,
      },
      color: status == DiscogsCollectionCandidateStatus.needsReview
          ? context.theme.colorScheme.primary
          : context.tokens.textMuted,
    );
  }
}

class _ImportProgressState extends StatelessWidget {
  const _ImportProgressState({required this.progress});

  final DiscogsImportProgress? progress;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final value = progress;
    final fraction = value == null || value.total == 0
        ? null
        : value.completed / value.total;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: fraction),
            SizedBox(height: tokens.space16),
            Text(
              value == null
                  ? 'Starting import…'
                  : 'Importing ${value.completed} of ${value.total}',
              key: const Key('discogs-import-progress-label'),
              style: context.theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (value?.currentTitle != null) ...[
              SizedBox(height: tokens.space8),
              Text(
                value!.currentTitle!,
                textAlign: TextAlign.center,
                style: context.theme.textTheme.bodyMedium?.copyWith(
                  color: tokens.textMuted,
                ),
              ),
            ],
            SizedBox(height: tokens.space12),
            Text(
              'Keep Groovefolio open while the selected records are written locally.',
              textAlign: TextAlign.center,
              style: context.theme.textTheme.bodySmall?.copyWith(
                color: tokens.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportResultState extends StatelessWidget {
  const _ImportResultState({
    required this.result,
    required this.onViewCollection,
    required this.onImportMore,
  });

  final DiscogsCollectionImportResult result;
  final VoidCallback onViewCollection;
  final Future<void> Function() onImportMore;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ListView(
      padding: EdgeInsets.all(tokens.space16),
      children: [
        Icon(
          result.failed == 0
              ? Icons.check_circle_rounded
              : Icons.info_outline_rounded,
          size: 56,
          color: context.theme.colorScheme.primary,
        ),
        SizedBox(height: tokens.space12),
        Text(
          'Import complete',
          textAlign: TextAlign.center,
          style: context.theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: tokens.space16),
        _InfoPanel(
          icon: Icons.album_outlined,
          message:
              '${result.imported} imported • ${result.skipped} skipped • ${result.failed} failed',
        ),
        if (result.warnings.isNotEmpty) ...[
          SizedBox(height: tokens.space16),
          Text(
            'Warnings',
            style: context.theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: tokens.space8),
          for (final warning in result.warnings)
            Padding(
              padding: EdgeInsets.only(bottom: tokens.space8),
              child: _InfoPanel(
                icon: Icons.image_not_supported_outlined,
                message: '${warning.title}: ${warning.message}',
              ),
            ),
        ],
        if (result.failures.isNotEmpty) ...[
          SizedBox(height: tokens.space16),
          Text(
            'Could not import',
            style: context.theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: tokens.space8),
          for (final failure in result.failures)
            Padding(
              padding: EdgeInsets.only(bottom: tokens.space8),
              child: _InfoPanel(
                icon: Icons.error_outline_rounded,
                message: '${failure.title}: ${failure.message}',
              ),
            ),
        ],
        SizedBox(height: tokens.space24),
        FilledButton.icon(
          key: const Key('discogs-import-view-collection'),
          onPressed: onViewCollection,
          icon: const Icon(Icons.library_music_outlined),
          label: const Text('View collection'),
        ),
        SizedBox(height: tokens.space8),
        OutlinedButton.icon(
          onPressed: onImportMore,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Scan Discogs again'),
        ),
      ],
    );
  }
}

class _ImportErrorState extends StatelessWidget {
  const _ImportErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48),
            SizedBox(height: tokens.space12),
            Text(
              'Couldn’t prepare import',
              style: context.theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: tokens.space8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.theme.textTheme.bodyMedium?.copyWith(
                color: tokens.textMuted,
              ),
            ),
            SizedBox(height: tokens.space16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: EdgeInsets.all(tokens.space12),
      decoration: BoxDecoration(
        color: tokens.surfaceElevated,
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: tokens.textMuted),
          SizedBox(width: tokens.space8),
          Expanded(
            child: Text(
              message,
              style: context.theme.textTheme.bodySmall?.copyWith(
                color: tokens.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
