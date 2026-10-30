import Foundation
import Darwin

private struct IntegrationFailure: Error, CustomStringConvertible {
    let description: String
}

@main
struct IntegrationTests {
    @MainActor private static var checks = 0
    @MainActor private static var scenarios = 0
    @MainActor private static var skips = 0
    private static let fm = FileManager.default
    private static let sentinel = "FAKE_ENV_SENTINEL_INTEGRATION_62948"

    @MainActor private static func expect(_ value: @autoclosure () -> Bool, _ message: String) throws {
        checks += 1
        if !value() { throw IntegrationFailure(description: message) }
    }

    private static func put(_ path: String, _ text: String) throws {
        try fm.createDirectory(atPath: (path as NSString).deletingLastPathComponent,
                               withIntermediateDirectories: true)
        try Data(text.utf8).write(to: URL(fileURLWithPath: path))
    }

    private static func rag(_ names: [String], changedA: Bool = false) throws -> String {
        let sources: [[String: Any]] = names.map { name in
            var source: [String: Any] = ["name": name, "path": "./" + name.lowercased()]
            if changedA && name == "A" { source["requires"] = ["skill:remote-source"] }
            return source
        }
        let data = try JSONSerialization.data(withJSONObject: ["sources": sources], options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    private static func mcp(_ names: [String]) throws -> String {
        var servers: [String: Any] = [:]
        for name in names {
            servers[name] = ["command": "fixture", "env": ["FIXTURE_TOKEN": sentinel]]
        }
        let data = try JSONSerialization.data(withJSONObject: ["mcpServers": servers], options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    @MainActor private static func waitForScan(_ model: InventoryModel) async throws {
        let deadline = ProcessInfo.processInfo.systemUptime + 5
        while model.isScanning && ProcessInfo.processInfo.systemUptime < deadline {
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        try expect(!model.isScanning, "Real scanner/model scan exceeded five seconds")
        try expect(model.hasScanned, "Real scanner/model scan did not publish a result")
        try expect(!String(reflecting: model.inventory).contains(sentinel), "Inventory exposed fake environment sentinel")
        try expect(!String(reflecting: model.changeJournal).contains(sentinel), "Journal exposed fake environment sentinel")
    }

    @MainActor private static func refresh(_ model: InventoryModel, complete: Bool = true) async throws {
        model.refresh()
        try await waitForScan(model)
        if complete {
            try expect(!model.comparisonDeferred, "Expected complete scan, got deferred comparison")
            try expect(model.inventory.notices.isEmpty, "Complete fixture scan unexpectedly emitted notices")
            try expect(!model.inventory.limited, "Complete fixture scan unexpectedly hit a limit")
        }
    }

    @MainActor private static func component(_ model: InventoryModel, _ name: String,
                                              kind: ComponentKind) throws -> LocalSkill {
        let matches = model.inventory.skills.filter { $0.name == name && $0.kind == kind }
        try expect(matches.count == 1, "Expected one \(kind.rawValue) component named \(name)")
        guard let result = matches.first else { throw IntegrationFailure(description: "Missing fixture component") }
        return result
    }

    @MainActor private static func unchanged(_ model: InventoryModel, _ previous: LocalSkill) throws {
        let current = try component(model, previous.name, kind: previous.kind)
        try expect(current.id == previous.id, "Sibling edit changed \(previous.name)'s identity")
        try expect(current.fingerprint == previous.fingerprint, "Sibling edit changed \(previous.name)'s fingerprint")
    }

    @MainActor private static func event(_ model: InventoryModel, category: String, id: String) throws {
        try expect(model.changeJournal.count == 1, "Expected exactly one \(category) event")
        try expect(model.changeJournal.first?.category == category && model.changeJournal.first?.componentID == id,
                   "Expected \(category) event for the affected component only")
    }

    @MainActor private static func run() async throws {
        let output = fm.currentDirectoryPath + "/build/native-debug-20261030"
        let base = output + "/integration-fixture-" + UUID().uuidString
        try fm.createDirectory(atPath: base, withIntermediateDirectories: true)
        defer { try? fm.removeItem(atPath: base) }
        let root = base + "/selected"
        let config = root + "/mcp.json"
        let sources = root + "/rag.json"
        try put(root + "/skills/local/SKILL.md",
                "---\nname: remote-source\ndescription: Fixture local skill.\n---\nFixture body.\n")
        try put(root + "/agents/observer.md",
                "---\nname: Observer\ndescription: Fixture observer.\nsource: https://example.invalid\nrequires: skill:remote-source\n---\nFixture body.\n")
        try put(sources, try rag(["A", "B"]))
        try put(config, try mcp(["original"]))

        // No injected scanner: every transition passes through production filesystem discovery.
        let model = InventoryModel(arguments: ["integration-tests", "--scan-root", root])
        model.start()
        try await waitForScan(model)
        try expect(model.inventory.skills.count == 5, "Baseline must discover skill, agent, two RAG sources and MCP server")
        try expect(model.inventory.notices.isEmpty && !model.inventory.limited && !model.comparisonDeferred,
                   "Baseline must be a complete real filesystem observation")
        try expect(model.changeJournal.isEmpty && !model.hasComparison, "First complete scan must establish an empty journal")
        let a = try component(model, "A", kind: .rag)
        let b = try component(model, "B", kind: .rag)
        let original = try component(model, "original", kind: .mcp)
        scenarios += 1

        let observer = try component(model, "Observer", kind: .agent)
        let remoteReferences = observer.references.filter { $0.relation == "source" }
        try expect(remoteReferences.count == 1 && remoteReferences.first?.isExternal == true,
                   "Remote header source must retain external provenance")
        try expect(remoteReferences.first?.target == "remote-source", "Remote address must use sanitized display label")
        try expect(remoteReferences.allSatisfy { $0.matchingComponents(in: model.inventory.skills).isEmpty },
                   "External source must not resolve to a local skill with the sanitized label")
        let localReferences = observer.references.filter { $0.relation == "requires" }
        try expect(localReferences.count == 1 && localReferences.first?.isExternal == false,
                   "Explicit local dependency must remain local")
        try expect(localReferences.first?.matchingComponents(in: model.inventory.skills).map(\.name) == ["remote-source"],
                   "Explicit local dependency must still resolve to the local skill")
        try expect(!String(reflecting: model.inventory).contains("https://example.invalid"), "Returned inventory exposed remote address")
        scenarios += 1

        try put(sources, try rag(["X", "A", "B"]))
        try await refresh(model)
        let x = try component(model, "X", kind: .rag)
        try event(model, category: "added", id: x.id)
        try unchanged(model, a)
        try unchanged(model, b)
        scenarios += 1
        model.acknowledgeChanges()

        try put(sources, try rag(["B", "A", "X"]))
        try await refresh(model)
        try expect(model.changeJournal.isEmpty, "Reordering RAG definitions must not create journal events")
        try unchanged(model, a)
        try unchanged(model, b)
        try unchanged(model, x)
        scenarios += 1

        try put(sources, try rag(["B", "A", "X"], changedA: true))
        try await refresh(model)
        let changedA = try component(model, "A", kind: .rag)
        try expect(changedA.id == a.id && changedA.fingerprint != a.fingerprint,
                   "Own dependency change must preserve identity and change the fingerprint")
        try event(model, category: "changed", id: a.id)
        try unchanged(model, b)
        try unchanged(model, x)
        scenarios += 1
        model.acknowledgeChanges()

        let completeConfig = try mcp(["original", "new-server"])
        try put(config, completeConfig)
        try await refresh(model)
        let newServer = try component(model, "new-server", kind: .mcp)
        try event(model, category: "added", id: newServer.id)
        try unchanged(model, original)
        scenarios += 1
        model.acknowledgeChanges()

        if geteuid() != 0 {
            var info = stat()
            guard stat(config, &info) == 0 else { throw IntegrationFailure(description: "Cannot stat fixture MCP configuration") }
            let mode = info.st_mode & 0o7777
            guard chmod(config, 0) == 0 else { throw IntegrationFailure(description: "Cannot make fixture MCP configuration unreadable") }
            do {
                defer { _ = chmod(config, mode) }
                try await refresh(model, complete: false)
                try expect(model.comparisonDeferred, "Unreadable real configuration must defer comparison")
                try expect(model.inventory.notices.contains { $0.code == "unreadable_file" },
                           "Unreadable fixture must provide an unreadable-file notice")
                try expect(model.changeJournal.isEmpty, "Unreadable configuration must preserve journal and baseline")
            }
            try await refresh(model)
            try expect(model.changeJournal.isEmpty, "Restored read permission must not create false additions or changes")
            try unchanged(model, original)
            try unchanged(model, newServer)
            scenarios += 1
        } else {
            skips += 1
            print("SKIP: permission-denial recovery requires a non-root effective user")
        }

        try put(config, "{")
        try await refresh(model, complete: false)
        try expect(model.comparisonDeferred && model.changeJournal.isEmpty,
                   "Invalid JSON must defer comparison without replacing the last complete baseline")
        try expect(model.inventory.notices.contains { $0.code == "invalid_config" },
                   "Malformed fixture must provide an invalid-config notice")
        try put(config, completeConfig)
        try await refresh(model)
        try expect(model.changeJournal.isEmpty, "Restoring exact MCP bytes after invalid JSON must not create false events")
        try unchanged(model, original)
        try unchanged(model, newServer)
        scenarios += 1

        try put(sources, try rag(["B", "X"]))
        try await refresh(model)
        try event(model, category: "missing", id: a.id)
        try unchanged(model, b)
        try unchanged(model, x)
        scenarios += 1
        model.acknowledgeChanges()
        try put(sources, try rag(["B", "A", "X"], changedA: true))
        try await refresh(model)
        try event(model, category: "added", id: a.id)
        try unchanged(model, changedA)
        scenarios += 1

        model.removeRoot(root)
        try await waitForScan(model)
        try expect(model.roots.isEmpty && model.inventory.skills.isEmpty, "Removing selected root must clear the real inventory")
        try expect(model.changeJournal.isEmpty && !model.hasComparison, "Removing root must establish a fresh empty baseline")
        model.addSuggestedFolders([root])
        try await waitForScan(model)
        try expect(model.roots == [root] && model.inventory.skills.count == 7, "Readding selected root must rediscover real components")
        try expect(model.changeJournal.isEmpty && !model.hasComparison && !model.comparisonDeferred,
                   "Readding selected root must reset comparison without spurious events")
        try await refresh(model)
        try expect(model.hasComparison && model.changeJournal.isEmpty, "Unchanged rescan after root reset must retain an empty journal")
        scenarios += 1
    }

    @MainActor static func main() async {
        do {
            try await run()
            print("PASS: \(checks) real scanner/model integration checks across \(scenarios) scenarios; \(skips) skipped")
        } catch {
            print("FAIL: \(error)")
            exit(1)
        }
    }
}
