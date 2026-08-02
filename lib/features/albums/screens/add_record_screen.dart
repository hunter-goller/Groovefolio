import 'package:flutter/material.dart';
import 'package:vinyl_app/features/route_test_buttons.dart';

// TODO(VinylApp-Screens): Replace with real Add Record Screen
// (ArtworkPicker, LabeledTextField form, DiscogsBanner, NFCToggleRow).
class AddRecordScreen extends StatelessWidget {
  const AddRecordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add a record')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add Record screen — placeholder'),
              SizedBox(height: 16),
              RouteTestButtons(),
            ],
          ),
        ),
      ),
    );
  }
}
