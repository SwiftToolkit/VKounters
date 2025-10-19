import Foundation
import AWSLambdaEvents

enum Path: String {
    case reset
    case counter
    case stats
    case getCounter
    case getStats
}

extension Path {
    init?(path: String) {
        var path = path
        if path.first == "/" {
            _ = path.removeFirst()
        }

        self.init(rawValue: path)
    }

    var method: String {
        switch self {
        case .reset,
             .counter,
             .getCounter,
             .getStats:
            "GET"
        case .stats:
            "POST"
        }
    }
}
