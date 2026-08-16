import Foundation

nonisolated struct Acknowledgement: Identifiable, Hashable {
    let name: String
    let copyright: String
    let licenseName: String
    let repositoryURL: URL?
    let licenseText: String

    var id: String { name }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension Acknowledgement {
    static let bundled: [Acknowledgement] = [
        Acknowledgement(
            name: "Swift Collections",
            copyright: "Copyright (c) 2021 Apple Inc. and the Swift project authors",
            licenseName: "Apache License 2.0 with Runtime Library Exception",
            repositoryURL: URL(string: "https://github.com/apple/swift-collections"),
            licenseText: LicenseText.apache2WithRuntimeException
        ),
        Acknowledgement(
            name: "Swift Identified Collections",
            copyright: "Copyright (c) 2021 Point-Free, Inc.",
            licenseName: "MIT License",
            repositoryURL: URL(string: "https://github.com/pointfreeco/swift-identified-collections"),
            licenseText: LicenseText.mit
        ),
    ]
}
