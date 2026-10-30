import Foundation

struct SuggestedFolder: Identifiable, Hashable {
    let id: String
    let path: String
    let reason: String
    let alreadyIncluded: Bool
}

struct FolderSuggestionResult {
    let folders: [SuggestedFolder]
    let rejectedCount: Int
    let rejectedCodes: [String]
}

enum FolderSuggestionError: String, Error {
    case oversized, invalidJSON, invalidSchema, tooMany
    var code: String { rawValue }
}

// Parses proposals only. There is deliberately no file existence check,
// path resolution, directory enumeration, network client, or executor here.
enum FolderSuggestionParser {
    static func parse(_ text: String, home: String, existing: [String]) throws -> FolderSuggestionResult {
        guard text.utf8.count <= 32768 else { throw FolderSuggestionError.oversized }
        var input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if input.hasPrefix("```json\n"), input.hasSuffix("```") {
            input = String(input.dropFirst(8).dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if input.hasPrefix("```\n"), input.hasSuffix("```") {
            input = String(input.dropFirst(4).dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard boundedNesting(input) else { throw FolderSuggestionError.invalidSchema }
        let object: Any
        do { object = try JSONSerialization.jsonObject(with: Data(input.utf8)) }
        catch { throw FolderSuggestionError.invalidJSON }
        guard let dictionary = object as? [String: Any], Set(dictionary.keys) == ["folders"],
              let entries = dictionary["folders"] as? [Any] else { throw FolderSuggestionError.invalidSchema }
        guard entries.count <= 32 else { throw FolderSuggestionError.tooMany }
        let included = Set(existing.compactMap { normalized($0, home: home).path })
        var seen = Set<String>()
        var folders: [SuggestedFolder] = []
        var rejected = 0
        var codes: [String] = []
        func reject(_ code: String) {
            rejected += 1
            if !codes.contains(code) { codes.append(code) }
        }
        for entry in entries {
            guard let item = entry as? [String: Any],
                  Set(item.keys).isSubset(of: ["path", "reason"]),
                  let raw = item["path"] as? String else { reject("invalid_path"); continue }
            let checked = normalized(raw, home: home)
            guard let path = checked.path else { reject(checked.code); continue }
            let reason: String
            if let value = item["reason"] {
                guard let value = value as? String, value.count <= 400, !hasHiddenControl(value) else {
                    reject("invalid_reason"); continue
                }
                reason = value.trimmingCharacters(in: .whitespacesAndNewlines)
            } else { reason = "" }
            guard seen.insert(path).inserted else { continue }
            folders.append(SuggestedFolder(id: path, path: path, reason: reason, alreadyIncluded: included.contains(path)))
        }
        return FolderSuggestionResult(folders: folders, rejectedCount: rejected, rejectedCodes: codes)
    }

    private static func normalized(_ value: String, home: String) -> (path: String?, code: String) {
        guard value.utf8.count <= 2048, !hasHiddenControl(value), home.hasPrefix("/"), !home.hasPrefix("//") else {
            return (nil, "invalid_path")
        }
        var path = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if path == "~" { path = home }
        else if path.hasPrefix("~/") { path = home + String(path.dropFirst()) }
        guard path.hasPrefix("/"), !path.hasPrefix("//"), !path.contains("://") else { return (nil, "invalid_path") }
        let parts = path.split(separator: "/").map(String.init)
        guard !parts.contains("..") else { return (nil, "invalid_path") }
        let clean = parts.filter { $0 != "." }
        path = "/" + clean.joined(separator: "/")
        let homePath = "/" + home.split(separator: "/").filter { $0 != "." }.joined(separator: "/")
        let parent = "/" + homePath.split(separator: "/").dropLast().joined(separator: "/")
        let broad: Set<String> = ["/", "/Users", "/Volumes", "/System", "/Library", "/private", "/tmp", homePath, parent]
        guard !broad.contains(path) else { return (nil, "broad_scope") }
        let excluded: Set<String> = [".ssh", ".aws", ".gnupg", ".git", ".env", ".cache", "cache", "caches", "models", "model-weights", "local-llm", "local-models"]
        guard !clean.contains(where: { excluded.contains($0.lowercased()) || $0.lowercased().hasPrefix(".env.") }) else {
            return (nil, "sensitive_path")
        }
        return (path, "")
    }

    private static func hasHiddenControl(_ text: String) -> Bool {
        text.unicodeScalars.contains {
            CharacterSet.controlCharacters.contains($0) || $0.properties.generalCategory == .format
        }
    }

    private static func boundedNesting(_ input: String) -> Bool {
        var depth = 0
        var quoted = false
        var escaped = false
        for byte in input.utf8 {
            if quoted {
                if escaped { escaped = false }
                else if byte == 92 { escaped = true }
                else if byte == 34 { quoted = false }
            } else if byte == 34 { quoted = true }
            else if byte == 91 || byte == 123 {
                depth += 1
                if depth > 16 { return false }
            } else if byte == 93 || byte == 125 { depth -= 1 }
        }
        return true
    }
}
