"use strict";
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const ui = require("../app.js");
const localeContext = { window: {} };
vm.runInNewContext(fs.readFileSync(path.join(__dirname, "../locales.js"), "utf8"), localeContext);
const strings = localeContext.window.SKILL_MONITOR_STRINGS;

// A deliberately small DOM, with HTML parsing prohibited. These tests render
// the actual interface and exercise events, without a browser dependency.
class Node {
  constructor(document, tag) { this.document = document; this.tagName = tag; this.children = []; this.attributes = {}; this.listeners = {}; this._text = ""; this.id = ""; this.disabled = false; }
  set textContent(value) { this.children = []; this._text = String(value); }
  get textContent() { return this._text + this.children.map(function (child) { return typeof child === "string" ? child : child.textContent; }).join(""); }
  set innerHTML(_) { throw new Error("HTML parsing is prohibited"); }
  append(...children) { this.children.push(...children); }
  replaceChildren(...children) { this._text = ""; this.children = children; }
  setAttribute(key, value) { this.attributes[key] = String(value); }
  addEventListener(type, callback) { this.listeners[type] = callback; }
  focus() { this.document.activeElement = this; }
  fire(type, values) { if (this.listeners[type]) this.listeners[type](Object.assign({ preventDefault() {} }, values)); }
}
function documentFor(locale) {
  const document = { activeElement: null, title: "", tags: [], createElement(tag) { this.tags.push(tag); return new Node(this, tag); } };
  document.documentElement = { lang: locale || "en" };
  document.app = document.createElement("div"); document.app.id = "app";
  document.getElementById = function (id) { return find(document.app, function (node) { return node.id === id; }); };
  return document;
}
function find(node, predicate) { if (predicate(node)) return node; for (const child of node.children) { if (typeof child !== "string") { const match = find(child, predicate); if (match) return match; } } return null; }
function component(id, overrides) {
  return Object.assign({ id, name: "Writer", kind: "skill", summary: "A clear description", path: "/chosen/skills/" + id + "/SKILL.md", resolvedPath: "", folderId: "chosen", locations: [], issues: [], findings: [], references: [] }, overrides);
}
function snapshot(components, overrides) {
  return Object.assign({ schemaVersion: 1, folders: [{ id: "chosen", name: "Chosen", path: "/chosen" }, { id: "other", name: "Other", path: "/other" }], components: components || [], notices: [], changes: [], complete: true, hasScanned: true, hasBaseline: true, scannedAt: "" }, overrides);
}
async function settle() { await new Promise(function (resolve) { setImmediate(resolve); }); }
const tests = [];
function test(name, run) { tests.push({ name, run }); }

test("disconnected interface gives no inventory counts or usable file actions in every language", function () {
  for (const locale of ["ru", "en", "zh-CN"]) {
    const document = documentFor(locale); const controller = ui.mount(document, strings);
    assert.equal(controller.state.status, "disconnected");
    assert.ok(document.app.textContent.includes(strings[locale].desktop_disconnected_title));
    assert.ok(document.app.textContent.includes(strings[locale].desktop_disconnected_body));
    assert.equal(controller.state.snapshot, null);
    const counts = [];
    function visit(node) { if (node.className === "metric") counts.push(node.children[0].textContent); node.children.filter(function (child) { return typeof child !== "string"; }).forEach(visit); }
    visit(document.app); assert.deepEqual(counts, ["—", "—", "—"]);
    assert.equal(find(document.app, function (node) { return node.tagName === "button" && node.textContent === strings[locale].add_folder; }).disabled, true);
    assert.equal(find(document.app, function (node) { return node.tagName === "button" && node.textContent === strings[locale].refresh; }).disabled, true);
  }
});

test("language changes work without a host and without storage", function () {
  const document = documentFor(); ui.mount(document, strings);
  const select = document.getElementById("language-select"); select.value = "zh-CN"; select.fire("change");
  assert.equal(document.documentElement.lang, "zh-CN");
  assert.ok(document.app.textContent.includes(strings["zh-CN"].desktop_disconnected_title));
});

test("name groups, aliases, advisory findings and read issues keep their separate units", function () {
  const model = ui.normalizeSnapshot(snapshot([
    component("a", { name: " Writer ", locations: ["/alias/a"] }),
    component("b", { name: "writer", kind: "agent", findings: [{ code: "rag_source_declared", severity: "info" }] }),
    component("c", { name: "Different", issues: ["missing_description"] })
  ]));
  assert.deepEqual(ui.summarize(model.components), { components: 3, duplicateGroups: 1, findings: 1 });
  assert.deepEqual(ui.filterComponents(model, { duplicatesOnly: true }).map(function (x) { return x.id; }), ["a", "b"]);
  assert.deepEqual(ui.filterComponents(model, { findingsOnly: true }).map(function (x) { return x.id; }), ["b"]);
  assert.deepEqual(ui.filterComponents(model, { query: "/ALIAS/A" }).map(function (x) { return x.id; }), ["a"]);
});

test("search, kind, folder and finding filters compose", function () {
  const model = ui.normalizeSnapshot(snapshot([component("a"), component("b", { name: "Writer source", kind: "rag", folderId: "other", findings: [{ code: "index_uninspected" }] })]));
  assert.deepEqual(ui.filterComponents(model, { query: "writer", kind: "rag", folderId: "other", findingsOnly: true }).map(function (x) { return x.id; }), ["b"]);
  assert.equal(ui.filterComponents(model, { kind: "rag", folderId: "chosen" }).length, 0);
});

test("search finds visible translated descriptions and preserves source and path search", async function () {
  for (const locale of ["ru", "en", "zh-CN"]) {
    const document = documentFor(locale);
    ui.mount(document, strings, { getState: async function () {
      return snapshot([component("m", { kind: "mcp", summary: "Original metadata example", summaryKey: "summary_mcp_declared" })]);
    } });
    await settle();
    for (const query of [strings[locale].summary_mcp_declared, "Original metadata", "/chosen/skills/m"]) {
      const search = document.getElementById("component-search"); search.value = query; search.fire("input");
      assert.ok(find(document.app, function (node) { return node.className === "component-card selected"; }), locale + ": " + query);
    }
  }
});

test("journal text describes displayed changes without promising an unavailable acknowledgement", async function () {
  for (const locale of ["ru", "en", "zh-CN"]) {
    for (const limited of [false, true]) {
    const document = documentFor(locale);
    ui.mount(document, strings, { getState: async function () {
      return snapshot([component("a")], { journalLimited: limited, changes: [{ category: "changed", name: "Example", path: "/chosen/a" }] });
    } });
    await settle(); document.getElementById("tab-changes").fire("click");
    const panel = document.getElementById("view-panel");
    assert.equal(panel.textContent.includes(strings[locale].changes_explanation), false);
    assert.equal(typeof strings[locale].desktop_changes_explanation, "string");
    assert.ok(panel.textContent.includes(strings[locale].desktop_changes_explanation));
    }
  }
});

test("selecting and removing folders restores focus to an attached usable control", async function () {
  for (const hasChooser of [false, true]) {
  const document = documentFor();
  let folders = snapshot().folders;
  const bridge = {
    getState: async function () { return snapshot([component("a")]); },
    removeFolder: async function (request) {
      folders = folders.filter(function (folder) { return folder.id !== request.folderId; });
      return snapshot(folders.length ? [component("a")] : [], { folders });
    }
  };
  if (hasChooser) bridge.chooseFolders = async function () { return snapshot([], { folders: [] }); };
  const controller = ui.mount(document, strings, bridge);
  await settle();
  const folder = find(document.app, function (node) { return node.className === "folder-select" && node.textContent.includes("/other"); });
  folder.focus(); folder.fire("click");
  assert.ok(find(document.app, function (node) { return node === document.activeElement; }), "Selected folder must keep focus in the new tree");
  assert.ok(document.activeElement.textContent.includes("/other"));
  const remove = find(document.app, function (node) { return node.className === "folder-remove" && node.attributes["aria-label"].includes("/other"); });
  remove.focus(); remove.fire("click"); await settle();
  assert.equal(controller.state.snapshot.folders.length, 1);
  assert.ok(find(document.app, function (node) { return node === document.activeElement; }), "Removed folder must leave focus on a usable replacement");
  assert.equal(document.activeElement.disabled, false);
  assert.equal(document.activeElement.attributes["aria-pressed"], "true");
  const lastRemove = find(document.app, function (node) { return node.className === "folder-remove"; });
  lastRemove.focus(); lastRemove.fire("click"); await settle();
  assert.equal(controller.state.snapshot.folders.length, 0);
  assert.ok(find(document.app, function (node) { return node === document.activeElement; }), "Last removal must leave focus attached even without a chooser");
  assert.equal(document.activeElement.disabled, false);
  assert.equal(document.activeElement.id, hasChooser ? "add-folder" : "language-select");
  }
});

test("metadata containing HTML remains literal text in actual cards and details", async function () {
  const malicious = "</button><img src=x onerror=alert(1)>";
  const document = documentFor(); const controller = ui.mount(document, strings, { getState: async function () { return snapshot([component("a", { name: malicious, summary: malicious, path: malicious })]); } });
  await settle(); assert.equal(controller.state.status, "connected");
  assert.ok(document.app.textContent.includes(malicious));
  assert.equal(document.tags.includes("img"), false); assert.equal(document.tags.includes("script"), false);
  assert.equal(find(document.app, function (node) { return Object.keys(node.attributes).some(function (key) { return /^on/.test(key); }); }), null);
});

test("external references never resolve to a same-named local component or expose addresses", async function () {
  const document = documentFor(); ui.mount(document, strings, { getState: async function () { return snapshot([component("a", { name: "Source", references: [{ relation: "source", external: true, targetId: "b", label: "https://private.invalid/path", status: "resolved" }] }), component("b", { name: "Misleading local target" })]); } });
  await settle(); document.getElementById("tab-links").fire("click");
  const panel = document.getElementById("view-panel").textContent;
  assert.ok(panel.includes(strings.en.external_reference_title));
  assert.equal(panel.includes("https://private.invalid/path"), false); assert.equal(panel.includes("Misleading local target"), false);
  assert.equal(find(document.getElementById("view-panel"), function (node) { return node.tagName === "a"; }), null);
});

test("malformed and duplicate identities cannot become a successful empty read", async function () {
  const changes = []; const controller = ui.createController({ getState: async function () { return {}; } }, function (state) { changes.push(state.status); });
  assert.equal(await controller.request("getState"), false); assert.equal(controller.state.status, "error"); assert.equal(controller.state.snapshot, null);
  assert.throws(function () { ui.normalizeSnapshot(snapshot([component("a"), component("a")])); }, /identity|metadata/);
  assert.throws(function () { ui.normalizeSnapshot(snapshot([component("a", { findings: [{ code: "future_unknown_rule" }] })])); }, /finding/);
  assert.deepEqual(changes, ["connecting", "error"]);
});

test("a rejected refresh retains the previous read while exposing failure", async function () {
  const controller = ui.createController({ getState: async function () { return snapshot([component("a")]); }, refresh: async function () { throw new Error("Private native diagnostic"); } }, function () {});
  await controller.request("getState"); await controller.request("refresh");
  assert.equal(controller.state.status, "error"); assert.equal(controller.state.snapshot.components.length, 1);
  assert.equal(controller.state.problem, "desktop_host_error"); assert.equal(controller.state.pending, false);
});

test("only named operations dispatch and pending requests cannot race", async function () {
  let resolve; let calls = 0;
  const bridge = { getState() { calls += 1; return new Promise(function (done) { resolve = done; }); }, removeFolder() { calls += 1; } };
  const controller = ui.createController(bridge, function () {}); const first = controller.request("getState");
  assert.equal(await controller.request("removeFolder", { folderId: "chosen" }), false);
  assert.equal(await controller.request("execute", "unsafe"), false); assert.equal(calls, 1);
  resolve(snapshot([])); assert.equal(await first, true); assert.equal(controller.state.pending, false);
});

test("a hung native response reaches a deadline and a late result cannot replace newer data", async function () {
  let resolveLate; let expire; let waitTime; let cleared = false;
  const controller = ui.createController({ getState() { return new Promise(function (resolve) { resolveLate = resolve; }); }, refresh: async function () { return snapshot([component("new")]); } }, function () {}, {
    setTimeout(callback, duration) { expire = callback; waitTime = duration; return 7; },
    clearTimeout(id) { assert.equal(id, 7); cleared = true; }
  });
  const pending = controller.request("getState"); await Promise.resolve();
  assert.equal(waitTime, 15000); expire(); assert.equal(await pending, false);
  assert.equal(controller.state.status, "error"); assert.equal(controller.state.pending, false); assert.equal(cleared, true);
  await controller.request("refresh"); resolveLate(snapshot([component("old")])); await settle();
  assert.equal(controller.state.snapshot.components[0].id, "new"); assert.equal(controller.state.status, "connected");
});

test("folder choice or cancellation after 31 simulated seconds is accepted without a read timeout", async function () {
  for (const choice of ["choose", "cancel"]) {
    let finishChoice; let clock = 0; let sequence = 0; const timers = new Map();
    const baseline = snapshot([component("before")]);
    const result = choice === "cancel" ? baseline : snapshot([component("chosen")]);
    const controller = ui.createController({
      getState: async function () { return baseline; },
      chooseFolders() { return new Promise(function (resolve) { finishChoice = resolve; }); }
    }, function () {}, {
      setTimeout(callback, duration) { const id = ++sequence; timers.set(id, { callback, at: clock + duration }); return id; },
      clearTimeout(id) { timers.delete(id); }
    });
    await controller.request("getState");
    const pendingChoice = controller.request("chooseFolders"); await Promise.resolve();
    clock += 31000;
    for (const timer of timers.values()) if (timer.at <= clock) timer.callback();
    await Promise.resolve();
    assert.equal(timers.size, 0, "human choice must not schedule a presentation deadline");
    assert.equal(controller.state.pending, true); assert.equal(controller.state.pendingMethod, "chooseFolders");
    assert.equal(controller.state.status, "connected"); assert.equal(controller.state.problem, "");
    assert.equal(controller.state.snapshot.components[0].id, "before");
    finishChoice(result); assert.equal(await pendingChoice, true);
    assert.equal(controller.state.pending, false); assert.equal(controller.state.pendingMethod, "");
    assert.equal(controller.state.snapshot.components[0].id, choice === "cancel" ? "before" : "chosen");
    assert.equal(controller.state.status, "connected"); assert.equal(controller.state.problem, "");
  }
});

test("folder picker pending state uses localized waiting text instead of reading text", async function () {
  for (const locale of ["ru", "en", "zh-CN"]) {
    let finishChoice; const document = documentFor(locale);
    const controller = ui.mount(document, strings, {
      getState: async function () { return snapshot([component("before")]); },
      chooseFolders() { return new Promise(function (resolve) { finishChoice = resolve; }); }
    });
    await settle(); const pendingChoice = controller.request("chooseFolders"); await Promise.resolve();
    assert.ok(document.app.textContent.includes(strings[locale].desktop_choosing_folder));
    assert.equal(document.app.textContent.includes(strings[locale].scanning), false);
    assert.equal(document.app.textContent.includes(strings[locale].desktop_stale_results), false);
    finishChoice(snapshot([component("before")])); assert.equal(await pendingChoice, true);
  }
});

test("oversized identities are rejected without clipping into another identity", function () {
  assert.throws(function () { ui.normalizeSnapshot(snapshot([component("x".repeat(513))])); }, /identifier/);
  assert.throws(function () { ui.normalizeSnapshot(snapshot([], { folders: [{ id: "x".repeat(513), path: "/chosen" }] })); }, /identifier/);
});

test("selecting a component keeps keyboard focus on its card", async function () {
  const document = documentFor(); ui.mount(document, strings, { getState: async function () { return snapshot([component("a"), component("b")]); } }); await settle();
  const card = document.getElementById("component-card-1"); card.focus(); card.fire("click");
  assert.equal(document.activeElement, document.getElementById("component-card-1"));
  assert.equal(document.activeElement.attributes["aria-pressed"], "true");
});

test("incomplete reads always pause comparison and missing entries do not claim deletion", async function () {
  const document = documentFor(); ui.mount(document, strings, { getState: async function () { return snapshot([], { complete: false, changes: [{ category: "missing", name: "Earlier component", path: "/chosen/earlier" }] }); } });
  await settle(); assert.ok(document.app.textContent.includes(strings.en.comparison_paused_detail));
  document.getElementById("tab-changes").fire("click");
  assert.ok(document.app.textContent.includes(strings.en.missing_is_not_deleted));
  assert.equal(document.getElementById("component-search"), null);
});

test("tab keyboard movement and displayed result scope stay usable", async function () {
  const document = documentFor(); ui.mount(document, strings, { getState: async function () { return snapshot([component("a"), component("b", { name: "Other" })]); } });
  await settle(); const search = document.getElementById("component-search"); search.value = "other"; search.fire("input");
  assert.ok(document.app.textContent.includes("1 of 2"));
  document.getElementById("tab-components").fire("keydown", { key: "ArrowRight" });
  assert.equal(document.getElementById("tab-links").attributes["aria-selected"], "true");
  assert.equal(document.activeElement.id, "tab-links");
});

test("embedded document blocks connections, inline script and external assets", function () {
  const html = fs.readFileSync(path.join(__dirname, "../index.html"), "utf8");
  assert.ok(html.includes("connect-src 'none'")); assert.ok(html.includes("script-src 'self'"));
  assert.equal(/<script(?![^>]*\bsrc=)[^>]*>/i.test(html), false);
  assert.equal(/https?:\/\//i.test(html), false);
});

test("all literal interface and dynamic metadata labels exist in every language", function () {
  const source = fs.readFileSync(path.join(__dirname, "../app.js"), "utf8");
  const keys = Array.from(source.matchAll(/\b(?:t|button|empty|status)\("([a-zA-Z][a-zA-Z0-9_-]*)"/g), function (match) { return match[1]; }).filter(function (key) { return !key.endsWith("_"); });
  keys.push("components", "links", "checks", "changes", "actual_path", "resolved_path", "duplicate_groups", "metadata_checks", "duplicates_only", "findings_only");
  for (const kind of ["skill", "agent", "mcp", "rag"]) keys.push("kind_" + kind);
  for (const code of ["shell_wrapper", "download_execute", "broad_filesystem_scope", "remote_endpoint", "unpinned_runtime", "rag_source_declared", "index_uninspected"]) for (const prefix of ["finding_", "evidence_", "action_"]) keys.push(prefix + code);
  for (const code of ["high", "medium", "low", "info"]) keys.push("severity_" + code);
  for (const code of ["requires", "recommended", "source"]) keys.push("relation_" + code);
  for (const code of ["added", "changed", "missing"]) keys.push("event_" + code);
  for (const locale of ["ru", "en", "zh-CN"]) for (const key of keys) assert.equal(typeof strings[locale][key], "string", locale + ": missing " + key);
});

(async function () {
  let failures = 0;
  for (const item of tests) {
    try { await item.run(); console.log("PASS " + item.name); }
    catch (error) { failures += 1; console.error("FAIL " + item.name); console.error(error); }
  }
  console.log(tests.length + " presentation checks, " + failures + " failures");
  process.exitCode = failures ? 1 : 0;
}());
