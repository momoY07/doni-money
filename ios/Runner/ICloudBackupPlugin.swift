import Flutter
import Foundation

/// Native transport for the Premium iCloud backup (Phase 1: manual only).
///
/// Stores one app-managed file, `Backups/latest-backup.json`, in the app's
/// own iCloud ubiquity container. It is outside `Documents/`, so it is not
/// shown in the Files app (user-visible exports stay with "Backup to File").
///
/// This class only moves bytes. Serialization/validation/restore live in the
/// Dart `BackupService`; the Dart `ICloudBackupService` drives the flow.
///
/// Channel `doni_money/icloud_backup`:
///   status()                 -> {state: available|notSignedIn|containerUnavailable}
///   inspect()                -> file state (see `fileState`)
///   read({timeoutSeconds})   -> {content, ...file state}  (downloads first)
///   write({json})            -> {isUploaded, isUploading, uploadError?}
/// Errors are FlutterError with codes:
///   notSignedIn, containerUnavailable, noBackup, syncInProgress,
///   downloadPending, readFailed, writeFailed, verifyFailed, badArgs
final class ICloudBackupPlugin: NSObject, FlutterPlugin {
  static let channelName = "doni_money/icloud_backup"
  static let containerIdentifier = "iCloud.com.sungwoong.easyfinancialledger"
  static let folderName = "Backups"
  static let fileName = "latest-backup.json"

  /// Serial: never two reads/writes of the backup at the same time.
  private let queue = DispatchQueue(label: "doni_money.icloud_backup", qos: .userInitiated)
  private var cachedContainerURL: URL?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(ICloudBackupPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    queue.async {
      let reply: Any?
      do {
        switch call.method {
        case "status":
          reply = self.status()
        case "inspect":
          reply = try self.inspect()
        case "read":
          let timeout = (args["timeoutSeconds"] as? NSNumber)?.doubleValue ?? 30
          reply = try self.read(timeout: timeout)
        case "write":
          guard let json = args["json"] as? String, !json.isEmpty else {
            throw BridgeError("badArgs", "Missing backup JSON")
          }
          reply = try self.write(json: json)
        default:
          reply = FlutterMethodNotImplemented
        }
      } catch let e as BridgeError {
        reply = FlutterError(code: e.code, message: e.message, details: nil)
      } catch {
        reply = FlutterError(code: "readFailed", message: error.localizedDescription, details: nil)
      }
      DispatchQueue.main.async { result(reply) }
    }
  }

  // MARK: - Availability

  private struct BridgeError: Error {
    let code: String
    let message: String
    init(_ code: String, _ message: String) { self.code = code; self.message = message }
  }

  private func status() -> [String: Any] {
    // nil when no Apple Account is signed in to iCloud or iCloud Drive is off.
    if FileManager.default.ubiquityIdentityToken == nil {
      cachedContainerURL = nil
      return ["state": "notSignedIn"]
    }
    if containerURL() == nil { return ["state": "containerUnavailable"] }
    return ["state": "available"]
  }

  /// Must not run on the main thread (can block while iCloud initializes).
  private func containerURL() -> URL? {
    if let url = cachedContainerURL { return url }
    let url = FileManager.default.url(forUbiquityContainerIdentifier: Self.containerIdentifier)
    cachedContainerURL = url
    return url
  }

  private func requireBackupsDir() throws -> URL {
    switch status()["state"] as? String {
    case "notSignedIn": throw BridgeError("notSignedIn", "iCloud is not available")
    case "containerUnavailable": throw BridgeError("containerUnavailable", "iCloud container unavailable")
    default: break
    }
    guard let container = containerURL() else {
      throw BridgeError("containerUnavailable", "iCloud container unavailable")
    }
    return container.appendingPathComponent(Self.folderName, isDirectory: true)
  }

  // MARK: - Discovery

  /// Uses NSMetadataQuery so a backup another device uploaded is found even
  /// before its contents are downloaded to this iPhone.
  private func discover(in dir: URL, timeout: TimeInterval) -> (item: [String: Any]?, timedOut: Bool) {
    let semaphore = DispatchSemaphore(value: 0)
    var found: [String: Any]?
    var finished = false
    var query: NSMetadataQuery?
    var observer: NSObjectProtocol?

    DispatchQueue.main.async {
      let q = NSMetadataQuery()
      q.searchScopes = [NSMetadataQueryUbiquitousDataScope]
      q.predicate = NSPredicate(format: "%K == %@", NSMetadataItemFSNameKey, Self.fileName)
      observer = NotificationCenter.default.addObserver(
        forName: .NSMetadataQueryDidFinishGathering, object: q, queue: .main
      ) { _ in
        q.disableUpdates()
        let expected = dir.appendingPathComponent(Self.fileName).standardizedFileURL.path
        for case let item as NSMetadataItem in q.results {
          guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL,
                url.standardizedFileURL.path == expected else { continue }
          found = Self.metadataState(item, url: url)
          break
        }
        finished = true
        q.stop()
        if let o = observer { NotificationCenter.default.removeObserver(o) }
        semaphore.signal()
      }
      query = q
      if !q.start() {
        if let o = observer { NotificationCenter.default.removeObserver(o) }
        semaphore.signal()
      }
    }

    let waited = semaphore.wait(timeout: .now() + timeout)
    if waited == .timedOut {
      DispatchQueue.main.async {
        query?.stop()
        if let o = observer { NotificationCenter.default.removeObserver(o) }
      }
    }
    return (found, waited == .timedOut || !finished)
  }

  private static func metadataState(_ item: NSMetadataItem, url: URL) -> [String: Any] {
    var s: [String: Any] = ["exists": true, "path": url.path]
    if let status = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String {
      s["downloadStatus"] = downloadStatusName(status)
    }
    s["isUploaded"] = (item.value(forAttribute: NSMetadataUbiquitousItemIsUploadedKey) as? NSNumber)?.boolValue ?? false
    s["isUploading"] = (item.value(forAttribute: NSMetadataUbiquitousItemIsUploadingKey) as? NSNumber)?.boolValue ?? false
    s["isDownloading"] = (item.value(forAttribute: NSMetadataUbiquitousItemIsDownloadingKey) as? NSNumber)?.boolValue ?? false
    if let date = item.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date {
      s["modifiedAt"] = Int(date.timeIntervalSince1970 * 1000)
    }
    if let err = item.value(forAttribute: NSMetadataUbiquitousItemUploadingErrorKey) as? NSError {
      s["uploadError"] = err.localizedDescription
    }
    if let err = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingErrorKey) as? NSError {
      s["downloadError"] = err.localizedDescription
    }
    return s
  }

  private static func downloadStatusName(_ raw: String) -> String {
    switch raw {
    case NSMetadataUbiquitousItemDownloadingStatusCurrent: return "current"
    case NSMetadataUbiquitousItemDownloadingStatusDownloaded: return "downloaded"
    case NSMetadataUbiquitousItemDownloadingStatusNotDownloaded: return "notDownloaded"
    default: return "unknown"
    }
  }

  /// URL resource values for a file this device already knows about.
  private func resourceState(_ url: URL) -> [String: Any]? {
    var u = url
    u.removeAllCachedResourceValues()
    let keys: Set<URLResourceKey> = [
      .ubiquitousItemDownloadingStatusKey, .ubiquitousItemIsUploadedKey,
      .ubiquitousItemIsUploadingKey, .ubiquitousItemIsDownloadingKey,
      .ubiquitousItemUploadingErrorKey, .ubiquitousItemDownloadingErrorKey,
      .contentModificationDateKey,
    ]
    guard let v = try? u.resourceValues(forKeys: keys) else { return nil }
    var s: [String: Any] = ["exists": true, "path": url.path]
    if let st = v.ubiquitousItemDownloadingStatus { s["downloadStatus"] = Self.downloadStatusName(st.rawValue) }
    s["isUploaded"] = v.ubiquitousItemIsUploaded ?? false
    s["isUploading"] = v.ubiquitousItemIsUploading ?? false
    s["isDownloading"] = v.ubiquitousItemIsDownloading ?? false
    if let d = v.contentModificationDate { s["modifiedAt"] = Int(d.timeIntervalSince1970 * 1000) }
    if let e = v.ubiquitousItemUploadingError { s["uploadError"] = e.localizedDescription }
    if let e = v.ubiquitousItemDownloadingError { s["downloadError"] = e.localizedDescription }
    return s
  }

  private func inspect() throws -> [String: Any] {
    let dir = try requireBackupsDir()
    let fileURL = dir.appendingPathComponent(Self.fileName)
    let (item, timedOut) = discover(in: dir, timeout: 10)
    if let item = item { return item }
    // Metadata index can lag a write made moments ago on this device.
    if FileManager.default.fileExists(atPath: fileURL.path), let s = resourceState(fileURL) { return s }
    return ["exists": false, "discoveryTimedOut": timedOut]
  }

  // MARK: - Read

  private func read(timeout: TimeInterval) throws -> [String: Any] {
    let started = Date()
    let state = try inspect()
    guard state["exists"] as? Bool == true, let path = state["path"] as? String else {
      if state["discoveryTimedOut"] as? Bool == true {
        throw BridgeError("syncInProgress", "iCloud is still gathering file information")
      }
      throw BridgeError("noBackup", "No iCloud backup")
    }
    let url = URL(fileURLWithPath: path)

    // Make sure the newest version is local before reading it.
    var current = state
    if (current["downloadStatus"] as? String) != "current" {
      try? FileManager.default.startDownloadingUbiquitousItem(at: url)
      while (current["downloadStatus"] as? String) != "current" {
        if Date().timeIntervalSince(started) > timeout {
          throw BridgeError("downloadPending", "Backup is still downloading from iCloud")
        }
        Thread.sleep(forTimeInterval: 0.5)
        current = resourceState(url) ?? current
        if current["downloadStatus"] == nil, let again = discover(in: url.deletingLastPathComponent(), timeout: 5).item {
          current = again
        }
      }
    }

    let data = try coordinatedRead(url)
    guard let content = String(data: data, encoding: .utf8) else {
      throw BridgeError("readFailed", "Backup is not UTF-8 text")
    }
    var out = current
    out["content"] = content
    return out
  }

  private func coordinatedRead(_ url: URL) throws -> Data {
    var coordError: NSError?
    var data: Data?
    var readError: Error?
    NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &coordError) { u in
      do { data = try Data(contentsOf: u) } catch { readError = error }
    }
    if let e = coordError ?? (readError as NSError?) {
      throw BridgeError("readFailed", e.localizedDescription)
    }
    guard let d = data else { throw BridgeError("readFailed", "Empty read") }
    return d
  }

  // MARK: - Write (temp → verify → replace → verify)

  private func write(json: String) throws -> [String: Any] {
    let dir = try requireBackupsDir()
    let data = Data(json.utf8)
    let finalURL = dir.appendingPathComponent(Self.fileName)
    let tempURL = dir.appendingPathComponent(".latest-backup-\(UUID().uuidString).tmp")
    let fm = FileManager.default
    defer { try? fm.removeItem(at: tempURL) }

    do {
      try fm.createDirectory(at: dir, withIntermediateDirectories: true)
    } catch {
      throw BridgeError("writeFailed", error.localizedDescription)
    }

    // 1. Write the new backup to a temp file next to the canonical one.
    var coordError: NSError?
    var writeError: Error?
    NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: tempURL, options: .forReplacing, error: &coordError) { u in
      do { try data.write(to: u, options: .atomic) } catch { writeError = error }
    }
    if let e = coordError ?? (writeError as NSError?) {
      throw BridgeError("writeFailed", e.localizedDescription)
    }

    // 2. Verify the temp file byte-for-byte before touching the good backup.
    guard (try? coordinatedRead(tempURL)) == data else {
      throw BridgeError("verifyFailed", "Temporary backup did not verify")
    }

    // 3. Swap it into place. replaceItemAt keeps the old file if it fails.
    coordError = nil
    writeError = nil
    NSFileCoordinator(filePresenter: nil).coordinate(
      writingItemAt: tempURL, options: .forMoving,
      writingItemAt: finalURL, options: .forReplacing,
      error: &coordError
    ) { src, dst in
      do {
        if fm.fileExists(atPath: dst.path) {
          _ = try fm.replaceItemAt(dst, withItemAt: src)
        } else {
          try fm.moveItem(at: src, to: dst)
        }
      } catch {
        writeError = error
      }
    }
    if let e = coordError ?? (writeError as NSError?) {
      throw BridgeError("writeFailed", e.localizedDescription)
    }

    // 4. Verify the canonical file.
    guard (try? coordinatedRead(finalURL)) == data else {
      throw BridgeError("verifyFailed", "Saved backup did not verify")
    }

    // 5. Report upload progress as far as iCloud tells us (bounded wait).
    var state = resourceState(finalURL) ?? [:]
    let deadline = Date().addingTimeInterval(8)
    while state["isUploaded"] as? Bool != true, state["uploadError"] == nil, Date() < deadline {
      Thread.sleep(forTimeInterval: 0.5)
      state = resourceState(finalURL) ?? state
    }
    var out: [String: Any] = [
      "isUploaded": state["isUploaded"] as? Bool ?? false,
      "isUploading": state["isUploading"] as? Bool ?? false,
    ]
    if let e = state["uploadError"] { out["uploadError"] = e }
    return out
  }
}
