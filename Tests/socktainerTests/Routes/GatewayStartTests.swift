import ContainerAPIClient
import ContainerResource
import ContainerizationOCI
import Foundation
import Testing
import Vapor
import VaporTesting

@testable import socktainer

/// SocktainerDNSServer registration is gated on the container's frozen gateway label.
@Suite("ContainerStartRoute — gateway label guard")
struct GatewayStartTests {

    @Test("a gateway (labeled) container registers nothing on start")
    func labeledContainerRegistersNothing() async throws {
        let nativeId = "web-labeled"
        let ip = "192.168.65.80"
        let network = "myapp_default"
        let snapshot = try makeContainerSnapshot(
            nativeId: nativeId, ip: ip, network: network,
            labels: [DNSResolutionMode.resolutionModeLabel: "container_name_only"],
            status: .stopped
        )
        let mock = StaticSnapshotClientMock(snapshot: snapshot)
        let dnsServer = SocktainerDNSServer()

        try await withApp(configure: { _ in }) { app in
            let regexRouter = app.regexRouter(with: app.logger)
            app.setRegexRouter(regexRouter)
            regexRouter.installMiddleware(on: app)
            app.storage[SocktainerDNSServerKey.self] = dnsServer
            app.storage[EventBroadcasterKey.self] = EventBroadcaster()
            try app.register(collection: ContainerStartRoute(client: mock))

            try await app.testing().test(.POST, "/v1.51/containers/\(nativeId)/start") { res async in
                #expect(res.status == .noContent)
            }
        }

        #expect(dnsServer.listEntries().isEmpty, "gateway containers never enter the in-memory table")
        await ContainerRestartState.shared.reset(id: nativeId)
    }

    @Test("an unlabeled container registers its aliases on start")
    func unlabeledContainerRegisters() async throws {
        let nativeId = "web-unlabeled"
        let ip = "192.168.65.81"
        let network = "myapp_default"
        let snapshot = try makeContainerSnapshot(
            nativeId: nativeId, ip: ip, network: network,
            labels: [
                "com.docker.compose.service": "web",
                "com.docker.compose.project": "myapp",
                "socktainer.dns.names": "web-alias",
            ]
        )
        let mock = StaticSnapshotClientMock(snapshot: snapshot)
        let dnsServer = SocktainerDNSServer()

        try await withApp(configure: { _ in }) { app in
            let regexRouter = app.regexRouter(with: app.logger)
            app.setRegexRouter(regexRouter)
            regexRouter.installMiddleware(on: app)
            app.storage[SocktainerDNSServerKey.self] = dnsServer
            app.storage[EventBroadcasterKey.self] = EventBroadcaster()
            try app.register(collection: ContainerStartRoute(client: mock))

            try await app.testing().test(.POST, "/v1.51/containers/\(nativeId)/start") { res async in
                #expect(res.status == .noContent)
            }
        }

        #expect(dnsServer.listEntries()[nativeId] == ip, "the container's own name is registered")
        #expect(dnsServer.listEntries()["web-alias"] == ip, "socktainer.dns.names alias is registered")
        #expect(dnsServer.listEntries()["web.myapp"] == ip, "compose project-qualified alias is registered")

        await ContainerRestartState.shared.reset(id: nativeId)
    }
}
