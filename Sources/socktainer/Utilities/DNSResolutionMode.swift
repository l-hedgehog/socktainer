/// Per-network DNS resolution mode. `sidecar` (default) keeps socktainer's forwarder and
/// in-memory IP table; `containerNameOnly` points the guest at the vmnet gateway so Apple's
/// allocator resolves `{name}.{network}.{dnsDomain}` FQDNs, where `dnsDomain` is the
/// configured `systemConfig.dns.domain`.
enum DNSResolutionMode: String, Sendable {
    case sidecar
    case containerNameOnly

    /// Label key for the per-network `container_name_only` DNS opt-in (also frozen on the container).
    static let resolutionModeLabel = "l-hedgehog.dns.resolution-mode"

    init?(rawString: String) {
        switch rawString.lowercased() {
        case "sidecar": self = .sidecar
        case "container_name_only": self = .containerNameOnly
        default: return nil
        }
    }

    var rawString: String {
        switch self {
        case .sidecar: "sidecar"
        case .containerNameOnly: "container_name_only"
        }
    }
}
