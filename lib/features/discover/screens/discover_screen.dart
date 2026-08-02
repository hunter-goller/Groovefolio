import 'package:flutter/material.dart';
import 'package:vinyl_app/features/route_test_buttons.dart';

// TODO(VinylApp-Screens): Replace with real Discover Screen
// (TasteProfileCard, AlbumActionCard rediscover/genre/era sections).
class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Discover')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Discover screen — placeholder'),
              SizedBox(height: 16),
              RouteTestButtons(),
            ],
          ),
        ),
      ),
    );
  }
}
