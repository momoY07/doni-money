import 'dart:io';
import 'dart:ui' show Rect;

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Moves backup JSON in and out of the device (Share Sheet / Files app).
///
/// Holds no backup logic: it only writes/reads strings. A future iCloud
/// transport can sit next to this without touching [BackupService].
class BackupFileTransfer {
  const BackupFileTransfer();

  /// Writes [json] to a temp file named [fileName] and opens the Share Sheet
  /// (which includes "Save to Files").
  Future<void> share(String json, String fileName, {Rect? origin}) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(json, flush: true);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json', name: fileName)],
      subject: 'Doni Money Backup',
      sharePositionOrigin: origin,
    );
  }

  /// Lets the user pick a JSON file and returns its contents, or null if
  /// they cancelled.
  Future<String?> pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return null;
    final path = result.files.first.path;
    if (path == null) return null;
    return File(path).readAsString();
  }
}
