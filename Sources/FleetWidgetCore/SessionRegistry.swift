import Foundation

/// Reads Claude Code's live session registry from `~/.claude/sessions/`.
///
/// Polled on a timer rather than watched. The registry files are replaced by
/// atomic rename, so a watch bound to a file's inode keeps watching the old,
/// unlinked inode and silently stops updating — a failure that presents as a
/// frozen widget with no error. Re-reading a handful of small files is cheap and
/// has no such failure mode.
public final class SessionRegistry {
    public static var defaultDirectory: URL {
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent("sessions", isDirectory: true)
    }

    private let directory: URL
    private let liveness: SessionLiveness
    private let fileManager: FileManager
    private let decoder = JSONDecoder()

    /// Last successfully decoded record per file name. A record caught mid-write
    /// falls back to this so the session holds its previous state instead of
    /// blinking out of the widget for a tick.
    private var lastGood: [String: SessionRecord] = [:]

    public init(
        directory: URL = SessionRegistry.defaultDirectory,
        checker: ProcessLivenessChecking = SystemProcessLiveness(),
        fileManager: FileManager = .default
    ) {
        self.directory = directory
        self.liveness = SessionLiveness(checker: checker)
        self.fileManager = fileManager
    }

    /// Reads the registry once and returns the sessions confirmed live.
    ///
    /// Ordering is by session start time, then pid. This is stable across status
    /// changes, so a row never jumps position in the widget when its state moves.
    public func poll() -> [LiveSession] {
        let files = registryFiles()
        if files.isEmpty {
            lastGood.removeAll()
            return []
        }

        var seen = Set<String>()
        var live: [SessionRecord] = []

        for url in files {
            let key = url.lastPathComponent
            seen.insert(key)

            // A record that fails to decode is not an error worth surfacing —
            // it is almost always a read that landed mid-write. Fall back to the
            // last good copy for this file; skip only if there has never been one.
            var record = decodeRecord(at: url)
            if record == nil { record = lastGood[key] }
            guard let resolved = record else { continue }

            lastGood[key] = resolved

            guard liveness.isLive(resolved) else {
                lastGood.removeValue(forKey: key)
                continue
            }
            live.append(resolved)
        }

        // Drop cache entries whose files are gone, so a pid that later reappears
        // cannot inherit a stale record.
        for key in lastGood.keys where !seen.contains(key) {
            lastGood.removeValue(forKey: key)
        }

        live.sort { lhs, rhs in
            let l = lhs.startedAt ?? 0
            let r = rhs.startedAt ?? 0
            if l != r { return l < r }
            return lhs.pid < rhs.pid
        }
        return live.map { LiveSession(record: $0) }
    }

    /// Registry files, or an empty list when the directory is missing or
    /// unreadable — the normal state before Claude Code has ever run.
    private func registryFiles() -> [URL] {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return entries.filter { $0.pathExtension == "json" }
    }

    private func decodeRecord(at url: URL) -> SessionRecord? {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return nil }
        return try? decoder.decode(SessionRecord.self, from: data)
    }
}
