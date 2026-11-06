import '../services/backup_service.dart';
import '../services/icloud_backup_service.dart';
import 'i18n.dart';

/// User-facing text for an iCloud backup state/failure.
String icloudIssueText(ICloudBackupIssue issue, String language) {
  final key = switch (issue) {
    ICloudBackupIssue.premiumRequired => 'premium_locked_hint',
    ICloudBackupIssue.notSignedIn => 'icloud_not_signed_in',
    ICloudBackupIssue.containerUnavailable => 'icloud_container_unavailable',
    ICloudBackupIssue.unsupportedPlatform => 'icloud_unsupported_platform',
    ICloudBackupIssue.noBackup => 'icloud_no_backup',
    ICloudBackupIssue.downloadPending => 'icloud_downloading',
    ICloudBackupIssue.syncInProgress => 'icloud_syncing',
    ICloudBackupIssue.corrupted => 'icloud_corrupt',
    ICloudBackupIssue.unsupportedVersion => 'icloud_unsupported_version',
    ICloudBackupIssue.readFailed => 'icloud_read_failed',
    ICloudBackupIssue.writeFailed => 'icloud_write_failed',
    ICloudBackupIssue.restoreFailed => 'backup_err_storage',
  };
  return t(key, language);
}

/// e.g. `2026-11-04 13:05 · 13 transactions`.
String backupSummaryText(ValidatedBackup b, String language) {
  final parts = <String>[];
  final c = b.createdAt?.toLocal();
  if (c != null) {
    String two(int v) => v.toString().padLeft(2, '0');
    parts.add('${c.year}-${two(c.month)}-${two(c.day)} ${two(c.hour)}:${two(c.minute)}');
  }
  parts.add('${b.transactions.length} ${t('backup_transactions', language)}');
  return parts.join(' · ');
}
