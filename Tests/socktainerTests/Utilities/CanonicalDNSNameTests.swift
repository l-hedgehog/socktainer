import Testing

@testable import socktainer

@Suite("CanonicalDNSName")
struct CanonicalDNSNameTests {

    // MARK: label

    @Test("label lowercases and keeps [a-z0-9-]")
    func labelKeepsAlnumAndDash() {
        #expect(CanonicalDNSName.label("FooBar99") == "foobar99")
        #expect(CanonicalDNSName.label("already-ok") == "already-ok")
    }

    @Test("label maps invalid chars to dashes and collapses repeats")
    func labelCollapsesInvalidChars() {
        #expect(CanonicalDNSName.label("foo_bar") == "foo-bar")
        #expect(CanonicalDNSName.label("a/b//c") == "a-b-c")
        #expect(CanonicalDNSName.label("a  b") == "a-b")
    }

    @Test("label trims leading/trailing dashes")
    func labelTrimsDashes() {
        #expect(CanonicalDNSName.label("-foo-") == "foo")
        #expect(CanonicalDNSName.label("__bar_") == "bar")
    }

    @Test("label caps at 63 chars")
    func labelCapsAt63() {
        #expect(CanonicalDNSName.label(String(repeating: "a", count: 80)).count == 63)
    }

    @Test("an all-invalid label normalizes to empty")
    func labelAllInvalidIsEmpty() {
        #expect(CanonicalDNSName.label("___///") == "")
    }

    // MARK: normalizedNetwork

    @Test("normalizedNetwork maps network names to valid labels")
    func normalizedNetworkMapsToLabel() {
        #expect(CanonicalDNSName.normalizedNetwork("my_app_overlay") == "my-app-overlay")
        #expect(CanonicalDNSName.normalizedNetwork("myapp_default") == "myapp-default")
    }

    @Test("normalizedNetwork normalizes empty to default")
    func normalizedNetworkEmptyIsDefault() {
        #expect(CanonicalDNSName.normalizedNetwork("") == "default")
    }

    // MARK: fqdn / searchDomains

    @Test("fqdn joins label, network, and dns domain with a trailing dot")
    func fqdnShape() {
        #expect(CanonicalDNSName.fqdn(label: "py", network: "net1", dnsDomain: "test") == "py.net1.test.")
    }

    @Test("searchDomains emits [net.dnsDomain, dnsDomain]")
    func searchDomainsShape() {
        #expect(CanonicalDNSName.searchDomains(network: "net1", dnsDomain: "test") == ["net1.test", "test"])
    }

    // MARK: ndots

    @Test("ndots defaults to 2 when absent")
    func ndotsDefaultsTo2() {
        #expect(CanonicalDNSName.ndots(from: []) == "ndots:2")
        #expect(CanonicalDNSName.ndots(from: ["timeout:2", "attempts:3"]) == "ndots:2")
    }

    @Test("ndots keeps a user value above 2")
    func ndotsKeepsUserValueAbove2() {
        #expect(CanonicalDNSName.ndots(from: ["ndots:5"]) == "ndots:5")
    }

    @Test("ndots bumps a user value below 2 up to 2")
    func ndotsBumpsBelow2() {
        #expect(CanonicalDNSName.ndots(from: ["ndots:1"]) == "ndots:2")
        #expect(CanonicalDNSName.ndots(from: ["ndots:0"]) == "ndots:2")
    }

    @Test("ndots parses the value case-insensitively and ignores non-ndots options")
    func ndotsParsesCaseInsensitive() {
        #expect(CanonicalDNSName.ndots(from: ["NDOTS:3", "timeout:1"]) == "ndots:3")
    }
}
