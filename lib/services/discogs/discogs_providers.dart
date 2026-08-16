import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/services/discogs/discogs_api_client.dart';
import 'package:vinyl_app/services/discogs/discogs_auth_service.dart';
import 'package:vinyl_app/services/discogs/discogs_config.dart';
import 'package:vinyl_app/services/discogs/discogs_credential_store.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';

final discogsConfigProvider = Provider<DiscogsConfig>((ref) {
  return DiscogsConfig.fromEnvironment;
});

final discogsCredentialStoreProvider = Provider<DiscogsCredentialStore>((ref) {
  return SecureDiscogsCredentialStore();
});

final discogsApiClientProvider = Provider<DiscogsApiClient>((ref) {
  final client = DiscogsApiClient(config: ref.watch(discogsConfigProvider));
  ref.onDispose(client.close);
  return client;
});

final discogsAuthServiceProvider = Provider<DiscogsAuthService>((ref) {
  return DiscogsAuthService(
    apiClient: ref.watch(discogsApiClientProvider),
    credentialStore: ref.watch(discogsCredentialStoreProvider),
  );
});

final discogsAccountProvider = FutureProvider.autoDispose<DiscogsAccount?>((
  ref,
) {
  return ref.watch(discogsAuthServiceProvider).currentAccount();
});
