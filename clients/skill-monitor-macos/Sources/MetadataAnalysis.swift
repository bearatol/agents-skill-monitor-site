import Foundation
import CryptoKit

enum MetadataFileType { case skill, agent, mcp, rag, indexHint }

struct MetadataDraft {
    var kind: ComponentKind
    var name: String
    var summary: String
    var references: [ComponentReference] = []
    var findings: [MetadataFinding] = []
    var issues: [String] = []
    var discovery = "metadata"
    var idSuffix = ""
    var summaryKey = ""
    var definitionDigest = ""
}

// This parser returns a small sanitized projection. It never returns command
// arguments, environment values, headers, endpoints, or raw configuration.
enum MetadataAnalysis {
    static let mcpNames: Set<String> = [".mcp.json", "mcp.json", "mcp-config.json", "claude_desktop_config.json"]
    static func classify(_ path: String) -> MetadataFileType? {
        let name = (path as NSString).lastPathComponent
        if name == "SKILL.md" { return .skill }
        let documentation: Set<String> = ["readme.md", "index.md", "agents.md", "changelog.md", "license.md"]
        if path.split(separator: "/").dropLast().contains("agents"), name.hasSuffix(".md"),
           !documentation.contains(name.lowercased()) { return .agent }
        if mcpNames.contains(name) { return .mcp }
        if name == "rag.sources.json" || name == "rag.json" { return .rag }
        if name == "index.faiss" || name == "chroma.sqlite3" { return .indexHint }
        return nil
    }

    static func configuration(_ data: Data, type: MetadataFileType) -> [MetadataDraft]? {
        guard boundedJSON(data) else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: data), let root = object as? [String: Any] else { return nil }
        if type == .mcp { return mcp(root) }
        if type == .rag { return rag(root) }
        return nil
    }

    static func indexHint(name: String) -> MetadataDraft {
        MetadataDraft(kind: .rag, name: name, summary: "Index filename hint. Metadata and source content were not inspected.",
            findings: [finding("index_uninspected", "info", "A supported index filename was found using file metadata only.")],
            discovery: "index_hint", summaryKey: "summary_index_hint")
    }

    static func fingerprint(draft: MetadataDraft, marker: String) -> String {
        // Container entries track their own complete normalized definition,
        // independent of sibling entries and the container file's timestamp.
        if !draft.definitionDigest.isEmpty { return draft.definitionDigest }
        // A local change marker, not a cryptographic integrity or safety claim.
        let values = [draft.kind.rawValue, draft.name, draft.summary, draft.discovery, marker] +
            draft.references.map { $0.relation + ":" + $0.target } + draft.findings.map(\.code) + draft.issues
        var hash: UInt64 = 14695981039346656037
        for byte in values.joined(separator: "\u{0}").utf8 { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
        return String(hash, radix: 16)
    }

    static func reference(_ value: String, relation: String, line: Int? = nil) -> ComponentReference? {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= 512 else { return nil }
        guard isRemote(value) || matches(value, #"^[\p{L}\p{N} ._:/@+~\-]+$"#) else { return nil }
        let target = isRemote(value) ? "remote-source" : safeText(value, limit: 512)
        // Altered credential-like labels must not become fabricated graph IDs.
        if !isRemote(value), target.contains("[redacted]") { return nil }
        guard !target.isEmpty else { return nil }
        return ComponentReference(target: target, relation: relation, line: line, isExternal: isRemote(value))
    }

    static func referenceFindings(_ references: [ComponentReference]) -> [MetadataFinding] {
        var result: [MetadataFinding] = []
        if references.contains(where: { $0.isExternal }) {
            result.append(finding("remote_endpoint", "info", "A remote source is declared; its address is omitted."))
        }
        if references.contains(where: { broadPath($0.target) }) {
            result.append(finding("broad_filesystem_scope", "medium", "Declared metadata includes a filesystem root or home-wide scope."))
        }
        return result
    }

    static func metadataText(_ value: String) -> String { safeText(value, limit: 65536) }

    private static func boundedJSON(_ data: Data) -> Bool {
        guard data.count <= 65536 else { return false }
        var depth = 0
        var entries = 0
        var quoted = false
        var escaped = false
        for byte in data {
            if quoted {
                if byte == 34 && !escaped { quoted = false }
                if byte == 92 { escaped.toggle() } else { escaped = false }
            } else if byte == 34 { quoted = true; escaped = false }
            else if byte == 91 || byte == 123 { depth += 1; if depth > 32 { return false } }
            else if byte == 93 || byte == 125 { depth -= 1; if depth < 0 { return false } }
            else if byte == 44 || byte == 58 { entries += 1; if entries > 8192 { return false } }
        }
        return !quoted && depth == 0
    }

    private static func mcp(_ root: [String: Any]) -> [MetadataDraft]? {
        guard let servers = (root["mcpServers"] ?? root["mcp_servers"]) as? [String: Any], servers.count <= 512 else { return nil }
        var drafts: [MetadataDraft] = []
        for key in servers.keys.sorted() {
            let name = safeLabel(key, fallback: "MCP server")
            let suffix = "#mcp:" + digest(Data(key.utf8))
            let entryDigest = definitionDigest(["key": key, "definition": servers[key] ?? NSNull()])
            guard let server = servers[key] as? [String: Any] else {
                drafts.append(MetadataDraft(kind: .mcp, name: name, summary: "Server metadata has an unsupported structure.", issues: ["invalid_config"], idSuffix: suffix, summaryKey: "summary_invalid_server", definitionDigest: entryDigest))
                continue
            }
            let command = server["command"] as? String ?? ""
            let arguments = server["args"] as? [String] ?? []
            let transportValue = (server["transport"] ?? server["type"]) as? String ?? ""
            let transport = transportValue.lowercased()
            let knownTransport = ["stdio", "sse", "http", "streamable-http", "streamable_http", "ws", "websocket"].contains(transport)
            var summary = "Declared MCP server."
            var summaryKey = "summary_mcp_declared"
            if knownTransport { summary += " Transport: " + transport + "."; summaryKey = "summary_mcp_transport_" + transport }
            else if !command.isEmpty { summary += " A local command is configured."; summaryKey = "summary_mcp_local_command" }
            if let description = server["description"] as? String, !description.isEmpty { summary = safeText(description, limit: 1024); summaryKey = "" }
            let refs = references(server)
            var findings = commandFindings(command: command, arguments: arguments)
            let remote = ["sse", "http", "streamable-http", "streamable_http", "ws", "websocket"].contains(transport) ||
                ["url", "endpoint", "serverUrl"].contains { key in (server[key] as? String).map(isRemote) ?? false }
            if remote { findings.append(finding("remote_endpoint", "info", "A remote MCP endpoint or transport is configured; its address is omitted.")) }
            findings += referenceFindings(refs).filter { finding in !findings.contains { $0.code == finding.code } }
            var issues: [String] = []
            if server["args"] != nil && !(server["args"] is [String]) { issues.append("invalid_config") }
            if server["command"] != nil && !(server["command"] is String) { issues.append("invalid_config") }
            drafts.append(MetadataDraft(kind: .mcp, name: name, summary: summary, references: refs, findings: findings,
                issues: Array(Set(issues)).sorted(), idSuffix: suffix, summaryKey: summaryKey, definitionDigest: entryDigest))
        }
        return drafts
    }

    private static func rag(_ root: [String: Any]) -> [MetadataDraft]? {
        guard let sources = root["sources"] as? [Any], sources.count <= 512 else { return nil }
        var entries: [(identity: String, draft: MetadataDraft)] = sources.map { item in
            let source = item as? [String: Any]
            let rawPath = (item as? String) ?? (["path", "source", "url", "uri"].compactMap { source?[$0] as? String }.first ?? "")
            let explicitName = (source?["name"] ?? source?["id"]) as? String
            let fallback = isRemote(rawPath) || rawPath.isEmpty ? "RAG source" : (rawPath as NSString).lastPathComponent
            let name = safeLabel(explicitName ?? fallback, fallback: "RAG source")
            var refs = source.map(references) ?? []
            if !rawPath.isEmpty, let ref = reference(rawPath, relation: "source"), !refs.contains(ref) { refs.append(ref) }
            var findings = [finding("rag_source_declared", "info", "A RAG source is declared. Source content was not inspected.")]
            findings += referenceFindings(refs)
            if isRemote(rawPath), !findings.contains(where: { $0.code == "remote_endpoint" }) {
                findings.append(finding("remote_endpoint", "info", "A remote RAG source is declared; its address is omitted."))
            }
            let valid = item is String || (source != nil && (!rawPath.isEmpty || explicitName != nil))
            let entryDigest = definitionDigest(item)
            let explicitID = (source?["id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let pathIdentity = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
            let nameIdentity = explicitName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let identity: String
            if !explicitID.isEmpty { identity = "id\u{0}" + explicitID }
            else if !pathIdentity.isEmpty { identity = "source\u{0}" + pathIdentity }
            else if !nameIdentity.isEmpty { identity = "name\u{0}" + nameIdentity }
            else { identity = "anonymous\u{0}" + entryDigest }
            let draft = MetadataDraft(kind: .rag, name: name,
                summary: "Declared RAG source. Source content was not inspected.", references: refs, findings: findings,
                issues: valid ? [] : ["invalid_config"], summaryKey: "summary_rag_declared", definitionDigest: entryDigest)
            return (digest(Data(identity.utf8)), draft)
        }
        // Equal identities need stable, distinct slots. Sorting their bounded
        // definitions makes reorderings deterministic; identical duplicates
        // are interchangeable and retain the same set of slots.
        let order = entries.indices.sorted {
            if entries[$0].identity != entries[$1].identity { return entries[$0].identity < entries[$1].identity }
            if entries[$0].draft.definitionDigest != entries[$1].draft.definitionDigest {
                return entries[$0].draft.definitionDigest < entries[$1].draft.definitionDigest
            }
            return $0 < $1
        }
        var occurrences: [String: Int] = [:]
        for index in order {
            let identity = entries[index].identity
            let occurrence = occurrences[identity, default: 0]
            entries[index].draft.idSuffix = "#rag:" + identity + ":\(occurrence)"
            occurrences[identity] = occurrence + 1
        }
        return entries.map(\.draft)
    }

    private static func definitionDigest(_ value: Any) -> String {
        // Values originate from the bounded JSON parser. Wrapping permits
        // scalar source entries while sorting object keys canonically.
        guard let data = try? JSONSerialization.data(withJSONObject: ["entry": value], options: [.sortedKeys]) else { return "" }
        return digest(data)
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func references(_ object: [String: Any]) -> [ComponentReference] {
        var result: [ComponentReference] = []
        for (field, relation) in [("requires", "requires"), ("recommended_skills", "recommended"), ("source", "source")] {
            let values = (object[field] as? [String]) ?? (object[field] as? String).map { [$0] } ?? []
            for value in values {
                if let ref = reference(value, relation: relation), !result.contains(ref) { result.append(ref) }
            }
        }
        return result
    }

    private static func commandFindings(command: String, arguments: [String]) -> [MetadataFinding] {
        let executable = (command.trimmingCharacters(in: .whitespacesAndNewlines) as NSString).lastPathComponent.lowercased()
        let shells: Set<String> = ["sh", "bash", "zsh", "dash", "fish", "ksh", "csh", "pwsh", "powershell", "powershell.exe", "cmd", "cmd.exe"]
        var result: [MetadataFinding] = []
        let wrapped = shells.contains(executable)
        if wrapped { result.append(finding("shell_wrapper", "medium", "The configured executable is a shell wrapper.")) }
        let text = arguments.joined(separator: " ")
        let download = matches(text, #"(?i)\b(curl|wget|invoke-webrequest|iwr)\b"#)
        let pipedExecution = matches(text, #"(?i)(\||;|&&)\s*(sh|bash|zsh|dash|python[0-9.]*|node|pwsh|powershell)\b"#)
        if wrapped && download && (pipedExecution || text.contains("$(") || text.contains("`")) {
            result.append(finding("download_execute", "high", "Shell arguments combine a download tool with an execution pattern."))
        }
        if arguments.contains(where: broadPath) {
            result.append(finding("broad_filesystem_scope", "medium", "Command arguments include a filesystem root or home-wide scope."))
        }
        let runtime = ["npx", "bunx", "uvx"].contains(executable) ||
            (executable == "pnpm" && arguments.first == "dlx") || (executable == "npm" && arguments.first == "exec")
        if runtime {
            let candidates = arguments.filter { !$0.hasPrefix("-") && !["dlx", "exec", "run"].contains($0) }
            if let package = candidates.first, !matches(package, #"(==|@)v?[0-9]+\.[0-9]+(\.[0-9]+)?([+-][a-zA-Z0-9.-]+)?$"#),
               !package.hasPrefix("/"), !package.hasPrefix("."), !isRemote(package) {
                result.append(finding("unpinned_runtime", "medium", "A supported runtime package invocation has no explicit version pin in its package label."))
            }
        }
        return result
    }

    private static func broadPath(_ value: String) -> Bool {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let scopes: Set<String> = ["/", "~", "~/", "$home", "${home}", "%userprofile%", "/users", "/users/", "/home", "/home" + "/", "/volumes", "/volumes/", "--allow-all", "--allow-all-paths"]
        if scopes.contains(value) { return true }
        if let split = value.firstIndex(of: "="), value.hasPrefix("--") { return scopes.contains(String(value[value.index(after: split)...])) }
        return false
    }
    private static func finding(_ code: String, _ severity: String, _ evidence: String) -> MetadataFinding {
        MetadataFinding(id: code, code: code, severity: severity, evidence: evidence, line: nil)
    }
    private static func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }
    private static func isRemote(_ value: String) -> Bool {
        matches(value, #"(?i)^[a-z][a-z0-9+.-]*://"#)
    }
    private static func safeLabel(_ value: String, fallback: String) -> String {
        let label = safeText(value, limit: 256).trimmingCharacters(in: .whitespacesAndNewlines)
        return label.isEmpty || isRemote(value) ? fallback : label
    }
    private static func safeText(_ value: String, limit: Int) -> String {
        // Text labels can contain URLs too. Omit the whole address rather than
        // attempting to distinguish public query fields from credentials.
        let clipped = String(value.prefix(limit))
        let patterns: [(String, String)] = [
            (#"(?i)[a-z][a-z0-9+.-]*://[^\s\"'<>]+"#, "[remote address omitted]"),
            (#"(?i)\bbearer\s+[^\s,;]+"#, "Bearer [redacted]"),
            (#"(?i)\b(api[_-]?key|token|secret|password|passwd|authorization|credential|access[_-]?key|client[_-]?secret)\b\s*[:=]\s*(\"[^\"]*\"|'[^']*'|[^\s,;]+)"#, "$1=[redacted]"),
            (#"\bsk-(?:proj-)?[A-Za-z0-9_-]{12,}"#, "[redacted]")
        ]
        var output = clipped
        for (pattern, replacement) in patterns {
            let range = NSRange(output.startIndex..<output.endIndex, in: output)
            guard let expression = try? NSRegularExpression(pattern: pattern) else { return "" }
            output = expression.stringByReplacingMatches(in: output, range: range, withTemplate: replacement)
        }
        return String(output.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) || $0 == "\n" || $0 == "\t" })
    }
}
