import Foundation
import Darwin

enum ComponentKind: String, CaseIterable { case skill, agent, mcp, rag }

struct ComponentReference: Hashable {
    let target: String
    let relation: String
    let line: Int?
    let isExternal: Bool

    init(target: String, relation: String, line: Int?, isExternal: Bool = false) {
        self.target = target; self.relation = relation; self.line = line; self.isExternal = isExternal
    }

    func matchingComponents(in components: [LocalSkill]) -> [LocalSkill] {
        guard !isExternal else { return [] }
        let target = self.target.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = target.split(separator: ":", maxSplits: 1).map(String.init)
        return components.filter { item in
            item.id == target || item.name.caseInsensitiveCompare(target) == .orderedSame ||
            (parts.count == 2 && item.kind.rawValue == parts[0] && item.name.caseInsensitiveCompare(parts[1]) == .orderedSame)
        }
    }
}

struct MetadataFinding: Identifiable, Hashable {
    let id: String
    let code: String
    let severity: String
    let evidence: String
    let line: Int?
}

struct SkillLocation: Hashable {
    let path: String
    let root: String
    let viaSymlink: Bool
}

struct LocalSkill: Identifiable, Hashable {
    let id: String
    let name: String
    let summary: String
    let filePath: String
    let canonicalPath: String
    let locations: [SkillLocation]
    let issues: [String]
    let modifiedAt: Date?
    let kind: ComponentKind
    let references: [ComponentReference]
    let findings: [MetadataFinding]
    let fingerprint: String
    let discovery: String
    let summaryKey: String

    init(id: String, name: String, summary: String, filePath: String, canonicalPath: String,
         locations: [SkillLocation], issues: [String], modifiedAt: Date?, kind: ComponentKind = .skill,
         references: [ComponentReference] = [], findings: [MetadataFinding] = [],
         fingerprint: String = "", discovery: String = "metadata", summaryKey: String = "") {
        self.id = id; self.name = name; self.summary = summary; self.filePath = filePath
        self.canonicalPath = canonicalPath; self.locations = locations; self.issues = issues
        self.modifiedAt = modifiedAt; self.kind = kind; self.references = references
        self.findings = findings; self.fingerprint = fingerprint; self.discovery = discovery
        self.summaryKey = summaryKey
    }
}

struct ScanNotice: Identifiable, Hashable {
    let id: String
    let code: String
    let path: String
}

struct LocalInventory {
    let skills: [LocalSkill]
    let notices: [ScanNotice]
    let scannedAt: Date
    let roots: [String]
    let scanPaths: [String]
    let limited: Bool
    static var empty: LocalInventory {
        LocalInventory(skills: [], notices: [], scannedAt: Date(), roots: [], scanPaths: [], limited: false)
    }
}

struct ScanLimits {
    var maxDepth: Int = 12
    var maxDirectories: Int = 10000
    var maxSkills: Int = 5000
    var maxHeaderBytes: Int = 65536
    var maxTotalBytes: Int = 33554432
    var maxSeconds: Double = 5
}

enum SkillScanner {
    static func scan(roots: [String], limits: ScanLimits = ScanLimits()) -> LocalInventory {
        ScanSession(roots: roots, limits: limits).run()
    }
}

private final class ScanSession {
    private struct Anchor {
        let path: String
        let fd: Int32
        let device: dev_t
        let inode: ino_t
    }
    private struct Opened {
        let fd: Int32
        let path: String
        let linked: Bool
    }
    private let roots: [String]
    private let limits: ScanLimits
    private let started = ProcessInfo.processInfo.systemUptime
    private var anchors: [Anchor] = []
    private var records: [String: LocalSkill] = [:]
    private var recordIDsByFile: [String: [String]] = [:]
    private var notices: [ScanNotice] = []
    private var noticeKeys = Set<String>()
    private var scanPaths: [String] = []
    private var directories = 0
    private var bytesRead = 0
    private var limited = false
    private static let excluded: Set<String> = [
        ".git", ".ssh", ".aws", ".gnupg", ".venv", "node_modules",
        "models", "weights", "local-llm", "build", "dist", "cache", ".cache",
        "secrets", "credentials", ".credentials", ".env", "logs", ".logs"
    ]

    init(roots: [String], limits: ScanLimits) {
        self.roots = roots
        self.limits = limits
    }

    deinit { for anchor in anchors { close(anchor.fd) } }

    func run() -> LocalInventory {
        for requested in roots {
            guard !requested.isEmpty else { notice("missing_root", requested); continue }
            let path = normalized(requested)
            if isExcluded(path) {
                notice("outside_scope", requested)
                continue
            }
            let fd = Self.openDirectory(path)
            if fd < 0 {
                let openError = errno
                var info = stat()
                let exists = lstat(path, &info) == 0
                let code = openError == ELOOP || (exists && isLink(info)) ? "outside_scope" :
                    (exists || (openError != ENOENT && openError != ENOTDIR) ? "unreadable_root" : "missing_root")
                notice(code, requested)
                continue
            }
            var info = stat()
            guard fstat(fd, &info) == 0, let actual = descriptorPath(fd), actual == path else {
                close(fd)
                notice("changed_during_read", requested)
                continue
            }
            anchors.append(Anchor(path: path, fd: fd, device: info.st_dev, inode: info.st_ino))
        }
        for anchor in anchors {
            if !timeAvailable(anchor.path) { break }
            // All supported component metadata is beneath the selected root.
            let path = anchor.path
            scanPaths.append(path)
            guard let opened = resolve(path, display: path) else { continue }
            defer { close(opened.fd) }
            walk(opened, display: path, root: anchor.path, depth: 0, ancestors: [])
        }
        return LocalInventory(
            skills: records.values.sorted { $0.id < $1.id }, notices: notices,
            scannedAt: Date(), roots: roots, scanPaths: scanPaths, limited: limited
        )
    }

    private func walk(_ opened: Opened, display: String, root: String, depth: Int, ancestors: Set<String>) {
        guard timeAvailable(display) else { return }
        guard depth <= max(0, limits.maxDepth), directories < max(0, limits.maxDirectories) else {
            limit(display); return
        }
        guard descriptorPath(opened.fd) == opened.path else { notice("changed_during_read", display); return }
        var info = stat()
        guard fstat(opened.fd, &info) == 0, isDirectory(info) else { notice("unreadable_root", display); return }
        let identity = "\(info.st_dev):\(info.st_ino)"
        guard !ancestors.contains(identity) else { notice("symlink_cycle", display); return }
        var ancestry = ancestors
        ancestry.insert(identity)
        directories += 1
        // A fresh open file description keeps readdir's offset independent
        // from aliases and overlapping roots. fdopendir owns this descriptor.
        let duplicate = openat(opened.fd, ".", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard duplicate >= 0, let stream = fdopendir(duplicate) else {
            if duplicate >= 0 { close(duplicate) }
            notice("unreadable_root", display); return
        }
        defer { closedir(stream) }
        var names: [String] = []
        let entryCap = max(1, min(100000, max(0, min(100000, limits.maxDirectories)) + max(0, min(100000, limits.maxSkills))))
        while let entry = readdir(stream) {
            guard timeAvailable(display) else { return }
            let name = withUnsafePointer(to: &entry.pointee.d_name) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXNAMLEN) + 1) { String(cString: $0) }
            }
            if name == "." || name == ".." || Self.excluded.contains(name.lowercased()) { continue }
            if names.count >= entryCap { limit(display); break }
            names.append(name)
        }
        // Read the skill in this directory before descending into children.
        names.sort { lhs, rhs in lhs == "SKILL.md" ? rhs != "SKILL.md" : (rhs == "SKILL.md" ? false : lhs < rhs) }
        for name in names {
            guard timeAvailable(display) else { return }
            guard descriptorPath(opened.fd) == opened.path else { notice("changed_during_read", display); return }
            var child = stat()
            guard fstatat(opened.fd, name, &child, AT_SYMLINK_NOFOLLOW) == 0 else {
                notice("changed_during_read", joined(display, name)); continue
            }
            let childPath = joined(opened.path, name)
            let childDisplay = joined(display, name)
            let type = MetadataAnalysis.classify(childDisplay)
            // Unrecognized regular files are never opened. Index hints use
            // stat metadata only, with no descriptor opened for their bytes.
            if type == .indexHint && isRegular(child) {
                guard child.st_nlink == 1 else { notice("hard_link", childDisplay); continue }
                if appendLocation(canonical: childPath, display: childDisplay, root: root, linked: opened.linked) { continue }
                if descriptorPath(opened.fd) == opened.path && rootStillValid(root) {
                    record(MetadataAnalysis.indexHint(name: name), canonical: childPath, display: childDisplay,
                           root: root, linked: opened.linked, info: child)
                } else { notice("changed_during_read", childDisplay) }
                continue
            }
            if type == .indexHint && isLink(child) { notice("unsupported_file", childDisplay); continue }
            if !isDirectory(child) && !isLink(child) && type == nil { continue }
            if type != nil && !isDirectory(child) && !isLink(child) && !isRegular(child) {
                notice("unsupported_file", childDisplay); continue
            }
            guard let target = resolve(childPath, display: childDisplay, expected: child) else { continue }
            defer { close(target.fd) }
            var targetInfo = stat()
            guard fstat(target.fd, &targetInfo) == 0 else { notice("unreadable_file", childDisplay); continue }
            let linked = opened.linked || target.linked
            let located = Opened(fd: target.fd, path: target.path, linked: linked)
            if isDirectory(targetInfo) {
                walk(located, display: childDisplay, root: root, depth: depth + 1, ancestors: ancestry)
            } else if let type = type {
                guard MetadataAnalysis.classify(target.path) == type else { notice("unsupported_file", childDisplay); continue }
                if type == .skill || type == .agent {
                    readSkill(located, display: childDisplay, root: root, info: targetInfo, kind: type == .agent ? .agent : .skill)
                } else if type == .mcp || type == .rag {
                    readConfiguration(located, display: childDisplay, root: root, info: targetInfo, type: type)
                }
            }
        }
    }

    // Resolve within already selected, no-follow root descriptors. A symlink
    // restarts resolution only after its lexical target passes the scope test.
    private func resolve(_ path: String, display: String, links: Set<String> = [], linked: Bool = false, expected: stat? = nil) -> Opened? {
        guard timeAvailable(display) else { return nil }
        let path = normalized(path)
        guard !isExcluded(path), let anchor = anchors.filter({ inside(path, $0.path) }).max(by: { $0.path.count < $1.path.count }) else {
            notice("outside_scope", display); return nil
        }
        let check = Self.openDirectory(anchor.path)
        guard check >= 0 else { notice("changed_during_read", display); return nil }
        var rootInfo = stat()
        let stable = fstat(check, &rootInfo) == 0 && rootInfo.st_dev == anchor.device && rootInfo.st_ino == anchor.inode
        close(check)
        guard stable, descriptorPath(anchor.fd) == anchor.path else { notice("changed_during_read", display); return nil }
        var current = dup(anchor.fd)
        guard current >= 0 else { notice("unreadable_root", display); return nil }
        var currentPath = anchor.path
        let relative = path == anchor.path ? "" : String(path.dropFirst(anchor.path.count + (anchor.path == "/" ? 0 : 1)))
        let components = relative.split(separator: "/").map(String.init)
        for (index, component) in components.enumerated() {
            var before = stat()
            guard fstatat(current, component, &before, AT_SYMLINK_NOFOLLOW) == 0 else {
                close(current); notice("unreadable_file", display); return nil
            }
            if index == components.count - 1, let expected = expected, !same(expected, before) {
                close(current); notice("changed_during_read", display); return nil
            }
            let nextPath = joined(currentPath, component)
            if isLink(before) {
                guard links.count < 40, !links.contains(nextPath) else {
                    close(current); notice("symlink_cycle", display); return nil
                }
                var buffer = [CChar](repeating: 0, count: Int(PATH_MAX) + 1)
                let count = buffer.withUnsafeMutableBufferPointer { readlinkat(current, component, $0.baseAddress!, Int(PATH_MAX)) }
                var after = stat()
                let unchanged = fstatat(current, component, &after, AT_SYMLINK_NOFOLLOW) == 0 && same(before, after)
                close(current)
                guard unchanged, count > 0, count < Int(PATH_MAX) else { notice("changed_during_read", display); return nil }
                let destination = String(decoding: buffer.prefix(count).map { UInt8(bitPattern: $0) }, as: UTF8.self)
                // Lexical normalization must not erase a possible intermediate
                // symlink before a parent step. Refuse that ambiguous spelling.
                var hasNamedComponent = false
                var ambiguousParent = false
                for part in destination.split(separator: "/") {
                    if part == ".." && hasNamedComponent { ambiguousParent = true }
                    if part != "." && part != ".." { hasNamedComponent = true }
                }
                guard !ambiguousParent else { notice("outside_scope", display); return nil }
                let target = normalized(destination.hasPrefix("/") ? destination : joined(currentPath, destination))
                guard anchors.contains(where: { inside(target, $0.path) }), !isExcluded(target) else {
                    notice("outside_scope", display); return nil
                }
                let rest = components.dropFirst(index + 1).joined(separator: "/")
                var visited = links; visited.insert(nextPath)
                return resolve(rest.isEmpty ? target : joined(target, rest), display: display, links: visited, linked: true)
            }
            guard isDirectory(before) || (index == components.count - 1 && isRegular(before)) else {
                close(current); notice("unsupported_file", display); return nil
            }
            if isRegular(before) && before.st_nlink > 1 {
                close(current); notice("hard_link", display); return nil
            }
            let flags = O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK | (isDirectory(before) ? O_DIRECTORY : 0)
            let next = openat(current, component, flags)
            close(current)
            guard next >= 0 else { notice(errno == ELOOP ? "changed_during_read" : "unreadable_file", display); return nil }
            var after = stat()
            guard fstat(next, &after) == 0, same(before, after), descriptorPath(next) == nextPath else {
                close(next); notice("changed_during_read", display); return nil
            }
            current = next
            currentPath = nextPath
        }
        return Opened(fd: current, path: currentPath, linked: linked)
    }

    private func readSkill(_ opened: Opened, display: String, root: String, info: stat, kind: ComponentKind) {
        // A metadata filename alias must not turn an unrelated file into input.
        guard isRegular(info) else { notice("unsupported_file", display); return }
        guard info.st_nlink == 1 else { notice("hard_link", display); return }
        if appendLocation(canonical: opened.path, display: display, root: root, linked: opened.linked) { return }
        guard records.count < max(0, limits.maxSkills) else { limit(display); return }
        let headerCap = max(0, min(65536, limits.maxHeaderBytes))
        var data = Data()
        var line: [UInt8] = []
        var first = true
        var closed = false
        var invalid = false
        var issues: [String] = []
        func finishLine() {
            let text = String(bytes: line, encoding: .utf8)?.trimmingCharacters(in: CharacterSet(charactersIn: "\r"))
            line.removeAll(keepingCapacity: true)
            if first {
                first = false
                if text != "---" && text != "\u{FEFF}---" { invalid = true }
            } else if text == "---" || text == "..." { closed = true }
        }
        while !closed && !invalid {
            guard timeAvailable(display) else { issues.append("scan_limit"); break }
            if info.st_size == data.count {
                if !line.isEmpty { finishLine() }
                break
            }
            if data.count >= headerCap { issues.append("oversized_header"); limit(display); break }
            if bytesRead >= max(0, limits.maxTotalBytes) { issues.append("scan_limit"); limit(display); break }
            var byte: UInt8 = 0
            let count = Darwin.read(opened.fd, &byte, 1)
            if count == 0 {
                if !line.isEmpty { finishLine() }
                break
            }
            if count < 0 { issues.append("unreadable_file"); break }
            bytesRead += 1
            data.append(byte)
            if byte == 10 { finishLine() } else { line.append(byte) }
        }
        var after = stat()
        guard fstat(opened.fd, &after) == 0, same(info, after), info.st_size == after.st_size,
              info.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec,
              info.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec,
              info.st_ctimespec.tv_sec == after.st_ctimespec.tv_sec,
              info.st_ctimespec.tv_nsec == after.st_ctimespec.tv_nsec,
              descriptorPath(opened.fd) == opened.path, rootStillValid(root) else {
            notice("changed_during_read", display); return
        }
        let parsed = closed && !invalid ? HeaderParser.parse(data) : nil
        if parsed == nil && !issues.contains("oversized_header") && !issues.contains("scan_limit") { issues.append("invalid_frontmatter") }
        if parsed?.invalid == true { issues.append("invalid_frontmatter") }
        let name = MetadataAnalysis.metadataText(parsed?.name ?? "")
        let description = MetadataAnalysis.metadataText(parsed?.description ?? "")
        if name.isEmpty { issues.append("missing_name") }
        if description.isEmpty { issues.append("missing_description") }
        let fallback = kind == .agent ? ((display as NSString).lastPathComponent as NSString).deletingPathExtension :
            ((display as NSString).deletingLastPathComponent as NSString).lastPathComponent
        record(MetadataDraft(kind: kind, name: name.isEmpty ? fallback : name, summary: description,
                             references: parsed?.references ?? [], findings: MetadataAnalysis.referenceFindings(parsed?.references ?? []), issues: issues),
               canonical: opened.path, display: display, root: root, linked: opened.linked, info: info)
    }

    private func appendLocation(canonical: String, display: String, root: String, linked: Bool) -> Bool {
        guard let ids = recordIDsByFile[canonical] else { return false }
        let location = SkillLocation(path: display, root: root, viaSymlink: linked)
        for id in ids {
            guard let previous = records[id], !previous.locations.contains(location) else { continue }
            records[id] = LocalSkill(id: previous.id, name: previous.name, summary: previous.summary,
                filePath: previous.filePath, canonicalPath: previous.canonicalPath, locations: previous.locations + [location],
                issues: previous.issues, modifiedAt: previous.modifiedAt, kind: previous.kind,
                references: previous.references, findings: previous.findings, fingerprint: previous.fingerprint,
                discovery: previous.discovery, summaryKey: previous.summaryKey)
        }
        return true
    }

    private func record(_ draft: MetadataDraft, canonical: String, display: String, root: String, linked: Bool, info: stat) {
        guard records.count < max(0, limits.maxSkills) else { limit(display); return }
        let id = canonical + draft.idSuffix
        let fileMarker = "\(info.st_size):\(info.st_mtimespec.tv_sec):\(info.st_mtimespec.tv_nsec)"
        let marker = draft.definitionDigest.isEmpty ? fileMarker : draft.definitionDigest
        let fingerprint = MetadataAnalysis.fingerprint(draft: draft, marker: marker)
        records[id] = LocalSkill(id: id, name: draft.name, summary: draft.summary, filePath: display,
            canonicalPath: canonical, locations: [SkillLocation(path: display, root: root, viaSymlink: linked)],
            issues: draft.issues, modifiedAt: Date(timeIntervalSince1970: Double(info.st_mtimespec.tv_sec) + Double(info.st_mtimespec.tv_nsec) / 1e9),
            kind: draft.kind, references: draft.references, findings: draft.findings, fingerprint: fingerprint,
            discovery: draft.discovery, summaryKey: draft.summaryKey)
        recordIDsByFile[canonical, default: []].append(id)
    }

    private func readConfiguration(_ opened: Opened, display: String, root: String, info: stat, type: MetadataFileType) {
        if appendLocation(canonical: opened.path, display: display, root: root, linked: opened.linked) { return }
        guard records.count < max(0, limits.maxSkills) else { limit(display); return }
        let cap = max(0, min(65536, limits.maxHeaderBytes))
        guard info.st_size <= cap else { notice("oversized_header", display); limit(display); return }
        guard info.st_size <= max(0, limits.maxTotalBytes) - min(bytesRead, max(0, limits.maxTotalBytes)) else { limit(display); return }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while data.count < info.st_size {
            guard timeAvailable(display) else { return }
            let capacity = min(buffer.count, Int(info.st_size) - data.count)
            let count = Darwin.read(opened.fd, &buffer, capacity)
            guard count > 0 else { notice(count == 0 ? "changed_during_read" : "unreadable_file", display); return }
            data.append(contentsOf: buffer.prefix(count)); bytesRead += count
        }
        var after = stat()
        guard fstat(opened.fd, &after) == 0, same(info, after), info.st_size == after.st_size,
              info.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec, info.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec,
              info.st_ctimespec.tv_sec == after.st_ctimespec.tv_sec, info.st_ctimespec.tv_nsec == after.st_ctimespec.tv_nsec,
              descriptorPath(opened.fd) == opened.path, rootStillValid(root) else { notice("changed_during_read", display); return }
        guard let drafts = MetadataAnalysis.configuration(data, type: type) else {
            notice("invalid_config", display)
            record(MetadataDraft(kind: type == .mcp ? .mcp : .rag, name: (display as NSString).lastPathComponent,
                summary: "Configuration metadata could not be parsed.", issues: ["invalid_config"], summaryKey: "summary_invalid_config"),
                canonical: opened.path, display: display, root: root, linked: opened.linked, info: info)
            return
        }
        for draft in drafts {
            guard timeAvailable(display) else { return }
            if draft.issues.contains("invalid_config") { notice("invalid_config", display) }
            record(draft, canonical: opened.path, display: display, root: root, linked: opened.linked, info: info)
        }
    }

    private func rootStillValid(_ path: String) -> Bool {
        guard let anchor = anchors.first(where: { $0.path == path }) else { return false }
        let fd = Self.openDirectory(path)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        var info = stat()
        return fstat(fd, &info) == 0 && info.st_dev == anchor.device && info.st_ino == anchor.inode
    }

    private func timeAvailable(_ path: String) -> Bool {
        if ProcessInfo.processInfo.systemUptime - started >= max(0, limits.maxSeconds) { limit(path); return false }
        return true
    }
    private func notice(_ code: String, _ path: String) {
        let key = code + "\u{0}" + path
        if noticeKeys.insert(key).inserted { notices.append(ScanNotice(id: key, code: code, path: path)) }
    }
    private func limit(_ path: String) { limited = true; notice("scan_limit", path) }
    private func normalized(_ path: String) -> String { URL(fileURLWithPath: path).standardizedFileURL.path }
    private func joined(_ path: String, _ name: String) -> String { path == "/" ? "/" + name : path + "/" + name }
    private func inside(_ path: String, _ root: String) -> Bool { path == root || root == "/" || path.hasPrefix(root + "/") }
    private func isExcluded(_ path: String) -> Bool {
        let sensitive: Set<String> = [".ssh", ".aws", ".gnupg"]
        if path.split(separator: "/").contains(where: { sensitive.contains($0.lowercased()) }) { return true }
        // An explicit root may itself be beneath a build directory. Exclusions
        // apply to descendants, not unrelated ancestors of a selected root.
        for anchor in anchors where inside(path, anchor.path) {
            let suffix = path.dropFirst(anchor.path.count)
            if suffix.split(separator: "/").contains(where: { Self.excluded.contains($0.lowercased()) }) { return true }
        }
        return Self.excluded.contains((path as NSString).lastPathComponent.lowercased())
    }
    private func isDirectory(_ info: stat) -> Bool { info.st_mode & S_IFMT == S_IFDIR }
    private func isLink(_ info: stat) -> Bool { info.st_mode & S_IFMT == S_IFLNK }
    private func isRegular(_ info: stat) -> Bool { info.st_mode & S_IFMT == S_IFREG }
    private func same(_ a: stat, _ b: stat) -> Bool {
        a.st_dev == b.st_dev && a.st_ino == b.st_ino && a.st_mode == b.st_mode && a.st_nlink == b.st_nlink
    }
    private func descriptorPath(_ fd: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX) + 1)
        guard fcntl(fd, F_GETPATH, &buffer) == 0 else { return nil }
        return String(cString: buffer)
    }
    private static func openDirectory(_ path: String) -> Int32 {
        var fd = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard fd >= 0 else { return -1 }
        for component in path.split(separator: "/") {
            let next = openat(fd, String(component), O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
            let savedError = errno
            close(fd)
            if next < 0 { errno = savedError; return -1 }
            fd = next
        }
        return fd
    }
}

private enum HeaderParser {
    struct Metadata {
        var name = ""
        var description = ""
        var references: [ComponentReference] = []
        var invalid = false
    }
    static func parse(_ data: Data) -> Metadata? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        let lines = text.components(separatedBy: "\n").map { $0.hasSuffix("\r") ? String($0.dropLast()) : $0 }
        guard lines.count >= 2 else { return nil }
        var result = Metadata()
        var seen = Set<String>()
        var index = 1
        while index < lines.count {
            let line = lines[index]
            if line == "---" || line == "..." { break }
            index += 1
            if line.isEmpty || line.hasPrefix("#") || line.first?.isWhitespace == true { continue }
            guard let colon = line.firstIndex(of: ":") else { result.invalid = true; continue }
            let key = String(line[..<colon])
            guard ["name", "description", "requires", "recommended_skills", "source"].contains(key) else { continue }
            guard seen.insert(key).inserted else { result.invalid = true; continue }
            let raw = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            if key == "requires" || key == "recommended_skills" || key == "source" {
                let relation = key == "recommended_skills" ? "recommended" : key
                let declarationLine = index
                var values: [(String, Int)] = []
                if raw.isEmpty {
                    while index < lines.count {
                        let next = lines[index]
                        guard next.first?.isWhitespace == true else { break }
                        let item = next.trimmingCharacters(in: .whitespaces)
                        guard item.hasPrefix("- "), let value = scalar(String(item.dropFirst(2))) else { result.invalid = true; index += 1; continue }
                        values.append((value, index + 1)); index += 1
                    }
                } else if raw.hasPrefix("["), raw.hasSuffix("]") {
                    guard let list = scalarList(String(raw.dropFirst().dropLast())) else { result.invalid = true; continue }
                    values = list.map { ($0, declarationLine) }
                } else if let value = scalar(raw) { values = [(value, declarationLine)] }
                else { result.invalid = true }
                for (value, number) in values {
                    if let reference = MetadataAnalysis.reference(value, relation: relation, line: number), !result.references.contains(reference) {
                        result.references.append(reference)
                    }
                }
                continue
            }
            var value: String?
            if key == "description", let marker = raw.first, marker == "|" || marker == ">" {
                let indicator = raw.split(separator: "#", maxSplits: 1).first.map { $0.trimmingCharacters(in: .whitespaces) } ?? raw
                if !["|", "|-", "|+", ">", ">-", ">+"].contains(indicator) { result.invalid = true; continue }
                var block: [String] = []
                while index < lines.count {
                    let next = lines[index]
                    if !next.isEmpty && next.first?.isWhitespace != true { break }
                    block.append(next); index += 1
                }
                value = blockValue(block, folded: marker == ">")
            } else { value = scalar(raw) }
            guard let value = value else { result.invalid = true; continue }
            if key == "name" { result.name = value } else { result.description = value }
        }
        return result
    }

    private static func scalarList(_ raw: String) -> [String]? {
        var values: [String] = []
        var item = ""
        var quote: Character?
        var escaped = false
        for character in raw {
            if character == "," && quote == nil {
                guard let value = scalar(item.trimmingCharacters(in: .whitespaces)) else { return nil }
                if !value.isEmpty { values.append(value) }; item = ""; continue
            }
            item.append(character)
            if (character == "'" || character == "\"") && !escaped {
                if quote == character { quote = nil } else if quote == nil { quote = character }
            }
            if character == "\\" && quote == "\"" { escaped.toggle() } else { escaped = false }
        }
        guard quote == nil, let value = scalar(item.trimmingCharacters(in: .whitespaces)) else { return nil }
        if !value.isEmpty { values.append(value) }
        return values
    }

    private static func scalar(_ raw: String) -> String? {
        if raw.hasPrefix("'") {
            var output = ""
            var index = raw.index(after: raw.startIndex)
            while index < raw.endIndex {
                let character = raw[index]
                let next = raw.index(after: index)
                if character == "'" {
                    if next < raw.endIndex && raw[next] == "'" { output.append("'"); index = raw.index(after: next); continue }
                    return suffixAllowed(String(raw[next...])) ? output : nil
                }
                output.append(character); index = next
            }
            return nil
        }
        if raw.hasPrefix("\"") {
            // JSON's string decoder handles the common YAML double-quoted
            // escapes without evaluating tags, aliases, or expressions.
            var escaped = false
            var index = raw.index(after: raw.startIndex)
            while index < raw.endIndex {
                let character = raw[index]
                if character == "\"" && !escaped {
                    let end = raw.index(after: index)
                    guard suffixAllowed(String(raw[end...])) else { return nil }
                    return try? JSONDecoder().decode(String.self, from: Data(raw[..<end].utf8))
                }
                if character == "\\" { escaped.toggle() } else { escaped = false }
                index = raw.index(after: index)
            }
            return nil
        }
        var previousWhitespace = true
        for index in raw.indices {
            if raw[index] == "#" && previousWhitespace { return String(raw[..<index]).trimmingCharacters(in: .whitespaces) }
            previousWhitespace = raw[index].isWhitespace
        }
        if let first = raw.first, "[{@&*!|>".contains(first) { return nil }
        return raw.trimmingCharacters(in: .whitespaces)
    }
    private static func suffixAllowed(_ suffix: String) -> Bool {
        let suffix = suffix.trimmingCharacters(in: .whitespaces)
        return suffix.isEmpty || suffix.hasPrefix("#")
    }
    private static func blockValue(_ block: [String], folded: Bool) -> String {
        let indent = block.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { $0.prefix(while: { $0 == " " }).count }.min() ?? 0
        var lines = block.map { String($0.dropFirst(min(indent, $0.count))) }
        while lines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { lines.removeLast() }
        guard folded else { return lines.joined(separator: "\n") }
        var output = ""
        for (index, line) in lines.enumerated() {
            if index > 0 {
                let previous = lines[index - 1]
                output += line.isEmpty || previous.isEmpty || line.hasPrefix(" ") || previous.hasPrefix(" ") ? "\n" : " "
            }
            output += line
        }
        return output
    }
}
