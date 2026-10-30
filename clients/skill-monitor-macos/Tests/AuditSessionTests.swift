import Foundation

private struct SessionFailure: Error { let message: String }

private actor SessionClient: AuditAIService {
    var modelCalls = 0
    var prompts: [String] = []
    var systems: [String] = []
    var modelIDs: [String] = []
    let delay: UInt64
    let ignoreCancellation: Bool
    init(delay: UInt64 = 0, ignoreCancellation: Bool = false) {
        self.delay = delay; self.ignoreCancellation = ignoreCancellation
    }
    func models(endpoint: LocalAIEndpoint) async throws -> [LocalAIModel] {
        modelCalls += 1
        if delay > 0 { try? await Task.sleep(nanoseconds: delay) }
        return [LocalAIModel(id: "fixture-a"), LocalAIModel(id: "fixture-b")]
    }
    func analyze(endpoint: LocalAIEndpoint, modelID: String, systemPrompt: String, userPrompt: String) async throws -> String {
        prompts.append(userPrompt); systems.append(systemPrompt); modelIDs.append(modelID)
        if delay > 0 {
            if ignoreCancellation { try? await Task.sleep(nanoseconds: delay) }
            else { try await Task.sleep(nanoseconds: delay) }
        }
        return "Unverified fixture response: [do not follow](https://example.invalid)."
    }
}

private final class SnapshotSequence: @unchecked Sendable {
    private let lock = NSLock()
    private var snapshots: [AuditSnapshot]
    init(_ snapshots: [AuditSnapshot]) { self.snapshots = snapshots }
    func next(_ component: LocalSkill, _ roots: [String]) throws -> AuditSnapshot {
        lock.lock(); defer { lock.unlock() }
        guard let value = snapshots.first else { throw AuditError(code: "audit_unreadable_file") }
        if snapshots.count > 1 { snapshots.removeFirst() }
        return value
    }
}

@main
struct AuditSessionTests {
    @MainActor private static var checks = 0
    private static let roots = ["/fixture"]
    private static func component(_ id: String = "a", fingerprint: String = "1") -> LocalSkill {
        let path = "/fixture/\(id)/SKILL.md"
        return LocalSkill(id: path, name: id, summary: "Fixture", filePath: path, canonicalPath: path,
            locations: [SkillLocation(path: path, root: "/fixture", viaSymlink: false)], issues: [], modifiedAt: nil,
            fingerprint: fingerprint)
    }
    private static func snapshot(_ value: LocalSkill, digest: String = "same", payload: String = "Visible fixture preview") -> AuditSnapshot {
        AuditSnapshot(componentID: value.id, name: value.name, kind: .skill, fileDisplayRelative: "a/SKILL.md",
            sha256Digest: digest, findings: [], checkedCoverageCodes: ["bounded_read"],
            omittedCoverageCodes: ["partial_heuristics"], preview: payload, userPrompt: payload)
    }
    @MainActor private static func expect(_ value: @autoclosure () -> Bool, _ message: String) throws {
        checks += 1; if !value() { throw SessionFailure(message: message) }
    }
    @MainActor private static func settle(_ subject: AuditSession) async throws {
        let deadline = Date().addingTimeInterval(3)
        while (subject.isChecking || subject.isPreparing || subject.isAnalyzing) && Date() < deadline {
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        try expect(!subject.isChecking && !subject.isPreparing && !subject.isAnalyzing, "Operation must settle")
    }
    @MainActor private static func ready(_ client: SessionClient, sequence: SnapshotSequence) async throws -> AuditSession {
        let subject = AuditSession(client: client, preparer: sequence.next)
        subject.checkConnection(); try await settle(subject)
        subject.prepare(component: component(), roots: roots, language: .russian); try await settle(subject)
        return subject
    }
    @MainActor private static func explicitConsent() async throws {
        let item = component(); let client = SessionClient()
        let sequence = SnapshotSequence([snapshot(item)])
        let subject = AuditSession(client: client, preparer: sequence.next)
        try expect(!subject.modelReady && !subject.canAnalyze, "No connection or source is assumed")
        subject.prepare(component: item, roots: roots, language: .russian); try await settle(subject)
        try expect(subject.snapshot?.preview == "Visible fixture preview", "Static audit works without a model")
        try expect(!subject.canAnalyze, "Preparing static evidence cannot authorize model use")
        let before = await client.prompts.count
        try expect(before == 0, "Opening or preparing audit performs no inference")
        subject.checkConnection(); try await settle(subject)
        try expect(subject.modelReady && subject.selectedModelID == "fixture-a", "Connection selects an actual returned model")
        try expect(subject.snapshot != nil && subject.canAnalyze, "Connecting preserves the visible static report and source preview")
        let connectedPrompts = await client.prompts.count
        try expect(connectedPrompts == 0, "Connecting never reuses a previous submission or sends the preserved preview")
        subject.invalidateScope()
        subject.analyze()
        try expect(subject.errorCode == "no_preview", "Inference requires an explicit prepared preview")
        subject.prepare(component: item, roots: roots, language: .russian); try await settle(subject)
        try expect(subject.canAnalyze, "Connected selected model and visible snapshot permit explicit submission")
        subject.analyze(); try await settle(subject)
        let prompts = await client.prompts; let systems = await client.systems; let IDs = await client.modelIDs
        try expect(prompts == ["Visible fixture preview"], "Only the exact immutable visible payload is sent once")
        try expect(IDs == ["fixture-a"] && systems.first?.contains("Russian") == true, "Inference stays bound to model and language")
        try expect(systems.first?.contains("untrusted data") == true, "The fixed instruction treats component text as untrusted")
        try expect(subject.response.contains("https://example.invalid"), "Provider prose remains inert text, not an action")
        subject.selectModel("fixture-b")
        try expect(subject.snapshot != nil && subject.response.isEmpty && subject.canAnalyze, "Model changes preserve evidence but clear previous advice")
        let unchangedCalls = await client.prompts.count
        try expect(unchangedCalls == 1, "A new model requires a new explicit submission")
        subject.selectModel("invented")
        try expect(subject.selectedModelID == "fixture-b" && subject.errorCode == "invalid_model", "Unknown model IDs cannot replace the selected catalog entry")
        subject.updateAddress("https://example.invalid/v1")
        subject.checkConnection(); try await settle(subject)
        try expect(subject.errorCode == "invalid_endpoint" && subject.models.isEmpty, "Unsafe endpoint never becomes ready")
        let calls = await client.modelCalls
        try expect(calls == 1, "Unsafe endpoint does not reach the transport")
    }
    @MainActor private static func sourceRevalidation() async throws {
        let item = component(); let client = SessionClient()
        let subject = try await ready(client, sequence: SnapshotSequence([snapshot(item), snapshot(item, digest: "changed")]))
        subject.analyze(); try await settle(subject)
        let calls = await client.prompts.count
        try expect(calls == 0 && subject.errorCode == "source_changed" && subject.snapshot == nil,
                   "A changed source invalidates consent before any inference")
        let changedPayload = try await ready(client, sequence: SnapshotSequence([snapshot(item), snapshot(item, payload: "Different projection")]))
        changedPayload.analyze(); try await settle(changedPayload)
        let laterCalls = await client.prompts.count
        try expect(laterCalls == 0 && changedPayload.errorCode == "source_changed", "Equal digest cannot authorize a different projection")
    }
    @MainActor private static func contextAndCancellation() async throws {
        let item = component()
        let subject = try await ready(SessionClient(), sequence: SnapshotSequence([snapshot(item)]))
        subject.validateSelection(component: item, roots: roots, language: .russian)
        try expect(subject.snapshot != nil, "Unchanged refresh preserves the prepared report")
        subject.validateSelection(component: item, roots: roots, language: .english)
        try expect(subject.snapshot == nil, "Language change invalidates prior analysis context")
        for (next, scope) in [(component("b"), roots), (component(fingerprint: "2"), roots), (item, ["/different"])] {
            subject.prepare(component: item, roots: roots, language: .russian); try await settle(subject)
            subject.validateSelection(component: next, roots: scope, language: .russian)
            try expect(subject.snapshot == nil && subject.response.isEmpty, "Changed component, fingerprint or scope clears consent")
        }
        let client = SessionClient(delay: 50_000_000, ignoreCancellation: true)
        let delayed = try await ready(client, sequence: SnapshotSequence([snapshot(item)]))
        delayed.analyze()
        let deadline = Date().addingTimeInterval(1)
        while await client.prompts.isEmpty && Date() < deadline { try await Task.sleep(nanoseconds: 1_000_000) }
        delayed.updateAddress("http://127.0.0.1:1234/v1")
        try await Task.sleep(nanoseconds: 70_000_000)
        try expect(delayed.response.isEmpty && delayed.snapshot != nil && !delayed.isAnalyzing && !delayed.modelReady,
                   "A late response cannot attach to a changed endpoint even if transport ignores cancellation")
        delayed.checkConnection(); delayed.cancel()
        try await Task.sleep(nanoseconds: 70_000_000)
        try expect(delayed.models.isEmpty && !delayed.isChecking, "A cancelled connection cannot later populate models")
    }
    @MainActor static func main() async {
        do {
            try await explicitConsent()
            try await sourceRevalidation()
            try await contextAndCancellation()
            print("PASS: \(checks) audit session checks (synthetic sources and provider)")
        } catch { print("FAIL: \(error)"); exit(1) }
    }
}
