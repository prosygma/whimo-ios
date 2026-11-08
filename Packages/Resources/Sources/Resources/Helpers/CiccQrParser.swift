//
//  CiccQrParser.swift
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

/// Reads the QR code printed on a CICC plot identification card. The code is plain text, not
/// GeoJSON:
///
///     NIPr_CICC :XX.AAA.BBB0001
///     GLN_Parcelle :0000000000001
///     Lien_GS1_Parcelle :https://example.org/414/0000000000001
///     Coordonnées :
///     [4.1;12.1],[4.1005;12.1004],...
///
/// Each point is `[latitude;longitude]`. The plot becomes a GeoJSON polygon whose feature
/// properties carry the CICC keys and `"Source": "CICC"`, which the backend checks.
public enum CiccQrParser {
    public static let nipr = "NIPr_CICC"
    public static let gln = "GLN_Parcelle"
    public static let gs1Link = "Lien_GS1_Parcelle"
    public static let coordinates = "Coordonnees"
    public static let requiredKeys = [nipr, gln, gs1Link]

    public struct Plot: Equatable, Sendable {
        public let geoJSON: String
        /// First corner.
        public let latitude: Double
        public let longitude: Double
        public let properties: [String: String]
    }

    public enum ParseError: Error, Equatable {
        /// The listed keys are missing; `coordinates` also means "fewer than 3 valid points".
        case missing([String])
    }

    private static let minCorners = 3

    public static func parse(_ text: String) -> Result<Plot, ParseError> {
        let fields = readFields(text)
        var missing = requiredKeys.filter { fields[normalise($0)] == nil }

        let corners = points(in: fields[normalise(coordinates)] ?? "")
        if corners.count < minCorners { missing.append(coordinates) }
        guard missing.isEmpty, let first = corners.first else { return .failure(.missing(missing)) }

        var properties: [String: String] = [:]
        for key in requiredKeys { properties[key] = fields[normalise(key)] }
        return .success(Plot(
            geoJSON: geoJSON(corners: corners, properties: properties),
            latitude: first.latitude,
            longitude: first.longitude,
            properties: properties
        ))
    }

    // MARK: - Private

    /// Values by normalised key. A value runs until the next "Key :" line; split on the first
    /// colon only, because the GS1 link contains "https:".
    private static func readFields(_ text: String) -> [String: String] {
        var fields: [String: String] = [:]
        var current: String?
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if let colon = line.firstIndex(of: ":"), isKey(String(line[..<colon])) {
                let key = normalise(String(line[..<colon]))
                fields[key] = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                current = key
            } else if let key = current {
                fields[key, default: ""] += "\n" + line
            }
        }
        return fields
    }

    private static func isKey(_ candidate: String) -> Bool {
        let key = candidate.trimmingCharacters(in: .whitespaces)
        guard let first = key.unicodeScalars.first, CharacterSet.letters.contains(first) else { return false }
        let allowed = CharacterSet.letters.union(.decimalDigits).union(CharacterSet(charactersIn: "_"))
        return key.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private static func points(in value: String) -> [(latitude: Double, longitude: Double)] {
        var result: [(latitude: Double, longitude: Double)] = []
        var rest = Substring(value)
        while let open = rest.firstIndex(of: "["), let close = rest[open...].firstIndex(of: "]") {
            let parts = rest[rest.index(after: open)..<close].split(separator: ";")
            rest = rest[rest.index(after: close)...]
            guard parts.count == 2,
                  let latitude = number(parts[0]), let longitude = number(parts[1]),
                  (-90...90).contains(latitude), (-180...180).contains(longitude)
            else { continue }
            result.append((latitude, longitude))
        }
        return result
    }

    private static func number(_ text: Substring) -> Double? {
        Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }

    private static func geoJSON(corners: [(latitude: Double, longitude: Double)], properties: [String: String]) -> String {
        var ring = corners.map { [$0.longitude, $0.latitude] }
        if let first = ring.first, first != ring.last { ring.append(first) }
        var featureProperties = properties
        featureProperties["Source"] = "CICC"
        let object: [String: Any] = [
            "type": "FeatureCollection",
            "features": [[
                "type": "Feature",
                "properties": featureProperties,
                "geometry": ["type": "Polygon", "coordinates": [ring]],
            ]],
        ]
        let data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }

    /// "Coordonnées " -> "coordonnees": keys are matched without accents, case or spaces.
    private static func normalise(_ key: String) -> String {
        key.trimmingCharacters(in: .whitespaces)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
    }
}
