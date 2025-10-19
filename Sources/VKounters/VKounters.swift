import AWSLambdaEvents
import AWSLambdaRuntime
import CloudSDK
import Foundation
import ServiceLifecycle
import Valkey

@main
struct VKounters {
    let valkey: ValkeyClient

    static func main() async throws {
#if DEBUG
        try await runLocal()
#else
        try await runLambda()
#endif
    }

    static func runLocal() async throws {
        let valkeyClient = ValkeyClient(
            .hostname("localhost"),
            configuration: .init(tls: .disable),
            logger: .init(label: "ValkeyClient")
        )
        async let _ = valkeyClient.run()

        try await valkeyClient.set(
            "pokemon",
            value: ["Pikachu", "Charmander", "Bulbasaur"].randomElement()!
        )

        if let pokemon = try await valkeyClient.get("pokemon") {
            print("Pokemon is now \(String(buffer: pokemon))")
        }

        let count = try await valkeyClient.incr("likes")
        print("Likes counter is now \(count)")
    }

    static func runLambda() async throws {
        let valkeyClient = try ValkeyClient(
            .hostname(Cloud.Resource.VkountersValkey.hostname),
            configuration: .init(
                tls: .enable(.clientDefault, tlsServerName: Cloud.Resource.VkountersValkey.hostname),
            ),
            logger: .init(label: "ValkeyClient")
        )

        let vKounters = VKounters(valkey: valkeyClient)

        let lambdaRuntime = LambdaRuntime(lambdaHandler: vKounters)

        let services: [Service] = [valkeyClient, lambdaRuntime]
        let serviceGroup = ServiceGroup(
            services: services,
            gracefulShutdownSignals: [.sigint],
            cancellationSignals: [.sigterm],
            logger: .init(label: "ServiceGroup")
        )
        try await serviceGroup.run()
    }

    private func incrementCounter() async throws -> Int {
        try await valkey.incr("counter")
    }

    private func addStats(_ stats: StatsRequest, context: LambdaContext) async throws -> StatsResponse {
        let (totalCount, _, _) = await valkey.execute(
            INCR("stats:total"),
            INCR(ValkeyKey("stats:os:\(stats.os)")),
            INCR(ValkeyKey("stats:browser:\(stats.browser)"))
        )

        async let osDistribution = try await getValues(matching: "stats:os")
        async let browserDistribution = try await getValues(matching: "stats:browser")

        return try await StatsResponse(
            totalCount: (try? totalCount.get()) ?? 0,
            browserDistribution: browserDistribution,
            osDistribution: osDistribution
        )
    }

    private func getValues(matching pattern: String) async throws -> [String: Int] {
        let scan = try await valkey.scan(cursor: 0, pattern: "\(pattern):*")
        let keys = try scan.keys.decode(as: [ValkeyKey].self)

        guard !keys.isEmpty else {
            return [:]
        }

        let values = try await valkey.withConnection { connection in
            await connection.execute(keys.map { GET($0) })
        }

        var result: [String: Int] = [:]
        for (index, key) in keys.enumerated() {
            guard let value = try? values[index].get().decode(as: Int.self) else { continue }

            let valueWithoutPrefix = String(valkeyKey: key).dropFirst("\(pattern):".count)
            result[String(valueWithoutPrefix)] = value
        }

        return result
    }

    private func reset(context: LambdaContext) async throws {
        try await valkey.flushdb()
    }
}

extension VKounters: LambdaHandler {
    typealias Event = FunctionURLRequest
    typealias Output = FunctionURLResponse

    func handle(
        _ event: Event,
        context: LambdaContext
    ) async throws -> Output {
        let requestPath = event.requestContext.http.path
        let method = event.requestContext.http.method

        guard let path = Path(path: requestPath),
              path.method == method.rawValue else {
            return .init(
                statusCode: .notFound,
                body: "\(method.rawValue) \(requestPath) Not found"
            )
        }

        switch path {
        case .reset:
            guard let authHeader = event.headers.first(name: "x-auth-header"),
                  authHeader == ProcessInfo.processInfo.environment["AUTH_HEADER"] else {
                return .init(statusCode: .unauthorized, body: "Unauthorized")
            }

            try await reset(context: context)
            return .init(statusCode: .ok)
        case .counter:
            let count = try await incrementCounter()
            return .encoding(CounterResponse(count: count))
        case .stats:
            do {
                let stats = try event.decodeBody(StatsRequest.self)
                let response = try await addStats(stats, context: context)
                return .encoding(response)
            } catch let error as DecodingError {
                return .init(statusCode: .badRequest, body: String(describing: error))
            } catch {
                return .init(statusCode: .internalServerError, body: String(describing: error))
            }
        }
    }
}

struct CounterResponse: Encodable {
    let count: Int
}

struct StatsRequest: Decodable {
    let browser: String
    let os: String
}

struct StatsResponse: Encodable {
    let totalCount: Int
    let browserDistribution: [String: Int]
    let osDistribution: [String: Int]
}

extension RESPToken {
    var stringValue: String? {
        switch value {
        case let .simpleString(byteBuffer),
             let .bulkString(byteBuffer):
            String(buffer: byteBuffer)
        default:
            nil
        }
    }

    var stringArrayValue: [String]? {
        switch value {
        case let .array(array):
            array.compactMap { $0.stringValue }
        default:
            nil
        }
    }
}
