import Testing

@testable import socktainer

@Suite("DNSResolutionMode")
struct DNSResolutionModeTests {

    @Test("parses sidecar (case-insensitive)")
    func parsesSidecar() {
        #expect(DNSResolutionMode(rawString: "sidecar") == .sidecar)
        #expect(DNSResolutionMode(rawString: "SIDECAR") == .sidecar)
        #expect(DNSResolutionMode(rawString: "Sidecar") == .sidecar)
    }

    @Test("parses container_name_only (case-insensitive)")
    func parsesContainerNameOnly() {
        #expect(DNSResolutionMode(rawString: "container_name_only") == .containerNameOnly)
        #expect(DNSResolutionMode(rawString: "CONTAINER_NAME_ONLY") == .containerNameOnly)
        #expect(DNSResolutionMode(rawString: "Container_Name_Only") == .containerNameOnly)
    }

    @Test("rawString round-trips to the label spelling")
    func rawStringRoundTrips() {
        #expect(DNSResolutionMode.sidecar.rawString == "sidecar")
        #expect(DNSResolutionMode.containerNameOnly.rawString == "container_name_only")
    }

    @Test("an invalid label value parses to nil (treated as absent → sidecar at create)")
    func invalidLabelValueParsesToNil() {
        #expect(DNSResolutionMode(rawString: "bogus") == nil)
        #expect(DNSResolutionMode(rawString: "") == nil)
    }

    @Test("the resolution-mode label key passes sanitizeKey unchanged")
    func labelKeySurvivesSanitize() {
        #expect(LabelNormalization.sanitizeKey(DNSResolutionMode.resolutionModeLabel) == DNSResolutionMode.resolutionModeLabel)
    }
}
