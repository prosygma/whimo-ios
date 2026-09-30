//
//  UserAgentService.swift
//  Whimo
//
//  Created by Vyacheslav Razumeenko on 08.05.2025.
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
import StorageKit
import struct Resources.LocalizeKeys
import class Resources.LanguageCatalog
import Utility

final class UserAgentService: UserAgentServiceProtocol {
    // MARK: - Private Properties
    private let bundle: Bundle = .main
    private let userDefaultsStore: AnyStorage<UserDefaultsStore>

    init(userDefaultsStore: AnyStorage<UserDefaultsStore>) {
        self.userDefaultsStore = userDefaultsStore
    }

    // MARK: - Public Properties
    var appName: String {
        getBundleProperty("CFBundleName") ?? ""
    }

    var appVersion: String {
        getBundleProperty("CFBundleShortVersionString") ?? ""
    }

    var appBuild: String {
        getBundleProperty("CFBundleVersion") ?? ""
    }

    var bundleIdentifier: String {
        getBundleProperty("CFBundleIdentifier") ?? ""
    }

    func configure() {
        detectLanguage()

        // Languages and strings are managed in the admin panel: refresh them, then make sure
        // the language in use is still offered.
        Task {
            let catalog: LanguageCatalog = .shared
            await catalog.refreshLanguages(baseURL: ApiConfiguration.baseUrl)
            detectLanguage()
            let language: LocalizeKeys? = userDefaultsStore.get(.currentLocalize)
            await catalog.refreshStrings(language: language?.code ?? LocalizeKeys.default.code, baseURL: ApiConfiguration.baseUrl)
        }
    }
}

// MARK: - Private Methods
private extension UserAgentService {
    func getBundleProperty(_ key: String) -> String? {
        guard
            let infoDictionary: [String: Any] = bundle.infoDictionary,
            let property: String = infoDictionary[key] as? String
        else { return nil }

        return property
    }

    /// The stored language if still offered, else the device's preferred one if offered
    /// (fr-FR matches fr), else the default language of the admin panel.
    func detectLanguage() {
        let stored: LocalizeKeys? = userDefaultsStore.get(.currentLocalize)
        log.debug("preferredLanguages: \(Locale.preferredLanguages)")
        let code = LanguageCatalog.shared.resolve(stored: stored?.code, preferred: Locale.preferredLanguages)
        guard code != stored?.code else { return }

        let language: LocalizeKeys = .init(rawValue: code)
        UserDefaults.standard.setValue(language.code, forKey: UserDefaultsStore.StoreKeys.currentLocalize.rawValue)
        userDefaultsStore.set(language, key: .currentLocalize)
    }
}
