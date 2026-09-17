import CoreText
import SwiftUI

enum GameFont {
    static func registerFonts() {
        let fontFiles = ["Cinzel-Regular.ttf", "Cinzel-Bold.ttf", "Cinzel-Black.ttf"]
        for file in fontFiles {
            let name = (file as NSString).deletingPathExtension
            let ext = (file as NSString).pathExtension
            if let url = Bundle.main.url(forResource: name, withExtension: ext) ??
                         Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Fonts") {
                var error: Unmanaged<CFError>?
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            }
        }
    }

    static func title(_ size: CGFloat) -> Font {
        .custom("Cinzel-Black", size: size, relativeTo: .largeTitle)
    }

    static func display(_ size: CGFloat) -> Font {
        .custom("Cinzel-Bold", size: size, relativeTo: .title)
    }

    static func number(_ size: CGFloat) -> Font {
        .custom("Cinzel-Regular", size: size, relativeTo: .body)
    }

    static func body(_ size: CGFloat) -> Font {
        .custom("Cinzel-Regular", size: size, relativeTo: .body)
    }
}
