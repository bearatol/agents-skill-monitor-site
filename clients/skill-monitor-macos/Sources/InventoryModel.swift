import AppKit
import Combine

struct InventoryChange: Identifiable {
    let id = UUID()
    let category: String
    let componentID: String
    let name: String
    let kind: ComponentKind
    let path: String
    let previousPath: String?
    let recordedAt: Date
}

private struct ComponentSnapshot {
    let fingerprint: String
    let name: String
    let kind: ComponentKind
    let path: String
}

@MainActor
final class InventoryModel: ObservableObject {
    @Published var language: AppLanguage
    @Published private(set) var roots: [String]
    @Published private(set) var inventory = LocalInventory.empty
    @Published private(set) var isScanning = false
    @Published private(set) var hasScanned = false
    @Published private(set) var duplicateGroups: [[LocalSkill]] = []
    private(set) var duplicateIDs: Set<String> = []
    @Published var search = ""
    @Published var duplicatesOnly = false
    @Published var findingsOnly = false
    @Published var selectedID: String?
    @Published var showNotices = false
    @Published var kindFilter = "all"
    @Published var mode = "components"
    @Published private(set) var changedIDs: Set<String> = []
    @Published private(set) var addedIDs: Set<String> = []
    @Published private(set) var removedIDs: Set<String> = []
    @Published private(set) var hasComparison = false
    @Published private(set) var comparisonDeferred = false
    @Published private(set) var changeJournal: [InventoryChange] = []
    @Published private(set) var journalLimited = false
    @Published var autoRefresh = true
    private var snapshots: [String: ComponentSnapshot] = [:]
    private var hasBaseline = false
    private let scannerQueue = DispatchQueue(label: "local.skill.inventory", qos: .userInitiated)
    private var generation = 0
    private var running = false
    private var rerunRequested = false
    private var started = false
    private let scan: ([String]) -> LocalInventory

    init(arguments: [String] = CommandLine.arguments,
         scanner: @escaping ([String]) -> LocalInventory = { SkillScanner.scan(roots: $0) }) {
        scan = scanner
        var selectedRoots: [String] = []
        var selectedLanguage = AppLanguage.russian
        var index = 1
        while index < arguments.count {
            if arguments[index] == "--scan-root", index + 1 < arguments.count {
                selectedRoots.append(arguments[index + 1])
                index += 2
            } else if arguments[index] == "--locale", index + 1 < arguments.count {
                selectedLanguage = AppLanguage(rawValue: arguments[index + 1]) ?? .russian
                index += 2
            } else {
                index += 1
            }
        }
        language = selectedLanguage
        roots = selectedRoots.isEmpty
            ? [FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".agents").path]
            : Array(NSOrderedSet(array: selectedRoots)) as? [String] ?? selectedRoots
    }

    var l: Localization { Localization(language: language) }

    var filteredSkills: [LocalSkill] {
        let duplicates = duplicateIDs
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return inventory.skills.filter { skill in
            (kindFilter == "all" || skill.kind.rawValue == kindFilter) &&
            (!duplicatesOnly || duplicates.contains(skill.id)) &&
            (!findingsOnly || !skill.findings.isEmpty) &&
            (query.isEmpty || [skill.name, skill.summary, skill.summaryKey.isEmpty ? "" : l.text(skill.summaryKey), skill.filePath, skill.canonicalPath]
                .contains { $0.localizedCaseInsensitiveContains(query) } ||
                skill.locations.contains { $0.path.localizedCaseInsensitiveContains(query) })
        }
    }

    var selectedSkill: LocalSkill? { filteredSkills.first { $0.id == selectedID } }

    func start() {
        guard !started else { return }
        started = true
        refresh()
    }

    func refresh() {
        generation += 1
        isScanning = true
        if running { rerunRequested = true; return }
        startScan()
    }

    private func startScan() {
        running = true
        rerunRequested = false
        let requestedRoots = roots
        let requestedGeneration = generation
        let scanner = scan
        scannerQueue.async { [weak self] in
            let result = scanner(requestedRoots)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.running = false
                if self.generation == requestedGeneration {
                    self.inventory = result
                    self.comparisonDeferred = !self.canCompare(result, roots: requestedRoots)
                    if !self.comparisonDeferred {
                        let nextSnapshots = Dictionary(uniqueKeysWithValues: result.skills.map {
                            ($0.id, ComponentSnapshot(fingerprint: $0.fingerprint, name: $0.name, kind: $0.kind, path: $0.filePath))
                        })
                        if self.hasBaseline {
                            var events: [InventoryChange] = []
                            for item in result.skills {
                                if let previous = self.snapshots[item.id] {
                                    if previous.fingerprint != item.fingerprint {
                                        events.append(InventoryChange(category: "changed", componentID: item.id,
                                            name: item.name, kind: item.kind, path: item.filePath,
                                            previousPath: previous.path, recordedAt: result.scannedAt))
                                    }
                                } else {
                                    events.append(InventoryChange(category: "added", componentID: item.id,
                                        name: item.name, kind: item.kind, path: item.filePath,
                                        previousPath: nil, recordedAt: result.scannedAt))
                                }
                            }
                            for id in Set(self.snapshots.keys).subtracting(nextSnapshots.keys).sorted() {
                                guard let previous = self.snapshots[id] else { continue }
                                events.append(InventoryChange(category: "missing", componentID: id,
                                    name: previous.name, kind: previous.kind, path: previous.path,
                                    previousPath: previous.path, recordedAt: result.scannedAt))
                            }
                            self.changeJournal.append(contentsOf: events)
                            if self.changeJournal.count > 500 {
                                self.changeJournal.removeFirst(self.changeJournal.count - 500)
                                self.journalLimited = true
                            }
                            self.updateChangeMarkers()
                            self.hasComparison = true
                        }
                        self.snapshots = nextSnapshots
                        self.hasBaseline = true
                    }
                    self.duplicateGroups = Dictionary(grouping: result.skills.filter { !$0.issues.contains("missing_name") }) {
                        $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    }.values.filter { $0.count > 1 }
                    self.duplicateIDs = Set(self.duplicateGroups.flatMap { $0.map(\.id) })
                    self.hasScanned = true
                    if !result.skills.contains(where: { $0.id == self.selectedID }) {
                        self.selectedID = result.skills.first?.id
                    }
                }
                if self.rerunRequested || self.generation != requestedGeneration {
                    self.startScan()
                } else {
                    self.isScanning = false
                }
            }
        }
    }

    private func canCompare(_ result: LocalInventory, roots: [String]) -> Bool {
        guard !result.limited else { return false }
        let selectedPaths = Set(roots.map { URL(fileURLWithPath: $0).standardizedFileURL.path })
        for notice in result.notices {
            // Excluded descendant links do not make the selected scope incomplete.
            // A selected root that cannot be scanned must retain the last baseline.
            if ["outside_scope", "symlink_cycle"].contains(notice.code),
               !selectedPaths.contains(URL(fileURLWithPath: notice.path).standardizedFileURL.path) {
                continue
            }
            return false
        }
        let incompleteIssues: Set<String> = ["scan_limit", "unreadable_file", "changed_during_read",
            "invalid_config", "oversized_header", "unsupported_file", "hard_link"]
        return !result.skills.contains { !incompleteIssues.isDisjoint(with: $0.issues) }
    }

    func chooseFolders() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.showsHiddenFiles = true
        var isDirectory: ObjCBool = false
        if let root = roots.first,
           FileManager.default.fileExists(atPath: root, isDirectory: &isDirectory), isDirectory.boolValue {
            panel.directoryURL = URL(fileURLWithPath: root, isDirectory: true)
        } else {
            panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        }
        panel.title = l.text("choose_folders")
        panel.prompt = l.text("add")
        panel.message = l.text("folder_picker_message")
        panel.begin { [weak self] response in
            guard response == .OK else { return }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let additions = panel.urls.map(\.path).filter { !self.roots.contains($0) }
                guard !additions.isEmpty else { return }
                self.roots.append(contentsOf: additions)
                self.resetForNewRoots()
            }
        }
    }

    func removeRoot(_ root: String) {
        roots.removeAll { $0 == root }
        resetForNewRoots()
    }

    func addSuggestedFolders(_ paths: [String]) {
        let additions = paths.filter { !roots.contains($0) }
        guard !additions.isEmpty else { return }
        roots.append(contentsOf: additions)
        resetForNewRoots()
    }

    func acknowledgeChanges() {
        changeJournal = []
        journalLimited = false
        updateChangeMarkers()
    }

    private func updateChangeMarkers() {
        addedIDs = Set(changeJournal.filter { $0.category == "added" }.map(\.componentID))
        changedIDs = Set(changeJournal.filter { $0.category == "changed" }.map(\.componentID))
        removedIDs = Set(changeJournal.filter { $0.category == "missing" }.map(\.componentID))
    }

    private func resetForNewRoots() {
        inventory = .empty
        duplicateGroups = []
        duplicateIDs = []
        changedIDs = []
        addedIDs = []
        removedIDs = []
        snapshots = [:]
        changeJournal = []
        journalLimited = false
        hasBaseline = false
        hasComparison = false
        comparisonDeferred = false
        hasScanned = false
        selectedID = nil
        refresh()
    }

    func scanPath(for root: String) -> String? {
        let normalized = URL(fileURLWithPath: root).standardizedFileURL.path
        return inventory.scanPaths.first { $0 == normalized || $0 == normalized + "/skills" }
    }

    func rootFailed(_ root: String) -> Bool {
        inventory.notices.contains {
            ["missing_root", "unreadable_root", "outside_scope", "changed_during_read"].contains($0.code) && $0.path == root
        }
    }
}

