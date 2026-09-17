import SwiftUI

enum GameFont {
    static func title(_ size: CGFloat) -> Font {
        .custom("Cinzel-Black", size: size, relativeTo: .largeTitle)
    }

    static func display(_ size: CGFloat) -> Font {
        .custom("Cinzel-Bold", size: size, relativeTo: .title)
    }

    static func number(_ size: CGFloat) -> Font {
        .custom("Cinzel-Regular", size: size, relativeTo: .body)
    }
}
