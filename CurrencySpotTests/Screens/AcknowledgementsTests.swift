//
//  AcknowledgementsTests.swift
//  CurrencySpotTests
//

@testable import CurrencySpot
import Foundation
import Testing

@Suite("Acknowledgements")
struct AcknowledgementsTests {
    @Test("lists every resolved third-party dependency")
    func listsBundledDependencies() {
        let names = Acknowledgement.bundled.map(\.name)
        #expect(names.contains("Swift Collections"))
        #expect(names.contains("Swift Identified Collections"))
    }

    @Test("every acknowledgement carries copyright, license name, and text")
    func metadataPresent() {
        for acknowledgement in Acknowledgement.bundled {
            #expect(!acknowledgement.copyright.isEmpty)
            #expect(!acknowledgement.licenseName.isEmpty)
            #expect(!acknowledgement.licenseText.isEmpty)
        }
    }

    @Test("MIT notice carries the copyright and permission notice the license requires")
    func mitNoticeComplete() throws {
        let mit = try #require(Acknowledgement.bundled.first { $0.name == "Swift Identified Collections" })
        #expect(mit.licenseText.contains("Copyright (c) 2021 Point-Free, Inc."))
        #expect(mit.licenseText.contains("The above copyright notice and this permission notice shall be included"))
    }

    @Test("Apache license retains the Runtime Library Exception clause")
    func apacheRuntimeException() throws {
        let collections = try #require(Acknowledgement.bundled.first { $0.name == "Swift Collections" })
        #expect(collections.licenseText.contains("Apache License"))
        #expect(collections.licenseText.contains("Runtime Library Exception"))
    }

    @Test("identity is keyed on name, ignoring the embedded license text")
    func identityIsNameBased() {
        let original = Acknowledgement.bundled[0]
        let sameNameDifferentText = Acknowledgement(
            name: original.name,
            copyright: original.copyright,
            licenseName: original.licenseName,
            repositoryURL: original.repositoryURL,
            licenseText: "different"
        )
        #expect(original == sameNameDifferentText)
        #expect(original.hashValue == sameNameDifferentText.hashValue)
    }
}
