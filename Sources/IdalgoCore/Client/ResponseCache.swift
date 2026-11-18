import Foundation

/// Cache mémoire des réponses par URL : servies telles quelles pendant `max-age`, puis
/// revalidées avec leur `ETag` (`If-None-Match`, 304).
actor ResponseCache {
    struct Entry: Sendable {
        let data: Data
        let etag: String?
        let expiresAt: Date

        func isFresh(at now: Date) -> Bool { now < expiresAt }
    }

    private var entries: [URL: Entry] = [:]
    private var order: [URL] = []
    private let capacity: Int

    init(capacity: Int = 64) {
        self.capacity = capacity
    }

    func entry(for url: URL) -> Entry? {
        entries[url]
    }

    /// Range une réponse 200 ou 304 ; une réponse `no-store`, ou sans `max-age` ni `ETag`, n'est pas gardée.
    func store(_ data: Data, etag: String?, cacheControl: CacheControl, for url: URL, at now: Date) {
        guard !cacheControl.noStore, cacheControl.maxAge > 0 || etag != nil else {
            remove(url)
            return
        }
        if entries[url] == nil { order.append(url) }
        entries[url] = Entry(data: data, etag: etag, expiresAt: now.addingTimeInterval(cacheControl.maxAge))
        if order.count > capacity { remove(order[0]) }
    }

    private func remove(_ url: URL) {
        entries[url] = nil
        order.removeAll { $0 == url }
    }
}
