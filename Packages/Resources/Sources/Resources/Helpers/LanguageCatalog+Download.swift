//
//  LanguageCatalog+Download.swift
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
#if canImport(FoundationNetworking)
import FoundationNetworking // Linux
#endif

// MARK: - Download from the API
public extension LanguageCatalog {
    /// Downloads the languages enabled in the admin panel. Offline, keeps the cached ones.
    /// - Parameter baseURL: the API base, ending with /api/v1.
    func refreshLanguages(baseURL: URL, session: URLSession = .shared) async {
        let url = baseURL.appendingPathComponent("languages/")
        guard let response: ListResponse = await Self.get(url, session: session) else { return }
        update(
            languages: response.data.languages.map {
                Language(code: $0.code, name: $0.name, englishName: $0.englishName, flag: $0.flag, version: $0.version)
            },
            defaultCode: response.data.default
        )
    }

    /// Downloads the strings uploaded for a language, unless the ones kept are up to date.
    func refreshStrings(language code: String, baseURL: URL, session: URLSession = .shared) async {
        guard let language = language(code: code) else { return }
        if let kept = stringsVersion(language: code), kept >= language.version { return }
        let url = baseURL.appendingPathComponent("languages/\(language.code)/ios/")
        guard let response: StringsResponse = await Self.get(url, session: session) else { return }
        update(strings: response.data)
    }

    // MARK: - Responses
    internal struct ListResponse: Decodable {
        struct Data: Decodable {
            let `default`: String?
            let languages: [Language]
        }
        let data: Data
    }

    internal struct StringsResponse: Decodable {
        let data: Strings
    }

    private static func get<T: Decodable>(_ url: URL, session: URLSession) async -> T? {
        do {
            let (data, response) = try await session.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            return nil
        }
    }
}
