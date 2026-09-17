import CoreText
import SwiftUI
import UIKit

enum GameFont {
    static func registerFonts() {
        let fontFiles = ["Cinzel-Regular.ttf", "Cinzel-Bold.ttf", "Cinzel-Black.ttf", "ToneOZ-Tsuipita-TC.ttf"]
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

    private static func fontWithFallback(name: String, weight: UIFont.Weight, size: CGFloat) -> Font {
        let baseFont = UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
        let customChineseFont = UIFont(name: "ToneOZ-Tsuipita-TC", size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
        let cascadedDescriptor = baseFont.fontDescriptor.addingAttributes([
            .cascadeList: [customChineseFont.fontDescriptor]
        ])
        let combinedUIFont = UIFont(descriptor: cascadedDescriptor, size: size)
        return Font(combinedUIFont)
    }

    static func title(_ size: CGFloat) -> Font {
        fontWithFallback(name: "Cinzel-Black", weight: .black, size: size)
    }

    static func display(_ size: CGFloat) -> Font {
        fontWithFallback(name: "Cinzel-Bold", weight: .bold, size: size)
    }

    static func number(_ size: CGFloat) -> Font {
        fontWithFallback(name: "Cinzel-Regular", weight: .regular, size: size)
    }

    static func body(_ size: CGFloat) -> Font {
        fontWithFallback(name: "Cinzel-Regular", weight: .regular, size: size)
    }
}
