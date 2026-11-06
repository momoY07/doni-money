import 'backup_service.dart';
import 'icloud_backup_storage.dart';

/// Every state the iCloud backup UI can show / every way an action can fail.
enum ICloudBackupIssue {
  premiumRequired,
  notSignedIn,
  containerUnavailable,
  unsupportedPlatform,
  noBackup,

  /// The backup exists in iCloud but its contents aren't on this iPhone yet.
  downloadPending,

  /// iCloud is still syncing; we can't tell yet whether a backup exists.
  syncInProgress,

  /// The cloud file isn't a valid Doni Money backup.
  corrupted,

  /// Made by a newer app version (unsupported schemaVersion).
  unsupportedVersion,
  readFailed,
  writeFailed,

  /// Local restore failed; existing data was kept.
  restoreFailed,
}

class ICloudBackupException implements Exception {
  final ICloudBackupIssue issue;
  final String message;
  const ICloudBackupException(this.issue, this.message);

  @override
  String toString() => 'ICloudBackupException(${issue.name}): $message';
}

/// Result of [ICloudBackupService.loadStatus]. Exactly one of [backup] or
/// [issue] is set.
class ICloudBackupStatus {
  final ICloudBackupIssue? issue;

  /// Metadata comes from the backup itself (createdAt, appVersion,
  /// transaction count, schemaVersion) — no separate metadata file.
  final ValidatedBackup? backup;
  final bool isUploaded;
  final bool isUploading;

  /// iCloud's modification date of the file (useful while downloading).
  final DateTime? cloudModifiedAt;

  const ICloudBackupStatus.ready(
    ValidatedBackup this.backup, {
    this.isUploaded = false,
    this.isUploading = false,
    this.cloudModifiedAt,
  }) : issue = null;

  const ICloudBackupStatus.problem(ICloudBackupIssue this.issue, {this.cloudModifiedAt})
      : backup = null,
        isUploaded = false,
        isUploading = false;

  bool get hasBackup => backup != null;
}

/// A downloaded, validated cloud backup awaiting the user's confirmation.
class PreparedCloudRestore {
  final String rawJson;
  final ValidatedBackup backup;
  const PreparedCloudRestore(this.rawJson, this.backup);
}

/// Manual Premium iCloud backup (Phase 1). Platform-independent flow logic;
/// all bytes go through [ICloudBackupStorage], all format work through
/// [BackupService]. No automatic/background backup here.
class ICloudBackupService {
  final ICloudBackupStorage storage;
  final BackupService backupService;
  final bool Function() isPremium;

  /// How long a status check waits for a not-yet-downloaded backup.
  final Duration statusReadTimeout;

  /// How long restore waits for the download before giving up.
  final Duration restoreReadTimeout;

  ICloudBackupService({
    required this.storage,
    required this.backupService,
    required this.isPremium,
    this.statusReadTimeout = const Duration(seconds: 10),
    this.restoreReadTimeout = const Duration(seconds: 45),
  });

  /// Latest backup info for Settings. Never throws.
  Future<ICloudBackupStatus> loadStatus() async {
    if (!isPremium()) return const ICloudBackupStatus.problem(ICloudBackupIssue.premiumRequired);
    DateTime? modifiedAt;
    try {
      await _requireAvailable();
      final state = await storage.inspectLatest();
      if (!state.exists) {
        return ICloudBackupStatus.problem(
            state.discoveryTimedOut ? ICloudBackupIssue.syncInProgress : ICloudBackupIssue.noBackup);
      }
      modifiedAt = state.modifiedAt;
      final read = await storage.readLatest(timeout: statusReadTimeout);
      final backup = _validate(read.content);
      return ICloudBackupStatus.ready(
        backup,
        isUploaded: read.state.isUploaded,
        isUploading: read.state.isUploading,
        cloudModifiedAt: read.state.modifiedAt ?? modifiedAt,
      );
    } on ICloudBackupException catch (e) {
      return ICloudBackupStatus.problem(e.issue, cloudModifiedAt: modifiedAt);
    } on ICloudStorageException catch (e) {
      return ICloudBackupStatus.problem(_fromStorage(e).issue, cloudModifiedAt: modifiedAt);
    } catch (_) {
      return ICloudBackupStatus.problem(ICloudBackupIssue.readFailed, cloudModifiedAt: modifiedAt);
    }
  }

  /// Back Up Now. Only a backup that passes [BackupService.validateBackup]
  /// is ever handed to storage, so a known-good cloud backup can't be
  /// replaced by invalid data.
  Future<CloudWriteResult> backUpNow({String? appVersion}) async {
    _requirePremium();
    await _requireAvailable();

    final String json;
    try {
      // createBackupJson self-validates; validate the exact bytes again.
      json = backupService.createBackupJson(appVersion: appVersion);
      backupService.validateBackup(json);
    } on BackupException catch (e) {
      throw ICloudBackupException(ICloudBackupIssue.writeFailed, 'Local backup invalid: ${e.message}');
    } catch (e) {
      // Unreadable local data: never upload anything.
      throw ICloudBackupException(ICloudBackupIssue.writeFailed, 'Could not create backup: $e');
    }

    try {
      return await storage.writeLatest(json);
    } on ICloudStorageException catch (e) {
      throw _fromStorage(e);
    }
  }

  /// Steps 1–3 of restore: find, download, validate. Writes nothing.
  Future<PreparedCloudRestore> prepareRestore() async {
    _requirePremium();
    await _requireAvailable();
    final CloudReadResult read;
    try {
      read = await storage.readLatest(timeout: restoreReadTimeout);
    } on ICloudStorageException catch (e) {
      throw _fromStorage(e);
    }
    return PreparedCloudRestore(read.content, _validate(read.content));
  }

  /// After the user confirmed. Uses the same restore path as file restore
  /// (validate → prepare → single putAll, rollback on failure).
  Future<ValidatedBackup> restore(PreparedCloudRestore prepared) async {
    _requirePremium();
    try {
      return await backupService.restoreBackup(prepared.rawJson);
    } on BackupException catch (e) {
      throw ICloudBackupException(ICloudBackupIssue.restoreFailed, e.message);
    }
  }

  // ───────────────────────────── helpers ─────────────────────────────

  void _requirePremium() {
    if (!isPremium()) {
      throw const ICloudBackupException(ICloudBackupIssue.premiumRequired, 'Premium required');
    }
  }

  Future<void> _requireAvailable() async {
    final a = await storage.availability();
    switch (a) {
      case ICloudAvailability.available:
        return;
      case ICloudAvailability.notSignedIn:
        throw const ICloudBackupException(ICloudBackupIssue.notSignedIn, 'iCloud unavailable');
      case ICloudAvailability.containerUnavailable:
        throw const ICloudBackupException(
            ICloudBackupIssue.containerUnavailable, 'iCloud container unavailable');
      case ICloudAvailability.unsupportedPlatform:
        throw const ICloudBackupException(ICloudBackupIssue.unsupportedPlatform, 'iOS only');
    }
  }

  ValidatedBackup _validate(String content) {
    try {
      return backupService.validateBackup(content);
    } on BackupException catch (e) {
      throw ICloudBackupException(
        e.code == BackupErrorCode.unsupportedSchemaVersion
            ? ICloudBackupIssue.unsupportedVersion
            : ICloudBackupIssue.corrupted,
        e.message,
      );
    }
  }

  ICloudBackupException _fromStorage(ICloudStorageException e) {
    final issue = switch (e.code) {
      ICloudStorageErrorCode.notSignedIn => ICloudBackupIssue.notSignedIn,
      ICloudStorageErrorCode.containerUnavailable => ICloudBackupIssue.containerUnavailable,
      ICloudStorageErrorCode.unsupportedPlatform => ICloudBackupIssue.unsupportedPlatform,
      ICloudStorageErrorCode.noBackup => ICloudBackupIssue.noBackup,
      ICloudStorageErrorCode.downloadPending => ICloudBackupIssue.downloadPending,
      ICloudStorageErrorCode.syncInProgress => ICloudBackupIssue.syncInProgress,
      ICloudStorageErrorCode.readFailed => ICloudBackupIssue.readFailed,
      ICloudStorageErrorCode.writeFailed ||
      ICloudStorageErrorCode.verifyFailed =>
        ICloudBackupIssue.writeFailed,
    };
    return ICloudBackupException(issue, e.message);
  }
}
