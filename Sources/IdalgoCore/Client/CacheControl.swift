import Foundation

/// Les directives de `Cache-Control` qui comptent pour le cache du client.
struct CacheControl: Equatable {
    var maxAge: TimeInterval = 0
    var noStore = false

    init(header: String?) {
        for directive in (header ?? "").split(separator: ",") {
            let parts = directive.split(separator: "=", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces).lowercased()
            }
            switch parts.first {
            case "max-age": maxAge = parts.count > 1 ? TimeInterval(parts[1]) ?? 0 : 0
            case "no-store": noStore = true
            default: continue
            }
        }
    }
}
