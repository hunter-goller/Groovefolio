import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/features/albums/drafts/record_draft.dart';
import 'package:vinyl_app/routing/app_routes.dart';

bool _offered = false;

@visibleForTesting
void resetRecordDraftOffer() => _offered = false;

/// Once per launch: if the app was closed while a record was being added or
/// edited, offer to go back to it. The form then fills itself back in.
void offerToResumeRecordDraft(BuildContext context, WidgetRef ref) {
  if (_offered) return;
  _offered = true;
  final store = ref.read(recordDraftStoreProvider);
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final add = await store.read(RecordDraftKind.add);
    final edit = add == null ? await store.read(RecordDraftKind.edit) : null;
    final draft = add ?? edit;
    final albumId = edit?.albumId;
    if (draft == null || (add == null && albumId == null)) return;
    if (!context.mounted) return;
    final route = add != null
        ? AppRoutes.addAlbum
        : AppRoutes.editAlbumPath(albumId!);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        key: const Key('record-draft-offer'),
        duration: const Duration(seconds: 10),
        content: Text(
          add != null
              ? 'You were adding ${draft.name}. Pick up where you left off?'
              : 'You were editing ${draft.name}. Pick up where you left off?',
        ),
        action: SnackBarAction(
          label: 'Continue',
          onPressed: () {
            if (context.mounted) context.push(route);
          },
        ),
      ),
    );
  });
}
