//
//  LanguageCatalogTests.swift
//  ResourcesTests
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


import XCTest
@testable import Resources

final class LanguageCatalogTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func catalog() -> LanguageCatalog {
        let catalog = LanguageCatalog(directory: directory)
        catalog.update(
            languages: [
                .init(code: "fr", name: "Français"),
                .init(code: "en", name: "English"),
                .init(code: "hi", name: "हिन्दी", flag: "🇮🇳", version: 2),
            ],
            defaultCode: "fr"
        )
        return catalog
    }

    func testBundledLanguagesUntilTheListIsReceived() {
        let catalog = LanguageCatalog(directory: directory)

        XCTAssertEqual(catalog.languages.map(\.code), ["en", "fr", "es"])
        XCTAssertEqual(catalog.defaultCode, "en")
    }

    func testResolveKeepsAnEnabledStoredLanguage() {
        XCTAssertEqual(catalog().resolve(stored: "hi", preferred: ["en-US"]), "hi")
    }

    func testResolveReplacesADisabledLanguage() {
        let catalog = catalog()

        XCTAssertEqual(catalog.resolve(stored: "es", preferred: ["en-US", "fr-FR"]), "en")
        XCTAssertEqual(catalog.resolve(stored: "es", preferred: ["de-DE"]), "fr")
        XCTAssertEqual(catalog.resolve(stored: nil, preferred: []), "fr")
    }

    func testMatchesTheBaseLanguage() {
        let catalog = catalog()

        XCTAssertEqual(catalog.match("fr_CA")?.code, "fr")
        XCTAssertEqual(catalog.match("HI-in")?.code, "hi")
        XCTAssertNil(catalog.match("de"))
    }

    func testUnknownDefaultFallsBackToTheFirstLanguage() {
        let catalog = LanguageCatalog(directory: directory)
        catalog.update(languages: [.init(code: "en", name: "English")], defaultCode: "es")

        XCTAssertEqual(catalog.defaultCode, "en")
    }

    func testListAndStringsAreKeptOnDisk() {
        let catalog = catalog()
        catalog.update(strings: .init(code: "hi", version: 2, strings: ["general.appName": "व्हिमो"]))

        let reloaded = LanguageCatalog(directory: directory)

        XCTAssertEqual(reloaded.languages.map(\.code), ["fr", "en", "hi"])
        XCTAssertEqual(reloaded.defaultCode, "fr")
        XCTAssertEqual(reloaded.string(for: "general.appName", language: "hi"), "व्हिमो")
        XCTAssertEqual(reloaded.stringsVersion(language: "hi"), 2)
        XCTAssertNil(reloaded.string(for: "general.appName", language: "fr"))
    }

    func testDecodesTheApiResponses() throws {
        let list = Data(#"""
        {"success": true, "data": {"default": "fr", "languages": [
            {"code": "hi", "name": "हिन्दी", "english_name": "Hindi", "flag": "🇮🇳", "version": 3}
        ]}}
        """#.utf8)
        let strings = Data(#"""
        {"success": true, "data": {"code": "hi", "version": 3, "strings": {"auth.login.title": "लॉग इन"}}}
        """#.utf8)

        let decodedList = try JSONDecoder().decode(LanguageCatalog.ListResponse.self, from: list)
        let decodedStrings = try JSONDecoder().decode(LanguageCatalog.StringsResponse.self, from: strings)

        XCTAssertEqual(decodedList.data.default, "fr")
        XCTAssertEqual(decodedList.data.languages, [.init(code: "hi", name: "हिन्दी", englishName: "Hindi", flag: "🇮🇳", version: 3)])
        XCTAssertEqual(decodedStrings.data.strings["auth.login.title"], "लॉग इन")
    }
}

final class LocalizeKeysTests: XCTestCase {
    func testEncodesAsAPlainStringLikeTheFormerEnum() throws {
        let data = try JSONEncoder().encode(LocalizeKeys.french)

        XCTAssertEqual(String(decoding: data, as: UTF8.self), #""fr""#)
        XCTAssertEqual(try JSONDecoder().decode(LocalizeKeys.self, from: Data(#""HI""#.utf8)).code, "hi")
    }

    func testBundledLanguagesKeepTheirTitlesAndLocales() {
        XCTAssertEqual(LocalizeKeys.english.title, "English")
        XCTAssertEqual(LocalizeKeys.english.locale.identifier, "en_US")
        XCTAssertEqual(LocalizeKeys(rawValue: "fr"), .french)
    }
}
