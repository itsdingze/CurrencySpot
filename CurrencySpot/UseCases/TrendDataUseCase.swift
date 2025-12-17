//
//  TrendDataUseCase.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 7/30/25.
//

import Foundation

// MARK: - TrendDataUseCase

/// Use case responsible for trend data management
/// Extracted from HistoryViewModel to separate concerns
final class TrendDataUseCase {
    // MARK: - Dependencies

    private let service: ExchangeRateService

    // MARK: - Initialization

    init(service: ExchangeRateService) {
        self.service = service
    }

    // MARK: - Trend Data Management

    /// Initializes trend data by checking cache and fetching if needed
    func initializeTrendData() async -> [TrendDataValue] {
        do {
            // Check if we have existing trend data
            let existingTrends = try await service.loadTrendData()

            if existingTrends.isEmpty {
                // Check if we have sufficient historical data for trend calculation
                let hasSufficientData = try await service.hasSufficientHistoricalDataForTrends()

                if !hasSufficientData {
                    // Only fetch historical data if we don't have enough
                    let calendar = TimeZoneManager.cetCalendar
                    let endDate = Date()
                    let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate

                    // Fetch and save historical data (for graphs and trend calculation)
                    try await service.fetchAndSaveHistoricalRates(from: startDate, to: endDate)
                }

                // Calculate and save trend data
                try await service.calculateAndSaveTrendData()

                // Load the calculated trends into memory
                return try await service.loadTrendData()
            } else {
                // Use existing trends
                return existingTrends
            }
        } catch {
            // Trend calculation failed, but app continues working
            if let appError = AppError.from(error) {
                await AppState.shared.errorHandler.handle(appError)
            }

            return []
        }
    }

    /// Gets trend data for a specific currency
    func getTrendData(for currencyCode: String, from trendData: [TrendDataValue]) -> TrendDataValue? {
        trendData.first { $0.currencyCode == currencyCode }
    }

    /// Checks if any of the missing ranges affect trend calculation and recalculates trends if needed
    func checkAndRecalculateTrendsIfNeeded(for missingRanges: [DateRange]) async -> [TrendDataValue] {
        do {
            var shouldRecalculateTrends = false

            // Check each missing range to see if it affects trends
            for range in missingRanges {
                let affectsTrends = try await service.doesDateRangeAffectTrends(
                    startDate: range.start,
                    endDate: range.end
                )

                if affectsTrends {
                    shouldRecalculateTrends = true
                    AppLogger.info("New data in range \(TimeZoneManager.formatForAPI(range.start)) to \(TimeZoneManager.formatForAPI(range.end)) affects trends", category: .useCase)
                    break
                }
            }

            if shouldRecalculateTrends {
                AppLogger.info("Recalculating trend data due to new latest data...", category: .useCase)
                try await service.calculateAndSaveTrendData()
                let updatedTrends = try await service.loadTrendData()
                AppLogger.info("Trend data updated with \(updatedTrends.count) currencies", category: .useCase)
                return updatedTrends
            } else {
                // Return existing trends if no recalculation needed
                return try await service.loadTrendData()
            }
        } catch {
            AppLogger.warning("Failed to check/recalculate trends: \(error.localizedDescription)", category: .useCase)
            // Continue without failing the main flow
            return []
        }
    }
}
