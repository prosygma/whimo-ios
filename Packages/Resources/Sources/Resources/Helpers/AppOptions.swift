//
//  AppOptions.swift
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

/// Geodata choices set in the admin panel (Settings > Options), downloaded at start and kept
/// in UserDefaults. Before the first download the defaults keep today's behaviour.
public final class AppOptions: @unchecked Sendable {
    public struct Values: Codable, Equatable, Sendable {
        /// Ask "Are you on the plot?" when buying from a farmer.
        public var askOnPlot: Bool
        /// Offer "Add a GPS point" (pick on a map).
        public var allowGpsPoint: Bool
        /// Offer "Scan the CICC QR code".
        public var allowCiccQr: Bool

        public init(askOnPlot: Bool = true, allowGpsPoint: Bool = true, allowCiccQr: Bool = false) {
            self.askOnPlot = askOnPlot
            self.allowGpsPoint = allowGpsPoint
            self.allowCiccQr = allowCiccQr
        }

        enum CodingKeys: String, CodingKey {
            case askOnPlot = "ask_on_plot"
            case allowGpsPoint = "allow_gps_point"
            case allowCiccQr = "allow_cicc_qr"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let defaults = Values()
            askOnPlot = try container.decodeIfPresent(Bool.self, forKey: .askOnPlot) ?? defaults.askOnPlot
            allowGpsPoint = try container.decodeIfPresent(Bool.self, forKey: .allowGpsPoint) ?? defaults.allowGpsPoint
            allowCiccQr = try container.decodeIfPresent(Bool.self, forKey: .allowCiccQr) ?? defaults.allowCiccQr
        }
    }

    public static let shared: AppOptions = .init()

    private static let storageKey = "app_options"
    private let lock: NSLock = .init()
    private let defaults: UserDefaults
    private var cached: Values

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let values = try? JSONDecoder().decode(Values.self, from: data) {
            cached = values
        } else {
            cached = Values()
        }
    }

    public var values: Values {
        lock.lock()
        defer { lock.unlock() }
        return cached
    }

    func update(_ values: Values) {
        lock.lock()
        cached = values
        lock.unlock()
        if let data = try? JSONEncoder().encode(values) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    /// Downloads the options. Offline or on error, keeps the last ones.
    /// - Parameter baseURL: the API base, ending with /api/v1.
    public func refresh(baseURL: URL, session: URLSession = .shared) async {
        let url = baseURL.appendingPathComponent("app-options/")
        do {
            let (data, response) = try await session.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }
            update(try JSONDecoder().decode(Response.self, from: data).data)
        } catch {
            return
        }
    }

    struct Response: Decodable {
        let data: Values
    }
}
