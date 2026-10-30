import Foundation

@main
struct FolderSuggestionTests {
    private static var checks = 0
    private static let home = "/fixture-user"
    private static func expect(_ value: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        precondition(value(), message)
    }
    private static func encode(_ entries: [[String: Any]]) throws -> String {
        String(data: try JSONSerialization.data(withJSONObject: ["folders": entries]), encoding: .utf8)!
    }
    private static func parse(_ entries: [[String: Any]], existing: [String] = []) throws -> FolderSuggestionResult {
        try FolderSuggestionParser.parse(encode(entries), home: home, existing: existing)
    }
    private static func expectError(_ input: String, _ expected: FolderSuggestionError) {
        do {
            _ = try FolderSuggestionParser.parse(input, home: home, existing: [])
            expect(false, "Expected rejection")
        } catch let error as FolderSuggestionError { expect(error == expected, "Wrong rejection code") }
        catch { expect(false, "Unexpected error type") }
    }
    static func main() throws {
        let result = try parse([
            ["path": "~/.agents", "reason": "Known tool folder"],
            ["path": home + "/.agents/", "reason": "Duplicate spelling"],
            ["path": "~/Documents/AI skills", "reason": "User project"]
        ], existing: [home + "/.agents"])
        expect(result.folders.count == 2, "Normalize and deduplicate paths")
        expect(result.folders[0].alreadyIncluded && !result.folders[1].alreadyIncluded, "Keep existing roots disabled")
        expect(result.folders[1].path == home + "/Documents/AI skills", "Support spaces without command interpolation")
        let literal = try parse([["path": home + "/$(not-a-command)/skills"]])
        expect(literal.folders.count == 1, "Path is data, never a command")
        let missing = try parse([["path": "/a/nonexistent/approved-proposal/skills"]])
        expect(missing.folders.count == 1, "Never probe filesystem during proposal parsing")
        let blocked = ["/", "~", home, "/Users", "/private", "../skills", "relative/skills", "~someone/skills", "https://example.invalid/skills", "file://" + home + "/.agents", "//server/share", home + "/a/../skills", home + "/.ssh", home + "/.aws/skills", home + "/.env.private", home + "/models/skills", home + "/local-llm/skills", home + "/bad\nfolder", home + "/bad\u{202e}folder", home + "/bad\u{0}folder"]
        for path in blocked {
            let invalid = try parse([["path": path]])
            expect(invalid.folders.isEmpty && invalid.rejectedCount == 1, "Blocked proposal")
        }
        let unknown = try parse([["path": home + "/.agents", "command": "not executed"]])
        expect(unknown.folders.isEmpty, "Reject unknown entry fields")
        let reason = try parse([["path": home + "/.agents", "reason": String(repeating: "x", count: 401)]])
        expect(reason.rejectedCodes == ["invalid_reason"], "Bound displayed reason")
        let invalidReason = try parse([["path": home + "/.agents", "reason": 5]])
        expect(invalidReason.folders.isEmpty, "Reason must be text")
        let fenced = try FolderSuggestionParser.parse("```json\n" + encode([["path": "~/.agents"]]) + "\n```", home: home, existing: [])
        expect(fenced.folders.count == 1, "Accept a single JSON code fence")
        let empty = try parse([])
        expect(empty.folders.isEmpty && empty.rejectedCount == 0, "Empty response is not an invented result")
        expectError("not json", .invalidJSON)
        expectError("[]", .invalidSchema)
        expectError("{\"folders\":[],\"command\":\"never execute\"}", .invalidSchema)
        expectError(try encode(Array(repeating: ["path": "~/.agents"], count: 33)), .tooMany)
        expectError(String(repeating: " ", count: 32769), .oversized)
        expectError(String(repeating: "[", count: 18) + String(repeating: "]", count: 18), .invalidSchema)
        let quotedBrackets = try parse([["path": "~/[folders]/skills", "reason": "Quoted brackets do not nest JSON"]])
        expect(quotedBrackets.folders.count == 1, "Nesting guard respects strings")
        print("PASS: \(checks) folder suggestion checks; no filesystem or network access")
    }
}
