import AWSLambdaEvents
import AWSLambdaRuntime
import CloudSDK
import Valkey

@main
struct VKounters: LambdaHandler {
    typealias Event = FunctionURLRequest
    typealias Output = FunctionURLResponse

//    @MainActor static var client: ValkeyClient?

    static let instance = VKounters()

    static func main() async throws {
        let lambdaRuntime = LambdaRuntime { event, context in
            try await instance.handle(event, context: context)
        }

        try await lambdaRuntime.run()
    }

    func handle(
        _ event: Event,
        context: LambdaContext
    ) async throws -> Output {
        context.logger.info("\(event.requestContext.http.method.rawValue) at \(event.requestContext.http.path)")

        let request: Request

        do {
            request = try event.decodeBody(Request.self)
        } catch {
            return .init(statusCode: .badRequest, body: String(describing: error))
        }

//        let client = try await createClientIfNeeded(context: context)

        let (clicks, os, browser) = try await ValkeyConnection.withConnection(
            address: .hostname(Cloud.Resource.VkountersValkey.hostname),
            configuration: .init(tls: ValkeyConnectionConfiguration.TLS.enable(.init(configuration: .clientDefault), tlsServerName: nil)),
            logger: context.logger
        ) { connection in
            context.logger.info("Connected!")
            return await connection.execute(
                INCR("clicks"),
                INCR(ValkeyKey("clicks:os:\(request.os)")),
                INCR(ValkeyKey("clicks:browser:\(request.browser)"))
            )
        }

        context.logger.info("Got connection commands results")

        return .encoding(Response(
            totalCount: (try? clicks.get()) ?? 0,
            browserDistribution: [:],
            osDistribution: [:]
        ))
    }

//    @MainActor
//    private func createClientIfNeeded(context: LambdaContext) throws -> ValkeyClient {
//        if let client = Self.client {
//            return client
//        }
//
//        let client = try ValkeyClient(
//            .hostname(Cloud.Resource.VkountersValkey.hostname),
//            configuration: .init(
//                tls: .enable(.clientDefault, tlsServerName: Cloud.Resource.VkountersValkey.hostname),
//            ),
//            logger: context.logger
//        )
//        Self.client = client
//        return client
//    }
}

struct Request: Decodable {
    let browser: String
    let os: String
}

struct Response: Encodable {
    let totalCount: Int
    let browserDistribution: [String: Int]
    let osDistribution: [String: Int]
}
