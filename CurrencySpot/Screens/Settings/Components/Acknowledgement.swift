//
//  Acknowledgement.swift
//  CurrencySpot
//

import Foundation

/// A third-party package bundled into the app and the license it ships under.
///
/// `nonisolated` with identity-based `Hashable` so it can drive value-based
/// navigation the same way `SettingsRoute` does — SwiftUI matches destinations
/// off the MainActor, and keying equality on `id` keeps the embedded license
/// text out of every hash and compare.
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
    /// Dependencies resolved in `Package.resolved`, surfaced in
    /// Settings → Acknowledgements.
    ///
    /// Swift Collections ships under Apache 2.0 *with the Runtime Library
    /// Exception*, which waives the binary-redistribution attribution required
    /// by §4(a)/(b)/(d); it is listed anyway as good practice. Swift Identified
    /// Collections is MIT, whose copyright and permission notice must ship with
    /// every copy of the app and stay discoverable — which this screen provides.
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
