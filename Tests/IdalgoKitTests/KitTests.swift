import SwiftUI
import Testing
@testable import IdalgoKit

@Suite("Ouverture de la feuille de match")
struct ContestRouteTests {
    @Test("automatique : poussée dans une NavigationStack, dans la UINavigationController d'une app UIKit, sinon en feuille modale")
    func automatic() {
        #expect(ContestRoute(presentation: .automatic, host: .swiftUIStack) == .swiftUIPush)
        #expect(ContestRoute(presentation: .automatic, host: .uiKit) == .uiKitPush)
        #expect(ContestRoute(presentation: .automatic, host: .none) == .sheet)
    }

    @Test("push : jamais par navigationDestination dans une pile UIKit, où il ne ferait rien")
    func push() {
        #expect(ContestRoute(presentation: .push, host: .swiftUIStack) == .swiftUIPush)
        #expect(ContestRoute(presentation: .push, host: .uiKit) == .uiKitPush)
        #expect(ContestRoute(presentation: .push, host: .none) == .swiftUIPush)
    }

    @Test("sheet : toujours en feuille modale")
    func sheet() {
        for host in [NavigationHost.none, .swiftUIStack, .uiKit] {
            #expect(ContestRoute(presentation: .sheet, host: host) == .sheet)
        }
    }
}

@Suite("Thème résolu")
struct ResolvedThemeCacheTests {
    @Test("un thème n'est résolu qu'une fois par mode")
    func memoised() {
        let theme = IdalgoTheme.neutral.with(mode: .light)
        var other = theme
        other.name = "Autre \(UUID().uuidString)"
        _ = ResolvedTheme.cached(theme, mode: .light)
        let count = ResolvedTheme.cachedCount
        for _ in 0..<5 { _ = ResolvedTheme.cached(theme, mode: .light) }
        #expect(ResolvedTheme.cachedCount == count)
        _ = ResolvedTheme.cached(other, mode: .dark)
        #expect(ResolvedTheme.cachedCount == min(count + 1, ResolvedTheme.cacheLimit))
    }
}

@Suite("Animations")
struct PulsingTests {
    @Test("la pulsation s'arrête quand les animations sont réduites")
    func reduceMotion() {
        #expect(Pulsing.animation(duration: 0.9, reduceMotion: true) == nil)
        #expect(Pulsing.animation(duration: 0.9, reduceMotion: false) != nil)
    }
}
