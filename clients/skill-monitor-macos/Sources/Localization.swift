import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case russian = "ru"
    case english = "en"
    case chinese = "zh-CN"
    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }
}

struct Localization {
    let language: AppLanguage
    private static let strings: [String: [String: String]] = {
        guard let url = Bundle.main.url(forResource: "locales", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let strings = try? JSONDecoder().decode([String: [String: String]].self, from: data)
        else { return [:] }
        return strings
    }()

    func text(_ key: String) -> String {
        Self.strings[language.rawValue]?[key] ?? Self.strings["en"]?[key] ?? key
    }

    func count(_ key: String, _ value: Int) -> String {
        text(key).replacingOccurrences(of: "{count}", with: String(value))
    }

    func date(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.timeZone = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: value)
    }
}
