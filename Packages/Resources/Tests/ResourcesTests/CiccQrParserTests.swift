//
//  CiccQrParserTests.swift
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
import XCTest
@testable import Resources

final class CiccQrParserTests: XCTestCase {
    // Made-up values, laid out like a real CICC card.
    private let sample = """
    PROGRAMME D'IDENTIFICATION ET DE GEOLOCALISATION DES PARCELLES CACAOYERES

    NIPr_CICC :XX.AAA.BBB0001
    GLN_Parcelle :0000000000001
    Lien_GS1_Parcelle :https://example.org/414/0000000000001
    Coordonnées : 
    [4.1;12.1],[4.1005;12.1004],[4.101;12.1],[4.1012;12.1006],[4.1008;12.101],[4.1004;12.1012],[4.1;12.1008],[4.0998;12.1004],[4.0996;12.1002],[4.0997;12.1],[4.0998;12.0998],[4.0999;12.0999]
    """

    func testSampleCardBecomesClosedPolygonInLongitudeLatitudeOrder() throws {
        let plot = try CiccQrParser.parse(sample).get()

        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(plot.geoJSON.utf8)) as? [String: Any])
        let feature = try XCTUnwrap((json["features"] as? [[String: Any]])?.first)
        let geometry = try XCTUnwrap(feature["geometry"] as? [String: Any])
        let ring = try XCTUnwrap((geometry["coordinates"] as? [[[Double]]])?.first)
        let properties = try XCTUnwrap(feature["properties"] as? [String: String])

        XCTAssertEqual(geometry["type"] as? String, "Polygon")
        XCTAssertEqual(ring.count, 13)
        XCTAssertEqual(ring.first, [12.1, 4.1])
        XCTAssertEqual(ring.first, ring.last)
        XCTAssertEqual(plot.latitude, 4.1)
        XCTAssertEqual(plot.longitude, 12.1)
        XCTAssertEqual(properties["NIPr_CICC"], "XX.AAA.BBB0001")
        XCTAssertEqual(properties["GLN_Parcelle"], "0000000000001")
        XCTAssertEqual(properties["Lien_GS1_Parcelle"], "https://example.org/414/0000000000001")
        XCTAssertEqual(properties["Source"], "CICC")
    }

    func testKeysMatchWithoutAccentsOrCaseAndPointsMaySpanLines() throws {
        let text = """
        nipr_cicc : X
        GLN_PARCELLE: 1
        lien_gs1_parcelle :https://example.org/a:b
        COORDONNEES :
        [3.1;11.1],
        [3.2;11.2]
        [3.3;11.1]
        """

        let plot = try CiccQrParser.parse(text).get()

        XCTAssertEqual(plot.properties[CiccQrParser.gs1Link], "https://example.org/a:b")
        XCTAssertEqual(plot.properties[CiccQrParser.nipr], "X")
    }

    func testMissingCoordinatesAreRejected() {
        let text = sample.components(separatedBy: "Coordonn")[0]

        XCTAssertEqual(CiccQrParser.parse(text), .failure(.missing([CiccQrParser.coordinates])))
    }

    func testFewerThanThreeValidPointsAreRejected() {
        let text = sample.components(separatedBy: "Coordonn")[0] + "Coordonnées : [3.1;11.1],[95.0;11.2],[3.3;11.3]"

        XCTAssertEqual(CiccQrParser.parse(text), .failure(.missing([CiccQrParser.coordinates])))
    }

    func testEachMissingKeyIsReported() {
        let text = sample.components(separatedBy: "\n")
            .filter { !$0.hasPrefix("GLN_") && !$0.hasPrefix("Lien_") }
            .joined(separator: "\n")

        XCTAssertEqual(CiccQrParser.parse(text), .failure(.missing([CiccQrParser.gln, CiccQrParser.gs1Link])))
    }

    func testGeoJSONQrCodeIsNotACiccCode() {
        let result = CiccQrParser.parse(#"{"type":"Feature","geometry":{"type":"Point","coordinates":[1,2]}}"#)

        guard case .failure = result else { return XCTFail("a GeoJSON code must not pass") }
    }
}

final class AppOptionsTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "AppOptionsTests")
        defaults.removePersistentDomain(forName: "AppOptionsTests")
    }

    func testDefaultsBeforeFirstDownload() {
        XCTAssertEqual(AppOptions(defaults: defaults).values, .init(askOnPlot: true, allowGpsPoint: true, allowCiccQr: false))
    }

    func testDecodedValuesAreKept() throws {
        let json = #"{"success":true,"data":{"ask_on_plot":false,"allow_gps_point":false,"allow_cicc_qr":true}}"#
        let response = try JSONDecoder().decode(AppOptions.Response.self, from: Data(json.utf8))

        AppOptions(defaults: defaults).apply(response, language: "fr")

        XCTAssertEqual(AppOptions(defaults: defaults).values, .init(askOnPlot: false, allowGpsPoint: false, allowCiccQr: true))
    }

    func testMissingFieldsFallBackToDefaults() throws {
        let values = try JSONDecoder().decode(AppOptions.Values.self, from: Data(#"{"allow_cicc_qr":true}"#.utf8))

        XCTAssertEqual(values, .init(askOnPlot: true, allowGpsPoint: true, allowCiccQr: true))
    }

    func testTraceabilityDescriptionsAreKeptPerLanguage() throws {
        let json = #"{"data":{"ask_on_plot":true,"traceability_descriptions":{"full":"Obtenu avec : le scan du code QR du CICC.","partial":""}}}"#
        let response = try JSONDecoder().decode(AppOptions.Response.self, from: Data(json.utf8))

        AppOptions(defaults: defaults).apply(response, language: "FR")
        let options = AppOptions(defaults: defaults)

        XCTAssertEqual(options.traceabilityDescription(status: "full", language: "fr"), "Obtenu avec : le scan du code QR du CICC.")
        XCTAssertNil(options.traceabilityDescription(status: "full", language: "en"))
        XCTAssertNil(options.traceabilityDescription(status: "partial", language: "fr"))
        XCTAssertNil(options.traceabilityDescription(status: "incomplete", language: "fr"))
    }
}
