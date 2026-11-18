/// Enveloppe commune des réponses `/v1` : `{ data, meta, links }` ; seul `data` sert au SDK.
struct Envelope<T: Decodable & Sendable>: Decodable, Sendable {
    let data: T
}
