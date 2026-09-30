//
//  LocalizeKeys.swift
//  Resources
//
//  Created by Vyacheslav Razumeenko on 28.04.2025.
//
//  Copyright (c) 2025 EFI https://efi.int/
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import Foundation

/// A language of the app, identified by its ISO 639 code (en, fr, hi…).
///
/// The app ships strings for English, French and Spanish. The languages actually offered,
/// and any other language, come from the admin panel (see `LanguageCatalog`).
/// Stored as its code, both in `@AppStorage` and as JSON in `UserDefaultsStore`.
public struct LocalizeKeys: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue.lowercased()
    }

    public static let english: Self = .init(rawValue: "en")
    public static let french: Self = .init(rawValue: "fr")
    public static let spanish: Self = .init(rawValue: "es")

    /// Languages whose strings are built into the app.
    public static let bundled: [Self] = [.english, .french, .spanish]

    /// Languages offered in the app, in picker order: those enabled in the admin panel,
    /// or the bundled ones until the app has received the list.
    public static var allCases: [Self] {
        LanguageCatalog.shared.languages.map { Self(rawValue: $0.code) }
    }

    /// The default language chosen in the admin panel.
    public static var `default`: Self {
        .init(rawValue: LanguageCatalog.shared.defaultCode)
    }

    public var code: String { rawValue }

    /// Name shown in the language picker.
    public var title: String {
        switch self {
            case .english:
                return "English"
            case .french:
                return "French"
            case .spanish:
                return "Spanish"
            default:
                return LanguageCatalog.shared.language(code: code)?.name ?? code
        }
    }

    /// Optional flag emoji set in the admin panel.
    public var flag: String? {
        guard let flag = LanguageCatalog.shared.language(code: code)?.flag, !flag.isEmpty else { return nil }
        return flag
    }

    public var locale: Locale {
        self == .english ? .init(identifier: "en_US") : .init(identifier: code)
    }

    public static func getLocalize(title: String) -> Self {
        allCases.first { $0.title == title } ?? .default
    }

    // MARK: - Codable (a plain string, as when this was an enum)
    public init(from decoder: Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
