import 'package:flutter/material.dart';
import 'package:vinyl_app/features/route_test_buttons.dart';

// TODO(VinylApp-Screens): Replace with real Log Play Screen
// (NFCPrompt, SearchField, AlbumSelectTile, SideSelector, date/time pickers).
class LogPlayScreen extends StatelessWidget {
  const LogPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log a play')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Log Play screen — placeholder'),
              SizedBox(height: 16),
              RouteTestButtons(),
            ],
          ),
        ),
      ),
    );
  }
}
