import Foundation

protocol SyncCoverageRepository: AnyObject {
    var coveredFrom: Date? { get }
    var coveredThrough: Date? { get }
    var coverageCheckedAt: Date? { get }

    func recordCoverage(from: Date, through: Date, at now: Date)
}
