//
//  ErrorViewModel.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 4/23/25.
//

// AppError.swift
import Foundation

enum AppError: Error, Identifiable, Equatable {
    case networkError(String)
    case noInternetConnection
    case noCachedData
    case encodingError(String)
    case decodingError(String)
    case apiError(String)
    case dateCalculationError(String)
    case noDataError
    case unknownError(String)
    // SwiftData-specific errors
    case dataValidationError(String)
    case storageError(String)
    case dataCorrupted(String)
    case initializationFailed(String)
    // Retry-specific errors
    case retryExhausted(String, attempts: Int)
    case retryInProgress(attempt: Int, maxAttempts: Int)

    var id: String {
        let prefix = errorPrefix
        let suffix = errorSuffix
        return "\(prefix)-\(suffix)"
    }

    private var errorPrefix: String {
        switch self {
        case .networkError: "network"
        case .noInternetConnection: "noInternet"
        case .noCachedData: "noCache"
        case .encodingError: "encoding"
        case .decodingError: "decoding"
        case .apiError: "api"
        case .dateCalculationError: "dateCalculation"
        case .noDataError: "noData"
        case .unknownError: "unknown"
        case .dataValidationError: "dataValidation"
        case .storageError: "storage"
        case .dataCorrupted: "dataCorrupted"
        case .initializationFailed: "initializationFailed"
        case .retryExhausted: "retryExhausted"
        case .retryInProgress: "retryInProgress"
        }
    }

    private var errorSuffix: String {
        switch self {
        case let .networkError(message),
             let .encodingError(message),
             let .decodingError(message),
             let .apiError(message),
             let .dateCalculationError(message),
             let .unknownError(message),
             let .dataValidationError(message),
             let .storageError(message),
             let .dataCorrupted(message),
             let .initializationFailed(message):
            message
        case let .retryExhausted(message, attempts):
            "\(message)-\(attempts)"
        case let .retryInProgress(attempt, maxAttempts):
            "\(attempt)-\(maxAttempts)"
        case .noInternetConnection, .noCachedData, .noDataError:
            "static"
        }
    }

    var title: String {
        switch self {
        case .networkError: "Network Error"
        case .noInternetConnection: "No Internet Connection"
        case .noCachedData: "No Cached Data"
        case .encodingError: "Data Error"
        case .decodingError: "Data Error"
        case .apiError: "API Error"
        case .dateCalculationError: "Date Processing Error"
        case .noDataError: "No Data"
        case .unknownError: "Error"
        case .dataValidationError: "Data Validation Error"
        case .storageError: "Storage Error"
        case .dataCorrupted: "Data Corrupted"
        case .initializationFailed: "Initialization Failed"
        case .retryExhausted: "Connection Failed"
        case .retryInProgress: "Connecting..."
        }
    }

    var message: String {
        switch self {
        case let .networkError(message):
            "\(message). Please check your internet connection."
        case .noInternetConnection:
            "Unable to connect to the internet. Please check your connection."
        case .noCachedData:
            "No exchange rate data available. Connect to the internet to get the latest rates."
        case let .encodingError(message):
            "Error encoding data: \(message)"
        case let .decodingError(message):
            "Error decoding data: \(message)"
        case let .apiError(message):
            "\(message)"
        case let .dateCalculationError(message):
            "Error calculating date range for historical data: \(message)"
        case .noDataError:
            "No data received from the server."
        case let .unknownError(message):
            "An unexpected error occurred: \(message)"
        case let .dataValidationError(message):
            "Data validation failed: \(message). Please try again."
        case let .storageError(message):
            "Storage error: \(message). Please check available storage space."
        case let .dataCorrupted(message):
            "Data corruption detected: \(message). The app will attempt to recover."
        case let .initializationFailed(message):
            "Storage unavailable: \(message). The app works normally but data will not be saved after closing."
        case let .retryExhausted(message, attempts):
            "Failed to connect after \(attempts) attempts. \(message). Tap refresh to try again."
        case let .retryInProgress(attempt, maxAttempts):
            "Attempting to connect... (\(attempt) of \(maxAttempts))"
        }
    }

    static func == (lhs: AppError, rhs: AppError) -> Bool {
        lhs.id == rhs.id
    }

    static func from(_ error: Error) -> AppError? {
        if let appError = error as? AppError {
            return appError
        }

        // Handle cancellation errors - don't show these to users
        if error is CancellationError {
            return nil
        }

        // Handle Swift-native error types first
        switch error {
        case let decodingError as DecodingError:
            return .decodingError(decodingError.localizedDescription)
        case let urlError as URLError:
            if urlError.code == .cancelled {
                return nil // Don't show cancelled network requests
            } else if urlError.code == .notConnectedToInternet {
                return .noInternetConnection
            } else {
                // Handle specific URLError cases with better messages
                switch urlError.code {
                case .timedOut:
                    return .networkError("Request timed out. Please try again.")
                case .cannotFindHost:
                    return .networkError("Cannot find server. Please check your internet connection.")
                case .cannotConnectToHost:
                    return .networkError("Cannot connect to server. Please try again later.")
                case .networkConnectionLost:
                    return .networkError("Network connection lost. Please check your connection.")
                case .dnsLookupFailed:
                    return .networkError("DNS lookup failed. Please check your internet connection.")
                case .httpTooManyRedirects:
                    return .networkError("Too many redirects. Please try again later.")
                case .resourceUnavailable:
                    return .networkError("Resource unavailable. Please try again later.")
                case .badServerResponse:
                    return .networkError("Invalid server response. Please try again.")
                default:
                    return .networkError("Network error: \(urlError.code.rawValue)")
                }
            }
        default:
            // Legacy error handling for compatibility
            let nsError = error as NSError

            // Check for specific error domains
            if nsError.domain == "com.example.CurrencySpot" {
                if nsError.localizedDescription.contains("No cached rates") {
                    return .noCachedData
                }
            }

            if nsError.domain == "No Data" {
                return .noDataError
            }

            if nsError.domain == "Date calculation error" {
                return .dateCalculationError(nsError.localizedDescription)
            }

            return .unknownError(nsError.localizedDescription)
        }
    }
}
