import AppKit
import SwiftUI

struct AuditWorkspaceView: View {
    @ObservedObject var session: AuditSession
    @ObservedObject var model: InventoryModel
    @Environment(\.dismiss) private var dismiss
    private var l: Localization { model.l }
    private var busy: Bool { session.isChecking || session.isPreparing || session.isAnalyzing }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(l.text("audit_workspace")).font(MonitorTypography.title2.weight(.semibold))
                Spacer()
                if busy {
                    ProgressView().controlSize(.small)
                    Text(l.text(session.isChecking ? "audit_checking" : session.isPreparing ? "audit_preparing" : "audit_analyzing"))
                        .font(MonitorTypography.caption)
                    Button(l.text("audit_cancel_request")) { session.cancel() }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("audit-cancel-request")
                }
                Button(l.text("audit_close")) {
                    session.cancel()
                    dismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("audit-close")
            }
            if let code = session.errorCode {
                Label(localized("audit_error_" + code, fallback: "audit_error_unknown"), systemImage: "exclamationmark.circle")
                    .font(MonitorTypography.callout).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("audit-error")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    connection
                    Divider()
                    staticReview
                    if let snapshot = session.snapshot {
                        Label(l.count("audit_report_summary", snapshot.findings.count), systemImage: "doc.text.magnifyingglass")
                            .font(MonitorTypography.callout.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("audit-report-summary")
                        preview(snapshot)
                    }
                    if !session.response.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(l.text("audit_model_response")).font(MonitorTypography.headline)
                            Text(l.text("audit_response_note")).font(MonitorTypography.caption).foregroundStyle(.secondary)
                            Text(verbatim: session.response)
                                .font(MonitorTypography.body).textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("audit-response")
                        }
                    }
                    if let snapshot = session.snapshot {
                        DisclosureGroup(l.count("audit_report_details", snapshot.findings.count)) {
                            report(snapshot).padding(.top, 12)
                        }
                        .font(MonitorTypography.callout)
                        .accessibilityIdentifier("audit-report-details")
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(24)
        .frame(width: 880, height: 580)
        .font(MonitorTypography.body)
        .onAppear {
            session.validateSelection(component: model.selectedSkill, roots: model.roots, language: model.language)
        }
        .accessibilityIdentifier("audit-workspace")
    }

    private var connection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l.text("audit_connection")).font(MonitorTypography.headline)
            Text(l.text("audit_connection_note")).font(MonitorTypography.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                preset("MLX", "http://127.0.0.1:9944/v1")
                preset("Ollama", "http://127.0.0.1:11434/v1")
                preset("LM Studio", "http://127.0.0.1:1234/v1")
            }
            HStack(spacing: 12) {
                TextField(l.text("audit_address"), text: Binding(
                    get: { session.address }, set: { session.updateAddress($0) }
                ))
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("audit-address")
                Button(l.text("audit_check_connection")) { session.checkConnection() }
                    .buttonStyle(.bordered)
                    .disabled(busy)
                    .accessibilityIdentifier("audit-check-connection")
            }
            if !session.models.isEmpty {
                Picker(l.text("audit_model"), selection: Binding(
                    get: { session.selectedModelID }, set: { session.selectModel($0) }
                )) {
                    Text(l.text("audit_select_model")).tag("").disabled(true)
                    ForEach(session.models, id: \.id) { item in
                        Text(verbatim: item.id).tag(item.id)
                    }
                }.accessibilityIdentifier("audit-model")
            }
            Label(l.text(session.modelReady ? "local_ai_ready" : "local_ai_not_connected"),
                  systemImage: session.modelReady ? "checkmark.circle" : "circle.dashed")
                .font(MonitorTypography.caption).foregroundStyle(.secondary)
            Text(l.text("audit_scope_reset_note")).font(MonitorTypography.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func preset(_ title: String, _ address: String) -> some View {
        Button(title) { session.updateAddress(address) }
            .buttonStyle(.bordered)
            .help(address)
            .accessibilityLabel(title + ": " + address)
    }

    private var staticReview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l.text("audit_static_review")).font(MonitorTypography.headline)
            Text(l.text("audit_scope_note")).font(MonitorTypography.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Picker(l.text("audit_component"), selection: $model.selectedID) {
                Text(l.text("audit_select_component")).tag(Optional<String>.none)
                ForEach(model.filteredSkills) { component in
                    Text(verbatim: component.name).tag(Optional(component.id))
                }
            }.accessibilityIdentifier("audit-component")
            Button(l.text("audit_prepare")) {
                if let component = model.selectedSkill {
                    session.prepare(component: component, roots: model.roots, language: model.language)
                }
            }
            .buttonStyle(.bordered)
            .disabled(model.selectedSkill == nil || busy)
            .accessibilityIdentifier("audit-prepare")
            Text(l.text("audit_prepare_note")).font(MonitorTypography.caption).foregroundStyle(.secondary)
        }
    }

    private func report(_ snapshot: AuditSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l.text("audit_static_results")).font(MonitorTypography.headline)
            Text(verbatim: snapshot.name).font(MonitorTypography.callout.weight(.semibold)).textSelection(.enabled)
            Text(verbatim: snapshot.fileDisplayRelative).font(MonitorTypography.path).textSelection(.enabled)
            Text("SHA-256").font(MonitorTypography.caption.weight(.semibold))
            Text(verbatim: snapshot.sha256Digest).font(MonitorTypography.code).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            if snapshot.findings.isEmpty {
                Text(l.text("audit_no_findings")).font(MonitorTypography.callout).foregroundStyle(.secondary)
            }
            ForEach(snapshot.findings, id: \.id) { finding in
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 10) {
                        Label(localized("severity_" + finding.severity, fallback: "severity_info"),
                              systemImage: finding.severity == "high" ? "exclamationmark.octagon" : finding.severity == "medium" ? "exclamationmark.triangle" : "info.circle")
                            .font(MonitorTypography.caption.weight(.semibold))
                        if let line = finding.line {
                            Text(l.text("source_line").replacingOccurrences(of: "{line}", with: String(line)))
                                .font(MonitorTypography.caption).foregroundStyle(.secondary)
                        }
                    }
                    Text(localized("audit_finding_" + finding.code, fallback: "audit_finding_unknown"))
                        .font(MonitorTypography.callout).fixedSize(horizontal: false, vertical: true)
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            }
            coverage("audit_checked_coverage", snapshot.checkedCoverageCodes)
            coverage("audit_omitted_coverage", snapshot.omittedCoverageCodes)
        }.accessibilityIdentifier("audit-static-report")
    }

    private func coverage(_ title: String, _ codes: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(l.text(title)).font(MonitorTypography.caption.weight(.semibold))
            ForEach(Array(codes.enumerated()), id: \.offset) { _, code in
                Label(localized("audit_coverage_" + code, fallback: "audit_coverage_unknown"), systemImage: "minus")
                    .font(MonitorTypography.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func preview(_ snapshot: AuditSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l.text("audit_preview")).font(MonitorTypography.headline)
            Text(l.text("audit_preview_note")).font(MonitorTypography.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ScrollView([.horizontal, .vertical]) {
                Text(verbatim: snapshot.preview).font(MonitorTypography.path).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(height: 210)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .accessibilityIdentifier("audit-preview")
            VStack(alignment: .leading, spacing: 5) {
                Text(l.text("audit_destination")).font(MonitorTypography.caption.weight(.semibold))
                Text(verbatim: session.address).font(MonitorTypography.path).textSelection(.enabled)
                Text(verbatim: session.selectedModelID.isEmpty ? l.text("audit_select_model") : session.selectedModelID)
                    .font(MonitorTypography.path).textSelection(.enabled)
            }
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("audit-send-destination")
            Button { session.analyze() } label: {
                Label(l.text("audit_send_preview"), systemImage: "paperplane")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!session.canAnalyze || busy)
            .accessibilityIdentifier("audit-analyze")
            if !session.modelReady {
                Text(l.text("audit_connect_to_analyze")).font(MonitorTypography.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func localized(_ key: String, fallback: String) -> String {
        let value = l.text(key)
        return value == key ? l.text(fallback) : value
    }
}
