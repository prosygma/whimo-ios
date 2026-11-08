//
//  ScanQRViewModel.swift
//  Whimo
//
//  Created by Vyacheslav Razumeenko on 07.05.2025.
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
import Combine
import AudioToolbox
import struct CoreLocation.CLLocationCoordinate2D
import Utility
import Resources

private struct CiccQrError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private typealias Module = ScanQRModule
private typealias ViewModel = Module.ViewModel

// MARK: - ViewModel
extension Module {
    final class ViewModel: ViewModelProtocol {
        // MARK: - Public Properties
        @Published var payload: String = ""

        // MARK: - Private Properties
        private var cancellable: CancelBag = .init()
        private let cicc: Bool
        // MARK: - Dependencies
        @Inject(\.appState) private var appState
        @Inject(\.qrCodeDataService) private var qrCodeDataService

        // MARK: - Init
        init(cicc: Bool = false) {
            self.cicc = cicc
            setupBinding()
        }

        // MARK: - ViewModelProtocol
    }
}

// MARK: - Private Methods
private extension ViewModel {
    // MARK: - Setup
    func setupBinding() {
        $payload
            .dropFirst()
            .handleEvents(receiveOutput: { code in log.debug("\n\(code)") })
            .sink { [weak self] code in
                guard let self else { return }

                do {
                    let geoJSON = try self.cicc ? Self.ciccGeoJSON(from: code) : code
                    let farmData = try self.qrCodeDataService.saveGroundFarmInfo(from: geoJSON)
                    self.saveData(farmData.coordinates, selectedFile: farmData.selectedFile)
                } catch {
                    appState.showError(message: error.localizedDescription)
                }
            }
            .store(in: cancellable)
    }

    /// CamerTrace: a CICC plot card becomes a GeoJSON polygon marked `"Source": "CICC"`, then follows
    /// the generic QR path. The backend recognises the mark and applies the CICC traceability rule.
    static func ciccGeoJSON(from code: String) throws -> String {
        switch CiccQrParser.parse(code) {
            case .success(let plot):
                return plot.geoJSON
            case .failure(.missing(let keys)):
                if keys.contains(CiccQrParser.coordinates) {
                    throw CiccQrError(message: AppLocale.ScanQR.Cicc.Error.coordinates)
                }
                throw CiccQrError(message: AppLocale.ScanQR.Cicc.Error.fields(keys.joined(separator: ", ")))
        }
    }

    // MARK: - Common
    func saveData(_ coordinates: CLLocationCoordinate2D, selectedFile: FileObject?) {
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        guard let selectedFile else { return }

        appState.createTransaction[\.farmLocation] = .qrCode(file: selectedFile, coordinates: coordinates)
        appState.navigation[\.path].removeLast(2)
    }
}
