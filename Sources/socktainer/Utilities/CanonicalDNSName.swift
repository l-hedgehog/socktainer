import Foundation

/// Normalized DNS labels, FQDNs, search domains, and ndots for the `container_name_only` mode.
enum CanonicalDNSName {

    /// Normalizes a string to a valid DNS label (per RFC 1035): lowercase; non `[a-z0-9-]` → `-`,
    /// with collapse/trim of `-`; capped at 63 chars. All-invalid → empty.
    static func label(_ s: String) -> String {
        var out = ""
        var pendingDash = false
        for ch in s.lowercased() {
            if ch.isLetter || ch.isNumber {
                if pendingDash, !out.isEmpty { out.append("-") }
                pendingDash = false
                out.append(ch)
            } else {
                pendingDash = true
            }
        }
        if out.count > 63 { out = String(out.prefix(63)) }
        return out
    }

    /// The network name as a valid label, `"default"` when it normalizes empty.
    static func normalizedNetwork(_ name: String) -> String {
        let l = label(name)
        return l.isEmpty ? "default" : l
    }

    /// The registered FQDN: `label.net.dnsDomain.`. The trailing dot makes it a canonical,
    /// fully-qualified name the allocator matches (apple/container#1810).
    static func fqdn(label: String, network: String, dnsDomain: String) -> String {
        "\(label).\(network).\(dnsDomain)."
    }

    /// Search domains (`[net.dnsDomain, dnsDomain]`) so peer short names resolve at `ndots:2`.
    static func searchDomains(network: String, dnsDomain: String) -> [String] {
        ["\(network).\(dnsDomain)", dnsDomain]
    }

    /// The `ndots:N` option: max(user, 2), or `ndots:2` when absent.
    static func ndots(from userOptions: [String]) -> String {
        guard let entry = userOptions.first(where: { $0.lowercased().hasPrefix("ndots:") }),
            let value = entry.split(separator: ":").last.flatMap({ Int($0) })
        else { return "ndots:2" }
        return "ndots:\(max(value, 2))"
    }
}
