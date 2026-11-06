import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Whether this device can use the app's iCloud container right now.
enum ICloudAvailability {
  available,

  /// No Apple Account signed in to iCloud, or iCloud Drive is turned off.
  /// (iOS reports both the same way without CloudKit.)
  notSignedIn,

  /// Signed in, but the app's container can't be opened: iCloud Drive is off
  /// for Doni Money, or the container isn't provisioned for this build.
  containerUnavailable,

  /// Not iOS.
  unsupportedPlatform,
}

enum CloudDownloadStatus { current, downloaded, notDownloaded, unknown }

/// What iCloud knows about `latest-backup.json` without reading it.
class CloudFileState {
  final bool exists;

  /// Discovery didn't finish in time (iCloud still gathering metadata).
  final bool discoveryTimedOut;
  final CloudDownloadStatus downloadStatus;
  final bool isUploaded;
  final bool isUploading;
  final bool isDownloading;
  final DateTime? modifiedAt;
  final String? uploadError;
  final String? downloadError;

  const CloudFileState({
    required this.exists,
    this.discoveryTimedOut = false,
    this.downloadStatus = CloudDownloadStatus.unknown,
    this.isUploaded = false,
    this.isUploading = false,
    this.isDownloading = false,
    this.modifiedAt,
    this.uploadError,
    this.downloadError,
  });

  factory CloudFileState.fromMap(Map<dynamic, dynamic> m) {
    final ms = m['modifiedAt'];
    return CloudFileState(
      exists: m['exists'] == true,
      discoveryTimedOut: m['discoveryTimedOut'] == true,
      downloadStatus: switch (m['downloadStatus']) {
        'current' => CloudDownloadStatus.current,
        'downloaded' => CloudDownloadStatus.downloaded,
        'notDownloaded' => CloudDownloadStatus.notDownloaded,
        _ => CloudDownloadStatus.unknown,
      },
      isUploaded: m['isUploaded'] == true,
      isUploading: m['isUploading'] == true,
      isDownloading: m['isDownloading'] == true,
      modifiedAt: ms is int ? DateTime.fromMillisecondsSinceEpoch(ms) : null,
      uploadError: m['uploadError'] as String?,
      downloadError: m['downloadError'] as String?,
    );
  }
}

class CloudReadResult {
  final String content;
  final CloudFileState state;
  const CloudReadResult(this.content, this.state);
}

class CloudWriteResult {
  /// iCloud confirmed the new file reached the server.
  final bool isUploaded;
  final bool isUploading;
  final String? uploadError;
  const CloudWriteResult({required this.isUploaded, this.isUploading = false, this.uploadError});
}

enum ICloudStorageErrorCode {
  notSignedIn,
  containerUnavailable,
  unsupportedPlatform,
  noBackup,

  /// File metadata exists, contents not downloaded yet.
  downloadPending,

  /// iCloud still gathering/syncing; existence unknown.
  syncInProgress,
  readFailed,
  writeFailed,

  /// Written bytes didn't match on read-back; previous backup kept.
  verifyFailed,
}

class ICloudStorageException implements Exception {
  final ICloudStorageErrorCode code;
  final String message;
  const ICloudStorageException(this.code, this.message);

  @override
  String toString() => 'ICloudStorageException(${code.name}): $message';
}

/// Moves the backup JSON to/from the app's iCloud container. Knows nothing
/// about the backup format (that's `BackupService`). Injectable for tests.
abstract class ICloudBackupStorage {
  Future<ICloudAvailability> availability();
  Future<CloudFileState> inspectLatest();

  /// Ensures the newest version is downloaded, then returns its contents.
  Future<CloudReadResult> readLatest({Duration timeout});

  /// Safe replace: temp file → verify → replace canonical → verify.
  /// On failure the previous backup is left as it was.
  Future<CloudWriteResult> writeLatest(String json);
}

/// iOS implementation over `ios/Runner/ICloudBackupPlugin.swift`.
class MethodChannelICloudBackupStorage implements ICloudBackupStorage {
  static const _channel = MethodChannel('doni_money/icloud_backup');

  const MethodChannelICloudBackupStorage();

  bool get _supported => Platform.isIOS;

  @override
  Future<ICloudAvailability> availability() async {
    if (!_supported) return ICloudAvailability.unsupportedPlatform;
    final r = await _call<Map>('status');
    return switch (r?['state']) {
      'available' => ICloudAvailability.available,
      'notSignedIn' => ICloudAvailability.notSignedIn,
      _ => ICloudAvailability.containerUnavailable,
    };
  }

  @override
  Future<CloudFileState> inspectLatest() async {
    _requireSupported();
    return CloudFileState.fromMap(await _call<Map>('inspect') ?? const {});
  }

  @override
  Future<CloudReadResult> readLatest({Duration timeout = const Duration(seconds: 30)}) async {
    _requireSupported();
    final r = await _call<Map>('read', {'timeoutSeconds': timeout.inMilliseconds / 1000});
    final content = r?['content'];
    if (content is! String) {
      throw const ICloudStorageException(ICloudStorageErrorCode.readFailed, 'No content returned');
    }
    return CloudReadResult(content, CloudFileState.fromMap(r!));
  }

  @override
  Future<CloudWriteResult> writeLatest(String json) async {
    _requireSupported();
    final r = await _call<Map>('write', {'json': json});
    return CloudWriteResult(
      isUploaded: r?['isUploaded'] == true,
      isUploading: r?['isUploading'] == true,
      uploadError: r?['uploadError'] as String?,
    );
  }

  void _requireSupported() {
    if (!_supported) {
      throw const ICloudStorageException(
          ICloudStorageErrorCode.unsupportedPlatform, 'iCloud backup is iOS only');
    }
  }

  Future<T?> _call<T>(String method, [Map<String, dynamic>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw ICloudStorageException(_code(e.code), e.message ?? e.code);
    } on MissingPluginException {
      throw const ICloudStorageException(
          ICloudStorageErrorCode.unsupportedPlatform, 'iCloud bridge not available');
    }
  }

  static ICloudStorageErrorCode _code(String c) => switch (c) {
        'notSignedIn' => ICloudStorageErrorCode.notSignedIn,
        'containerUnavailable' => ICloudStorageErrorCode.containerUnavailable,
        'noBackup' => ICloudStorageErrorCode.noBackup,
        'downloadPending' => ICloudStorageErrorCode.downloadPending,
        'syncInProgress' => ICloudStorageErrorCode.syncInProgress,
        'writeFailed' || 'badArgs' => ICloudStorageErrorCode.writeFailed,
        'verifyFailed' => ICloudStorageErrorCode.verifyFailed,
        _ => ICloudStorageErrorCode.readFailed,
      };
}
