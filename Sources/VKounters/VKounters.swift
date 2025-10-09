import AWSLambdaEvents
import AWSLambdaRuntime
import CloudSDK
import Valkey
import ServiceLifecycle

@main
struct VKounters: LambdaHandler {
    typealias Event = FunctionURLRequest
    typealias Output = FunctionURLResponse

    let valkey: ValkeyClient

    static func main() async throws {
        let valkeyClient = try ValkeyClient(
            .hostname(Cloud.Resource.VkountersValkey.hostname),
            configuration: .init(
                tls: .enable(.clientDefault, tlsServerName: Cloud.Resource.VkountersValkey.hostname),
            ),
            logger: .init(label: "ValkeyClient")
        )

        let lambdaHandler = VKounters(valkey: valkeyClient)

        // https://github.com/swift-server/swift-aws-lambda-runtime/pull/581
//        let lambdaRuntime = LambdaRuntime(lambdaHandler: lambdaHandler)
        let lambdaRuntime = LambdaRuntime { (event: Event, context: LambdaContext) in
            try await lambdaHandler.handle(event, context: context)
        }

        let services: [Service] = [valkeyClient, lambdaRuntime]
        let serviceGroup = ServiceGroup(
            services: services,
            gracefulShutdownSignals: [.sigint],
            cancellationSignals: [.sigterm],
            logger: .init(label: "ServiceGroup")
        )
        try await serviceGroup.run()
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

        let (clicks, os, browser) = try await valkey.withConnection { connection in
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


