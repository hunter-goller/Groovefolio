import 'package:flutter/material.dart';
import 'package:vinyl_app/features/route_test_buttons.dart';

// TODO(VinylApp-Screens): Replace with real Stats Screen
// (StatTile grid, PlaysBarChart, GenreBreakdownList, AlbumRankTile list).
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Stats screen — placeholder'),
              SizedBox(height: 16),
              RouteTestButtons(),
            ],
          ),
        ),
      ),
    );
  }
}
