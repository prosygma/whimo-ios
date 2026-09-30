//
//  LanguageCatalog.swift
//  Resources
//
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

/// Languages enabled in the admin panel, and the strings uploaded there for this app.
///
/// The app ships strings for a few languages. An administrator can disable them, choose the
/// default language, add a new language (for example Hindi) or correct strings, by uploading
/// them in the admin panel. `LanguagesService` downloads the list and the strings of the
/// current language; they are kept on disk so that the app works offline.
public final class LanguageCatalog: @unchecked Sendable {
    public struct Language: Codable, Equatable, Sendable {
        public let code: String
        /// Name in the language itself, for example हिन्दी.
        public let name: String
        public let englishName: String
        /// Optional flag emoji, empty when not set.
        public let flag: String
        /// Increases with each upload of strings.
        public let version: Int

        public init(code: String, name: String, englishName: String = "", flag: String = "", version: Int = 0) {
            self.code = code.lowercased()
            self.name = name
            self.englishName = englishName
            self.flag = flag
            self.version = version
        }

        enum CodingKeys: String, CodingKey {
            case code, name, flag, version
            case englishName = "english_name"
        }
    }

    public struct Strings: Codable, Equatable, Sendable {
        public let code: String
        public let version: Int
        public let strings: [String: String]

        public init(code: String, version: Int, strings: [String: String]) {
            self.code = code
            self.version = version
            self.strings = strings
        }
    }

    public static let shared: LanguageCatalog = .init()

    private let lock: NSLock = .init()
    private let directory: URL
    private var list: (languages: [Language], defaultCode: String)
    /// Strings per language; nil once the disk was checked and holds none.
    private var strings: [String: Strings?] = [:]

    /// - Parameter directory: where the list and the strings are kept (Application Support by default).
    public init(directory: URL? = nil) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.directory = directory ?? base.appendingPathComponent("Languages", isDirectory: true)
        self.list = Self.bundledList
        if let cached: CachedList = read("languages.json"), !cached.languages.isEmpty {
            self.list = (cached.languages, cached.defaultCode)
        }
    }

    // MARK: - Languages

    /// Enabled languages, in picker order.
    public var languages: [Language] {
        lock.withLock { list.languages }
    }

    public var defaultCode: String {
        lock.withLock { list.defaultCode }
    }

    public func language(code: String) -> Language? {
        languages.first { $0.code == code.lowercased() }
    }

    /// Enabled language for a code such as fr, fr-CA or pt-BR: exact match first, then same base.
    public func match(_ code: String?) -> Language? {
        guard let code = code?.lowercased().replacingOccurrences(of: "_", with: "-") else { return nil }
        let languages = languages
        return languages.first { $0.code == code }
            ?? languages.first { Self.base($0.code) == Self.base(code) }
    }

    /// Language to use: the stored choice if still enabled, else the first enabled preferred
    /// language of the device, else the default one.
    public func resolve(stored: String?, preferred: [String]) -> String {
        if let language = match(stored) { return language.code }
        for code in preferred {
            if let language = match(code) { return language.code }
        }
        return defaultCode
    }

    public func update(languages: [Language], defaultCode: String?) {
        guard !languages.isEmpty else { return }
        let defaultCode = defaultCode.flatMap { code in languages.first { $0.code == code.lowercased() }?.code }
            ?? languages[0].code
        lock.withLock { list = (languages, defaultCode) }
        write(CachedList(languages: languages, defaultCode: defaultCode), to: "languages.json")
    }

    // MARK: - Strings

    /// Uploaded text for a key of Localizable.strings in a language, if any.
    public func string(for key: String, language code: String) -> String? {
        storedStrings(code)?.strings[key]
    }

    /// Version of the strings kept for a language, nil when none were downloaded.
    public func stringsVersion(language code: String) -> Int? {
        storedStrings(code)?.version
    }

    public func update(strings: Strings) {
        let code = strings.code.lowercased()
        lock.withLock { self.strings[code] = strings }
        write(strings, to: "strings-\(code).json")
    }

    private func storedStrings(_ code: String) -> Strings? {
        let code = code.lowercased()
        if let known = lock.withLock({ strings[code] }) { return known }
        let cached: Strings? = read("strings-\(code).json")
        lock.withLock { strings[code] = .some(cached) }
        return cached
    }

    // MARK: - Storage

    private struct CachedList: Codable {
        let languages: [Language]
        let defaultCode: String
    }

    private static let bundledList: ([Language], String) = (
        [
            .init(code: "en", name: "English", englishName: "English"),
            .init(code: "fr", name: "Français", englishName: "French"),
            .init(code: "es", name: "Español", englishName: "Spanish"),
        ],
        "en"
    )

    private static func base(_ code: String) -> String {
        String(code.split(separator: "-").first ?? Substring(code))
    }

    private func read<T: Decodable>(_ name: String) -> T? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(name)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func write<T: Encodable>(_ value: T, to name: String) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(value).write(to: directory.appendingPathComponent(name), options: .atomic)
        } catch {
            // Not fatal: the strings are downloaded again at the next start.
        }
    }
}
