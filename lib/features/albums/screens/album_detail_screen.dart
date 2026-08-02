import 'package:flutter/material.dart';
import 'package:vinyl_app/features/route_test_buttons.dart';

// TODO(VinylApp-Screens): Replace with real Album Detail Screen
// (collapsing AlbumHeroCard, TotalPlaysCard, PlaysBarChart, etc.).
class AlbumDetailScreen extends StatelessWidget {
  const AlbumDetailScreen({required this.albumId, super.key});

  final String albumId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Album detail')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Album detail — placeholder (id: $albumId)'),
              const SizedBox(height: 16),
              const RouteTestButtons(),
            ],
          ),
        ),
      ),
    );
  }
}
