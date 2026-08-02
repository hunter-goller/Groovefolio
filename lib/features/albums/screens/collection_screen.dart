import 'package:flutter/material.dart';
import 'package:vinyl_app/features/route_test_buttons.dart';

// TODO(VinylApp-Screens): Replace with real Collection Screen
// (SummaryBar, FilterChipRow, AlbumListTile list, BottomNavBar).
class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Collection')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Collection screen — placeholder'),
              SizedBox(height: 16),
              RouteTestButtons(),
            ],
          ),
        ),
      ),
    );
  }
}
