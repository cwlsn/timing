import Foundation

/// The picture that labels a timer.
public enum TimerIcon {
    public static let fallback = "⏲️"

    /// First match wins, so the more particular words come first.
    private static let words: [(icon: String, category: TimerCategory, words: [String])] = [
        ("🥞", .cooking, ["pancake", "crepe", "waffle"]), ("🍳", .cooking, ["fried egg", "omelette", "omelet", "fry", "pan"]),
        ("🥚", .cooking, ["egg"]), ("🍚", .cooking, ["rice", "risotto"]),
        ("🍝", .cooking, ["pasta", "spaghetti", "penne", "linguine", "lasagna"]), ("🍜", .cooking, ["noodle", "ramen", "pho"]),
        ("🍕", .baking, ["pizza"]), ("🍔", .cooking, ["burger"]), ("🥩", .cooking, ["steak", "beef", "roast"]),
        ("🍗", .cooking, ["chicken", "turkey", "wing"]), ("🥓", .cooking, ["bacon"]), ("🐟", .cooking, ["fish", "salmon", "cod", "tuna"]),
        ("🍤", .cooking, ["shrimp", "prawn"]), ("🍟", .cooking, ["fries", "chips"]), ("🥔", .cooking, ["potato"]),
        ("🥦", .cooking, ["broccoli", "vegetable", "veg"]), ("🥕", .cooking, ["carrot"]), ("🌽", .cooking, ["corn"]),
        ("🫘", .cooking, ["bean", "lentil"]), ("🍲", .cooking, ["soup", "stew", "stock", "curry", "chili"]),
        ("🍪", .baking, ["cookie", "biscuit"]), ("🧁", .baking, ["muffin", "cupcake"]), ("🎂", .baking, ["cake"]), ("🥧", .baking, ["pie"]),
        ("🍞", .baking, ["bread", "sourdough", "dough", "loaf", "proof"]), ("🍞", .cooking, ["toast"]),
        ("🌿", .drinks, ["herbal", "mint", "chamomile"]), ("🍵", .drinks, ["tea", "matcha"]),
        ("☕️", .drinks, ["coffee", "espresso", "french press", "pour over", "brew"]),
        ("🏋️", .exercise, ["plank", "workout", "lift", "weights", "hiit"]), ("🧘", .exercise, ["stretch", "yoga", "meditate", "breathe"]),
        ("🏃", .exercise, ["run", "jog", "walk"]), ("💤", .exercise, ["rest"]), ("😴", .everyday, ["nap", "sleep"]),
        ("🎯", .everyday, ["focus", "study", "work", "pomodoro"]), ("🧺", .everyday, ["laundry", "washing", "dryer"]),
        ("🅿️", .everyday, ["parking", "meter"]), ("🔥", .cooking, ["grill", "bbq", "oven"]), ("🔥", .baking, ["preheat"]),
    ]

    /// Each picture once, in the order above.
    public static let choices: [String] = {
        var seen: Set<String> = []
        return (words.map(\.icon) + ["⏱️", "⌛️", fallback]).filter { seen.insert($0).inserted }
    }()

    public static func suggestion(for label: String) -> String? { match(label)?.icon }

    static func match(_ label: String) -> (icon: String, category: TimerCategory)? {
        let text = label.lowercased()
        let tokens = text.split { !$0.isLetter }.map(String.init)
        return words.first { entry in
            entry.words.contains { word in
                word.contains(" ") ? text.contains(word) : tokens.contains { $0 == word || $0 == word + "s" || $0 == word + "es" }
            }
        }.map { ($0.icon, $0.category) }
    }
}
