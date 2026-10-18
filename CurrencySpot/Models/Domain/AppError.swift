import Foundation

nonisolated enum AppError: Error, Identifiable, Equatable {
    case networkError(String)
    case requestFailed(RequestFailure)
    case noInternetConnection
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

    nonisolated enum RequestFailure: Sendable {
        case timedOut
        case cannotFindHost
        case cannotConnectToHost
        case connectionLost
        case dnsLookupFailed
        case tooManyRedirects
        case resourceUnavailable
        case badServerResponse

        fileprivate var message: LocalizedStringResource {
            switch self {
            case .timedOut: .errorRequestTimedOutMessage
            case .cannotFindHost: .errorRequestCannotFindHostMessage
            case .cannotConnectToHost: .errorRequestCannotConnectToHostMessage
            case .connectionLost: .errorRequestConnectionLostMessage
            case .dnsLookupFailed: .errorRequestDnsLookupFailedMessage
            case .tooManyRedirects: .errorRequestTooManyRedirectsMessage
            case .resourceUnavailable: .errorRequestResourceUnavailableMessage
            case .badServerResponse: .errorRequestBadServerResponseMessage
            }
        }
    }

    var id: String {
        let prefix = errorPrefix
        let suffix = errorSuffix
        return "\(prefix)-\(suffix)"
    }

    private var errorPrefix: String {
        switch self {
        case .networkError: "network"
        case .requestFailed: "requestFailed"
        case .noInternetConnection: "noInternet"
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
        case let .requestFailed(failure):
            "\(failure)"
        case let .retryExhausted(message, attempts):
            "\(message)-\(attempts)"
        case let .httpError(statusCode):
            "\(statusCode)"
        case .noInternetConnection, .cameraCaptureFailed, .photoImportFailed,
             .textRecognitionFailed:
            "static"
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .networkError, .requestFailed: .errorNetworkTitle
        case .noInternetConnection: .errorNoInternetTitle
        case .decodingError: .errorDecodingTitle
        case .httpError: .errorHttpTitle
        case .dateCalculationError: .errorDateCalculationTitle
        case .unknownError: .errorUnexpectedTitle
        case .dataValidationError: .errorDataValidationTitle
        case .initializationFailed: .errorStorageTitle
        case .retryExhausted: .errorRetryExhaustedTitle
        case .cameraCaptureFailed: .errorCameraCaptureTitle
        case .photoImportFailed: .errorPhotoImportTitle
        case .textRecognitionFailed: .errorTextRecognitionTitle
        }
    }

    var message: LocalizedStringResource {
        switch self {
        case .networkError: .errorNetworkMessage
        case let .requestFailed(failure): failure.message
        case .noInternetConnection: .errorNoInternetMessage
        case .decodingError: .errorDecodingMessage
        case .httpError: .errorHttpMessage
        case .dateCalculationError: .errorDateCalculationMessage
        case .unknownError: .errorUnexpectedMessage
        case .dataValidationError: .errorDataValidationMessage
        case .initializationFailed: .errorStorageMessage
        case let .retryExhausted(_, attempts): .errorRetryExhaustedMessage(attempts: attempts)
        case .cameraCaptureFailed: .errorCameraCaptureMessage
        case .photoImportFailed: .errorPhotoImportMessage
        case .textRecognitionFailed: .errorTextRecognitionMessage
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
        case .cancelled: nil
        case .notConnectedToInternet: .noInternetConnection
        case .timedOut: .requestFailed(.timedOut)
        case .cannotFindHost: .requestFailed(.cannotFindHost)
        case .cannotConnectToHost: .requestFailed(.cannotConnectToHost)
        case .networkConnectionLost: .requestFailed(.connectionLost)
        case .dnsLookupFailed: .requestFailed(.dnsLookupFailed)
        case .httpTooManyRedirects: .requestFailed(.tooManyRedirects)
        case .resourceUnavailable: .requestFailed(.resourceUnavailable)
        case .badServerResponse: .requestFailed(.badServerResponse)
        default: .networkError("URLError \(urlError.code.rawValue)")
        }
    }
}
