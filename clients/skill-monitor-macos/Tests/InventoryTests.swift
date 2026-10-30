import Foundation
import Darwin

@main
struct InventoryTests {
    static var checks = 0
    static var fixturePath: String?
    static let fm = FileManager.default
    static func expect(_ value: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        if !value() {
            if let path = fixturePath { try? fm.removeItem(atPath: path) }
            fatalError("FAIL: " + message)
        }
    }
    static func put(_ path: String, _ text: String) throws {
        try fm.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        try Data(text.utf8).write(to: URL(fileURLWithPath: path))
    }
    static func skill(_ path: String, _ name: String = "sample") throws {
        try put(path + "/SKILL.md", "---\nname: \(name)\ndescription: Fixture metadata.\n---\nDO NOT READ BODY\n")
    }
    static func codes(_ result: LocalInventory) -> Set<String> {
        Set(result.notices.map(\.code))
    }
    static func main() throws {
        let project = fm.currentDirectoryPath
        let base = project + "/build/native-core-tests-" + UUID().uuidString
        fixturePath = base
        try fm.createDirectory(atPath: base, withIntermediateDirectories: true)
        defer { try? fm.removeItem(atPath: base) }

        let home = base + "/home"
        try skill(home + "/skills/one", "One")
        try skill(home + "/unrelated", "Hidden")
        var result = SkillScanner.scan(roots: [home])
        // Expanded component discovery scans the selected root itself, so
        // sibling metadata now participates alongside the skills subtree.
        expect(result.skills.count == 2, "selected root includes sibling metadata")
        expect(result.roots == [home] && result.scanPaths == [home], "root provenance")
        let stable = result.skills[0].id
        try skill(home + "/skills/pack/nested", "Nested")
        result = SkillScanner.scan(roots: [home])
        expect(result.skills.count == 3 && result.skills.contains { $0.id == stable }, "refresh and nested skill")
        try fm.removeItem(atPath: home + "/skills/one")
        expect(SkillScanner.scan(roots: [home]).skills.count == 2, "refresh removal")

        let extra = base + "/extra"
        try skill(extra, "Other")
        expect(SkillScanner.scan(roots: [home, extra]).skills.count == 3, "add folder selection")
        expect(SkillScanner.scan(roots: [extra]).skills.count == 1, "remove folder selection")
        expect(SkillScanner.scan(roots: []).skills.isEmpty, "no fallback data")
        expect(codes(SkillScanner.scan(roots: [""])).contains("missing_root"), "empty root never becomes current directory")

        let parse = base + "/parse"
        try put(parse + "/quoted/SKILL.md", #"""
---
name: 'Alice''s skill'
description: "Escaped \"quote\" and \u03BB"
---
"""#)
        try put(parse + "/fold/SKILL.md", "---\nname: Fold\ndescription: >-\n  First line\n  second line.\n\n  Next paragraph.\n---\n")
        try put(parse + "/literal/SKILL.md", "---\nname: Literal\ndescription: |-\n  First line\n  second line.\n---\n")
        try put(parse + "/bad/SKILL.md", "not frontmatter\nsecret fixture body\n")
        try put(parse + "/missing/SKILL.md", "---\nother: value\n---\n")
        result = SkillScanner.scan(roots: [parse])
        expect(result.skills.count == 5, "invalid records are isolated")
        expect(result.skills.first { $0.name == "Alice's skill" }?.summary == "Escaped \"quote\" and \u{03BB}", "quoted scalar escapes")
        expect(result.skills.first { $0.name == "Fold" }?.summary == "First line second line.\n\nNext paragraph.", "folded description")
        expect(result.skills.first { $0.name == "Literal" }?.summary == "First line\nsecond line.", "literal description")
        expect(result.skills.first { $0.name == "bad" }?.issues.contains("invalid_frontmatter") == true, "fallback for malformed header")
        expect(result.skills.first { $0.name == "missing" }?.issues == ["missing_name", "missing_description"], "missing metadata")
        try put(parse + "/unclosed/SKILL.md", "---\nname: Unclosed\ndescription: no closing delimiter\n")
        try put(parse + "/invalidquote/SKILL.md", "---\nname: 'Unclosed\ndescription: Intact description\n---\n")
        result = SkillScanner.scan(roots: [parse])
        expect(result.skills.count == 7, "additional malformed records retain isolation")
        expect(result.skills.first { $0.name == "unclosed" }?.issues.contains("invalid_frontmatter") == true, "unclosed header")
        expect(result.skills.first { $0.name == "invalidquote" }?.summary == "Intact description", "malformed name preserves valid description")

        let links = base + "/links"
        try skill(links + "/original", "Same")
        try skill(links + "/duplicate", "Same")
        try fm.createSymbolicLink(atPath: links + "/alias", withDestinationPath: "original")
        try fm.createSymbolicLink(atPath: links + "/escape", withDestinationPath: extra)
        try fm.createSymbolicLink(atPath: links + "/original/cycle", withDestinationPath: "..")
        result = SkillScanner.scan(roots: [links])
        expect(result.skills.count == 2, "duplicate names remain distinct")
        expect(result.skills.first { $0.canonicalPath.contains("/original/") }?.locations.count == 2, "internal alias retains locations")
        expect(result.skills.contains { $0.locations.contains { $0.viaSymlink } }, "alias provenance")
        expect(codes(result).contains("outside_scope") && codes(result).contains("symlink_cycle"), "outside alias and cycle notices")
        result = SkillScanner.scan(roots: [links, links + "/original"])
        expect(result.skills.first { $0.canonicalPath.contains("/original/") }?.locations.count == 3, "overlapping root provenance")
        result = SkillScanner.scan(roots: [links + "/escape"])
        expect(result.skills.isEmpty && codes(result).contains("outside_scope"), "symlink root is observable")
        let filenameAlias = base + "/filename-alias"
        try put(filenameAlias + "/private.txt", "---\nname: Forbidden\ndescription: Not a named metadata file.\n---\n")
        try fm.createSymbolicLink(atPath: filenameAlias + "/SKILL.md", withDestinationPath: "private.txt")
        result = SkillScanner.scan(roots: [filenameAlias])
        expect(result.skills.isEmpty && codes(result).contains("unsupported_file"), "metadata alias cannot read unrelated filename")
        let selectedSkillsAlias = base + "/skills-alias-root"
        try fm.createDirectory(atPath: selectedSkillsAlias, withIntermediateDirectories: true)
        try fm.createSymbolicLink(atPath: selectedSkillsAlias + "/skills", withDestinationPath: extra)
        result = SkillScanner.scan(roots: [selectedSkillsAlias])
        expect(result.scanPaths == [selectedSkillsAlias] && codes(result).contains("outside_scope"), "outside skills alias remains refused")
        let internalFileAlias = base + "/internal-file-alias"
        try skill(internalFileAlias + "/target")
        try fm.createSymbolicLink(atPath: internalFileAlias + "/SKILL.md", withDestinationPath: "target/SKILL.md")
        result = SkillScanner.scan(roots: [internalFileAlias])
        expect(result.skills.count == 1 && result.skills[0].locations.count == 2, "internal named file alias deduplicates")
        try fm.createSymbolicLink(atPath: internalFileAlias + "/ambiguous", withDestinationPath: "target/../target")
        expect(codes(SkillScanner.scan(roots: [internalFileAlias])).contains("outside_scope"), "ambiguous parent-step alias fails closed")

        let special = base + "/special"
        try fm.createDirectory(atPath: special + "/fifo", withIntermediateDirectories: true)
        expect(mkfifo(special + "/fifo/SKILL.md", 0o600) == 0, "create fixture FIFO")
        try skill(special + "/hard")
        expect(link(special + "/hard/SKILL.md", special + "/hardlink") == 0, "create fixture hard link")
        try skill(special + "/.aws/denied")
        try skill(special + "/models/denied")
        result = SkillScanner.scan(roots: [special])
        expect(result.skills.isEmpty, "special files and excluded paths rejected")
        expect(codes(result).contains("unsupported_file") && codes(result).contains("hard_link"), "special file notices")

        let budget = base + "/budget"
        try skill(budget + "/a")
        try skill(budget + "/b")
        try skill(budget + "/deep/more/skill")
        var limits = ScanLimits()
        limits.maxDepth = 1
        result = SkillScanner.scan(roots: [budget], limits: limits)
        expect(result.skills.count == 2 && result.limited, "depth budget")
        limits = ScanLimits(); limits.maxSkills = 1
        result = SkillScanner.scan(roots: [budget], limits: limits)
        expect(result.skills.count == 1 && result.limited && codes(result).contains("scan_limit"), "skill count budget")
        limits = ScanLimits(); limits.maxDirectories = 1
        result = SkillScanner.scan(roots: [budget], limits: limits)
        expect(result.skills.isEmpty && result.limited, "directory count budget")
        limits = ScanLimits(); limits.maxSeconds = 0
        expect(SkillScanner.scan(roots: [budget], limits: limits).limited, "time budget")
        limits = ScanLimits(); limits.maxTotalBytes = 4
        result = SkillScanner.scan(roots: [budget], limits: limits)
        expect(result.limited && codes(result).contains("scan_limit"), "total read budget")
        let large = base + "/large"
        try put(large + "/SKILL.md", "---\nname: Large\ndescription: " + String(repeating: "x", count: 200) + "\n---\n")
        limits = ScanLimits(); limits.maxHeaderBytes = 40
        result = SkillScanner.scan(roots: [large], limits: limits)
        expect(result.skills.count == 1 && result.skills[0].issues.contains("oversized_header") && result.limited, "header size budget")
        let body = base + "/body"
        try skill(body)
        limits = ScanLimits(); limits.maxHeaderBytes = 80; limits.maxTotalBytes = 80
        result = SkillScanner.scan(roots: [body], limits: limits)
        expect(result.skills.count == 1 && result.skills[0].issues.isEmpty && !result.limited, "stop at header closure")
        let exact = base + "/exact"
        let exactHeader = "---\r\nname: Exact\r\ndescription: Header at EOF\r\n---"
        try put(exact + "/SKILL.md", exactHeader)
        limits = ScanLimits(); limits.maxHeaderBytes = exactHeader.utf8.count; limits.maxTotalBytes = exactHeader.utf8.count
        result = SkillScanner.scan(roots: [exact], limits: limits)
        expect(result.skills.count == 1 && result.skills[0].issues.isEmpty && !result.limited, "CRLF and exact EOF budget")

        result = SkillScanner.scan(roots: [base + "/missing"])
        expect(codes(result).contains("missing_root") && result.skills.isEmpty, "missing root")
        let denied = base + "/denied"
        try skill(denied)
        expect(chmod(denied, 0) == 0, "create unreadable root")
        result = SkillScanner.scan(roots: [denied])
        _ = chmod(denied, 0o700)
        if geteuid() != 0 { expect(codes(result).contains("unreadable_root"), "unreadable root") }
        let deniedFile = base + "/denied-file"
        try skill(deniedFile)
        expect(chmod(deniedFile + "/SKILL.md", 0) == 0, "create unreadable metadata")
        result = SkillScanner.scan(roots: [deniedFile])
        _ = chmod(deniedFile + "/SKILL.md", 0o600)
        if geteuid() != 0 { expect(result.skills.isEmpty && codes(result).contains("unreadable_file"), "unreadable metadata notice") }
        print("PASS: \(checks) inventory checks (synthetic fixtures only)")
    }
}
