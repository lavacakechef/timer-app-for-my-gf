import SwiftUI
import Lottie

/// SwiftUI wrapper around bundled Lottie mascot animations. Each character has
/// its own set of JSONs in `Resources/Mascot/`, named `{characterID}-{state}.json`.
/// License + provenance is recorded in `Resources/Mascot/LICENSE.txt`.
///
/// Ten characters ship today:
///   - "maltese" → "mochi-{state}.json" (Pancake the Shiba Inu, Lottie Simple License)
///   - "biscuit" → "biscuit-{state}.json" (Cativity productivity cat, MIT)
///   - "tofu" / "bao" / "bramble" / "pip" / "yolk" / "soba" / "hazel" / "acorn"
///     → "{character}-idle.json" — Google Noto Animated Emoji set (CC-BY 4.0).
///     Noto only ships a single idle loop per emoji, so all CozyTime mascot
///     states resolve to the same JSON; state distinction comes from the
///     surrounding tint / accessory composition in `MascotView`.
///
/// Characters cover slightly different state sets — `animationName(character:state:)`
/// resolves the closest available file per character.
struct CozyLottieMascot: View {
    let characterID: String
    let state: MascotState
    let size: CGFloat

    /// Characters that only ship a single idle-loop JSON. Every MascotState
    /// resolves to `"{character}-idle"` for these. Kept in one place so the
    /// mapping table and the `MascotStyleCard` previews stay in lock-step.
    static let singleStateCharacters: Set<String> = [
        "tofu", "bao", "bramble", "pip", "yolk", "soba", "hazel", "acorn"
    ]

    /// Map MascotStyle.id (the picker key) → the character prefix used for Lottie
    /// filenames. Returns nil when no Lottie set ships for this style — caller
    /// should fall through to the SwiftUI vector body.
    static func lottiePrefix(forStyleID styleID: String) -> String? {
        switch styleID {
        case "maltese": "mochi"
        case "biscuit": "biscuit"
        case "tofu": "tofu"
        case "bao": "bao"
        case "bramble": "bramble"
        case "pip": "pip"
        case "yolk": "yolk"
        case "soba": "soba"
        case "hazel": "hazel"
        case "acorn": "acorn"
        default: nil
        }
    }

    /// Per-character state → filename mapping. Honors which states each
    /// character actually has — e.g. Pancake has no `sleep`, so paused states
    /// reuse the `pause` (unicorn) animation; Biscuit has a real sleep animation.
    /// Noto emoji characters only ship a single idle loop, so every state
    /// returns `"{character}-idle"`.
    static func animationName(character: String, state: MascotState) -> String {
        if singleStateCharacters.contains(character) {
            return "\(character)-idle"
        }
        return switch character {
        case "biscuit":
            switch state {
            case .idle, .countdown, .overdue: "biscuit-idle"
            case .breakTime: "biscuit-sleep"     // break = peaceful sleep
            case .settling: "biscuit-pause"      // about to start = watching the clock
            case .focus, .deepFocus, .landing: "biscuit-focus"
            case .complete: "biscuit-complete"
            }
        default: // "mochi" (Pancake) and any unknown character with the mochi-* set
            switch state {
            case .idle, .countdown, .breakTime, .overdue: "mochi-idle"
            case .settling, .focus, .deepFocus, .landing: "mochi-focus"
            case .complete: "mochi-complete"
            }
        }
    }

    /// Cheap once-per-process check that the character's JSONs are actually in
    /// the main bundle. Used to gate the Lottie branch in DesignSystem.
    static func isBundled(character: String) -> Bool {
        cachedBundleStates(for: character).isEmpty == false
    }

    private static var bundleCache: [String: Set<String>] = [:]

    private static func cachedBundleStates(for character: String) -> Set<String> {
        if let cached = bundleCache[character] { return cached }
        let probeStates = ["idle", "focus", "pause", "complete", "sleep"]
        var found: Set<String> = []
        for s in probeStates {
            if LottieAnimation.named("\(character)-\(s)", bundle: .main) != nil {
                found.insert(s)
            }
        }
        bundleCache[character] = found
        return found
    }

    var body: some View {
        let name = Self.animationName(character: characterID, state: state)
        LottieView(animation: .named(name, bundle: .main))
            .playing(loopMode: .loop)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
