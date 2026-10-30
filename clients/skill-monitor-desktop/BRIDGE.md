# Presentation bridge contract

Status: consumer contract for future native integration. No native bridge,
filesystem scanner, Tauri configuration, permissions, persistence or desktop
binary is implemented in this directory. The current entry point is a static
presentation. Node tests supply synthetic objects only inside the tests.

## Trusted host entry point

A future native host may supply `window.skillMonitorBridge` before `app.js`
loads. The presentation captures this object once. It does not inspect Tauri
internals, discover endpoints, send network requests or execute component
instructions. CSP sets `connect-src 'none'` and permits only same-origin
external script and style files. This policy will require an independent review
before any native IPC integration changes it.

The presentation recognizes these named methods only:

```ts
interface PresentationBridge {
  getState(): Promise<Snapshot>;
  chooseFolders?(): Promise<Snapshot>;
  removeFolder?(request: { folderId: string }): Promise<Snapshot>;
  refresh?(): Promise<Snapshot>;
}
```

Every method must return a full snapshot, including a canceled folder picker.
An acknowledgment, partial result or missing value is an incompatible response.
`getState`, `refresh` and `removeFolder` have a 15-second presentation deadline.
On failure, pending state clears; a previous snapshot remains visible with a
stale-results warning. Late responses to timed operations are ignored.
`chooseFolders` waits for a human choice without that deadline. The interface
sets `pendingMethod: "chooseFolders"` and displays a localized waiting message,
without claiming that reading is in progress. Choosing or canceling after more
than 15 seconds still accepts the returned snapshot. The future native host
must separately bound any scan started after the choice to five seconds; the
single presentation promise cannot observe when the native dialog closes.
No native scan or timeout enforcement is implemented here.

The presentation prevents concurrent requests. It reads `getState` once at
startup and on connection retry. It does not poll.

Language and search choices exist in the page's memory only. There is no
`setPreferences` call or settings persistence. Changing a visible filter does
not request a filesystem read. Removing a folder sends its opaque ID; the page
does not send arbitrary paths to native operations.

## Snapshot schema

```ts
type Kind = "skill" | "agent" | "mcp" | "rag";
type FindingCode = "shell_wrapper" | "download_execute" |
  "broad_filesystem_scope" | "remote_endpoint" | "unpinned_runtime" |
  "rag_source_declared" | "index_uninspected";
type IssueCode = "missing_root" | "unreadable_root" | "outside_scope" |
  "symlink_cycle" | "unreadable_file" | "invalid_frontmatter" |
  "missing_name" | "missing_description" | "oversized_header" |
  "changed_during_read" | "unsupported_file" | "hard_link" |
  "scan_limit" | "invalid_config";

interface Snapshot {
  schemaVersion: 1;
  folders: Array<{ id: string; path: string; name?: string }>;
  components: Array<{
    id: string;
    name?: string;
    kind: Kind;
    summary?: string;
    summaryKey?: string;
    path?: string;
    resolvedPath?: string;
    folderId?: string;
    locations: string[];
    issues: IssueCode[];
    findings: Array<{
      code: FindingCode;
      severity?: "high" | "medium" | "low" | "info";
      line?: number;
    }>;
    references: Array<{
      relation?: "requires" | "recommended" | "source";
      targetId?: string;
      label?: string;
      status?: "resolved" | "unresolved" | "ambiguous";
      external?: boolean;
    }>;
  }>;
  notices: Array<{ code: IssueCode; path?: string }>;
  changes: Array<{
    category?: "added" | "changed" | "missing";
    name?: string;
    path?: string;
    recordedAt?: string;
  }>;
  complete: boolean;
  hasScanned: boolean;
  scannedAt?: string;
  hasBaseline?: boolean;
  comparisonPaused?: boolean;
  journalLimited?: boolean;
}
```

Folder and component IDs must be unique nonempty strings of at most 512 code
units. They must represent stable native identities, not a lossy filename
normalization. The UI rejects oversized IDs rather than truncating them.
Arrays are required even when empty. A snapshot accepts at most 128 folders,
10,000 components, 10,000 notices and 500 change events. Presentation bounds
per component are 128 locations, 64 issues, 128 findings and 256 references.
Display strings are bounded to 8,192 code units and names to 512. These are
presentation bounds, not a scanner or native input validation policy.

Unknown finding and issue codes reject a snapshot to avoid displaying a false
clean result. Unknown severities display as information. `summaryKey` is only
for the reviewed `summary_*` translations in `locales.js`; native metadata must
use `summary` for original text. Do not send secrets, executable command bodies,
remote addresses or unneeded raw configuration in this contract.

External references must set `external: true`. Their target ID and original
label are discarded, and the UI shows the reviewed external-source explanation.
They never resolve to a local component with a matching name or ID. No metadata
link becomes an active URL. All metadata is inserted with `textContent`.

## Native responsibilities that remain unimplemented

The future host must enforce user-selected roots, readable-file boundaries,
symlink and hard-link handling, metadata limits, sensitive-data redaction,
physical identity, safe passive checks and complete-read semantics. The renderer
is not a permissions or security boundary for a native scanner. A display bound
does not authorize scanning, execution, storage or network access.

`complete: false` always pauses comparison in the presentation. The host must
retain any prior complete baseline and avoid treating inaccessible components
as deletions. The UI only displays a provided journal; it does not generate,
persist or acknowledge history. `hasBaseline` controls the empty journal text.
When no valid host response exists, counts remain unknown rather than zero.

The summary covers the full received component snapshot. Duplicate groups count
trimmed, case-insensitive names shared by multiple components, excluding missing
names; alias paths do not create additional components. Findings include
informational notices and remain separate from read failures. The result line
counts components passing all visible filters. Changes display the entire
provided journal without component filters. Read notices cover all selected
folders even when the component list is filtered.

## Review checks

Run from the repository root:

```sh
node clients/skill-monitor-desktop/tests/test.js
```

The dependency-free suite checks disconnected states in three languages,
literal HTML rendering, filters and count units, external reference handling,
malformed responses, bounded nonhuman operations, unrestricted human choice
time, late timed responses, retained stale results, keyboard focus and
incomplete comparisons. It does not establish native
security, platform compatibility or visual correctness in a real webview.
