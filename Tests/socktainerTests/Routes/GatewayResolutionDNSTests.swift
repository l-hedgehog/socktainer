import ContainerResource
import Foundation
import Testing

@testable import socktainer

@Suite("ContainerCreateRoute — gateway resolution DNS helpers")
struct GatewayResolutionDNSTests {

    // MARK: gatewayHostname

    @Test("a named network with a dns domain registers the {label}.{net}.{dnsDomain} FQDN")
    func namedNetworkGetsFQDN() {
        let h = ContainerCreateRoute.gatewayHostname(
            fallback: "web-abc",
            firstLabel: "my-web",
            network: "my_app_overlay",
            dnsDomain: "test",
            mode: .containerNameOnly
        )
        // Only the network name is normalized here: my_app_overlay → my-app-overlay.
        #expect(h == "my-web.my-app-overlay.test.")
    }

    @Test("sidecar mode keeps the plain hostname")
    func sidecarKeepsPlainHostname() {
        let h = ContainerCreateRoute.gatewayHostname(
            fallback: "web-abc",
            firstLabel: "my-web",
            network: "my_app_overlay",
            dnsDomain: "test",
            mode: .sidecar
        )
        #expect(h == "web-abc")
    }

    @Test("a nil dns domain keeps the plain hostname (container_name_only falls back)")
    func nilDNSDomainKeepsPlainHostname() {
        let h = ContainerCreateRoute.gatewayHostname(
            fallback: "web-abc",
            firstLabel: "my-web",
            network: "my_app_overlay",
            dnsDomain: nil,
            mode: .containerNameOnly
        )
        #expect(h == "web-abc")
    }

    @Test("a reserved network keeps the plain hostname even in container_name_only")
    func reservedNetworkKeepsPlainHostname() {
        for net in ["default", "bridge", "host", "none"] {
            let h = ContainerCreateRoute.gatewayHostname(
                fallback: "web-abc",
                firstLabel: "my-web",
                network: net,
                dnsDomain: "test",
                mode: .containerNameOnly
            )
            #expect(h == "web-abc", "network \(net) must not become an FQDN")
        }
    }

    @Test("only container_name_only is a gateway FQDN mode today")
    func gatewayModePredicate() {
        #expect(ContainerCreateRoute.isGatewayFQDNMode(.containerNameOnly))
        #expect(!ContainerCreateRoute.isGatewayFQDNMode(.sidecar))
    }

    // MARK: gatewayResolutionDNS

    private func dns(nameservers: [String], domain: String?, search: [String], options: [String]) -> ContainerConfiguration.DNSConfiguration {
        ContainerConfiguration.DNSConfiguration(nameservers: nameservers, domain: domain, searchDomains: search, options: options)
    }

    @Test("nameserver is the passed gateway; search/domain/ndots appended")
    func appendsSearchDomainAndNdots() {
        let existing = dns(nameservers: ["1.1.1.1"], domain: nil, search: ["example.com"], options: [])
        let out = ContainerCreateRoute.gatewayResolutionDNS(
            existing: existing, nameservers: ["192.168.254.1"], network: "net1", dnsDomain: "test"
        )
        #expect(out.nameservers == ["192.168.254.1"])
        #expect(out.searchDomains == ["example.com", "net1.test", "test"])
        #expect(out.domain == "test")  // user set none
        #expect(out.options == ["ndots:2"])
    }

    @Test("empty nameservers are preserved unchanged")
    func preservesEmptyNameservers() {
        let existing = dns(nameservers: [], domain: nil, search: [], options: [])
        let out = ContainerCreateRoute.gatewayResolutionDNS(
            existing: existing, nameservers: [], network: "net1", dnsDomain: "test"
        )
        #expect(out.nameservers == [])
        #expect(out.searchDomains == ["net1.test", "test"])
        #expect(out.options == ["ndots:2"])
    }

    @Test("a user ndots above 2 is kept; non-ndots options are preserved")
    func keepsUserNdotsAbove2() {
        let existing = dns(nameservers: [], domain: nil, search: [], options: ["ndots:5", "timeout:2"])
        let out = ContainerCreateRoute.gatewayResolutionDNS(
            existing: existing, nameservers: ["192.168.254.1"], network: "net1", dnsDomain: "test"
        )
        #expect(out.options == ["timeout:2", "ndots:5"])
    }

    @Test("a user ndots below 2 is bumped to 2")
    func bumpsUserNdotsBelow2() {
        let existing = dns(nameservers: [], domain: nil, search: [], options: ["ndots:1"])
        let out = ContainerCreateRoute.gatewayResolutionDNS(
            existing: existing, nameservers: ["192.168.254.1"], network: "net1", dnsDomain: "test"
        )
        #expect(out.options == ["ndots:2"])
    }

    @Test("an existing user domain is not clobbered by the dns domain")
    func keepsUserDomain() {
        let existing = dns(nameservers: [], domain: "corp.local", search: [], options: [])
        let out = ContainerCreateRoute.gatewayResolutionDNS(
            existing: existing, nameservers: ["192.168.254.1"], network: "net1", dnsDomain: "test"
        )
        #expect(out.domain == "corp.local")
        #expect(out.searchDomains == ["net1.test", "test"])
    }

    @Test("network with invalid chars is normalized in search domains")
    func normalizesNetworkInSearch() {
        let existing = dns(nameservers: [], domain: nil, search: [], options: [])
        let out = ContainerCreateRoute.gatewayResolutionDNS(
            existing: existing, nameservers: ["192.168.254.1"], network: "my_app_overlay", dnsDomain: "test"
        )
        #expect(out.searchDomains == ["my-app-overlay.test", "test"])
    }

    @Test("already-present search domains are not duplicated")
    func doesNotDuplicateSearchDomains() {
        let existing = dns(nameservers: [], domain: nil, search: ["net1.test", "test"], options: ["ndots:3"])
        let out = ContainerCreateRoute.gatewayResolutionDNS(
            existing: existing, nameservers: ["192.168.254.1"], network: "net1", dnsDomain: "test"
        )
        #expect(out.searchDomains == ["net1.test", "test"])
        #expect(out.options == ["ndots:3"])
    }

    // MARK: effectiveResolutionMode

    @Test("absent label value → sidecar (the unlabeled default)")
    func absentLabelIsSidecar() {
        var warnings: [String] = []
        #expect(ContainerCreateRoute.effectiveResolutionMode(labelValue: nil, warn: { warnings.append($0) }) == .sidecar)
        #expect(ContainerCreateRoute.effectiveResolutionMode(labelValue: "", warn: { warnings.append($0) }) == .sidecar)
        #expect(warnings.isEmpty)
    }

    @Test("container_name_only / sidecar label values parse correctly")
    func validLabelValuesParse() {
        var warnings: [String] = []
        #expect(ContainerCreateRoute.effectiveResolutionMode(labelValue: "container_name_only", warn: { warnings.append($0) }) == .containerNameOnly)
        #expect(ContainerCreateRoute.effectiveResolutionMode(labelValue: "sidecar", warn: { warnings.append($0) }) == .sidecar)
        #expect(warnings.isEmpty)
    }

    @Test("an invalid label value falls back to sidecar and warns")
    func invalidLabelFallsBackToSidecar() {
        var warnings: [String] = []
        #expect(ContainerCreateRoute.effectiveResolutionMode(labelValue: "bogus", warn: { warnings.append($0) }) == .sidecar)
        #expect(warnings.count == 1)
        #expect(warnings[0].contains("bogus"))
    }

    // MARK: networkDNSPolicies

    @Test("policies map each network to its mode + nameservers from one listing")
    func networkPoliciesBuildModeAndNameservers() {
        var warnings: [String] = []
        let policies = ContainerCreateRoute.networkDNSPolicies(
            networks: [
                (name: "net1", labels: [DNSResolutionMode.resolutionModeLabel: "container_name_only"], gateway: "192.168.254.1"),
                (name: "net2", labels: [:], gateway: "192.168.253.1"),
            ],
            warn: { warnings.append($0) }
        )
        #expect(policies["net1"]?.mode == .containerNameOnly)
        #expect(policies["net1"]?.nameservers == ["192.168.254.1"])
        #expect(policies["net2"]?.mode == .sidecar, "absent label → the unlabeled sidecar default")
        #expect(policies["net2"]?.nameservers == ["192.168.253.1"])
        #expect(warnings.isEmpty)
    }

    @Test("an invalid label value falls back to sidecar and warns")
    func networkPoliciesInvalidLabelWarns() {
        var warnings: [String] = []
        let policies = ContainerCreateRoute.networkDNSPolicies(
            networks: [(name: "net1", labels: [DNSResolutionMode.resolutionModeLabel: "bogus"], gateway: "192.168.254.1")],
            warn: { warnings.append($0) }
        )
        #expect(policies["net1"]?.mode == .sidecar)
        #expect(warnings.count == 1)
        #expect(warnings[0].contains("bogus"))
    }

    @Test("an empty or 0.0.0.0 gateway → empty nameservers (apple substitutes)")
    func networkPoliciesUnknownGatewayStaysEmpty() {
        var warnings: [String] = []
        for gateway in ["", "0.0.0.0"] {
            let policies = ContainerCreateRoute.networkDNSPolicies(
                networks: [(name: "net1", labels: [DNSResolutionMode.resolutionModeLabel: "container_name_only"], gateway: gateway)],
                warn: { warnings.append($0) }
            )
            #expect(policies["net1"]?.mode == .containerNameOnly)
            #expect(policies["net1"]?.nameservers == [])
        }
        #expect(warnings.isEmpty)
    }

    // MARK: gatewayHostname (per-network mixed behavior)

    @Test("FQDN is genuinely per network: opted-in gets FQDN, a sidecar network keeps plain")
    func hostnameIsPerNetwork() {
        let optedIn = ContainerCreateRoute.gatewayHostname(
            fallback: "web-abc", firstLabel: "my-web", network: "net1", dnsDomain: "test", mode: .containerNameOnly
        )
        let sidecar = ContainerCreateRoute.gatewayHostname(
            fallback: "web-abc", firstLabel: "my-web", network: "net2", dnsDomain: "test", mode: .sidecar
        )
        let noDomain = ContainerCreateRoute.gatewayHostname(
            fallback: "web-abc", firstLabel: "my-web", network: "net1", dnsDomain: nil, mode: .containerNameOnly
        )
        #expect(optedIn == "my-web.net1.test.")
        #expect(sidecar == "web-abc")
        #expect(noDomain == "web-abc", "no dns domain → no FQDN even for an opted-in network")
    }
}
