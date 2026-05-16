import Foundation

public enum PetStage: String, Codable, CaseIterable, Sendable {
    // Each stage names Mochi's role/age so the ladder reads as her life-stages. Previously
    // the highest tier was "Cozy Expert," which framed the user's mastery — breaking the
    // mascot-life-stage progression. Now it's Mochi's stage all the way up.
    case puppy = "Puppy"
    case studyBuddy = "Study Buddy"
    case deskGuardian = "Desk Guardian"
    case cozyExpert = "Cozy Companion"
}

public enum RewardRarity: String, Codable, CaseIterable, Sendable {
    case everyday = "Everyday"
    case cozy = "Cozy"
    case special = "Special"
    case dream = "Dream"

    public var odds: Int {
        switch self {
        case .everyday: 70
        case .cozy: 22
        case .special: 7
        case .dream: 1
        }
    }

    public var colorHex: String {
        switch self {
        case .everyday: "#8CB8D0"
        case .cozy: "#F2AFC5"
        case .special: "#A8512D"
        case .dream: "#496FA6"
        }
    }

    public var duplicatePaws: Int {
        // Halved/quartered per economy rebalance (Scenario B). Compensates
        // for the per-session bonus that previously stacked with the +1
        // long-session bonus to push 165-min totals to ~124 paws — far
        // ahead of the shop ceiling. Tone-safe: still always &gt;= 1.
        switch self {
        case .everyday: 1
        case .cozy: 1
        case .special: 2
        case .dream: 4
        }
    }
}

public struct AdventureRollResult: Equatable, Sendable {
    public var rarity: RewardRarity
    public var reward: RewardItem?
    public var duplicatePaws: Int

    public init(rarity: RewardRarity, reward: RewardItem?, duplicatePaws: Int = 0) {
        self.rarity = rarity
        self.reward = reward
        self.duplicatePaws = duplicatePaws
    }

    public var isDuplicateConversion: Bool {
        reward == nil && duplicatePaws > 0
    }
}

public struct ProgressionSummary: Equatable, Sendable {
    public var xp: Int
    public var level: Int
    public var coinsEarned: Int
    public var coinsAvailable: Int
    public var petStage: PetStage
    public var nextLevelXP: Int
    public var progressToNextLevel: Double

    public init(
        xp: Int,
        level: Int,
        coinsEarned: Int,
        coinsAvailable: Int,
        petStage: PetStage,
        nextLevelXP: Int,
        progressToNextLevel: Double
    ) {
        self.xp = xp
        self.level = level
        self.coinsEarned = coinsEarned
        self.coinsAvailable = coinsAvailable
        self.petStage = petStage
        self.nextLevelXP = nextLevelXP
        self.progressToNextLevel = progressToNextLevel
    }
}

public struct ShopCatalogItem: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var category: String
    public var symbolName: String
    public var colorHex: String
    public var coinCost: Int
    public var requiredLevel: Int
    public var description: String

    public init(
        id: String,
        name: String,
        category: String,
        symbolName: String,
        colorHex: String,
        coinCost: Int,
        requiredLevel: Int,
        description: String
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.coinCost = coinCost
        self.requiredLevel = requiredLevel
        self.description = description
    }

    public var rewardItem: RewardItem {
        RewardItem(
            id: UUID(uuidString: stableUUIDString) ?? UUID(),
            name: name,
            category: category,
            symbolName: symbolName,
            colorHex: colorHex,
            isEquipped: false
        )
    }

    private var stableUUIDString: String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in id.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return String(format: "00000000-0000-0000-0000-%012llX", hash & 0xFFFFFFFFFFFF)
    }
}

public enum CozyProgression {
    private struct AdventureCatalogEntry: Sendable {
        var rarity: RewardRarity
        var name: String
        var category: String
        var symbolName: String
        var colorHex: String

        var reward: RewardItem {
            RewardItem(
                name: name,
                category: category,
                symbolName: symbolName,
                colorHex: colorHex,
                isEquipped: category.localizedCaseInsensitiveContains("accessory")
            )
        }
    }

    private static let adventureCatalog: [AdventureCatalogEntry] = [
        AdventureCatalogEntry(rarity: .everyday, name: "Cloud Doodle", category: "Adventure sticker", symbolName: "cloud.fill", colorHex: "#8CB8D0"),
        AdventureCatalogEntry(rarity: .everyday, name: "Tiny Biscuit", category: "Care treat", symbolName: "circle.hexagongrid.fill", colorHex: "#FFD7B8"),
        AdventureCatalogEntry(rarity: .everyday, name: "Pencil Spark", category: "Adventure sticker", symbolName: "pencil.tip.crop.circle.fill", colorHex: "#DDEDE7"),
        AdventureCatalogEntry(rarity: .cozy, name: "Mint Paw Charm", category: "Mascot accessory", symbolName: "pawprint.fill", colorHex: "#2F6F64"),
        AdventureCatalogEntry(rarity: .cozy, name: "Lofi Cushion", category: "Room decor", symbolName: "rectangle.inset.filled", colorHex: "#F2AFC5"),
        AdventureCatalogEntry(rarity: .cozy, name: "Peach Desk Snack", category: "Care treat", symbolName: "takeoutbag.and.cup.and.straw.fill", colorHex: "#FFD7B8"),
        AdventureCatalogEntry(rarity: .special, name: "Starry Bandana", category: "Mascot accessory", symbolName: "star.fill", colorHex: "#A8512D"),
        AdventureCatalogEntry(rarity: .special, name: "Moon Window", category: "Room decor", symbolName: "moon.stars.fill", colorHex: "#6E4C77"),
        AdventureCatalogEntry(rarity: .dream, name: "Aurora Study Portal", category: "Room decor", symbolName: "sparkles", colorHex: "#496FA6")
    ]

    public static let shopCatalog: [ShopCatalogItem] = [
        ShopCatalogItem(
            id: "twinkle-bow",
            name: "Twinkle Bow",
            category: "Mascot accessory",
            symbolName: "sparkles",
            colorHex: "#F2AFC5",
            coinCost: 8,
            requiredLevel: 1,
            description: "A glittery pink bow that catches the light when Mochi tilts her head."
        ),
        ShopCatalogItem(
            id: "strawberry-bandana",
            name: "Strawberry Bandana",
            category: "Mascot accessory",
            symbolName: "heart.fill",
            colorHex: "#FF7DA8",
            coinCost: 10,
            requiredLevel: 1,
            description: "Sweet strawberry pattern — Mochi's go-to scarf on celebrate days."
        ),
        ShopCatalogItem(
            id: "bubble-tea",
            name: "Bubble Tea Break",
            category: "Care treat",
            symbolName: "cup.and.saucer.fill",
            colorHex: "#FFD7B8",
            coinCost: 12,
            requiredLevel: 1,
            description: "Warm peach-honey boba in a tiny cup. Mochi takes a slow sip."
        ),
        ShopCatalogItem(
            id: "rose-ring-timer-skin",
            name: "Rose Ring Timer Skin",
            category: "Timer skin",
            symbolName: "heart.circle.fill",
            colorHex: "#B84E73",
            coinCost: 14,
            requiredLevel: 1,
            description: "Soft rose ring around the timer — a hug for the seconds."
        ),
        ShopCatalogItem(
            id: "peach-hourglass-timer-skin",
            name: "Peach Hourglass Timer Skin",
            category: "Timer skin",
            symbolName: "hourglass",
            colorHex: "#A8512D",
            coinCost: 16,
            requiredLevel: 2,
            description: "Peach sand drifts down the hourglass while you focus. Warm, slow."
        ),
        ShopCatalogItem(
            id: "pill-timer-frame",
            name: "Pill Timer Frame",
            category: "Timer frame",
            symbolName: "capsule.fill",
            colorHex: "#F2AFC5",
            coinCost: 18,
            requiredLevel: 2,
            description: "Swap the round timer for a softer pill shape. Less clock, more cozy."
        ),
        ShopCatalogItem(
            id: "focus-headphones",
            name: "Focus Headphones",
            category: "Mascot accessory",
            symbolName: "headphones",
            colorHex: "#2F6F64",
            coinCost: 20,
            requiredLevel: 2,
            description: "Tiny jade headphones for Mochi. The world quiets when they go on."
        ),
        ShopCatalogItem(
            id: "lofi-moon-timer-skin",
            name: "Lofi Moon Timer Skin",
            category: "Timer skin",
            symbolName: "moon.stars.fill",
            colorHex: "#496FA6",
            coinCost: 35,
            requiredLevel: 3,
            description: "Moonlit blue timer for night sessions. Stars drift across the ring."
        ),
        ShopCatalogItem(
            id: "hourglass-timer-frame",
            name: "Hourglass Timer Frame",
            category: "Timer frame",
            symbolName: "hourglass",
            colorHex: "#A8512D",
            coinCost: 38,
            requiredLevel: 3,
            description: "Pivots the timer into a tall hourglass. Sand whispers as it falls."
        ),
        ShopCatalogItem(
            id: "lofi-speaker",
            name: "Lofi Speaker",
            category: "Room decor",
            symbolName: "speaker.wave.2.fill",
            colorHex: "#496FA6",
            coinCost: 22,
            requiredLevel: 2,
            description: "Bluetooth lofi speaker for Mochi's room. Soft beats, no lyrics."
        ),
        ShopCatalogItem(
            id: "peach-desk-lamp",
            name: "Peach Desk Lamp",
            category: "Room decor",
            symbolName: "lamp.desk.fill",
            colorHex: "#FFD7B8",
            coinCost: 30,
            requiredLevel: 3,
            description: "Peach desk lamp with a fluttery moth shadow. Pure 9pm energy."
        ),
        ShopCatalogItem(
            id: "mini-calendar",
            name: "Mini Calendar",
            category: "Room decor",
            symbolName: "calendar",
            colorHex: "#8CB8D0",
            coinCost: 32,
            requiredLevel: 3,
            description: "Pin-up wall calendar with hand-drawn stickers on the dates that matter."
        ),
        ShopCatalogItem(
            id: "jade-focus-mat",
            name: "Jade Focus Mat",
            category: "Room decor",
            symbolName: "rectangle.roundedtop.fill",
            colorHex: "#2F6F64",
            coinCost: 50,
            requiredLevel: 4,
            description: "Jade-green mat Mochi curls up on. It's where the best ideas land."
        ),
        ShopCatalogItem(
            id: "study-hoodie",
            name: "Study Hoodie",
            category: "Mascot outfit",
            symbolName: "tshirt.fill",
            colorHex: "#DDEDE7",
            coinCost: 55,
            requiredLevel: 4,
            description: "Oversized mint hoodie for marathon study days. Mochi looks bookish."
        ),
        ShopCatalogItem(
            id: "night-hoodie",
            name: "Night Hoodie",
            category: "Mascot outfit",
            symbolName: "moon.stars.fill",
            colorHex: "#6E4C77",
            coinCost: 75,
            requiredLevel: 5,
            description: "Dusk-plum hoodie for 1 AM mode. Tiny stars stitched on the hood."
        ),
        ShopCatalogItem(
            id: "twinkle-wall-lights",
            name: "Twinkle Wall Lights",
            category: "Room decor",
            symbolName: "lightbulb.led.fill",
            colorHex: "#5F7114",
            coinCost: 100,
            requiredLevel: 6,
            description: "Wasabi-glow fairy lights strung around the desk. Twinkle slowly on focus."
        ),
        ShopCatalogItem(
            id: "cloud-bed",
            name: "Cloud Bed",
            category: "Room decor",
            symbolName: "bed.double.fill",
            colorHex: "#8CB8D0",
            coinCost: 130,
            requiredLevel: 7,
            description: "Cloud-soft bed for the Rewards Room. Mochi naps here between blocks."
        ),
        ShopCatalogItem(
            id: "gold-star-collar",
            name: "Gold Star Collar",
            category: "Mascot outfit",
            symbolName: "star.circle.fill",
            colorHex: "#A8512D",
            coinCost: 170,
            requiredLevel: 9,
            description: "Gold-star collar — the final cosmetic. Earned over months of cozy work."
        )
    ]

    public static func summary(for database: CozyDatabase) -> ProgressionSummary {
        let xp = totalXP(for: database)
        let level = level(forXP: xp)
        let focusPaws = database.focusSessions.reduce(0) { $0 + max(0, $1.rewardPoints) }
        let coinsEarned = max(0, xp / 4) + focusPaws
        let spent = spentCoins(for: database.rewards)
        let nextLevelXP = xpNeeded(forLevel: level + 1)
        let currentLevelXP = xpNeeded(forLevel: level)
        let denominator = max(1, nextLevelXP - currentLevelXP)
        let progress = Double(xp - currentLevelXP) / Double(denominator)

        return ProgressionSummary(
            xp: xp,
            level: level,
            coinsEarned: coinsEarned,
            coinsAvailable: max(0, coinsEarned - spent),
            petStage: petStage(forLevel: level),
            nextLevelXP: nextLevelXP,
            progressToNextLevel: min(1, max(0, progress))
        )
    }

    public static func isPurchased(_ item: ShopCatalogItem, rewards: [RewardItem]) -> Bool {
        rewards.contains { $0.name == item.name && $0.category == item.category }
    }

    /// Resolves the rarity of an owned `RewardItem` by matching name+category
    /// against the shop catalog. Falls back to `.everyday` for non-shop
    /// rewards (seeded items, adventure-roll drops named outside the catalog).
    /// Used by Inventory views to enable the rare-tier shimmer overlay
    /// without piping rarity through every model boundary.
    public static func rarity(for reward: RewardItem) -> RewardRarity {
        guard let item = shopCatalog.first(where: {
            $0.name == reward.name && $0.category == reward.category
        }) else { return .everyday }
        switch item.requiredLevel {
        case ...2: return .everyday
        case 3...4: return .cozy
        case 5...7: return .special
        default: return .dream
        }
    }

    public static func canPurchase(_ item: ShopCatalogItem, database: CozyDatabase) -> Bool {
        let summary = summary(for: database)
        return summary.level >= item.requiredLevel
            && summary.coinsAvailable >= item.coinCost
            && !isPurchased(item, rewards: database.rewards)
    }

    public static func nearestUnlock(in database: CozyDatabase) -> ShopCatalogItem? {
        let summary = summary(for: database)
        return shopCatalog
            .filter { !isPurchased($0, rewards: database.rewards) }
            .sorted { lhs, rhs in
                let lhsLevelGap = max(0, lhs.requiredLevel - summary.level)
                let rhsLevelGap = max(0, rhs.requiredLevel - summary.level)
                if lhsLevelGap != rhsLevelGap { return lhsLevelGap < rhsLevelGap }

                let lhsCoinGap = max(0, lhs.coinCost - summary.coinsAvailable)
                let rhsCoinGap = max(0, rhs.coinCost - summary.coinsAvailable)
                if lhsCoinGap != rhsCoinGap { return lhsCoinGap < rhsCoinGap }

                return lhs.coinCost < rhs.coinCost
            }
            .first
    }

    public static var adventureOddsText: String {
        RewardRarity.allCases.map { "\($0.rawValue) \($0.odds)%" }.joined(separator: " / ")
    }

    public static func adventureRarity(for seed: Int) -> RewardRarity {
        let roll = abs(seed % 100)
        switch roll {
        case 0..<70:
            return .everyday
        case 70..<92:
            return .cozy
        case 92..<99:
            return .special
        default:
            return .dream
        }
    }

    /// Minimum completed reward-eligible sessions before `.dream` rarity is
    /// eligible to drop. Per Stardew geode pity-counter precedent — keeps the
    /// rarest tier from triggering on session 1 (a known cause of the early
    /// shop feeling cheap).
    public static let dreamPityThreshold = 15

    public static func adventureRoll(
        seed: Int,
        completedMinutes: Int,
        existingRewards: [RewardItem],
        lifetimeSessionCount: Int = 0
    ) -> AdventureRollResult {
        var rarity = adventureRarity(for: seed)
        // Pity gate — .dream only unlocks after the user has shown up a while.
        // Drops back to .special until threshold is crossed.
        if rarity == .dream && lifetimeSessionCount < dreamPityThreshold {
            rarity = .special
        }
        let candidates = adventureCatalog.filter { $0.rarity == rarity }
        let selectedIndex = abs((seed / 100) % max(1, candidates.count))
        let selected = candidates.isEmpty ? adventureCatalog[0] : candidates[selectedIndex]
        let alreadyOwned = existingRewards.contains { $0.name == selected.name && $0.category == selected.category }
        if alreadyOwned {
            // Long-session bonus removed per economy rebalance — duplicate-paw
            // value now lives entirely in `rarity.duplicatePaws`.
            return AdventureRollResult(rarity: rarity, reward: nil, duplicatePaws: rarity.duplicatePaws)
        }
        return AdventureRollResult(rarity: rarity, reward: selected.reward)
    }

    public static func totalXP(for database: CozyDatabase) -> Int {
        let focusXP = database.focusSessions.reduce(0) { total, session in
            guard session.isRewardEligible else { return total }
            return total + max(0, session.completedMinutes * 2)
        }
        let taskXP = database.tasks.filter(\.isCompleted).count * 12
        let habitXP = database.habits.reduce(0) { total, habit in
            total + habit.completionKeys.split(separator: ",").count * 8
        }
        let countdownXP = database.countdowns.count * 4
        return focusXP + taskXP + habitXP + countdownXP
    }

    public static func level(forXP xp: Int) -> Int {
        var level = 1
        while xp >= xpNeeded(forLevel: level + 1) {
            level += 1
        }
        return level
    }

    public static func xpNeeded(forLevel level: Int) -> Int {
        guard level > 1 else { return 0 }
        return 70 * (level - 1) * (level - 1)
    }

    public static func petStage(forLevel level: Int) -> PetStage {
        switch level {
        case 1...2: .puppy
        case 3...5: .studyBuddy
        case 6...9: .deskGuardian
        default: .cozyExpert
        }
    }

    private static func spentCoins(for rewards: [RewardItem]) -> Int {
        rewards.reduce(0) { total, reward in
            guard !isFreeStarterReward(reward) else {
                return total
            }
            guard let catalogItem = shopCatalog.first(where: { $0.name == reward.name && $0.category == reward.category }) else {
                return total
            }
            return total + catalogItem.coinCost
        }
    }

    private static func isFreeStarterReward(_ reward: RewardItem) -> Bool {
        reward.name == "Rose Ring Timer Skin" && reward.category == "Timer skin"
    }
}
