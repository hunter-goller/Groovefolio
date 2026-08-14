import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/routing/app_routes.dart';

/// TEMPORARY — nav-testing helper only, delete once real Screens-epic
/// cards replace each placeholder. Not part of the app's real widget set.
class RouteTestButtons extends StatelessWidget {
  const RouteTestButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        ElevatedButton(
          onPressed: () => context.go(AppRoutes.collection),
          child: const Text('Collection'),
        ),
        ElevatedButton(
          onPressed: () => context.go(AppRoutes.stats),
          child: const Text('Stats'),
        ),
        ElevatedButton(
          onPressed: () => context.go(AppRoutes.discover),
          child: const Text('Discover'),
        ),
        ElevatedButton(
          onPressed: () => context.push(AppRoutes.addAlbum),
          child: const Text('Add Record'),
        ),
        ElevatedButton(
          onPressed: () => context.push(AppRoutes.albumDetailPath('test-123')),
          child: const Text('Album Detail'),
        ),
        ElevatedButton(
          onPressed: () => context.push(AppRoutes.logPlay),
          child: const Text('Log Play'),
        ),
      ],
    );
  }
}
