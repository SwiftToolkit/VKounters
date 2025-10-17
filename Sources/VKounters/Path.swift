import Foundation
import AWSLambdaEvents

enum Path: String {
    case reset
    case counter
    case stats
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
        case .reset, .counter:
            "GET"
        case .stats:
            "POST"
        }
    }
}
