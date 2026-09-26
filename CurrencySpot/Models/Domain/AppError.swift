import Foundation

nonisolated enum AppError: Error, Identifiable, Equatable {
    case networkError(String)
    case noInternetConnection
    case noCachedData
    case decodingError(String)
    case httpError(statusCode: Int)
    case dateCalculationError(String)
    case unknownError(String)
    case dataValidationError(String)
    case initializationFailed(String)
    case retryExhausted(String, attempts: Int)
    case cameraCaptureFailed
    case photoImportFailed
    case textRecognitionFailed

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
        case .decodingError: "decoding"
        case .httpError: "http"
        case .dateCalculationError: "dateCalculation"
        case .unknownError: "unknown"
        case .dataValidationError: "dataValidation"
        case .initializationFailed: "initializationFailed"
        case .retryExhausted: "retryExhausted"
        case .cameraCaptureFailed: "cameraCapture"
        case .photoImportFailed: "photoImport"
        case .textRecognitionFailed: "textRecognition"
        }
    }

    private var errorSuffix: String {
        switch self {
        case let .networkError(message),
             let .decodingError(message),
             let .dateCalculationError(message),
             let .unknownError(message),
             let .dataValidationError(message),
             let .initializationFailed(message):
            message
        case let .retryExhausted(message, attempts):
            "\(message)-\(attempts)"
        case let .httpError(statusCode):
            "\(statusCode)"
        case .noInternetConnection, .noCachedData, .cameraCaptureFailed, .photoImportFailed,
             .textRecognitionFailed:
            "static"
        }
    }

    var title: String {
        switch self {
        case .networkError: "Network Error"
        case .noInternetConnection: "No Internet Connection"
        case .noCachedData: "No Cached Data"
        case .decodingError: "Data Error"
        case .httpError: "API Error"
        case .dateCalculationError: "Date Processing Error"
        case .unknownError: "Error"
        case .dataValidationError: "Data Validation Error"
        case .initializationFailed: "Initialization Failed"
        case .retryExhausted: "Connection Failed"
        case .cameraCaptureFailed: "Capture Failed"
        case .photoImportFailed: "Photo Import Failed"
        case .textRecognitionFailed: "Scan Failed"
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
        case let .decodingError(message):
            "Error decoding data: \(message)"
        case let .httpError(statusCode):
            "HTTP Error: \(statusCode)"
        case let .dateCalculationError(message):
            "Error calculating date range for historical data: \(message)"
        case let .unknownError(message):
            "An unexpected error occurred: \(message)"
        case let .dataValidationError(message):
            "Data validation failed: \(message). Please try again."
        case let .initializationFailed(message):
            "Storage unavailable: \(message). The app works normally but data will not be saved after closing."
        case let .retryExhausted(message, attempts):
            "Failed to connect after \(attempts) attempts. \(message). Tap refresh to try again."
        case .cameraCaptureFailed:
            "Couldn't capture the frame. Please try again."
        case .photoImportFailed:
            "Couldn't load that photo. Please try again."
        case .textRecognitionFailed:
            "Couldn't read text in this image. Please try again."
        }
    }

    static func == (lhs: AppError, rhs: AppError) -> Bool {
        lhs.id == rhs.id
    }

    static func from(_ error: Error) -> AppError? {
        if let appError = error as? AppError {
            return appError
        }

        if error is CancellationError {
            return nil
        }

        switch error {
        case let decodingError as DecodingError:
            return .decodingError(decodingError.localizedDescription)
        case let urlError as URLError:
            return from(urlError: urlError)
        default:
            return .unknownError((error as NSError).localizedDescription)
        }
    }

    private static func from(urlError: URLError) -> AppError? {
        switch urlError.code {
        case .cancelled:
            return nil
        case .notConnectedToInternet:
            return .noInternetConnection
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
}
