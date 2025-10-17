import CloudAWS

@main
struct Infra: AWSProject {
    func build() async throws -> Outputs {
        let vpc = AWS.VPC("VKounters-vpc")

        let authHeader = Random.Bytes("function-api-header", length: 16)
        let environment = ["AUTH_HEADER": authHeader.hex]

        let lambda = AWS.Function(
            "VKounters",
            targetName: "VKounters",
            url: .enabled(),
            environment: environment,
            vpc: .public(vpc)
        )

        let cache = AWS.Cache(
            "VKounters-valkey",
            engine: .valkey(), // .valkey is the default
            vpc: .private(vpc)
        )

        lambda.link(cache)

        return [
            "Function URL": lambda.url
        ]
    }
}
