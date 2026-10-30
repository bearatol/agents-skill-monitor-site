import Foundation
import Darwin

private struct ModelTestFailure: Error, CustomStringConvertible {
    let description: String
}

private final class ScanSequence {
    private let lock = NSLock()
    private var responses: [LocalInventory]
    private var requestedRoots: [[String]] = []
    var calls: [[String]] {
        lock.lock()
        defer { lock.unlock() }
        return requestedRoots
    }
    init(_ responses: [LocalInventory]) { self.responses = responses }
    func scan(_ roots: [String]) -> LocalInventory {
        lock.lock()
        defer { lock.unlock() }
        requestedRoots.append(roots)
        return responses.isEmpty ? .empty : responses.removeFirst()
    }
}

@main
struct InventoryModelTests {
    private static let root = "/fixture/inventory"
    @MainActor private static var checks = 0

    @MainActor private static func expect(_ value: @autoclosure () -> Bool, _ message: String) throws {
        checks += 1
        if !value() { throw ModelTestFailure(description: message) }
    }

    private static func component(_ id: String = "a", fingerprint: String = "1", issues: [String] = [],
                                  name: String? = nil, kind: ComponentKind = .skill,
                                  findings: [MetadataFinding] = []) -> LocalSkill {
        let path = root + "/" + id + "/SKILL.md"
        return LocalSkill(id: path, name: name ?? id, summary: "Fixture", filePath: path, canonicalPath: path,
            locations: [SkillLocation(path: path, root: root, viaSymlink: false)], issues: issues,
            modifiedAt: nil, kind: kind, findings: findings, fingerprint: fingerprint)
    }

    private static func inventory(_ skills: [LocalSkill], limited: Bool = false,
                                  notices: [ScanNotice] = []) -> LocalInventory {
        LocalInventory(skills: skills, notices: notices, scannedAt: Date(), roots: [root],
                       scanPaths: [root], limited: limited)
    }

    private static func notice(_ code: String, path: String = root) -> ScanNotice {
        ScanNotice(id: code + path, code: code, path: path)
    }

    @MainActor private static func model(_ responses: [LocalInventory]) -> InventoryModel {
        let sequence = ScanSequence(responses)
        return InventoryModel(arguments: ["tests", "--scan-root", root], scanner: sequence.scan)
    }

    @MainActor private static func waitForScan(_ model: InventoryModel) async throws {
        let deadline = Date().addingTimeInterval(5)
        while model.isScanning && Date() < deadline {
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        try expect(!model.isScanning, "Scan did not finish within five seconds")
    }

    @MainActor private static func refresh(_ model: InventoryModel) async throws {
        model.refresh()
        try await waitForScan(model)
    }

    @MainActor private static func partialRecovery() async throws {
        let a = component()
        let subject = model([inventory([a]), inventory([], limited: true), inventory([a])])
        try await refresh(subject)
        try expect(subject.changeJournal.isEmpty, "First complete scan establishes baseline")
        try await refresh(subject)
        try expect(subject.inventory.skills.isEmpty, "Partial current results remain visible")
        try expect(subject.changeJournal.isEmpty, "Limited scan must not report a missing component")
        try expect(subject.comparisonDeferred && !subject.hasComparison, "Limited scan explains deferred comparison")
        try await refresh(subject)
        try expect(subject.changeJournal.isEmpty, "Recovery must not report an unchanged component as added")
        try expect(!subject.comparisonDeferred && subject.hasComparison, "Recovery resumes comparison")
    }

    @MainActor private static func failedObservationRecovery() async throws {
        let a = component()
        let failures = ["unreadable_root", "missing_root", "unreadable_file", "changed_during_read",
                        "invalid_config", "oversized_header", "unsupported_file", "hard_link", "scan_limit"]
        for code in failures {
            let subject = model([inventory([a]), inventory([], notices: [notice(code)]), inventory([a])])
            try await refresh(subject)
            try await refresh(subject)
            try expect(subject.comparisonDeferred && subject.changeJournal.isEmpty,
                       "\(code) must defer missing events")
            try await refresh(subject)
            try expect(!subject.comparisonDeferred && subject.changeJournal.isEmpty,
                       "\(code) recovery must compare the last complete baseline")
        }
        for issue in ["unreadable_file", "invalid_config", "oversized_header", "scan_limit",
                      "changed_during_read", "unsupported_file", "hard_link"] {
            let subject = model([inventory([a]), inventory([component(fingerprint: "partial", issues: [issue])]), inventory([a])])
            try await refresh(subject)
            try await refresh(subject)
            try expect(subject.comparisonDeferred && subject.changeJournal.isEmpty,
                       "Record-level \(issue) must defer changed events")
            try await refresh(subject)
            try expect(subject.changeJournal.isEmpty, "Record failure must not replace the baseline")
        }
    }

    @MainActor private static func firstPartialScan() async throws {
        let subject = model([inventory([component("partial")], limited: true), inventory([component()]),
                             inventory([component(fingerprint: "2")])])
        try await refresh(subject)
        try expect(subject.hasScanned && subject.comparisonDeferred, "First partial results are visible")
        try await refresh(subject)
        try expect(subject.changeJournal.isEmpty && !subject.hasComparison,
                   "First complete scan after partial results establishes baseline without invented history")
        try await refresh(subject)
        try expect(subject.changeJournal.map(\.category) == ["changed"], "Next complete scan compares the first usable baseline")
    }

    @MainActor private static func actualChanges() async throws {
        let a = component()
        let updated = component(fingerprint: "2")
        let subject = model([inventory([a]), inventory([updated]), inventory([]), inventory([updated])])
        try await refresh(subject)
        try await refresh(subject)
        try expect(subject.changedIDs == [a.id], "Complete metadata changes create changed marker")
        try await refresh(subject)
        try expect(subject.removedIDs == [a.id], "Complete empty scan creates missing marker")
        try await refresh(subject)
        try expect(subject.changeJournal.map(\.category) == ["changed", "missing", "added"],
                   "Complete absence and return create legitimate missing and added events")
        try expect(subject.addedIDs == [a.id], "Returned component has added marker")

        let malformed = component(fingerprint: "malformed", issues: ["missing_name", "invalid_frontmatter"])
        let stableRecord = model([inventory([a]), inventory([malformed]), inventory([a])])
        try await refresh(stableRecord)
        try await refresh(stableRecord)
        try expect(!stableRecord.comparisonDeferred && stableRecord.changeJournal.map(\.category) == ["changed"],
                   "Stable record with frontmatter warnings is changed, never missing")
        try await refresh(stableRecord)
        try expect(stableRecord.changeJournal.map(\.category) == ["changed", "changed"],
                   "Fixing frontmatter creates a real changed event")
    }

    @MainActor private static func excludedLinks() async throws {
        for code in ["outside_scope", "symlink_cycle"] {
            let subject = model([inventory([component()]), inventory([component(fingerprint: "2")],
                notices: [notice(code, path: root + "/excluded-link")])])
            try await refresh(subject)
            try await refresh(subject)
            try expect(!subject.comparisonDeferred && subject.changeJournal.map(\.category) == ["changed"],
                       "Intentionally excluded descendant \(code) must not permanently pause the journal")
        }
        let subject = model([inventory([component()]), inventory([], notices: [notice("outside_scope", path: root + "/./")]),
                             inventory([component()])])
        try await refresh(subject)
        try await refresh(subject)
        try expect(subject.comparisonDeferred && subject.changeJournal.isEmpty,
                   "Normalized selected-root outside_scope must defer comparison")
        try await refresh(subject)
        try expect(subject.changeJournal.isEmpty, "Selected-root recovery preserves baseline")
    }

    @MainActor private static func retentionAndAcknowledgement() async throws {
        let a = component()
        let additions = (0...500).map { component("b\($0)") }
        let subject = model([inventory([a]), inventory([a] + additions), inventory([a] + additions), inventory([])])
        try await refresh(subject)
        try await refresh(subject)
        try expect(subject.changeJournal.count == 500 && subject.journalLimited, "Journal retains newest 500 events")
        try expect(subject.changeJournal.first?.componentID == additions[1].id &&
                   subject.changeJournal.last?.componentID == additions[500].id, "Journal drops oldest events")
        try expect(subject.addedIDs.count == 500, "Markers match retained journal")
        subject.acknowledgeChanges()
        try expect(subject.changeJournal.isEmpty && !subject.journalLimited && subject.addedIDs.isEmpty &&
                   subject.changedIDs.isEmpty && subject.removedIDs.isEmpty, "Acknowledgement clears events and markers")
        try await refresh(subject)
        try expect(subject.changeJournal.isEmpty, "Acknowledgement preserves complete baseline")
        try await refresh(subject)
        try expect(subject.changeJournal.count == 500 && subject.removedIDs.count == 500,
                   "Subsequent real removals still compare against acknowledged baseline")
    }

    @MainActor private static func rootsAndGenerations() async throws {
        let sequence = ScanSequence([inventory([component("stale")]), inventory([component("current")]),
                                     inventory([component("current", fingerprint: "2")])])
        let subject = InventoryModel(arguments: ["tests", "--scan-root", root], scanner: sequence.scan)
        subject.start()
        subject.refresh()
        subject.refresh()
        try await waitForScan(subject)
        try expect(sequence.calls.count == 2, "Rapid refresh coalesces pending requests")
        try expect(subject.inventory.skills.first?.name == "current" && subject.changeJournal.isEmpty,
                   "Stale generation must not set current inventory or establish baseline")
        try await refresh(subject)
        try expect(subject.changeJournal.map(\.category) == ["changed"], "Latest complete generation establishes comparison baseline")

        let resetSequence = ScanSequence([inventory([component()]), inventory([component("new-root")]),
                                         inventory([], limited: true), inventory([component("new-root")])])
        let reset = InventoryModel(arguments: ["tests", "--scan-root", root], scanner: resetSequence.scan)
        try await refresh(reset)
        reset.addSuggestedFolders(["/fixture/second-root"])
        try await waitForScan(reset)
        try expect(reset.changeJournal.isEmpty && !reset.hasComparison && !reset.comparisonDeferred,
                   "Changing roots resets journal and establishes a fresh baseline")
        try expect(resetSequence.calls.last == [root, "/fixture/second-root"], "Scanner receives updated selected roots")
        try await refresh(reset)
        try expect(reset.comparisonDeferred, "Partial result defers after root reset")
        try await refresh(reset)
        try expect(reset.changeJournal.isEmpty, "Root-reset baseline survives later incomplete observation")

        let inflight = ScanSequence([inventory([component("old-scope")]), inventory([component("new-scope")])])
        let moving = InventoryModel(arguments: ["tests", "--scan-root", root], scanner: inflight.scan)
        moving.refresh()
        moving.addSuggestedFolders(["/fixture/second-root"])
        try await waitForScan(moving)
        try expect(moving.inventory.skills.first?.name == "new-scope" && moving.changeJournal.isEmpty && !moving.hasComparison,
                   "Root change during a scan discards stale scope and its baseline")
    }

    @MainActor private static func findingsFilter() async throws {
        let info = MetadataFinding(id: "info", code: "fixture_info", severity: "info", evidence: "Fixture", line: nil)
        let high = MetadataFinding(id: "high", code: "fixture_high", severity: "high", evidence: "Fixture", line: nil)
        let a = component("a", name: "Shared", findings: [info, high])
        let b = component("b", name: "Shared", kind: .agent, findings: [high])
        let c = component("c", name: "Shared")
        let d = component("d", name: "Other", findings: [info])
        let e = component("e", issues: ["missing_description"])
        let subject = model([inventory([a, b, c, d, e])])
        try await refresh(subject)
        try expect(subject.filteredSkills.count == 5, "Findings filter defaults to all components")
        subject.findingsOnly = true
        try expect(subject.filteredSkills.map(\.id) == [a.id, b.id, d.id],
                   "Findings filter includes advisory info and counts components once, excluding issues-only records")
        subject.duplicatesOnly = true
        try expect(subject.filteredSkills.map(\.id) == [a.id, b.id], "Findings and duplicate filters combine")
        subject.kindFilter = "skill"
        try expect(subject.filteredSkills.map(\.id) == [a.id], "Findings, duplicate and type filters combine")
        subject.search = "Other"
        try expect(subject.filteredSkills.isEmpty, "Search remains an AND condition with other filters")
        subject.duplicatesOnly = false
        try expect(subject.filteredSkills.map(\.id) == [d.id], "Search can match advisory info-only component")
        subject.search = "a/SKILL.md"
        try expect(subject.filteredSkills.map(\.id) == [a.id], "Findings filter preserves path search")
        subject.search = ""
        subject.findingsOnly = false
        try expect(subject.filteredSkills.map(\.id) == [a.id, c.id, d.id, e.id], "Disabling findings preserves type filter")
    }

    @MainActor static func main() async {
        do {
            try await findingsFilter()
            try await partialRecovery()
            try await failedObservationRecovery()
            try await firstPartialScan()
            try await actualChanges()
            try await excludedLinks()
            try await retentionAndAcknowledgement()
            try await rootsAndGenerations()
            print("PASS: \(checks) inventory model checks")
        } catch {
            print("FAIL: \(error)")
            exit(1)
        }
    }
}
