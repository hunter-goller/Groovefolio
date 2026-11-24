import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Moves backup bytes between the app and a place the user chooses.
///
/// Both directions go through Android's system file dialog (Storage Access
/// Framework), so no storage permission is needed and the user can pick
/// Downloads, Google Drive or any other installed document provider.
abstract interface class BackupFileGateway {
  /// Returns false if the user cancelled the save dialog.
  Future<bool> save(String fileName, Uint8List bytes);

  /// Returns null if the user cancelled the open dialog.
  Future<Uint8List?> open();
}

class FilePickerBackupFileGateway implements BackupFileGateway {
  const FilePickerBackupFileGateway();

  @override
  Future<bool> save(String fileName, Uint8List bytes) async {
    final saved = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: 'application/zip',
      dialogTitle: 'Save Groovefolio backup',
    );
    return saved != null;
  }

  @override
  Future<Uint8List?> open() async {
    // Any type: some providers (Drive, email apps) don't label zips reliably.
    // The backup service validates the contents instead.
    final file = await FilePicker.pickFile(
      dialogTitle: 'Choose a Groovefolio backup',
    );
    return file?.xFile.readAsBytes();
  }
}

final backupFileGatewayProvider = Provider<BackupFileGateway>(
  (ref) => const FilePickerBackupFileGateway(),
);
