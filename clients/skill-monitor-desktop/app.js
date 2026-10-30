(function (root, factory) {
  "use strict";
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  else api.mount(root.document, root.SKILL_MONITOR_STRINGS, root.skillMonitorBridge);
}(typeof window === "object" ? window : globalThis, function () {
  "use strict";
  const KINDS = Object.freeze(["skill", "agent", "mcp", "rag"]);
  const VIEWS = Object.freeze(["components", "links", "checks", "changes"]);
  const FINDINGS = Object.freeze(["shell_wrapper", "download_execute", "broad_filesystem_scope", "remote_endpoint", "unpinned_runtime", "rag_source_declared", "index_uninspected"]);
  const ISSUES = Object.freeze(["missing_root", "unreadable_root", "outside_scope", "symlink_cycle", "unreadable_file", "invalid_frontmatter", "missing_name", "missing_description", "oversized_header", "changed_during_read", "unsupported_file", "hard_link", "scan_limit", "invalid_config"]);
  const METHODS = Object.freeze(["getState", "chooseFolders", "removeFolder", "refresh"]);
  function text(value, limit) { return typeof value === "string" ? value.slice(0, limit || 8192) : ""; }
  function list(value, limit) { return Array.isArray(value) ? value.slice(0, limit || 10000) : []; }
  function record(value) { return value !== null && typeof value === "object" && !Array.isArray(value); }
  function member(value, options, fallback) { return options.includes(value) ? value : fallback; }
  function identifier(value, optional) {
    if (optional && (value === undefined || value === "")) return "";
    if (typeof value !== "string" || !value || value.length > 512) throw new TypeError("Invalid identifier");
    return value;
  }
  function folderControlID(prefix, id) {
    return prefix + "-" + Array.from(id, function (character) { return character.codePointAt(0).toString(16); }).join("-");
  }
  function normalizeFinding(value) {
    const code = member(value && value.code, FINDINGS, "");
    if (!code) throw new TypeError("Unsupported finding code");
    return { code, severity: member(value.severity, ["high", "medium", "low", "info"], "info"), line: Number.isSafeInteger(value.line) && value.line > 0 ? value.line : null };
  }
  function normalizeSnapshot(raw) {
    if (!record(raw) || raw.schemaVersion !== 1 || !Array.isArray(raw.components) || !Array.isArray(raw.folders) || !Array.isArray(raw.notices) || !Array.isArray(raw.changes) || typeof raw.complete !== "boolean" || typeof raw.hasScanned !== "boolean") throw new TypeError("Invalid presentation snapshot");
    if (raw.components.length > 10000 || raw.folders.length > 128 || raw.notices.length > 10000 || raw.changes.length > 500) throw new TypeError("Presentation snapshot exceeds limits");
    const ids = new Set();
    const folders = raw.folders.map(function (value) {
      if (!record(value) || !text(value.id) || !text(value.path) || ids.has(value.id)) throw new TypeError("Invalid folder identity");
      ids.add(value.id);
      return { id: identifier(value.id), name: text(value.name, 512), path: text(value.path) };
    });
    ids.clear();
    const components = raw.components.map(function (value) {
      if (!record(value) || !text(value.id) || ids.has(value.id) || !KINDS.includes(value.kind) || !Array.isArray(value.findings) || !Array.isArray(value.references) || !Array.isArray(value.issues) || !Array.isArray(value.locations) || value.issues.some(function (code) { return !ISSUES.includes(code); })) throw new TypeError("Invalid component metadata");
      ids.add(value.id);
      return {
        id: identifier(value.id), name: text(value.name, 512), kind: value.kind, summary: text(value.summary),
        summaryKey: /^summary_[a-z_-]+$/.test(value.summaryKey) ? value.summaryKey : "",
        path: text(value.path), resolvedPath: text(value.resolvedPath), folderId: identifier(value.folderId, true),
        locations: list(value.locations, 128).map(function (location) { return text(location); }).filter(Boolean),
        issues: list(value.issues, 64).filter(function (code) { return ISSUES.includes(code); }),
        findings: list(value.findings, 128).map(normalizeFinding).filter(Boolean),
        references: list(value.references, 256).filter(record).map(function (reference) {
          return { relation: member(reference.relation, ["requires", "recommended", "source"], "source"), targetId: reference.external === true ? "" : identifier(reference.targetId, true), label: reference.external === true ? "" : text(reference.label, 512), status: member(reference.status, ["resolved", "unresolved", "ambiguous"], "unresolved"), external: reference.external === true };
        })
      };
    });
    return {
      schemaVersion: 1, folders, components,
      notices: raw.notices.map(function (notice) { if (!record(notice) || !ISSUES.includes(notice.code)) throw new TypeError("Unsupported read notice"); return { code: notice.code, path: text(notice.path) }; }),
      changes: raw.changes.filter(record).map(function (change) { return { category: member(change.category, ["added", "changed", "missing"], "changed"), name: text(change.name, 512), path: text(change.path), recordedAt: text(change.recordedAt, 128) }; }),
      complete: raw.complete, hasScanned: raw.hasScanned, scannedAt: text(raw.scannedAt, 128),
      hasBaseline: raw.hasBaseline === true, comparisonPaused: raw.comparisonPaused === true || !raw.complete,
      journalLimited: raw.journalLimited === true
    };
  }
  function duplicateIDs(components) {
    const groups = new Map();
    components.forEach(function (component) {
      const name = component.name.trim().toLocaleLowerCase();
      if (!name || component.issues.includes("missing_name")) return;
      if (!groups.has(name)) groups.set(name, []);
      groups.get(name).push(component.id);
    });
    return { ids: new Set(Array.from(groups.values()).filter(function (group) { return group.length > 1; }).flat()), groups: Array.from(groups.values()).filter(function (group) { return group.length > 1; }).length };
  }
  function filterComponents(snapshot, filters, translate) {
    const query = text(filters.query).trim().toLocaleLowerCase();
    const duplicates = duplicateIDs(snapshot.components).ids;
    return snapshot.components.filter(function (component) {
      const visibleSummary = component.summaryKey && typeof translate === "function" ? text(translate(component.summaryKey)) : "";
      return (!filters.folderId || component.folderId === filters.folderId) &&
        (!filters.kind || filters.kind === "all" || component.kind === filters.kind) &&
        (!filters.duplicatesOnly || duplicates.has(component.id)) &&
        (!filters.findingsOnly || component.findings.length > 0) &&
        (!query || [component.name, component.summary, visibleSummary, component.path, component.resolvedPath].concat(component.locations).some(function (value) { return value.toLocaleLowerCase().includes(query); }));
    });
  }
  function summarize(components) {
    return { components: components.length, duplicateGroups: duplicateIDs(components).groups, findings: components.reduce(function (total, component) { return total + component.findings.length; }, 0) };
  }
  function element(document, tag, className, content) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (content !== undefined) node.textContent = String(content);
    return node;
  }
  function renderComponentCard(document, component, translate, selected, onSelect) {
    const card = element(document, "button", "component-card" + (selected ? " selected" : ""));
    card.type = "button";
    card.setAttribute("aria-pressed", String(selected));
    const heading = element(document, "span", "card-heading");
    heading.append(element(document, "span", "card-name", component.name || translate("issue_missing_name")), element(document, "span", "badge kind", translate("kind_" + component.kind)));
    card.append(heading, element(document, "span", "card-summary", component.summaryKey ? translate(component.summaryKey) : component.summary || translate("no_description")), element(document, "div", "card-path mono", component.path));
    if (component.findings.length || component.issues.length) {
      const badges = element(document, "span", "badges");
      if (component.findings.length) badges.append(element(document, "span", "badge warning", translate("finding_count", { count: component.findings.length })));
      if (component.issues.length) badges.append(element(document, "span", "badge", translate("metadata_issues")));
      card.append(badges);
    }
    card.addEventListener("click", onSelect);
    return card;
  }
  function createController(bridge, onChange, options) {
    let generation = 0;
    const schedule = options && options.setTimeout || setTimeout;
    const cancel = options && options.clearTimeout || clearTimeout;
    const deadline = Math.min(30000, Math.max(1000, options && options.timeoutMs || 15000));
    const state = { status: "disconnected", pending: false, pendingMethod: "", snapshot: null, problem: "" };
    async function request(method, argument) {
      if (state.pending || !METHODS.includes(method)) return false;
      if (!bridge || typeof bridge[method] !== "function") {
        state.problem = method === "getState" ? "desktop_disconnected_body" : "desktop_unsupported_action";
        onChange(state);
        return false;
      }
      const current = ++generation;
      state.pending = true;
      state.pendingMethod = method;
      state.status = state.snapshot ? "connected" : "connecting";
      state.problem = "";
      onChange(state);
      let timer;
      try {
        const operation = Promise.resolve().then(function () { return bridge[method](argument); });
        let response = operation;
        if (method !== "chooseFolders") {
          const timeout = new Promise(function (_, reject) { timer = schedule(function () { reject(new Error("Native response deadline exceeded")); }, deadline); });
          response = Promise.race([operation, timeout]);
        }
        const raw = await response;
        const snapshot = normalizeSnapshot(raw);
        if (current !== generation) return false;
        state.snapshot = snapshot;
        state.status = "connected";
        return true;
      } catch (error) {
        if (current !== generation) return false;
        state.status = "error";
        state.problem = error instanceof TypeError ? "desktop_bridge_incompatible" : "desktop_host_error";
        return false;
      } finally {
        if (timer !== undefined) cancel(timer);
        if (current === generation) { state.pending = false; state.pendingMethod = ""; onChange(state); }
      }
    }
    return { state, request };
  }
  function mount(document, strings, bridge) {
    const app = document.getElementById("app");
    if (!app || !record(strings) || !record(strings.en)) return;
    const ui = { locale: "en", view: "components", query: "", kind: "all", duplicatesOnly: false, findingsOnly: false, folderId: "", selectedId: "" };
    const language = document.documentElement.lang;
    if (["ru", "en", "zh-CN"].includes(language)) ui.locale = language;
    const controller = createController(bridge, render);
    function t(key, substitutions) {
      let value = text(strings[ui.locale] && strings[ui.locale][key]) || text(strings.en[key]) || key;
      Object.keys(substitutions || {}).forEach(function (name) { value = value.split("{" + name + "}").join(String(substitutions[name])); });
      return value;
    }
    function h(tag, className, content) { return element(document, tag, className, content); }
    function button(key, action, className, disabled) {
      const node = h("button", className || "", t(key)); node.type = "button"; node.disabled = Boolean(disabled); node.addEventListener("click", action); return node;
    }
    function empty(title, body) {
      const node = h("div", "empty"); const symbol = h("div", "empty-symbol"); symbol.setAttribute("aria-hidden", "true");
      node.append(symbol, h("h2", "", t(title)), h("p", "", t(body))); return node;
    }
    function setFilter(name, value) { ui[name] = value; render(); }
    function status(title, body, tone) {
      const node = h("section", "status " + (tone || "")); node.setAttribute("role", tone === "error" ? "alert" : "status");
      const copy = h("div"); copy.append(h("h2", "", t(title)), h("p", "", t(body))); node.append(copy); return node;
    }
    function findingNode(finding, component) {
      const node = h("article", "finding");
      const header = h("div", "card-heading"); header.append(h("h3", "", t("finding_" + finding.code)), h("span", "badge warning", t("severity_" + finding.severity))); node.append(header);
      node.append(h("p", "", t("evidence_" + finding.code)));
      if (component) node.append(h("p", "mono", component.path));
      if (finding.line) node.append(h("small", "muted", t("source_line", { line: finding.line })));
      const next = h("div", "next-step"); next.append(h("h3", "", t("finding_next_step")), h("p", "", t("action_" + finding.code))); node.append(next); return node;
    }
    function renderDetail(component) {
      if (!component) return empty("select_file", "select_file_detail");
      const detail = h("aside", "detail"); detail.setAttribute("aria-label", component.name);
      const header = h("div", "detail-header"); header.append(h("span", "eyebrow", t("kind_" + component.kind)), h("h2", "", component.name || t("issue_missing_name"))); detail.append(header);
      const summary = h("section", "detail-section"); summary.append(h("h3", "", t("description")), h("p", "", component.summaryKey ? t(component.summaryKey) : component.summary || t("no_description"))); detail.append(summary);
      const source = h("section", "detail-section"); source.append(h("h3", "", t("desktop_source")));
      const fields = h("dl", "provenance");
      [["actual_path", component.path], ["resolved_path", component.resolvedPath]].forEach(function (field) { if (field[1]) { const row = h("div"); row.append(h("dt", "", t(field[0])), h("dd", "mono", field[1])); fields.append(row); } });
      source.append(fields);
      if (component.locations.length) { source.append(h("h3", "", t("locations")), h("p", "muted", t("aliases_explanation"))); component.locations.forEach(function (path) { source.append(h("p", "mono", path)); }); }
      detail.append(source);
      if (component.issues.length) { const issues = h("section", "detail-section"); issues.append(h("h3", "", t("metadata_issues"))); component.issues.forEach(function (code) { issues.append(h("p", "", t("issue_" + code))); }); detail.append(issues); }
      const checks = h("section", "detail-section"); checks.append(h("h3", "", t("metadata_checks")), h("p", "muted", t("checks_scope")));
      if (!component.findings.length) checks.append(h("p", "", t("no_findings")));
      component.findings.forEach(function (finding) { checks.append(findingNode(finding)); }); detail.append(checks);
      return detail;
    }
    function render() {
      const active = document.activeElement;
      const focusedId = active && active.id;
      const selection = active && typeof active.selectionStart === "number" ? [active.selectionStart, active.selectionEnd] : null;
      const state = controller.state;
      const snapshot = state.snapshot;
      if (snapshot && ui.folderId && !snapshot.folders.some(function (folder) { return folder.id === ui.folderId; })) ui.folderId = "";
      const connected = state.status === "connected";
      document.documentElement.lang = ui.locale; document.title = t("app_title");
      app.replaceChildren(); app.setAttribute("aria-busy", String(state.pending));
      const skip = h("a", "skip-link", t("components")); skip.href = "#main-content"; app.append(skip);
      const shell = h("div", "shell"); const sidebar = h("aside", "sidebar");
      const brand = h("div", "brand"); const mark = h("span", "brand-mark"); mark.setAttribute("aria-hidden", "true"); const brandCopy = h("div"); brandCopy.append(h("strong", "", t("app_title")), h("small", "", t("local_client"))); brand.append(mark, brandCopy); sidebar.append(brand);
      const folders = h("section"); const folderHeading = h("div", "section-heading"); folderHeading.append(h("h2", "", t("folders"))); folders.append(folderHeading);
      const folderList = h("div", "folder-list");
      if (snapshot && snapshot.folders.length) {
        const all = button("desktop_all_folders", function () { setFilter("folderId", ""); }, "folder-select"); all.id = "folder-choice-all"; all.setAttribute("aria-pressed", String(!ui.folderId)); folderList.append(all);
        snapshot.folders.forEach(function (folder) {
          const row = h("div", "folder" + (ui.folderId === folder.id ? " selected" : ""));
          const select = button("", function () { setFilter("folderId", folder.id); }, "folder-select"); select.id = folderControlID("folder-choice", folder.id); select.textContent = ""; select.setAttribute("aria-pressed", String(ui.folderId === folder.id)); select.append(h("span", "folder-name", folder.name || folder.path), h("span", "folder-path mono", folder.path));
          const remove = button("", function () { controller.request("removeFolder", { folderId: folder.id }); }, "folder-remove", !connected || state.pending || !bridge || typeof bridge.removeFolder !== "function"); remove.id = folderControlID("folder-remove", folder.id); remove.textContent = "×"; remove.setAttribute("aria-label", t("remove_folder") + ": " + folder.path); row.append(select, remove); folderList.append(row);
        });
      } else folderList.append(h("p", "sidebar-note", t("no_folders_sidebar")));
      const addFolder = button("add_folder", function () { controller.request("chooseFolders"); }, "button-full", !connected || state.pending || !bridge || typeof bridge.chooseFolders !== "function"); addFolder.id = "add-folder";
      folders.append(folderList, addFolder); sidebar.append(folders);
      const help = h("section"); help.append(h("h3", "", t("where_to_look")), h("p", "sidebar-note", t("desktop_folder_help"))); sidebar.append(help);
      const bottom = h("div", "sidebar-bottom"); const languageLabel = h("label", "language"); languageLabel.append(h("span", "eyebrow", t("language")));
      const localeSelect = h("select"); localeSelect.id = "language-select"; ["ru", "en", "zh-CN"].forEach(function (locale) { const option = h("option", "", t("language_" + locale)); option.value = locale; option.selected = ui.locale === locale; localeSelect.append(option); }); localeSelect.addEventListener("change", function () { setFilter("locale", localeSelect.value); }); languageLabel.append(localeSelect); bottom.append(languageLabel, h("p", "sidebar-note", t("desktop_readonly"))); sidebar.append(bottom); shell.append(sidebar);
      const main = h("main", "workspace"); main.id = "main-content"; main.tabIndex = -1;
      const header = h("header", "page-header"); const title = h("div", "page-title"); title.append(h("span", "eyebrow", t("app_title")), h("h1", "", t("library_title")), h("p", "subtitle", t("library_subtitle"))); const actions = h("div", "header-actions"); actions.append(button(state.pending && state.pendingMethod !== "chooseFolders" ? "scanning" : "refresh", function () { controller.request("refresh"); }, "", !connected || state.pending || !bridge || typeof bridge.refresh !== "function")); header.append(title, actions); main.append(header);
      if (state.pendingMethod === "chooseFolders") main.append(status("desktop_choosing_folder", "folder_picker_message", "info"));
      else if (state.status === "disconnected") main.append(status("desktop_disconnected_title", state.problem || "desktop_disconnected_body"));
      else if (state.status === "connecting") main.append(status("desktop_connecting", "scanning_detail", "info"));
      else if (state.status === "error") { const error = status("desktop_host_error", snapshot ? "desktop_stale_results" : state.problem, "error"); error.append(button("desktop_retry", function () { controller.request("getState"); }, "", state.pending)); main.append(error); }
      else if (state.problem) main.append(status("desktop_unsupported_action", state.problem));
      if (snapshot && snapshot.comparisonPaused) main.append(status("comparison_paused", "comparison_paused_detail"));
      const totals = snapshot && snapshot.hasScanned ? summarize(snapshot.components) : null;
      const summary = h("section", "summary"); summary.setAttribute("aria-label", t("metadata_summary"));
      [["components", "components"], ["duplicateGroups", "duplicate_groups"], ["findings", "metadata_checks"]].forEach(function (metric) { const cell = h("div", "metric"); const value = h("strong", "", totals ? totals[metric[0]].toLocaleString(ui.locale) : "—"); if (!totals) value.setAttribute("aria-label", t("desktop_count_unavailable")); cell.append(value, h("span", "", t(metric[1]))); summary.append(cell); }); main.append(summary);
      const tabs = h("div", "tabs"); tabs.setAttribute("role", "tablist"); tabs.setAttribute("aria-label", t("view_mode"));
      VIEWS.forEach(function (view, index) { const tab = button(view, function () { ui.view = view; render(); }, "tab"); tab.id = "tab-" + view; tab.setAttribute("role", "tab"); tab.setAttribute("aria-selected", String(ui.view === view)); tab.setAttribute("aria-controls", "view-panel"); tab.tabIndex = ui.view === view ? 0 : -1; tab.addEventListener("keydown", function (event) { if (!["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return; event.preventDefault(); const next = event.key === "Home" ? 0 : event.key === "End" ? VIEWS.length - 1 : (index + (event.key === "ArrowRight" ? 1 : -1) + VIEWS.length) % VIEWS.length; ui.view = VIEWS[next]; render(); document.getElementById("tab-" + ui.view).focus(); }); tabs.append(tab); }); main.append(tabs);
      const panel = h("section"); panel.id = "view-panel"; panel.setAttribute("role", "tabpanel"); panel.setAttribute("aria-labelledby", "tab-" + ui.view); panel.tabIndex = 0;
      if (!snapshot || !snapshot.hasScanned) panel.append(empty(state.status === "disconnected" ? "desktop_disconnected_title" : snapshot && snapshot.folders.length ? "first_scan_baseline" : "no_folders", state.status === "disconnected" ? "desktop_disconnected_body" : snapshot && snapshot.folders.length ? "scanning_detail" : "no_folders_detail"));
      else if (ui.view === "changes") {
        panel.append(h("h2", "", t("changes_to_review")), h("p", "subtitle", t("desktop_changes_explanation")), h("p", "footnote", t("changes_reset_scope")));
        if (snapshot.journalLimited) panel.append(status("journal_limit", "desktop_changes_explanation"));
        if (!snapshot.changes.length) panel.append(empty(snapshot.hasBaseline ? "no_unreviewed_changes" : "first_scan_baseline", "changes_empty_detail"));
        snapshot.changes.forEach(function (change) { const row = h("article", "notice"); row.append(h("span", "badge", t("event_" + change.category)), h("h3", "", change.name), h("p", "mono", change.path)); if (change.category === "missing") row.append(h("p", "", t("missing_is_not_deleted"))); if (change.recordedAt) row.append(h("small", "muted", change.recordedAt)); panel.append(row); });
      } else {
        const toolbar = h("div", "toolbar"); const searchWrap = h("div", "search-wrap"); const search = h("input"); search.id = "component-search"; search.type = "search"; search.value = ui.query; search.placeholder = t("search"); search.setAttribute("aria-label", t("desktop_search_label")); search.addEventListener("input", function () { setFilter("query", search.value); }); searchWrap.append(search);
        if (ui.query) { const clear = button("", function () { ui.query = ""; render(); document.getElementById("component-search").focus(); }, "clear-search"); clear.textContent = "×"; clear.setAttribute("aria-label", t("clear_search")); searchWrap.append(clear); }
        const type = h("select"); type.id = "kind-select"; type.setAttribute("aria-label", t("component_type")); ["all"].concat(KINDS).forEach(function (kind) { const option = h("option", "", t(kind === "all" ? "all_types" : "kind_" + kind)); option.value = kind; option.selected = ui.kind === kind; type.append(option); }); type.addEventListener("change", function () { setFilter("kind", type.value); }); toolbar.append(searchWrap, type); panel.append(toolbar);
        const filters = h("div", "filter-row"); [["duplicatesOnly", "duplicates_only"], ["findingsOnly", "findings_only"]].forEach(function (entry) { const label = h("label", "checkbox"); const checkbox = h("input"); checkbox.type = "checkbox"; checkbox.id = "filter-" + entry[0]; checkbox.checked = ui[entry[0]]; checkbox.addEventListener("change", function () { setFilter(entry[0], checkbox.checked); }); label.append(checkbox, h("span", "", t(entry[1]))); filters.append(label); }); panel.append(filters);
        const filtered = filterComponents(snapshot, ui, t); const resultLine = h("div", "result-line"); resultLine.append(h("span", "", t("desktop_result_scope", { shown: filtered.length, total: snapshot.components.length }))); if (snapshot.scannedAt) resultLine.append(h("span", "", t("last_scan") + " " + snapshot.scannedAt)); panel.append(resultLine);
        if (ui.view === "components") {
          if (!filtered.length) panel.append(empty(snapshot.components.length ? "no_matches" : "no_files", snapshot.components.length ? "no_matches_detail" : "no_files_detail"));
          else {
            const results = h("div", "results"); const componentList = h("div", "component-list"); const selected = filtered.find(function (component) { return component.id === ui.selectedId; }) || filtered[0];
            filtered.forEach(function (component) { const card = renderComponentCard(document, component, t, selected.id === component.id, function () { ui.selectedId = component.id; render(); }); card.id = "component-card-" + snapshot.components.indexOf(component); componentList.append(card); }); results.append(componentList, renderDetail(selected)); panel.append(results);
          }
        } else if (ui.view === "links") {
          panel.append(h("p", "subtitle", t("links_explanation"))); const links = filtered.flatMap(function (component) { return component.references.map(function (reference) { return { component, reference }; }); });
          if (!links.length) panel.append(empty("no_links", "desktop_no_links_detail"));
          links.forEach(function (entry) { const row = h("article", "link-row"); const source = h("div", "link-label"); source.append(h("strong", "", entry.component.name), h("small", "", t("relation_" + entry.reference.relation))); const arrow = h("span", "muted", "→"); arrow.setAttribute("aria-hidden", "true"); const target = h("div", "link-label"); const found = snapshot.components.find(function (component) { return component.id === entry.reference.targetId; }); target.append(h("strong", "", entry.reference.external ? t("external_reference_title") : entry.reference.label || (found && found.name) || t("unresolved_reference")), h("small", "", entry.reference.external ? t("external_reference_detail") : entry.reference.status === "ambiguous" ? t("ambiguous_reference") : !found || entry.reference.status === "unresolved" ? t("unresolved_reference") : t("discovery_declared"))); row.append(source, arrow, target); panel.append(row); });
        } else if (ui.view === "checks") {
          panel.append(h("p", "subtitle", t("checks_explanation")), h("p", "footnote", t("checks_scope")));
          const findings = filtered.flatMap(function (component) { return component.findings.map(function (finding) { return { component, finding }; }); });
          if (!findings.length) panel.append(empty("metadata_checks", "no_findings"));
          findings.forEach(function (entry) { const block = h("section"); block.append(h("h3", "", entry.component.name), findingNode(entry.finding, entry.component)); panel.append(block); });
          const notices = h("section"); notices.append(h("h2", "", t("read_notices")), h("p", "subtitle", t("desktop_all_folders")));
          if (!snapshot.notices.length) notices.append(h("p", "subtitle", t("no_notices_detail")));
          snapshot.notices.forEach(function (notice) { const row = h("article", "notice"); row.append(h("h3", "", t("issue_" + notice.code)), h("p", "mono", notice.path)); if (notice.code === "invalid_config") row.append(h("p", "", t("notice_recovery_invalid_config"))); notices.append(row); }); panel.append(notices);
        }
      }
      main.append(panel, h("p", "footnote", t("phase_scope"))); shell.append(main); app.append(shell);
      if (focusedId) {
        let target = document.getElementById(focusedId);
        if ((!target || target.disabled) && /^folder-(choice|remove)-/.test(focusedId)) {
          target = ["folder-choice-all", "add-folder", "language-select"].map(function (id) { return document.getElementById(id); }).find(function (node) { return node && !node.disabled; });
        }
        if (target && !target.disabled) { target.focus({ preventScroll: true }); if (selection && typeof target.setSelectionRange === "function") target.setSelectionRange(selection[0], selection[1]); }
      }
    }
    render();
    if (bridge && typeof bridge.getState === "function") controller.request("getState");
    return controller;
  }
  return Object.freeze({ normalizeSnapshot, duplicateIDs, filterComponents, summarize, renderComponentCard, createController, mount });
}));
