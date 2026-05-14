import Foundation

public enum PetStage: String, Codable, CaseIterable, Sendable {
    case puppy = "Puppy"
    case studyBuddy = "Study Buddy"
    case deskGuardian = "Desk Guardian"
    case cozyExpert = "Cozy Expert"
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
        switch self {
        case .everyday: 1
        case .cozy: 2
        case .special: 4
        case .dream: 7
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
            coinCost: 4,
            requiredLevel: 1,
            description: "A tiny star bow for Mochi's good-focus days."
        ),
        ShopCatalogItem(
            id: "strawberry-bandana",
            name: "Strawberry Bandana",
            category: "Mascot accessory",
            symbolName: "heart.fill",
            colorHex: "#FF7DA8",
            coinCost: 6,
            requiredLevel: 1,
            description: "A soft pink bandana for tiny wins."
        ),
        ShopCatalogItem(
            id: "bubble-tea",
            name: "Bubble Tea Break",
            category: "Care treat",
            symbolName: "cup.and.saucer.fill",
            colorHex: "#FFD7B8",
            coinCost: 8,
            requiredLevel: 1,
            description: "A small treat after showing up."
        ),
        ShopCatalogItem(
            id: "rose-ring-timer-skin",
            name: "Rose Ring Timer Skin",
            category: "Timer skin",
            symbolName: "heart.circle.fill",
            colorHex: "#B84E73",
            coinCost: 10,
            requiredLevel: 1,
            description: "A soft pink timer accent for cozy starts."
        ),
        ShopCatalogItem(
            id: "peach-hourglass-timer-skin",
            name: "Peach Hourglass Timer Skin",
            category: "Timer skin",
            symbolName: "hourglass",
            colorHex: "#A8512D",
            coinCost: 12,
            requiredLevel: 2,
            description: "A warmer timer mood for deadline days."
        ),
        ShopCatalogItem(
            id: "pill-timer-frame",
            name: "Pill Timer Frame",
            category: "Timer frame",
            symbolName: "capsule.fill",
            colorHex: "#F2AFC5",
            coinCost: 12,
            requiredLevel: 2,
            description: "Switch the big timer from ring to a soft pill."
        ),
        ShopCatalogItem(
            id: "focus-headphones",
            name: "Focus Headphones",
            category: "Mascot accessory",
            symbolName: "headphones",
            colorHex: "#2F6F64",
            coinCost: 12,
            requiredLevel: 2,
            description: "Soft headphones for one-task mode."
        ),
        ShopCatalogItem(
            id: "lofi-moon-timer-skin",
            name: "Lofi Moon Timer Skin",
            category: "Timer skin",
            symbolName: "moon.stars.fill",
            colorHex: "#496FA6",
            coinCost: 18,
            requiredLevel: 3,
            description: "Cool blue timer accents for late study."
        ),
        ShopCatalogItem(
            id: "hourglass-timer-frame",
            name: "Hourglass Timer Frame",
            category: "Timer frame",
            symbolName: "hourglass",
            colorHex: "#A8512D",
            coinCost: 20,
            requiredLevel: 3,
            description: "A collectible hourglass display for focus blocks."
        ),
        ShopCatalogItem(
            id: "lofi-speaker",
            name: "Lofi Speaker",
            category: "Room decor",
            symbolName: "speaker.wave.2.fill",
            colorHex: "#496FA6",
            coinCost: 14,
            requiredLevel: 2,
            description: "A quiet corner sound for focus blocks."
        ),
        ShopCatalogItem(
            id: "peach-desk-lamp",
            name: "Peach Desk Lamp",
            category: "Room decor",
            symbolName: "lamp.desk.fill",
            colorHex: "#FFD7B8",
            coinCost: 16,
            requiredLevel: 3,
            description: "A warm lamp for the Rewards Room."
        ),
        ShopCatalogItem(
            id: "mini-calendar",
            name: "Mini Calendar",
            category: "Room decor",
            symbolName: "calendar",
            colorHex: "#8CB8D0",
            coinCost: 18,
            requiredLevel: 3,
            description: "A tiny wall calendar for upcoming plans."
        ),
        ShopCatalogItem(
            id: "jade-focus-mat",
            name: "Jade Focus Mat",
            category: "Room decor",
            symbolName: "rectangle.roundedtop.fill",
            colorHex: "#2F6F64",
            coinCost: 22,
            requiredLevel: 4,
            description: "Mochi's little study spot."
        ),
        ShopCatalogItem(
            id: "study-hoodie",
            name: "Study Hoodie",
            category: "Mascot outfit",
            symbolName: "tshirt.fill",
            colorHex: "#DDEDE7",
            coinCost: 24,
            requiredLevel: 4,
            description: "Cozy gear for longer sessions."
        ),
        ShopCatalogItem(
            id: "night-hoodie",
            name: "Night Hoodie",
            category: "Mascot outfit",
            symbolName: "moon.stars.fill",
            colorHex: "#6E4C77",
            coinCost: 28,
            requiredLevel: 5,
            description: "A quiet hoodie for late study sessions."
        ),
        ShopCatalogItem(
            id: "twinkle-wall-lights",
            name: "Twinkle Wall Lights",
            category: "Room decor",
            symbolName: "lightbulb.led.fill",
            colorHex: "#5F7114",
            coinCost: 32,
            requiredLevel: 6,
            description: "Little lights that make the desk feel alive."
        ),
        ShopCatalogItem(
            id: "cloud-bed",
            name: "Cloud Bed",
            category: "Room decor",
            symbolName: "bed.double.fill",
            colorHex: "#8CB8D0",
            coinCost: 38,
            requiredLevel: 7,
            description: "A nap spot unlocked by showing up often."
        ),
        ShopCatalogItem(
            id: "gold-star-collar",
            name: "Gold Star Collar",
            category: "Mascot outfit",
            symbolName: "star.circle.fill",
            colorHex: "#A8512D",
            coinCost: 46,
            requiredLevel: 9,
            description: "A bright collar for your long-term study buddy."
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

    public static func adventureRoll(
        seed: Int,
        completedMinutes: Int,
        existingRewards: [RewardItem]
    ) -> AdventureRollResult {
        let rarity = adventureRarity(for: seed)
        let candidates = adventureCatalog.filter { $0.rarity == rarity }
        let selectedIndex = abs((seed / 100) % max(1, candidates.count))
        let selected = candidates.isEmpty ? adventureCatalog[0] : candidates[selectedIndex]
        let alreadyOwned = existingRewards.contains { $0.name == selected.name && $0.category == selected.category }
        if alreadyOwned {
            let longSessionBonus = completedMinutes >= 25 ? 1 : 0
            return AdventureRollResult(rarity: rarity, reward: nil, duplicatePaws: rarity.duplicatePaws + longSessionBonus)
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
