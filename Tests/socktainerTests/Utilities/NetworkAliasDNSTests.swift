import Testing

@testable import socktainer

@Suite("NetworkAliasDNS")
struct NetworkAliasDNSTests {

    /// A distinct attachment hostname for the `myapp_default` fixtures below.
    let hostname = "host.myapp-default.test."

    // MARK: - label

    @Test("labels are lowercased, invalid runs collapse to one hyphen and are trimmed")
    func labelNormalization() {
        #expect(NetworkAliasDNS.label("web-1") == "web-1")
        #expect(NetworkAliasDNS.label("My_Net") == "my-net")
        #expect(NetworkAliasDNS.label("  My..Net  ") == "my-net")
        #expect(NetworkAliasDNS.label("-web-") == "web")
        #expect(NetworkAliasDNS.label("a---b") == "a-b")
    }

    @Test("labels are capped at 63 characters")
    func labelLengthCap() {
        let long = String(repeating: "a", count: 100)
        #expect(NetworkAliasDNS.label(long) == String(repeating: "a", count: 63))
    }

    @Test("all-invalid input yields an empty label")
    func labelAllInvalid() {
        #expect(NetworkAliasDNS.label("") == "")
        #expect(NetworkAliasDNS.label("---") == "")
        #expect(NetworkAliasDNS.label("_@!") == "")
    }

    // MARK: - normalizedNetwork

    @Test("network names normalize to their label form")
    func normalizedNetworkName() {
        #expect(NetworkAliasDNS.normalizedNetwork("myapp_default") == "myapp-default")
        #expect(NetworkAliasDNS.normalizedNetwork("MyApp.Net") == "myapp-net")
    }

    @Test("a network name that normalizes empty becomes default")
    func normalizedNetworkFallback() {
        #expect(NetworkAliasDNS.normalizedNetwork("") == "default")
        #expect(NetworkAliasDNS.normalizedNetwork("___") == "default")
    }

    // MARK: - isReservedNetwork

    @Test("reserved network names are recognized case-insensitively")
    func reservedNetworks() {
        for name in ["default", "bridge", "host", "none", "DEFAULT", "Bridge"] {
            #expect(NetworkAliasDNS.isReservedNetwork(name), "\(name)")
        }
    }

    @Test("user-defined networks are not reserved")
    func nonReservedNetwork() {
        #expect(!NetworkAliasDNS.isReservedNetwork("mynet"))
        #expect(!NetworkAliasDNS.isReservedNetwork("myapp_default"))
    }

    // MARK: - attachmentHostname

    @Test("the attachment hostname is label.network.domain with a trailing dot")
    func attachmentHostname() {
        #expect(
            NetworkAliasDNS.attachmentHostname(id: "web-1", network: "myapp_default", dnsDomain: "test")
                == "web-1.myapp-default.test."
        )
    }

    // MARK: - qualifiedAliases

    @Test("dotless aliases are qualified with the network and domain")
    func qualifiedDotlessAlias() {
        #expect(
            NetworkAliasDNS.qualifiedAliases(
                ["web"], network: "myapp_default", dnsDomain: "test", hostname: hostname)
                == ["web.myapp-default.test"]
        )
    }

    @Test("aliases already ending in the domain are left alone")
    func qualifiedPassesFQDNs() {
        let aliases = NetworkAliasDNS.qualifiedAliases(
            ["web.test"], network: "myapp_default", dnsDomain: "test",
            hostname: hostname)
        #expect(aliases == ["web.test"])
    }

    @Test("dotted aliases are zone-qualified, never registered raw")
    func qualifiedDottedAlias() {
        #expect(
            NetworkAliasDNS.qualifiedAliases(
                ["foo.bar"], network: "myapp_default", dnsDomain: "test", hostname: hostname)
                == ["foo.bar.myapp-default.test"]
        )
    }

    @Test("a subtree alias is zone-qualified")
    func qualifiedSubtreeAlias() {
        #expect(
            NetworkAliasDNS.qualifiedAliases(
                [".example.internal"], network: "myapp_default", dnsDomain: "test", hostname: hostname)
                == [".example.internal.myapp-default.test"]
        )
    }

    @Test("an alias the guest resolver may not expand warns")
    func qualifiedWarnsForUnexpandedAlias() {
        var warnings: [String] = []
        let aliases = NetworkAliasDNS.qualifiedAliases(
            ["db.example.com"], network: "myapp_default", dnsDomain: "test", hostname: hostname,
            warn: { warnings.append($0) }
        )
        #expect(aliases == ["db.example.com.myapp-default.test"])
        #expect(warnings.count == 1)
        #expect(warnings.first?.contains("db.example.com") == true)
        #expect(warnings.first?.contains("db.example.com.myapp-default.test") == true)
    }

    @Test("an alias with fewer dots than ndots does not warn")
    func qualifiedDoesNotWarnForExpandedAlias() {
        var warnings: [String] = []
        _ = NetworkAliasDNS.qualifiedAliases(
            ["db.example"], network: "myapp_default", dnsDomain: "test", hostname: hostname,
            warn: { warnings.append($0) }
        )
        _ = NetworkAliasDNS.qualifiedAliases(
            [".example"], network: "myapp_default", dnsDomain: "test", hostname: hostname,
            warn: { warnings.append($0) }
        )
        #expect(warnings.isEmpty)
    }

    @Test("a subtree alias counts its leading dot")
    func qualifiedWarnsForSubtreeAlias() {
        var warnings: [String] = []
        _ = NetworkAliasDNS.qualifiedAliases(
            [".example.internal"], network: "myapp_default", dnsDomain: "test", hostname: hostname,
            warn: { warnings.append($0) }
        )
        #expect(warnings.count == 1)
        #expect(warnings.first?.contains(".example.internal.myapp-default.test") == true)
    }

    @Test("empty aliases are dropped")
    func qualifiedDropsEmptyAliases() {
        #expect(
            NetworkAliasDNS.qualifiedAliases(
                ["", "web", ""], network: "myapp_default", dnsDomain: "test", hostname: hostname)
                == ["web.myapp-default.test"]
        )
        #expect(
            NetworkAliasDNS.qualifiedAliases(
                [], network: "myapp_default", dnsDomain: "test", hostname: hostname
            ).isEmpty)
    }

    @Test("deduplication is case-insensitive and keeps the first occurrence")
    func qualifiedDedupCaseInsensitive() {
        #expect(
            NetworkAliasDNS.qualifiedAliases(
                ["Web", "web", "WEB"], network: "myapp_default", dnsDomain: "test", hostname: hostname)
                == ["Web.myapp-default.test"]
        )
    }

    @Test("deduplication ignores a trailing dot")
    func qualifiedDedupIgnoresTrailingDot() {
        #expect(
            NetworkAliasDNS.qualifiedAliases(
                ["web.myapp-default.test.", "web.myapp-default.test"],
                network: "myapp_default", dnsDomain: "test", hostname: hostname)
                == ["web.myapp-default.test."]
        )
    }

    @Test("an alias equal to the attachment hostname is excluded (compose sends the container name)")
    func qualifiedExcludesOwnHostname() {
        #expect(
            NetworkAliasDNS.qualifiedAliases(
                ["host", "web"], network: "myapp_default", dnsDomain: "test",
                hostname: hostname)
                == ["web.myapp-default.test"]
        )
    }

    @Test("the hostname exclusion is case- and trailing-dot-insensitive")
    func qualifiedExcludesOwnHostnameCanonically() {
        let hostname = "Web.myapp-default.test."
        #expect(
            NetworkAliasDNS.qualifiedAliases(
                ["web.myapp-default.test"], network: "myapp_default", dnsDomain: "test",
                hostname: hostname
            ).isEmpty)
        #expect(
            NetworkAliasDNS.qualifiedAliases(
                ["web.myapp-default.test."], network: "myapp_default", dnsDomain: "test",
                hostname: hostname
            ).isEmpty)
    }

    @Test("aliases are qualified per network")
    func qualifiedPerNetwork() {
        let aliases = ["web"]
        #expect(
            NetworkAliasDNS.qualifiedAliases(
                aliases, network: "app_a", dnsDomain: "test", hostname: hostname)
                == ["web.app-a.test"]
        )
        #expect(
            NetworkAliasDNS.qualifiedAliases(
                aliases, network: "app_b", dnsDomain: "test", hostname: hostname)
                == ["web.app-b.test"]
        )
    }

    // MARK: - isFQDN / qualify

    @Test(
        "FQDNs end with a trailing dot or the dnsDomain",
        arguments: [
            ("web.myapp-default.test", true),
            ("web.test", true),
            ("web.other.", true),
            ("web", false),
            ("web.other-domain", false),
            ("foo.bar", false),
        ]
    )
    func fqdnDetection(name: String, expected: Bool) {
        #expect(NetworkAliasDNS.isFQDN(name, dnsDomain: "test") == expected)
    }

    @Test("qualify appends the network zone unless the name is already an FQDN")
    func qualifyNames() {
        #expect(
            NetworkAliasDNS.qualify("web", network: "myapp_default", dnsDomain: "test")
                == "web.myapp-default.test")
        #expect(
            NetworkAliasDNS.qualify("foo.bar", network: "myapp_default", dnsDomain: "test")
                == "foo.bar.myapp-default.test")
        #expect(
            NetworkAliasDNS.qualify("web.other.", network: "myapp_default", dnsDomain: "test")
                == "web.other.")
    }

    // MARK: - searchDomains

    @Test("search domains follow network order with the bare domain last")
    func searchDomainsMultiNetwork() {
        #expect(
            NetworkAliasDNS.searchDomains(networks: ["myapp_default", "app_2"], dnsDomain: "test")
                == ["myapp-default.test", "app-2.test", "test"]
        )
    }

    @Test("duplicate search domains are dropped, keeping the first occurrence")
    func searchDomainsDeduplicated() {
        #expect(
            NetworkAliasDNS.searchDomains(networks: ["my app", "my_app"], dnsDomain: "test")
                == ["my-app.test", "test"]
        )
    }

    @Test("a single network yields its zone plus the bare domain")
    func searchDomainsSingleNetwork() {
        #expect(
            NetworkAliasDNS.searchDomains(networks: ["myapp_default"], dnsDomain: "test")
                == ["myapp-default.test", "test"]
        )
    }

    // MARK: - ndots

    @Test("ndots defaults to 2 when the user gives none")
    func ndotsDefault() {
        #expect(NetworkAliasDNS.ndots(from: []) == "ndots:2")
        #expect(NetworkAliasDNS.ndots(from: ["timeout:1", "rotate"]) == "ndots:2")
    }

    @Test("ndots is raised to at least 2")
    func ndotsMinimum() {
        #expect(NetworkAliasDNS.ndots(from: ["ndots:1"]) == "ndots:2")
        #expect(NetworkAliasDNS.ndots(from: ["ndots:0"]) == "ndots:2")
    }

    @Test("ndots above 2 is preserved")
    func ndotsPreserved() {
        #expect(NetworkAliasDNS.ndots(from: ["ndots:5"]) == "ndots:5")
        #expect(NetworkAliasDNS.ndots(from: ["timeout:1", "ndots:3"]) == "ndots:3")
    }
}
