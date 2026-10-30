import AppKit
import SwiftUI


enum MonitorTypography {
    static let body = Font.system(size: 15)
    static let callout = Font.system(size: 14)
    static let caption = Font.system(size: 13)
    static let caption2 = Font.system(size: 12)
    static let headline = Font.system(size: 15, weight: .semibold)
    static let title2 = Font.system(size: 19)
    static let title3 = Font.system(size: 17)
    static let libraryTitle = Font.system(size: 29, weight: .semibold)
    static let componentTitle = Font.system(size: 25, weight: .semibold)
    static let rowTitle = Font.system(size: 16, weight: .semibold)
    static let count = Font.system(size: 26, weight: .semibold, design: .rounded)
    static let code = Font.system(size: 12, design: .monospaced)
    static let path = Font.system(size: 13, design: .monospaced)
}

final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct SkillMonitorApp: App {
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) private var delegate
    @StateObject private var model = InventoryModel()

    var body: some Scene {
        Window(model.l.text("app_title"), id: "inventory") {
            InventoryView(model: model)
                .font(MonitorTypography.body)
                .environment(\.locale, model.language.locale)
                .frame(minWidth: 1040, minHeight: 650)
                .onAppear { model.start() }
        }
        .defaultSize(width: 1180, height: 760)
        .commands { CommandGroup(replacing: .newItem) {} }
    }
}

struct InventoryView: View {
    @ObservedObject var model: InventoryModel
    @StateObject private var audit = AuditSession()
    @State private var showAudit = false
    @State private var showSuggestions = false
    @State private var showFolderHelp = false
    @State private var chooseManuallyAfterSheet = false
    private let refreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    private let accent = Color(red: 0.08, green: 0.43, blue: 0.43)
    private var l: Localization { model.l }

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 252)
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                header
                summary.padding(.horizontal, 24).padding(.bottom, 20)
                Picker(l.text("view_mode"), selection: $model.mode) {
                    Text(l.text("components")).tag("components")
                    Text(l.text("links")).tag("links")
                    Text(l.text("checks")).tag("checks")
                    Text(l.text("changes")).tag("changes")
                }.pickerStyle(.segmented).frame(maxWidth: 500)
                    .padding(.horizontal, 24).padding(.bottom, 16)
                    .accessibilityIdentifier("view-mode")
                Divider()
                HSplitView {
                    fileList.frame(minWidth: 320, idealWidth: 380)
                    inspector.frame(minWidth: 330, idealWidth: 390)
                }
                footer
            }
        }
        .tint(accent)
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: model.selectedID) { _ in
            model.showNotices = false
            audit.invalidateScope()
        }
        .onChange(of: model.roots) { _ in audit.invalidateScope() }
        .onChange(of: model.language) { _ in audit.invalidateScope() }
        .onChange(of: model.inventory.scannedAt) { _ in
            audit.validateSelection(component: model.selectedSkill, roots: model.roots, language: model.language)
        }
        .onChange(of: model.mode) { _ in model.showNotices = false }
        .sheet(isPresented: $showAudit, onDismiss: { audit.cancel() }) {
            AuditWorkspaceView(session: audit, model: model)
        }
        .sheet(isPresented: $showSuggestions, onDismiss: {
            if chooseManuallyAfterSheet {
                chooseManuallyAfterSheet = false
                model.chooseFolders()
            }
        }) {
            FolderSuggestionSheet(model: model) { chooseManuallyAfterSheet = true }
        }
        .sheet(isPresented: $showFolderHelp, onDismiss: {
            if chooseManuallyAfterSheet {
                chooseManuallyAfterSheet = false
                model.chooseFolders()
            }
        }) {
            FolderHelpSheet(model: model) { chooseManuallyAfterSheet = true }
        }
        .onReceive(refreshTimer) { _ in
            if model.autoRefresh && !model.roots.isEmpty && !model.isScanning { model.refresh() }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "square.stack.3d.up.fill").font(MonitorTypography.title2).foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(l.text("app_title")).font(MonitorTypography.headline)
                    Text(l.text("local_client")).font(MonitorTypography.caption).foregroundStyle(.secondary)
                }
            }.padding(.top, 10)
            Divider()
            HStack {
                Text(l.text("folders")).font(MonitorTypography.headline)
                Spacer()
            }
            Text(l.text("session_folders")).font(MonitorTypography.caption).foregroundStyle(.secondary)
            Button { model.chooseFolders() } label: {
                Label(l.text("add_folder"), systemImage: "plus").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("add-folder")
            Button { showFolderHelp = true } label: {
                Label(l.text("where_to_look"), systemImage: "questionmark.circle").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("where-to-look")
            Button { showSuggestions = true } label: {
                Label(l.text("ask_my_ai"), systemImage: "text.bubble").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("ask-ai")
            Button { showAudit = true } label: {
                Label(l.text("local_ai"), systemImage: "desktopcomputer").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("local-ai")
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(model.roots, id: \.self) { root in folderRow(root) }
                    if model.roots.isEmpty {
                        Text(l.text("no_folders_sidebar")).font(MonitorTypography.callout).foregroundStyle(.secondary)
                    }
                }
            }.accessibilityIdentifier("folders")
            Spacer(minLength: 0)
            Divider()
            Toggle(l.text("auto_refresh"), isOn: $model.autoRefresh)
                .toggleStyle(.checkbox).font(MonitorTypography.caption)
                .accessibilityIdentifier("auto-refresh")
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(l.text("connection_status")).font(MonitorTypography.caption.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Label(l.text(audit.modelReady ? "local_ai_ready" : "local_ai_not_connected"),
                              systemImage: audit.modelReady ? "checkmark.circle" : "circle.dashed")
                            .font(MonitorTypography.caption)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(l.text("antivirus_not_connected")).font(MonitorTypography.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }.accessibilityIdentifier("connection-status")
                    Label(l.text("local_only"), systemImage: "internaldrive")
                        .font(MonitorTypography.caption)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(l.text("phase_scope")).font(MonitorTypography.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 230)
            .accessibilityIdentifier("sidebar-status")
        }
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.65))
    }

    private func folderRow(_ root: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Image(systemName: model.rootFailed(root) ? "folder.badge.questionmark" : "folder")
                    .foregroundStyle(model.rootFailed(root) ? Color.orange : accent)
                Text(URL(fileURLWithPath: root).lastPathComponent).font(MonitorTypography.callout.weight(.semibold)).lineLimit(1)
                Spacer(minLength: 2)
                Button { model.removeRoot(root) } label: { Image(systemName: "minus.circle") }
                    .buttonStyle(.bordered)
                    .help(l.text("remove_folder"))
                    .accessibilityLabel(l.text("remove_folder") + ": " + root)
                    .accessibilityIdentifier("remove-folder")
            }
            pathText(root).font(MonitorTypography.caption)
            if let scope = model.scanPath(for: root), scope != root {
                Text(l.text("scan_path")).font(MonitorTypography.caption2).foregroundStyle(.secondary)
                pathText(scope).font(MonitorTypography.caption)
            }
            if model.rootFailed(root) {
                Text(l.text("folder_failed")).font(MonitorTypography.caption).foregroundStyle(.orange)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text(l.text("library_title")).font(MonitorTypography.libraryTitle)
                Text(l.text("library_subtitle")).font(MonitorTypography.callout).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Picker(l.text("language"), selection: $model.language) {
                ForEach(AppLanguage.allCases) { language in
                    Text(l.text("language_" + language.rawValue)).tag(language)
                }
            }
            .labelsHidden().frame(width: 130)
            .accessibilityLabel(l.text("language"))
            .accessibilityIdentifier("language")
            Button { model.refresh() } label: { Label(l.text("refresh"), systemImage: "arrow.clockwise") }
                .buttonStyle(.bordered)
                .disabled(model.isScanning)
                .keyboardShortcut("r", modifiers: .command)
                .accessibilityIdentifier("refresh")
        }.padding(24)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ForEach(ComponentKind.allCases, id: \.rawValue) { kind in
                    metric("kind_" + kind.rawValue, value: model.inventory.skills.filter { $0.kind == kind }.count,
                           icon: kindIcon(kind), color: accent)
                }
            }
            HStack(spacing: 16) {
                Text(model.hasScanned ? l.count("total_components", model.inventory.skills.count) : l.text("scanning"))
                if model.hasScanned { Text(l.count("duplicate_count", model.duplicateGroups.count)) }
            }.font(MonitorTypography.caption).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 12) {
                Button { model.showAllFindings() } label: {
                    Label(l.count("view_all_findings", model.findingComponentCount), systemImage: "checklist")
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.hasScanned)
                .accessibilityIdentifier("view-all-findings")
                Button { model.showNotices.toggle() } label: {
                    Label(l.count("view_read_notices", model.inventory.notices.count), systemImage: "text.bubble")
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(.bordered)
                .disabled(!model.hasScanned)
                .accessibilityIdentifier("notices")
            }.font(MonitorTypography.callout)
            if model.hasScanned {
                Text(l.count("finding_count", model.findingCount))
                    .font(MonitorTypography.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func metric(_ key: String, value: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon).font(MonitorTypography.title3).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 4) {
                Text(model.hasScanned ? String(value) : "...").font(MonitorTypography.count)
                Text(l.text(key)).font(MonitorTypography.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var fileList: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField(l.text("search"), text: $model.search)
                        .textFieldStyle(.plain).accessibilityIdentifier("search")
                    if !model.search.isEmpty {
                        Button { model.search = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.bordered).foregroundStyle(.secondary)
                            .help(l.text("clear_search"))
                            .accessibilityLabel(l.text("clear_search"))
                    }
                }.padding(9).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                Picker(l.text("component_type"), selection: $model.kindFilter) {
                    Text(l.text("all_types")).tag("all")
                    ForEach(ComponentKind.allCases, id: \.rawValue) { kind in
                        Text(l.text("kind_" + kind.rawValue)).tag(kind.rawValue)
                    }
                }.accessibilityIdentifier("type-filter")
                Toggle(l.text("duplicates_only"), isOn: $model.duplicatesOnly)
                    .toggleStyle(.checkbox).font(MonitorTypography.callout).accessibilityIdentifier("duplicates")
                Toggle(isOn: $model.findingsOnly) {
                    Text(l.text("findings_only")).fixedSize(horizontal: false, vertical: true)
                }
                .toggleStyle(.checkbox).font(MonitorTypography.callout)
                .accessibilityIdentifier("findings-only")
                Text(model.hasScanned ? l.count(model.findingsOnly ? "findings_component_count" : "shown_files", model.filteredSkills.count) : l.text("scanning"))
                    .font(MonitorTypography.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("filtered-component-count")
            }.padding(18)
            Divider()
            if !model.hasScanned && model.isScanning {
                emptyState("scanning", detail: "scanning_detail", icon: "magnifyingglass")
            } else if model.roots.isEmpty {
                emptyState("no_folders", detail: "no_folders_detail", icon: "folder.badge.plus")
            } else if model.filteredSkills.isEmpty {
                if model.findingsOnly && model.findingComponentCount == 0 {
                    emptyState("no_check_findings", detail: "no_findings", icon: "checklist")
                } else {
                    emptyState(model.inventory.skills.isEmpty ? (model.inventory.notices.isEmpty ? "no_files" : "no_files_with_notices") : "no_matches",
                           detail: model.inventory.skills.isEmpty ? "no_files_detail" : "no_matches_detail",
                           icon: "doc.text.magnifyingglass")
                }
            } else {
                List(selection: $model.selectedID) {
                    ForEach(model.filteredSkills) { skill in
                        skillRow(skill).tag(skill.id)
                    }
                }.listStyle(.inset).accessibilityIdentifier("list")
            }
        }
    }

    private func skillRow(_ skill: LocalSkill) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: kindIcon(skill.kind)).foregroundStyle(.secondary)
                Text(skill.name).font(MonitorTypography.rowTitle).lineLimit(1)
                Spacer(minLength: 0)
                if model.duplicateIDs.contains(skill.id) {
                    Image(systemName: "square.on.square").foregroundStyle(.secondary).help(l.text("duplicate_name"))
                }
                if !skill.issues.isEmpty {
                    Image(systemName: "exclamationmark.circle").foregroundStyle(.orange).help(l.text("metadata_issues"))
                }
                if model.changedIDs.contains(skill.id) {
                    Image(systemName: "circle.fill").font(.system(size: 7)).foregroundStyle(accent)
                        .help(l.text("changed_since_refresh"))
                }
                if model.addedIDs.contains(skill.id) {
                    Text(l.text("added_badge")).font(MonitorTypography.caption2).foregroundStyle(accent)
                }
            }
            Text(displaySummary(skill))
                .font(MonitorTypography.callout).foregroundStyle(.secondary).lineLimit(2)
            if !skill.findings.isEmpty {
                let severity = highestSeverity(skill.findings)
                Label(l.count("findings_badge", skill.findings.count)
                      .replacingOccurrences(of: "{severity}", with: l.text("severity_" + severity)),
                      systemImage: severityIcon(severity))
                    .font(MonitorTypography.caption.weight(.semibold))
                    .foregroundStyle(severityColor(severity))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("component-findings-badge")
            }
            Text(skill.filePath).font(MonitorTypography.code).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
        }
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var inspector: some View {
        if model.showNotices {
            noticesInspector
        } else if model.mode == "changes" {
            changesInspector
        } else if let skill = model.selectedSkill {
            if model.mode == "links" {
                relationshipInspector(skill)
            } else if model.mode == "checks" {
                checksInspector(skill)
            } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Label(l.text("kind_" + skill.kind.rawValue), systemImage: kindIcon(skill.kind)).font(MonitorTypography.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(skill.name).font(MonitorTypography.componentTitle).textSelection(.enabled)
                    reviewSecurityButton(skill)
                    if !skill.findings.isEmpty {
                        Button { model.mode = "checks" } label: {
                            Label(l.count("view_component_findings", skill.findings.count),
                                  systemImage: severityIcon(highestSeverity(skill.findings)))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("view-component-findings")
                    }
                    Text(l.text("discovery_" + skill.discovery)).font(MonitorTypography.caption).foregroundStyle(.secondary)
                    if model.changedIDs.contains(skill.id) {
                        Label(l.text("changed_since_refresh"), systemImage: "circle.fill").font(MonitorTypography.caption).foregroundStyle(accent)
                    }
                    detailSection(skill.summaryKey.isEmpty ? "description" : "metadata_summary") {
                        Text(displaySummary(skill))
                            .font(MonitorTypography.body).lineSpacing(4).textSelection(.enabled)
                    }
                    detailSection("actual_path") { pathText(skill.filePath) }
                    if skill.canonicalPath != skill.filePath {
                        detailSection("resolved_path") { pathText(skill.canonicalPath) }
                    }
                    detailSection("locations") {
                        Text(l.text("aliases_explanation")).font(MonitorTypography.caption).foregroundStyle(.secondary)
                        ForEach(Array(skill.locations.enumerated()), id: \.offset) { _, location in
                            VStack(alignment: .leading, spacing: 5) {
                                Label(l.text(location.viaSymlink ? "symlink_location" : "direct_location"), systemImage: location.viaSymlink ? "link" : "doc")
                                    .font(MonitorTypography.caption).foregroundStyle(.secondary)
                                pathText(location.path)
                            }.padding(.top, 6)
                        }
                    }
                    if model.duplicateIDs.contains(skill.id) {
                        detailSection("duplicate_name") {
                            Text(l.text("duplicates_explanation")).font(MonitorTypography.callout).foregroundStyle(.secondary)
                            ForEach(model.inventory.skills.filter { $0.id != skill.id && $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == skill.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }) { duplicate in
                                pathText(duplicate.filePath).padding(.top, 5)
                            }
                        }
                    }
                    if !skill.issues.isEmpty {
                        detailSection("metadata_issues") {
                            ForEach(skill.issues, id: \.self) { issue in issueText(issue) }
                        }
                    }
                    if !skill.references.isEmpty {
                        detailSection("declared_references") {
                            Text(l.count("reference_count", skill.references.count)).font(MonitorTypography.callout).foregroundStyle(.secondary)
                            Button(l.text("show_links")) { model.mode = "links" }.buttonStyle(.bordered)
                        }
                    }
                    if !skill.findings.isEmpty {
                        detailSection("metadata_checks") {
                            Text(l.count("finding_count", skill.findings.count)).font(MonitorTypography.callout).foregroundStyle(.secondary)
                            Button(l.text("show_checks")) { model.mode = "checks" }.buttonStyle(.bordered)
                        }
                    }
                    if let modified = skill.modifiedAt {
                        detailSection("modified") { Text(l.date(modified)).font(MonitorTypography.callout).textSelection(.enabled) }
                    }
                }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            }.accessibilityIdentifier("detail")
            }
        } else if model.mode == "checks" && model.hasScanned && model.findingComponentCount == 0 {
            emptyState("no_check_findings", detail: "no_findings", icon: "checklist")
                .accessibilityIdentifier("checks-pane")
        } else {
            emptyState("select_file", detail: "select_file_detail", icon: "doc.text")
                .accessibilityIdentifier("detail")
        }
    }

    private func kindIcon(_ kind: ComponentKind) -> String {
        switch kind {
        case .skill: return "doc.text"
        case .agent: return "person.2"
        case .mcp: return "server.rack"
        case .rag: return "books.vertical"
        }
    }

    private func reviewSecurityButton(_ skill: LocalSkill) -> some View {
        Button {
            showAudit = true
            audit.prepare(component: skill, roots: model.roots, language: model.language)
        } label: {
            Label(l.text("review_security"), systemImage: "shield.lefthalf.filled")
                .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("review-security")
    }

    private func highestSeverity(_ findings: [MetadataFinding]) -> String {
        if findings.contains(where: { $0.severity == "high" }) { return "high" }
        if findings.contains(where: { $0.severity == "medium" }) { return "medium" }
        return "info"
    }

    private func severityIcon(_ severity: String) -> String {
        severity == "high" ? "exclamationmark.octagon" : severity == "medium" ? "exclamationmark.triangle" : "info.circle"
    }

    private func severityColor(_ severity: String) -> Color {
        severity == "high" ? .red : severity == "medium" ? .orange : .secondary
    }

    private var changesInspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(l.text("changes_to_review")).font(MonitorTypography.title2.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(l.text("changes_explanation")).font(MonitorTypography.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(l.text("changes_reset_scope")).font(MonitorTypography.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if model.comparisonDeferred {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(l.text("comparison_paused"), systemImage: "exclamationmark.circle")
                                .font(MonitorTypography.headline).foregroundStyle(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(l.text("comparison_paused_detail")).font(MonitorTypography.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }.accessibilityIdentifier("comparison-paused-detail")
                    }
                    if model.journalLimited {
                        Text(l.text("journal_limit")).font(MonitorTypography.callout).foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Button { model.acknowledgeChanges() } label: {
                        Text(l.text("acknowledge_changes")).fixedSize(horizontal: false, vertical: true)
                    }
                        .disabled(model.changeJournal.isEmpty && !model.journalLimited)
                        .accessibilityIdentifier("acknowledge-changes")
                }.padding(22)
                Divider()
                if model.changeJournal.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath").font(.system(size: 30)).foregroundStyle(.tertiary)
                        Text(l.text(model.comparisonDeferred ? "comparison_paused" : (model.hasComparison ? "no_unreviewed_changes" : "first_scan_baseline")))
                            .font(MonitorTypography.headline).fixedSize(horizontal: false, vertical: true)
                        Text(l.text(model.comparisonDeferred ? "comparison_retry_detail" : "changes_empty_detail"))
                            .font(MonitorTypography.callout).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(model.changeJournal.reversed())) { event in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Label(l.text("event_" + event.category), systemImage: event.category == "missing" ? "questionmark.circle" : "circle.fill")
                                        .font(MonitorTypography.caption.weight(.semibold))
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer(minLength: 0)
                                    Text(l.text("kind_" + event.kind.rawValue)).font(MonitorTypography.caption).foregroundStyle(.secondary)
                                }
                                Text(event.name).font(MonitorTypography.headline).textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(l.date(event.recordedAt)).font(MonitorTypography.caption).foregroundStyle(.secondary)
                                if event.category == "missing" {
                                    Text(l.text("last_seen_path")).font(MonitorTypography.caption).foregroundStyle(.secondary)
                                    pathText(event.previousPath ?? event.path)
                                    Text(l.text("missing_is_not_deleted")).font(MonitorTypography.caption).foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                } else {
                                    pathText(event.path)
                                    if let previous = event.previousPath, previous != event.path {
                                        Text(l.text("last_seen_path")).font(MonitorTypography.caption).foregroundStyle(.secondary)
                                        pathText(previous)
                                    }
                                }
                            }
                            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }.padding(20)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.accessibilityIdentifier("changes-pane")
    }

    private func referencedComponents(_ reference: ComponentReference) -> [LocalSkill] {
        reference.matchingComponents(in: model.inventory.skills)
    }

    private func relationshipInspector(_ skill: LocalSkill) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(l.text("declared_links")).font(MonitorTypography.title2.weight(.semibold))
                Text(l.text("links_explanation")).font(MonitorTypography.callout).foregroundStyle(.secondary)
                if skill.references.isEmpty {
                    Text(l.text("no_links")).font(MonitorTypography.callout).foregroundStyle(.secondary)
                } else {
                    ForEach(Array(skill.references.enumerated()), id: \.offset) { _, reference in
                        VStack(alignment: .leading, spacing: 10) {
                            Label(skill.name, systemImage: kindIcon(skill.kind)).font(MonitorTypography.headline).textSelection(.enabled)
                            HStack(alignment: .center, spacing: 9) {
                                Image(systemName: "arrow.down").foregroundStyle(accent)
                                Text(l.text("relation_" + reference.relation)).font(MonitorTypography.caption).foregroundStyle(.secondary)
                                if let line = reference.line { Text(lineText(line)).font(MonitorTypography.caption).foregroundStyle(.secondary) }
                            }
                            Text(reference.isExternal ? l.text("external_reference_title") : reference.target)
                                .font(MonitorTypography.body.weight(.medium)).textSelection(.enabled)
                            let matches = referencedComponents(reference)
                            if reference.isExternal {
                                Label(l.text("external_reference_detail"), systemImage: "network")
                                    .font(MonitorTypography.caption).foregroundStyle(.secondary)
                            } else if matches.isEmpty {
                                Label(l.text("unresolved_reference"), systemImage: "questionmark.circle").font(MonitorTypography.caption).foregroundStyle(.secondary)
                            } else {
                                if matches.count > 1 {
                                    Text(l.text("ambiguous_reference")).font(MonitorTypography.caption).foregroundStyle(.orange)
                                }
                                ForEach(matches) { item in
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(l.text("kind_" + item.kind.rawValue)).font(MonitorTypography.caption).foregroundStyle(.secondary)
                                        pathText(item.filePath)
                                    }
                                }
                            }
                        }
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
        }.accessibilityIdentifier("links-pane")
    }

    private func checksInspector(_ skill: LocalSkill) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(l.text("metadata_checks")).font(MonitorTypography.title2.weight(.semibold))
                    Text(skill.name).font(MonitorTypography.headline).textSelection(.enabled)
                    Text(l.text("checks_signal_scope")).font(MonitorTypography.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    reviewSecurityButton(skill)
                }
                if skill.findings.isEmpty {
                    Text(l.text("no_findings")).font(MonitorTypography.callout).foregroundStyle(.secondary)
                }
                ForEach(skill.findings, id: \.id) { finding in
                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            Label(l.text("severity_" + finding.severity), systemImage: severityIcon(finding.severity))
                                .font(MonitorTypography.caption.weight(.semibold))
                                .foregroundStyle(severityColor(finding.severity))
                            if let line = finding.line { Text(lineText(line)).font(MonitorTypography.caption).foregroundStyle(.secondary) }
                        }
                        Text(l.text("finding_" + finding.code)).font(MonitorTypography.headline)
                        Text(l.text("evidence_" + finding.code)).font(MonitorTypography.callout).foregroundStyle(.secondary).textSelection(.enabled)
                        Text(l.text("finding_next_step")).font(MonitorTypography.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text(l.text("action_" + finding.code)).font(MonitorTypography.callout).textSelection(.enabled)
                        Text(finding.code).font(MonitorTypography.code).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                }
                if !skill.issues.isEmpty {
                    detailSection("metadata_issues") {
                        ForEach(skill.issues, id: \.self) { issue in issueText(issue) }
                    }
                }
                DisclosureGroup(l.text("checks_coverage_details")) {
                    VStack(alignment: .leading, spacing: 12) {
                        pathText(skill.filePath)
                        Text(l.text("checks_explanation")).font(MonitorTypography.callout).foregroundStyle(.secondary)
                        Text(l.text("checks_scope")).font(MonitorTypography.caption).foregroundStyle(.secondary)
                        Text(l.text("unsupported_toml")).font(MonitorTypography.caption).foregroundStyle(.secondary)
                    }.padding(.top, 10)
                }
                .font(MonitorTypography.callout)
                .accessibilityIdentifier("checks-coverage-details")
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
        }.accessibilityIdentifier("checks-pane")
    }

    private func lineText(_ line: Int) -> String {
        l.text("source_line").replacingOccurrences(of: "{line}", with: String(line))
    }

    private func displaySummary(_ skill: LocalSkill) -> String {
        skill.summaryKey.isEmpty ? (skill.summary.isEmpty ? l.text("no_description") : skill.summary) : l.text(skill.summaryKey)
    }

    private var noticesInspector: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(l.text("read_notices")).font(MonitorTypography.headline)
                Spacer()
                Button { model.showNotices = false } label: { Image(systemName: "xmark") }
                    .buttonStyle(.bordered).help(l.text("close_notices"))
                    .accessibilityLabel(l.text("close_notices"))
            }.padding(20)
            Divider()
            if !model.hasScanned && model.isScanning {
                emptyState("scanning", detail: "scanning_detail", icon: "magnifyingglass")
            } else if model.inventory.notices.isEmpty {
                emptyState("no_notices", detail: "no_notices_detail", icon: "text.bubble")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(model.inventory.notices) { notice in
                            VStack(alignment: .leading, spacing: 8) {
                                issueText(notice.code)
                                pathText(notice.path)
                                if notice.code == "invalid_config" {
                                    Text(l.text("notice_recovery_invalid_config"))
                                        .font(MonitorTypography.callout).foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Button {
                                        let board = NSPasteboard.general
                                        board.clearContents()
                                        board.setString(notice.path, forType: .string)
                                    } label: {
                                        Label(l.text("copy_path"), systemImage: "doc.on.doc")
                                    }
                                    .accessibilityLabel(l.text("copy_path") + ": " + notice.path)
                                    .accessibilityIdentifier("copy-notice-path")
                                }
                            }
                            Divider()
                        }
                    }.padding(20)
                }
            }
        }.accessibilityIdentifier("notices-pane")
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if model.isScanning {
                    ProgressView().controlSize(.small)
                    Text(l.text("scanning"))
                } else if model.hasScanned {
                    Image(systemName: model.inventory.limited ? "exclamationmark.circle" : "clock")
                    Text(l.text(model.inventory.limited ? "partial_scan" : "last_scan") + " " + l.date(model.inventory.scannedAt))
                }
                Spacer()
            }
            if model.hasComparison {
                HStack(spacing: 12) {
                    Text(l.count("added_count", model.addedIDs.count))
                    Text(l.count("changed_count", model.changedIDs.count))
                    Text(l.count("removed_count", model.removedIDs.count))
                }
            }
            HStack(spacing: 12) {
                if model.hasComparison {
                    Button { model.mode = "changes" } label: {
                        Label(l.text("view_changes"), systemImage: "clock.arrow.circlepath")
                            .fixedSize(horizontal: false, vertical: true)
                    }.buttonStyle(.bordered).help(l.text("view_changes"))
                }
                if !model.inventory.notices.isEmpty {
                    Button(l.text("show_notices")) { model.showNotices = true }.buttonStyle(.bordered)
                }
                Spacer(minLength: 0)
            }
            if model.comparisonDeferred {
                Label(l.text("comparison_paused_detail"), systemImage: "exclamationmark.circle")
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("comparison-paused-status")
            }
        }
        .font(MonitorTypography.caption).foregroundStyle(.secondary)
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
        .accessibilityIdentifier("scan-status")
    }

    private func emptyState(_ title: String, detail: String, icon: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 30)).foregroundStyle(.tertiary)
            Text(l.text(title)).font(MonitorTypography.headline).multilineTextAlignment(.center)
            Text(l.text(detail)).font(MonitorTypography.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.padding(30).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func pathText(_ path: String) -> some View {
        Text(path).font(MonitorTypography.path)
            .foregroundStyle(.secondary).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
    }

    private func detailSection<Content: View>(_ key: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(l.text(key)).font(MonitorTypography.caption.weight(.semibold)).foregroundStyle(.secondary)
            content()
        }
    }

    private func issueText(_ code: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(l.text("issue_" + code)).font(MonitorTypography.callout)
            Text(code).font(MonitorTypography.code).foregroundStyle(.secondary).textSelection(.enabled)
        }
    }
}

struct FolderHelpSheet: View {
    @ObservedObject var model: InventoryModel
    let chooseManually: () -> Void
    @Environment(\.dismiss) private var dismiss
    private var l: Localization { model.l }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(l.text("where_to_look")).font(MonitorTypography.title2.weight(.semibold))
                Spacer()
                Button(l.text("cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(l.text("folder_help")).font(MonitorTypography.callout)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(l.text("folders")).font(MonitorTypography.headline)
                    ForEach(model.roots, id: \.self) { root in
                        Text(root).font(MonitorTypography.path).textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if model.roots.isEmpty {
                        Text(l.text("no_folders_sidebar")).font(MonitorTypography.callout).foregroundStyle(.secondary)
                    }
                    Text(l.text("session_folders")).font(MonitorTypography.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            Button(l.text("choose_manually")) {
                chooseManually()
                dismiss()
            }.accessibilityIdentifier("help-choose-manually")
        }
        .padding(26)
        .frame(width: 620, height: 440)
        .font(MonitorTypography.body)
        .accessibilityIdentifier("folder-help-sheet")
    }
}

struct FolderSuggestionSheet: View {
    @ObservedObject var model: InventoryModel
    let chooseManually: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var response = ""
    @State private var preview: FolderSuggestionResult?
    @State private var selected: Set<String> = []
    @State private var parserError: String?
    @State private var copied = false
    private var l: Localization { model.l }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(l.text("ask_my_ai")).font(MonitorTypography.title2.weight(.semibold))
                Spacer()
                Button(l.text("cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Text(l.text("ai_flow_explanation")).font(MonitorTypography.callout).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button {
                    let board = NSPasteboard.general
                    board.clearContents()
                    copied = board.setString(l.text("ai_folder_prompt"), forType: .string)
                } label: {
                    Label(l.text("copy_ai_request"), systemImage: "doc.on.doc")
                }.accessibilityIdentifier("copy-ai-request")
                if copied { Text(l.text("request_copied")).font(MonitorTypography.caption).foregroundStyle(.secondary) }
            }
            Text(l.text("pasted_ai_response")).font(MonitorTypography.headline)
            Text(l.text("ai_response_format")).font(MonitorTypography.caption).foregroundStyle(.secondary)
            TextEditor(text: $response)
                .font(MonitorTypography.path)
                .frame(height: 130)
                .padding(6)
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.secondary.opacity(0.3)))
                .accessibilityLabel(l.text("pasted_ai_response"))
                .accessibilityIdentifier("ai-response")
                .onChange(of: response) { _ in
                    preview = nil
                    selected = []
                    parserError = nil
                }
            HStack {
                Button(l.text("preview_folders")) { parseResponse() }
                    .disabled(response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("preview-ai-folders")
                if let code = parserError {
                    Text(l.text("parsererror_" + code)).font(MonitorTypography.callout).foregroundStyle(.red)
                }
            }
            Divider()
            if let result = preview {
                Text(l.text("unverified_folders")).font(MonitorTypography.headline)
                Text(l.text("unverified_explanation")).font(MonitorTypography.caption).foregroundStyle(.secondary)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(result.folders) { folder in
                            Toggle(isOn: Binding(
                                get: { selected.contains(folder.id) },
                                set: { value in
                                    if value { selected.insert(folder.id) } else { selected.remove(folder.id) }
                                }
                            )) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(folder.path).font(MonitorTypography.path).textSelection(.enabled)
                                    if !folder.reason.isEmpty { Text(folder.reason).font(MonitorTypography.callout).foregroundStyle(.secondary) }
                                    Text(l.text(folder.alreadyIncluded ? "folder_already_included" : "folder_unverified"))
                                        .font(MonitorTypography.caption).foregroundStyle(.secondary)
                                }
                            }
                            .toggleStyle(.checkbox)
                            .disabled(folder.alreadyIncluded)
                            .accessibilityIdentifier("suggested-folder")
                        }
                        if result.folders.isEmpty {
                            Text(l.text(result.rejectedCount > 0 ? "no_eligible_suggestions" : "no_suggested_folders"))
                                .font(MonitorTypography.callout).foregroundStyle(.secondary)
                        }
                        if result.rejectedCount > 0 {
                            Text(l.count("rejected_folders", result.rejectedCount)).font(MonitorTypography.callout).foregroundStyle(.orange)
                            ForEach(Array(Set(result.rejectedCodes)).sorted(), id: \.self) { code in
                                Text(l.text("rejection_" + code)).font(MonitorTypography.caption).foregroundStyle(.secondary)
                            }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.frame(maxHeight: .infinity).accessibilityIdentifier("ai-folder-preview")
            } else {
                Text(l.text("preview_explanation")).font(MonitorTypography.callout).foregroundStyle(.secondary)
                Spacer(minLength: 20)
            }
            if parserError != nil || preview?.folders.isEmpty == true || (preview?.rejectedCount ?? 0) > 0 {
                Text(l.text("ai_recovery_step")).font(MonitorTypography.callout).foregroundStyle(.secondary)
            }
            HStack {
                Button(l.text("choose_manually")) {
                    chooseManually()
                    dismiss()
                }.accessibilityIdentifier("choose-folder-manually")
                Spacer()
                Text(l.count("folders_selected", selected.count)).font(MonitorTypography.caption).foregroundStyle(.secondary)
                Button(l.text("add_selected_folders")) {
                    let paths = preview?.folders.filter { selected.contains($0.id) && !$0.alreadyIncluded }.map(\.path) ?? []
                    guard !paths.isEmpty else { return }
                    model.addSuggestedFolders(paths)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selected.isEmpty)
                .accessibilityIdentifier("add-suggested-folders")
            }
        }
        .padding(26)
        .frame(width: 780, height: 710)
        .font(MonitorTypography.body)
        .accessibilityIdentifier("ai-folder-sheet")
    }

    private func parseResponse() {
        selected = []
        parserError = nil
        do {
            preview = try FolderSuggestionParser.parse(response,
                home: FileManager.default.homeDirectoryForCurrentUser.path, existing: model.roots)
        } catch let error as FolderSuggestionError {
            preview = nil
            parserError = error.code
        } catch {
            preview = nil
            parserError = "invalidJSON"
        }
    }
}
