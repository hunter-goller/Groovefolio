import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/features/stats/screens/stats_screen.dart';
import 'package:vinyl_app/providers/album_providers.dart';
import 'package:vinyl_app/services/recommendation_service.dart';

/// Refreshes every view that shows play data after a play is added or removed.
///
/// Manual logging, NFC logging and NFC Undo all use this, so Stats and
/// Discover stay in step with the Collection whichever way a play changes.
void refreshPlayData(WidgetRef ref, String albumId) {
  ref.invalidate(albumsProvider);
  ref.invalidate(recentlyPlayedProvider);
  ref.invalidate(playCountProvider(albumId));
  ref.invalidate(albumDetailProvider(albumId));
  ref.invalidate(albumSearchProvider);
  ref.invalidate(statsDashboardProvider);
  ref.invalidate(discoverRecommendationsProvider);
}
