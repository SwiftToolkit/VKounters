import CloudAWS

@main
struct Infra: AWSProject {
    func build() async throws -> Outputs {
        let vpc = AWS.VPC("VKounters-vpc")

        let lambda = AWS.Function(
            "VKounters",
            targetName: "VKounters",
            url: .enabled(),
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
