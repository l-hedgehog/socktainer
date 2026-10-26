import ContainerResource
import Foundation

/// DNS names, aliases, search domains and ndots for the `apple-dns` mode, which relies on
/// apple/container's built-in DNS fed by the aliases registered on each network attachment.
enum NetworkAliasDNS {

    private static let reservedNetworks: Set<String> = ["default", "bridge", "host", "none"]

    /// RFC1035 label: lowercase; runs of non `[a-z0-9]` collapse to a single `-`, trimmed at both
    /// ends; capped at 63 chars. All-invalid input yields an empty string.
    static func label(_ s: String) -> String {
        var out = ""
        var pendingDash = false
        for ch in s.lowercased() {
            if ch.isASCII, ch.isLetter || ch.isNumber {
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

    /// The network name as a label, `"default"` when it normalizes empty.
    static func normalizedNetwork(_ name: String) -> String {
        let normalized = label(name)
        return normalized.isEmpty ? "default" : normalized
    }

    /// Reserved Docker network names — they never get a per-network DNS zone and never
    /// count as a named network.
    static func isReservedNetwork(_ name: String) -> Bool {
        reservedNetworks.contains(name.lowercased())
    }

    /// Attachment hostname `label.network.dnsDomain.`; the trailing dot makes it a canonical FQDN
    /// that apple/container matches as an attachment hostname.
    static func attachmentHostname(id: String, network: String, dnsDomain: String) -> String {
        "\(label(id)).\(normalizedNetwork(network)).\(dnsDomain)."
    }

    /// True when `name` is already a fully-qualified name: a trailing dot, or ending in
    /// `.{dnsDomain}`. Everything else needs the per-network zone to be resolvable.
    static func isFQDN(_ name: String, dnsDomain: String) -> Bool {
        let canonical = AttachmentOptions.canonicalHostname(name)
        return name.hasSuffix(".") || canonical.hasSuffix(".\(dnsDomain.lowercased())")
    }

    /// The aliases as one attachment registers them: already-qualified names (trailing dot or
    /// ending in `.{dnsDomain}`) as given, every other name qualified with the per-network zone.
    /// Deduplicated on the canonical hostname form, excluding the attachment's own hostname.
    static func qualifiedAliases(
        _ aliases: [String], network: String, dnsDomain: String, hostname: String,
        warn: (String) -> Void = { _ in }
    ) -> [String] {
        var seen: Set<String> = [AttachmentOptions.canonicalHostname(hostname)]
        var qualified: [String] = []
        func add(_ name: String) {
            guard !name.isEmpty,
                seen.insert(AttachmentOptions.canonicalHostname(name)).inserted
            else { return }
            qualified.append(name)
        }
        for alias in aliases where !alias.isEmpty {
            if isFQDN(alias, dnsDomain: dnsDomain) {
                add(alias)
            } else {
                let qualifiedAlias = qualify(alias, network: network, dnsDomain: dnsDomain)
                add(qualifiedAlias)
                if guestMayNotExpand(alias) {
                    warn(
                        "apple-dns mode: the ndots option in /etc/resolv.conf may keep this container from expanding this alias (\(alias)), use the qualified name (\(qualifiedAlias)) in such cases"
                    )
                }
            }
        }
        return qualified
    }

    /// True when the guest resolver may not expand the name: musl expands a name only when
    /// it has fewer dots than `ndots` and otherwise looks it up as typed, while glibc falls
    /// back to the search list. A leading dot counts as a dot.
    static func guestMayNotExpand(_ name: String) -> Bool {
        name.filter { $0 == "." }.count >= 2
    }

    /// Search domains for a multi-network container: the client's existing ones first, then
    /// `<network>.<dnsDomain>` per network, then the bare `dnsDomain`, deduplicated in order.
    static func searchDomains(_ existing: [String] = [], networks: [String], dnsDomain: String) -> [String] {
        var seen = Set<String>()
        var domains: [String] = []
        for domain in existing + networks.map({ "\(normalizedNetwork($0)).\(dnsDomain)" }) + [dnsDomain] {
            if seen.insert(domain.lowercased()).inserted { domains.append(domain) }
        }
        return domains
    }

    /// Expands `name` into the per-network FQDN `name.<network>.<dnsDomain>`; FQDNs pass through.
    static func qualify(_ name: String, network: String, dnsDomain: String) -> String {
        guard !isFQDN(name, dnsDomain: dnsDomain) else { return name }
        return "\(name).\(normalizedNetwork(network)).\(dnsDomain)"
    }

    /// The `ndots:N` resolver option: max(user value, 2), or `ndots:2` when absent.
    static func ndots(from userOptions: [String]) -> String {
        guard let entry = userOptions.first(where: { $0.lowercased().hasPrefix("ndots:") }),
            let value = entry.split(separator: ":").last.flatMap({ Int($0) })
        else { return "ndots:2" }
        return "ndots:\(max(value, 2))"
    }
}
